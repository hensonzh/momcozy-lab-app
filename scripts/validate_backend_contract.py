#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_DIR = ROOT / "docs" / "backend-contract"
PRODUCT_OPENAPI_PATH = CONTRACT_DIR / "product.openapi.generated.json"
AGENT_RUNTIME_OPENAPI_PATH = CONTRACT_DIR / "agent-runtime.openapi.generated.json"
SMOKE_FLOWS_PATH = CONTRACT_DIR / "flutter-smoke-flows.json"
FORBIDDEN_REPOSITORY_PATHS = ("production_backend/", "flutter_app/")
PRODUCT_SERVICE = "product"
AGENT_RUNTIME_SERVICE = "agent_runtime"
REQUIRED_AGENT_RUNTIME_PATTERN = "proprietary_runtime"

REQUIRED_OPENAPI_PATHS = {
    PRODUCT_SERVICE: {
        "/v1/auth/register",
        "/v1/auth/verify-email",
        "/v1/auth/reset-password",
        "/v1/auth/me",
        "/v1/auth/signup",
        "/v1/auth/login",
        "/v1/auth/invite-login",
        "/v1/auth/refresh",
        "/v1/auth/logout",
        "/v1/files/upload",
        "/v1/onboarding/me",
        "/v1/onboarding/me/profile",
        "/v1/profile/lactation",
        "/v1/records/feeding",
        "/v1/records/pumping",
        "/v1/records/growth",
        "/v1/schedule",
        "/v1/speech/transcribe-chunk",
        "/v1/realtime-voice-stream",
    },
    AGENT_RUNTIME_SERVICE: {
        "/v1/agent/threads",
        "/v1/agent/threads/{thread_id}/history",
        "/v1/agent/runs",
        "/v1/agent/actions/{action_id}",
        "/v1/agent/actions/{action_id}/confirm",
        "/v1/agent/actions/{action_id}/reject",
        "/v1/agent/runs/{run_id}/events",
        "/v1/agent/runs/{run_id}/stream",
    },
}
REQUIRED_IDEMPOTENT_OPENAPI_OPERATIONS = {
    (AGENT_RUNTIME_SERVICE, "POST", "/v1/agent/runs"),
    (AGENT_RUNTIME_SERVICE, "POST", "/v1/agent/actions/{action_id}/confirm"),
}
REQUIRED_OPENAPI_OPERATIONS = {
    (PRODUCT_SERVICE, "GET", "/v1/onboarding/me"),
    (PRODUCT_SERVICE, "PUT", "/v1/onboarding/me/profile"),
    (PRODUCT_SERVICE, "GET", "/v1/schedule"),
    (PRODUCT_SERVICE, "POST", "/v1/schedule/personal"),
    (PRODUCT_SERVICE, "PATCH", "/v1/schedule/personal/{task_id}"),
}
REQUIRED_QUERY_KEYS = {
    (PRODUCT_SERVICE, "/v1/schedule"): {"start_date", "end_date", "timezone"},
    (
        AGENT_RUNTIME_SERVICE,
        "/v1/agent/runs/{run_id}/stream",
    ): {"after_sequence", "follow"},
    (
        AGENT_RUNTIME_SERVICE,
        "/v1/agent/threads/{thread_id}/history",
    ): {"before_sequence", "limit"},
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
    ("/v1/auth/register", "POST"), ("/v1/auth/verify-registration-code", "POST"),
    ("/v1/auth/verify-email", "POST"),
    ("/v1/auth/resend-verification", "POST"), ("/v1/auth/forgot-password", "POST"),
    ("/v1/auth/reset-password", "POST"),
    ("/v1/auth/logout-session", "POST"),
    ("/v1/auth/signup", "POST"),
    ("/v1/auth/login", "POST"),
    ("/v1/auth/invite-login", "POST"),
    ("/v1/auth/refresh", "POST"),
}


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    errors: list[str] = []
    for document in sorted(CONTRACT_DIR.glob("*.md")):
        content = document.read_text()
        for legacy_path in FORBIDDEN_REPOSITORY_PATHS:
            if legacy_path in content:
                errors.append(
                    f"{document.relative_to(ROOT)} references removed repository "
                    f"wrapper: {legacy_path}"
                )

    schemas = {
        PRODUCT_SERVICE: _read_json_object(args.product_openapi),
        AGENT_RUNTIME_SERVICE: _read_json_object(args.agent_runtime_openapi),
    }
    smoke_flows = _read_json_object(args.smoke_flows)
    service_paths: dict[str, dict[object, object]] = {}
    for service, schema in schemas.items():
        paths = schema.get("paths")
        if not isinstance(paths, dict):
            errors.append(f"{service} OpenAPI snapshot is missing a paths object.")
            paths = {}
        service_paths[service] = paths

    errors.extend(_validate_service_boundaries(service_paths))
    errors.extend(
        _validate_agent_runtime_pattern(
            schemas[AGENT_RUNTIME_SERVICE],
        )
    )
    errors.extend(
        _validate_mobile_wire_contracts(
            schemas[PRODUCT_SERVICE], schemas[AGENT_RUNTIME_SERVICE]
        )
    )

    for service, required_paths in REQUIRED_OPENAPI_PATHS.items():
        paths = service_paths[service]
        for path in sorted(required_paths):
            if path not in paths:
                errors.append(f"Missing required {service} OpenAPI path: {path}")

    for service, method, path in sorted(REQUIRED_IDEMPOTENT_OPENAPI_OPERATIONS):
        paths = service_paths[service]
        operation = _operation(paths, path, method)
        if operation is None:
            errors.append(
                f"Missing required {service} idempotent operation: {method} {path}"
            )
        elif not _requires_idempotency(operation):
            errors.append(
                f"{service} {method} {path} must declare Idempotency-Key."
            )

    for service, method, path in sorted(REQUIRED_OPENAPI_OPERATIONS):
        paths = service_paths[service]
        if _operation(paths, path, method) is None:
            errors.append(
                f"Missing required {service} OpenAPI operation: {method} {path}"
            )

    for (service, path), required_query_keys in sorted(REQUIRED_QUERY_KEYS.items()):
        paths = service_paths[service]
        operation = _operation(paths, path, "GET")
        if operation is None:
            errors.append(
                f"Missing required {service} query operation: GET {path}"
            )
            continue
        query_keys = {
            parameter.get("name")
            for parameter in _list(operation.get("parameters"))
            if isinstance(parameter, dict) and parameter.get("in") == "query"
        }
        missing = sorted(required_query_keys - query_keys)
        if missing:
            errors.append(
                f"{service} GET {path} is missing required query parameters: "
                f"{', '.join(missing)}."
            )

    for flow in _list(smoke_flows.get("flows")):
        flow_name = str(flow.get("name", "<unnamed>"))
        service = flow.get("service")
        if service not in service_paths:
            errors.append(
                f"{flow_name} must declare service as "
                f"{PRODUCT_SERVICE!r} or {AGENT_RUNTIME_SERVICE!r}."
            )
            continue
        paths = service_paths[service]
        for index, step in enumerate(_list(flow.get("steps")), start=1):
            errors.extend(_validate_step(paths, str(service), flow_name, index, step))

    if errors:
        for error in errors:
            print(f"backend-contract: {error}", file=sys.stderr)
        return 1

    print(
        "backend-contract: validated "
        f"{len(smoke_flows.get('flows', []))} smoke flows against "
        f"{len(service_paths[PRODUCT_SERVICE])} Product Backend paths and "
        f"{len(service_paths[AGENT_RUNTIME_SERVICE])} Agent Runtime paths"
    )
    return 0


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate Flutter smoke flows against split backend contracts."
    )
    parser.add_argument(
        "--product-openapi",
        type=Path,
        default=PRODUCT_OPENAPI_PATH,
    )
    parser.add_argument(
        "--agent-runtime-openapi",
        type=Path,
        default=AGENT_RUNTIME_OPENAPI_PATH,
    )
    parser.add_argument(
        "--smoke-flows",
        type=Path,
        default=SMOKE_FLOWS_PATH,
    )
    return parser.parse_args(argv)


