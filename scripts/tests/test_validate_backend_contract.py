import unittest
from copy import deepcopy
import json

from scripts.validate_backend_contract import (
    AGENT_RUNTIME_OPENAPI_PATH,
    PRODUCT_OPENAPI_PATH,
    AGENT_RUNTIME_SERVICE,
    PRODUCT_SERVICE,
    REQUIRED_OPENAPI_PATHS,
    REQUIRED_QUERY_KEYS,
    _parse_args,
    _validate_agent_runtime_pattern,
    _validate_service_boundaries,
    _validate_mobile_wire_contracts,
)


class SplitBackendContractTest(unittest.TestCase):
    def test_defaults_to_independent_product_and_agent_snapshots(self) -> None:
        args = _parse_args([])

        self.assertEqual(args.product_openapi, PRODUCT_OPENAPI_PATH)
        self.assertEqual(args.agent_runtime_openapi, AGENT_RUNTIME_OPENAPI_PATH)

    def test_rejects_routes_owned_by_the_other_service(self) -> None:
        errors = _validate_service_boundaries(
            {
                PRODUCT_SERVICE: {"/v1/agent/runs": {}},
                AGENT_RUNTIME_SERVICE: {"/v1/profile/me": {}},
            }
        )

        self.assertEqual(
            errors,
            [
                "Product Backend OpenAPI must not expose Agent Runtime path: "
                "/v1/agent/runs",
                "Agent Runtime OpenAPI contains Product Backend-owned path: "
                "/v1/profile/me",
            ],
        )

    def test_retired_package_routes_are_not_valid_contract_paths(self) -> None:
        errors = _validate_service_boundaries(
            {
                PRODUCT_SERVICE: {
                    "/v1/care/catalog": {},
                    "/v1/ibclc/me": {},
                    "/v1/plans": {},
                },
                AGENT_RUNTIME_SERVICE: {
                    "/v1/internal/care-reports/generate": {},
                },
            }
        )

        self.assertEqual(
            errors,
            [
                "Product Backend OpenAPI contains retired package path: /v1/care/catalog",
                "Product Backend OpenAPI contains retired package path: /v1/ibclc/me",
                "Agent Runtime OpenAPI contains Product Backend-owned path: "
                "/v1/internal/care-reports/generate",
            ],
        )

    def test_requires_owner_scoped_conversation_history_contract(self) -> None:
        history_path = "/v1/agent/threads/{thread_id}/history"

        self.assertIn(
            history_path,
            REQUIRED_OPENAPI_PATHS[AGENT_RUNTIME_SERVICE],
        )
        self.assertEqual(
            REQUIRED_QUERY_KEYS[(AGENT_RUNTIME_SERVICE, history_path)],
            {"before_sequence", "limit"},
        )

    def test_mobile_auth_wire_contract_rejects_deployed_registration_drift(self) -> None:
        product = json.loads(PRODUCT_OPENAPI_PATH.read_text())
        runtime = json.loads(AGENT_RUNTIME_OPENAPI_PATH.read_text())
        deployed_shape = deepcopy(product)
        registration = deployed_shape["components"]["schemas"]["EmailRegisterRequest"]
        registration["required"] = ["email", "password"]
        deployed_shape["paths"].pop("/v1/auth/verify-registration-code")
        verification = deployed_shape["components"]["schemas"]["EmailChallengeRequest"]
        verification["properties"].pop("confirm_password")
        verification["required"].remove("confirm_password")

        errors = _validate_mobile_wire_contracts(deployed_shape, runtime)
        self.assertTrue(any("/v1/auth/register" in error and "password" in error for error in errors))
        self.assertTrue(any("/v1/auth/verify-registration-code" in error for error in errors))
        self.assertTrue(any("/v1/auth/verify-email" in error and "confirm_password" in error for error in errors))

    def test_mobile_wire_contract_rejects_reset_and_history_drift(self) -> None:
        product = json.loads(PRODUCT_OPENAPI_PATH.read_text())
        runtime = json.loads(AGENT_RUNTIME_OPENAPI_PATH.read_text())
        deployed_product = deepcopy(product)
        deployed_runtime = deepcopy(runtime)
        reset = deployed_product["components"]["schemas"]["PasswordResetConfirmRequest"]
        reset["properties"].pop("confirm_password")
        reset["required"].remove("confirm_password")
        deployed_product["paths"].pop("/v1/auth/change-password")
        thread = deployed_runtime["components"]["schemas"]["AgentThreadRead"]
        thread["properties"].pop("created_at")
        thread["required"].remove("created_at")

        errors = _validate_mobile_wire_contracts(deployed_product, deployed_runtime)
        self.assertTrue(any("/v1/auth/reset-password" in error and "confirm_password" in error for error in errors))
        self.assertTrue(any("/v1/auth/change-password" in error for error in errors))
        self.assertTrue(any("AgentThreadRead" in error and "created_at" in error for error in errors))

    def test_mobile_wire_contract_accepts_current_snapshots(self) -> None:
        product = json.loads(PRODUCT_OPENAPI_PATH.read_text())
        runtime = json.loads(AGENT_RUNTIME_OPENAPI_PATH.read_text())
        self.assertEqual(_validate_mobile_wire_contracts(product, runtime), [])

    def test_requires_the_deployed_proprietary_runtime_pattern(self) -> None:
        def schema(pattern: str) -> dict[str, object]:
            return {
                "components": {
                    "schemas": {
                        "AgentRunCreate": {
                            "properties": {
                                "runtime_pattern": {
                                    "anyOf": [
                                        {"const": pattern, "type": "string"},
                                        {"type": "null"},
                                    ]
                                }
                            }
                        }
                    }
                }
            }

        self.assertEqual(
            _validate_agent_runtime_pattern(schema("proprietary_runtime")),
            [],
        )
        self.assertTrue(
            _validate_agent_runtime_pattern(schema("sdk_only"))[0].startswith(
                "AgentRunCreate.runtime_pattern must accept only"
            )
        )


if __name__ == "__main__":
    unittest.main()
