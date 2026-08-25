import unittest

from scripts.validate_backend_contract import (
    AGENT_RUNTIME_OPENAPI_PATH,
    PRODUCT_OPENAPI_PATH,
    AGENT_RUNTIME_SERVICE,
    PRODUCT_SERVICE,
    _parse_args,
    _validate_agent_runtime_pattern,
    _validate_service_boundaries,
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
