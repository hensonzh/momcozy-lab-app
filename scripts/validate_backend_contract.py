#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_DIR = ROOT / "docs" / "backend-contract"
OPENAPI_PATH = CONTRACT_DIR / "openapi.generated.json"
SMOKE_FLOWS_PATH = CONTRACT_DIR / "flutter-smoke-flows.json"
FORBIDDEN_REPOSITORY_PATHS = ("production_backend/", "flutter_app/")

REQUIRED_OPENAPI_PATHS = {
    "/v1/auth/signup",
    "/v1/auth/login",
    "/v1/auth/invite-login",
    "/v1/auth/refresh",
    "/v1/auth/logout",
    "/v1/files/upload",
    "/v1/records/feeding",
    "/v1/records/pumping",
    "/v1/records/growth",
    "/v1/plans",
    "/v1/realtime-voice-stream",
    "/v1/agent/threads",
    "/v1/agent/runs",
    "/v1/agent/actions/{action_id}",
    "/v1/agent/actions/{action_id}/confirm",
    "/v1/agent/actions/{action_id}/reject",
    "/v1/agent/runs/{run_id}/events",
    "/v1/agent/runs/{run_id}/stream",
}
FORBIDDEN_OPENAPI_PATHS = {
    "/v1/speech/transcribe-chunk",
}
REQUIRED_IDEMPOTENT_OPENAPI_OPERATIONS = {
    ("POST", "/v1/agent/runs"),
    ("POST", "/v1/agent/actions/{action_id}/confirm"),
}
REQUIRED_OPENAPI_OPERATIONS = {
    ("POST", "/v1/pregnancy-diary/entries"),
    ("PATCH", "/v1/pregnancy-diary/entries/{entry_date}"),
    ("DELETE", "/v1/pregnancy-diary/entries/{entry_date}"),
}
REQUIRED_QUERY_KEYS = {
    "/v1/plans": {"plan_type", "status"},
    "/v1/agent/runs/{run_id}/stream": {"after_sequence", "follow"},
}
FORBIDDEN_QUERY_KEYS = {
    "access_token",
    "api_key",
    "authorization",
    "refresh_token",
    "service_key",
    "token",
}
AUTH_EXEMPT_PATHS = {
    ("/v1/auth/signup", "POST"),
    ("/v1/auth/login", "POST"),
    ("/v1/auth/invite-login", "POST"),
    ("/v1/auth/refresh", "POST"),
}


def main() -> int:
    errors: list[str] = []
    for document in sorted(CONTRACT_DIR.glob("*.md")):
        content = document.read_text()
        for legacy_path in FORBIDDEN_REPOSITORY_PATHS:
            if legacy_path in content:
                errors.append(
                    f"{document.relative_to(ROOT)} references removed repository "
                    f"wrapper: {legacy_path}"
                )

    schema = _read_json_object(OPENAPI_PATH)
    smoke_flows = _read_json_object(SMOKE_FLOWS_PATH)
    paths = schema.get("paths")
    if not isinstance(paths, dict):
        errors.append("OpenAPI snapshot is missing a paths object.")
        paths = {}

    for path in sorted(REQUIRED_OPENAPI_PATHS):
        if path not in paths:
            errors.append(f"Missing required OpenAPI path: {path}")

    for path in sorted(FORBIDDEN_OPENAPI_PATHS):
        if path in paths:
            errors.append(f"Removed OpenAPI path is still present: {path}")

    for method, path in sorted(REQUIRED_IDEMPOTENT_OPENAPI_OPERATIONS):
        operation = _operation(paths, path, method)
        if operation is None:
            errors.append(f"Missing required idempotent operation: {method} {path}")
        elif not _requires_idempotency(operation):
            errors.append(f"{method} {path} must declare Idempotency-Key.")

    for method, path in sorted(REQUIRED_OPENAPI_OPERATIONS):
        if _operation(paths, path, method) is None:
            errors.append(f"Missing required OpenAPI operation: {method} {path}")

    for path, required_query_keys in sorted(REQUIRED_QUERY_KEYS.items()):
        operation = _operation(paths, path, "GET")
        if operation is None:
            errors.append(f"Missing required query operation: GET {path}")
            continue
        query_keys = {
            parameter.get("name")
            for parameter in _list(operation.get("parameters"))
            if isinstance(parameter, dict) and parameter.get("in") == "query"
        }
        missing = sorted(required_query_keys - query_keys)
        if missing:
            errors.append(
                f"GET {path} is missing stream query parameters: "
                f"{', '.join(missing)}."
            )

    for flow in _list(smoke_flows.get("flows")):
        flow_name = str(flow.get("name", "<unnamed>"))
        for index, step in enumerate(_list(flow.get("steps")), start=1):
            errors.extend(_validate_step(paths, flow_name, index, step))

    if errors:
        for error in errors:
            print(f"backend-contract: {error}", file=sys.stderr)
        return 1

    print(
        "backend-contract: validated "
        f"{len(smoke_flows.get('flows', []))} smoke flows against "
        f"{len(paths)} OpenAPI paths"
    )
    return 0