def _resolve_schema(document: dict[str, object], schema: object) -> dict[str, object]:
    while isinstance(schema, dict) and isinstance(schema.get("$ref"), str):
        ref = schema["$ref"]
        if not ref.startswith("#/components/schemas/"):
            return {}
        name = ref.rsplit("/", 1)[-1]
        components = document.get("components")
        schemas = components.get("schemas") if isinstance(components, dict) else None
        schema = schemas.get(name) if isinstance(schemas, dict) else None
    return schema if isinstance(schema, dict) else {}


def _validate_mobile_wire_contracts(
    product: dict[str, object], agent: dict[str, object]
) -> list[str]:
    """Guard fields needed by the current Flutter auth and conversation paths.

    Path-only smoke checks cannot detect an added mandatory registration field,
    removed password confirmation, or a thread shape that the client discards.
    """
    errors: list[str] = []

    def operation(
        document: dict[str, object], path: str, method: str
    ) -> dict[str, object]:
        paths = document.get("paths")
        route = paths.get(path) if isinstance(paths, dict) else None
        value = route.get(method.lower()) if isinstance(route, dict) else None
        if not isinstance(value, dict):
            errors.append(f"Missing mobile operation: {method} {path}")
            return {}
        return value

    def request(
        document: dict[str, object], path: str, method: str
    ) -> dict[str, object]:
        value = operation(document, path, method)
        body = value.get("requestBody")
        content = body.get("content") if isinstance(body, dict) else None
        json_body = (
            content.get("application/json") if isinstance(content, dict) else None
        )
        schema = json_body.get("schema") if isinstance(json_body, dict) else None
        return _resolve_schema(document, schema)

    register = request(product, "/v1/auth/register", "POST")
    register_required = set(_list(register.get("required")))
    if register and register_required - {"email"}:
        errors.append(
            "POST /v1/auth/register: App sends only email; server requires "
            + ", ".join(sorted(register_required - {"email"}))
        )

    operation(product, "/v1/auth/verify-registration-code", "POST")
    for path, required_fields in (
        (
            "/v1/auth/verify-email",
            {"email", "token", "password", "confirm_password"},
        ),
        (
            "/v1/auth/reset-password",
            {"email", "token", "new_password", "confirm_password"},
        ),
        (
            "/v1/auth/change-password",
            {"current_password", "new_password", "confirm_password"},
        ),
    ):
        schema = request(product, path, "POST")
        if not schema:
            continue
        properties = schema.get("properties")
        fields = set(properties) if isinstance(properties, dict) else set()
        required = set(_list(schema.get("required")))
        for field in sorted(required_fields - fields):
            errors.append(
                f"POST {path}: App field {field} is absent from request schema"
            )
        for field in sorted(required_fields - required):
            errors.append(f"POST {path}: server must require {field}")

    operation(product, "/v1/onboarding/me", "GET")
    operation(product, "/v1/onboarding/me/profile", "PUT")
    operation(agent, "/v1/agent/threads/{thread_id}/history", "GET")
    # The staging release smoke also lists the newly confirmed baby.
    operation(product, "/v1/babies", "GET")

    components = agent.get("components")
    schemas = components.get("schemas") if isinstance(components, dict) else None
    thread = schemas.get("AgentThreadRead") if isinstance(schemas, dict) else None
    if not isinstance(thread, dict):
        errors.append("AgentThreadRead: thread schema is missing")
    else:
        properties = thread.get("properties")
        fields = set(properties) if isinstance(properties, dict) else set()
        required = set(_list(thread.get("required")))
        for field in sorted({"id", "created_at", "updated_at"} - (fields & required)):
            errors.append(f"AgentThreadRead: App requires non-null {field}")
    return errors


