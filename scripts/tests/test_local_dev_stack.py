from __future__ import annotations

import base64
import json
import os
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "local-dev-stack.mjs"


class LocalDevStackTest(unittest.TestCase):
    def test_init_provisions_private_env_and_syncs_service_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            self._write_fixture(workspace)

            result = self._run(workspace, "init")

            self.assertEqual(result.returncode, 0, result.stderr)
            backend = _read_env(workspace / "backend/env/compose.local.env")
            agent = _read_env(workspace / "agent/env/compose.local.env")
            private_key = base64.b64decode(backend["AUTH_JWT_PRIVATE_KEY_B64"])
            self.assertTrue(private_key.startswith(b"-----BEGIN PRIVATE KEY-----"))
            self.assertEqual(
                agent["PRODUCT_BACKEND_BASE_URL"],
                "http://host.docker.internal:8769",
            )
            self.assertEqual(
                agent["AUTH_JWKS_URL"],
                "http://host.docker.internal:8769/.well-known/jwks.json",
            )
            self.assertEqual(
                backend["AGENT_RUNTIME_SERVICE_API_KEY"],
                agent["PRODUCT_BACKEND_SERVICE_KEY"],
            )

    def test_up_dry_run_starts_product_before_agent_and_verifies(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            self._write_fixture(workspace)
            env = {
                "MOMCOZY_LOCAL_DEV_DRY_RUN": "1",
                "MOMCOZY_LOCAL_DEV_SKIP_VERIFY": "1",
            }

            result = self._run(workspace, "up", env)

            self.assertEqual(result.returncode, 0, result.stderr)
            product = result.stdout.index("make backend-local-up")
            agent = result.stdout.index(
                "docker compose -f docker-compose.local.yml up -d --build --wait api worker"
            )
            self.assertLess(product, agent)

    def test_verify_uses_invite_session_across_both_services(self) -> None:
        product = _RecordingServer("product")
        agent = _RecordingServer("agent")
        product.start()
        agent.start()
        self.addCleanup(product.close)
        self.addCleanup(agent.close)

        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            self._write_fixture(workspace)
            result = self._run(
                workspace,
                "verify",
                {
                    "MOMCOZY_LOCAL_PRODUCT_URL": product.url,
                    "MOMCOZY_LOCAL_AGENT_URL": agent.url,
                },
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [request[1] for request in product.requests],
            [
                "/v1/health/ready",
                "/.well-known/jwks.json",
                "/v1/auth/invite-login",
                "/v1/babies",
            ],
        )
        self.assertEqual(
            [request[1] for request in agent.requests],
            ["/v1/health/ready", "/v1/agent/threads?limit=1"],
        )
        self.assertEqual(
            agent.requests[-1][2].get("authorization"),
            "Bearer local-e2e-access-token",
        )

    def _run(
        self,
        workspace: Path,
        command: str,
        extra_env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["MOMCOZY_WORKSPACE_ROOT"] = str(workspace)
        env.update(extra_env or {})
        return subprocess.run(
            ["node", str(SCRIPT), command],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    def _write_fixture(self, workspace: Path) -> None:
        (workspace / "app/scripts").mkdir(parents=True)
        (workspace / "backend/env").mkdir(parents=True)
        (workspace / "agent/env").mkdir(parents=True)
        (workspace / "backend/docker-compose.local.yml").write_text("services: {}\n")
        (workspace / "agent/docker-compose.local.yml").write_text("services: {}\n")
        (workspace / "backend/env/compose.local.env.example").write_text(
            "AUTH_JWT_PRIVATE_KEY_B64=${AUTH_JWT_PRIVATE_KEY_B64}\n"
            "AUTH_JWT_ISSUER=momcozy-local\n"
            "AUTH_JWT_RUNTIME_AUDIENCE=momcozy-agent-runtime\n"
            "AGENT_RUNTIME_SERVICE_API_KEY=local-agent-runtime-service-key-with-at-least-32-bytes\n"
        )
        (workspace / "agent/env/compose.local.env.example").write_text(
            "PRODUCT_BACKEND_BASE_URL=http://host.docker.internal:8000\n"
            "PRODUCT_BACKEND_SERVICE_KEY=local-agent-runtime-service-key-with-at-least-32-bytes\n"
            "AUTH_JWKS_URL=http://host.docker.internal:8000/.well-known/jwks.json\n"
            "AUTH_JWT_ISSUER=momcozy-local\n"
            "AUTH_JWT_AUDIENCE=momcozy-agent-runtime\n"
        )


def _read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


class _RecordingServer:
    def __init__(self, role: str) -> None:
        self.role = role
        self.requests: list[tuple[str, str, dict[str, str]]] = []
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                owner._record(self)
                if self.path == "/.well-known/jwks.json":
                    self._respond({"keys": [{"kid": "local"}]})
                elif self.path == "/v1/agent/threads?limit=1":
                    self._respond({"items": []})
                elif self.path == "/v1/babies":
                    self._respond({"items": []})
                else:
                    self._respond({"status": "ok"})

            def do_POST(self) -> None:
                owner._record(self)
                length = int(self.headers.get("content-length", "0"))
                if length:
                    self.rfile.read(length)
                self._respond(
                    {
                        "access_token": "local-e2e-access-token",
                        "refresh_token": "local-e2e-refresh-token",
                        "token_type": "bearer",
                        "expires_in": 900,
                        "user": {"id": "local-user"},
                    }
                )

            def _respond(self, body: dict[str, object]) -> None:
                payload = json.dumps(body).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def log_message(self, _format: str, *_args: object) -> None:
                return

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.server.server_port}"

    def start(self) -> None:
        self.thread.start()

    def close(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def _record(self, request: BaseHTTPRequestHandler) -> None:
        self.requests.append(
            (
                request.command,
                request.path,
                {key.lower(): value for key, value in request.headers.items()},
            )
        )


if __name__ == "__main__":
    unittest.main()
