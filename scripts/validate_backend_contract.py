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

REQUIRED_OPENAPI_PATHS = {
    "/v1/auth/signup",
    "/v1/auth/login",
    "/v1/auth/refresh",
    "/v1/auth/logout",
    "/v1/files/upload",
    "/v1/records/feeding",
    "/v1/records/pumping",
    "/v1/records/growth",
    "/v1/plans",
    "/v1/speech/transcribe-chunk",
    "/v1/realtime-voice-stream",
    "/v1/agent/threads",
    "/v1/agent/runs",
    "/v1/agent/runs/{run_id}/events",
    "/v1/agent/runs/{run_id}/stream",
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
    ("/v1/auth/refresh", "POST"),
}


def main() -> int:
    errors: list[str] = []
    schema = _read_json_object(OPENAPI_PATH)
    smoke_flows = _read_json_object(SMOKE_FLOWS_PATH)
    paths = schema.get("paths")
    if not isinstance(paths, dict):
        errors.append("OpenAPI snapshot is missing a paths object.")
        paths = {}

    for path in sorted(REQUIRED_OPENAPI_PATHS):
        if path not in paths:
            errors.append(f"Missing required OpenAPI path: {path}")

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
