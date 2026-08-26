from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any, cast


FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def validate_staging_service_manifests(
    *,
    backend_path: Path,
    agent_path: Path,
    environment: dict[str, str],
) -> None:
    backend = _read_manifest(backend_path)
    agent = _read_manifest(agent_path)
    expected_backend = _expected_identity(environment, "BACKEND")
    expected_agent = _expected_identity(environment, "AGENT")
    _validate_identity(
        path=backend_path,
        manifest=backend,
        service="product-backend",
        expected=expected_backend,
    )
    _validate_identity(
        path=agent_path,
        manifest=agent,
        service="agent-runtime",
        expected=expected_agent,
    )
    dependency = agent.get("product_backend")
    if not isinstance(dependency, dict):
        raise ValueError("Agent Runtime manifest has no Product Backend dependency")
    observed_dependency = {
        "commit": dependency.get("commit"),
        "image_digest": dependency.get("image_digest"),
        "openapi_sha256": dependency.get("openapi_sha256"),
    }
    if observed_dependency != expected_backend:
        raise ValueError(
            "Agent Runtime was not promoted against the requested Product Backend: "
            f"{observed_dependency}"
        )


def _expected_identity(environment: dict[str, str], prefix: str) -> dict[str, str]:
    commit = environment.get(f"MOMCOZY_{prefix}_COMMIT_SHA", "").strip()
    digest = environment.get(f"MOMCOZY_{prefix}_IMAGE_DIGEST", "").strip()
    openapi = environment.get(f"MOMCOZY_{prefix}_OPENAPI_SHA256", "").strip()
    if not FULL_SHA.fullmatch(commit):
        raise ValueError(f"{prefix} commit must be a full lowercase SHA")
    if not IMAGE_DIGEST.fullmatch(digest):
        raise ValueError(f"{prefix} image digest is invalid")
    if not SHA256.fullmatch(openapi):
        raise ValueError(f"{prefix} OpenAPI SHA256 is invalid")
    return {
        "commit": commit,
        "image_digest": digest,
        "openapi_sha256": openapi,
    }


def _validate_identity(
    *,
    path: Path,
    manifest: dict[str, Any],
    service: str,
    expected: dict[str, str],
) -> None:
    observed = {
        "commit": manifest.get("commit"),
        "image_digest": manifest.get("image_digest"),
        "openapi_sha256": manifest.get("openapi_sha256"),
    }
    if manifest.get("service") != service or manifest.get("environment") != "staging":
        raise ValueError(f"{path} has the wrong service/environment identity")
    if observed != expected:
        raise ValueError(f"{path} does not match the requested identity: {observed}")


def _read_manifest(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise ValueError(f"{path} is not a JSON object")
    return cast(dict[str, Any], payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", type=Path, required=True)
    parser.add_argument("--agent", type=Path, required=True)
    args = parser.parse_args()
    validate_staging_service_manifests(
        backend_path=args.backend,
        agent_path=args.agent,
        environment=os.environ,
    )


if __name__ == "__main__":
    main()