def _validate_step(
    paths: dict[object, object],
    flow_name: str,
    index: int,
    step: object,
) -> list[str]:
    if not isinstance(step, dict):
        return [f"{flow_name}[{index}] step must be an object."]

    method = str(step.get("method", "")).upper()
    raw_path = str(step.get("path", ""))
    normalized_path = _openapi_path(raw_path)
    operation = _operation(paths, normalized_path, method)
    errors: list[str] = []

    if operation is None:
        errors.append(
            f"{flow_name}[{index}] {method} {raw_path} is not in OpenAPI."
        )
    else:
        headers = set(_list(step.get("headers")))
        if _requires_auth(normalized_path, method) and "${auth_header}" not in headers:
            errors.append(
                f"{flow_name}[{index}] {method} {raw_path} is missing auth_header."
            )
        if _requires_idempotency(operation) and "${idempotency_header}" not in headers:
            errors.append(
                f"{flow_name}[{index}] {method} {raw_path} is missing "
                "idempotency_header."
            )

    query_keys = {
        key.lower()
        for key, _ in parse_qsl(urlsplit(raw_path).query, keep_blank_values=True)
    }
    forbidden = sorted(query_keys & FORBIDDEN_QUERY_KEYS)
    if forbidden:
        errors.append(
            f"{flow_name}[{index}] {method} {raw_path} puts secret-shaped "
            f"query keys in the URL: {', '.join(forbidden)}."
        )

    return errors


def _operation(
    paths: dict[object, object],
    openapi_path: str,
    method: str,
) -> dict[object, object] | None:
    path_item = paths.get(openapi_path)
    if not isinstance(path_item, dict):
        return None
    operation = path_item.get(method.lower())
    return operation if isinstance(operation, dict) else None


def _requires_auth(path: str, method: str) -> bool:
    return (path, method) not in AUTH_EXEMPT_PATHS


def _requires_idempotency(operation: dict[object, object]) -> bool:
    for parameter in _list(operation.get("parameters")):
        if not isinstance(parameter, dict):
            continue
        if parameter.get("in") == "header" and parameter.get("name") == "Idempotency-Key":
            return True
    return False


def _openapi_path(raw_path: str) -> str:
    path = urlsplit(raw_path).path
    return re.sub(r"\$\{([^}/]+)\}", r"{\1}", path)


def _read_json_object(path: Path) -> dict[str, object]:
    decoded = json.loads(path.read_text())
    if not isinstance(decoded, dict):
        raise TypeError(f"{path} must contain a JSON object.")
    return decoded


def _list(value: object) -> list[object]:
    return value if isinstance(value, list) else []


if __name__ == "__main__":
    raise SystemExit(main())