def _validate_service_boundaries(
    service_paths: dict[str, dict[object, object]],
) -> list[str]:
    errors: list[str] = []
    product_agent_paths = sorted(
        str(path)
        for path in service_paths[PRODUCT_SERVICE]
        if str(path).startswith("/v1/agent/")
    )
    for path in product_agent_paths:
        errors.append(
            f"Product Backend OpenAPI must not expose Agent Runtime path: {path}"
        )

    retired_package_paths = sorted(
        str(path)
        for path in service_paths[PRODUCT_SERVICE]
        if str(path).startswith(("/v1/care/", "/v1/ibclc/"))
    )
    for path in retired_package_paths:
        errors.append(f"Product Backend OpenAPI contains retired package path: {path}")

    runtime_exempt_paths = {"/v1/health/live", "/v1/health/ready"}
    invalid_runtime_paths = sorted(
        str(path)
        for path in service_paths[AGENT_RUNTIME_SERVICE]
        if not str(path).startswith("/v1/agent/")
        and path not in runtime_exempt_paths
    )
    for path in invalid_runtime_paths:
        errors.append(
            f"Agent Runtime OpenAPI contains Product Backend-owned path: {path}"
        )
    return errors


def _validate_agent_runtime_pattern(
    schema: dict[str, object],
) -> list[str]:
    components = schema.get("components")
    schemas = components.get("schemas") if isinstance(components, dict) else None
    run_create = (
        schemas.get("AgentRunCreate") if isinstance(schemas, dict) else None
    )
    properties = (
        run_create.get("properties") if isinstance(run_create, dict) else None
    )
    runtime_pattern = (
        properties.get("runtime_pattern")
        if isinstance(properties, dict)
        else None
    )
    variants = (
        runtime_pattern.get("anyOf")
        if isinstance(runtime_pattern, dict)
        else None
    )
    expected_variants = [
        {
            "const": REQUIRED_AGENT_RUNTIME_PATTERN,
            "type": "string",
        },
        {"type": "null"},
    ]
    if variants == expected_variants:
        return []
    return [
        "AgentRunCreate.runtime_pattern must accept only "
        f"{REQUIRED_AGENT_RUNTIME_PATTERN!r}; found {variants!r}."
    ]


def _validate_step(
    paths: dict[object, object],
    service: str,
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
            f"{flow_name}[{index}] {method} {raw_path} is not in "
            f"{service} OpenAPI."
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
