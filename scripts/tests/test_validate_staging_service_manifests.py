import json
import tempfile
import unittest
from pathlib import Path

from scripts.validate_staging_service_manifests import (
    validate_staging_service_manifests,
)


class ValidateStagingServiceManifestsTest(unittest.TestCase):
    def test_requires_exact_joined_service_identity(self) -> None:
        environment = {
            "MOMCOZY_BACKEND_COMMIT_SHA": "a" * 40,
            "MOMCOZY_BACKEND_IMAGE_DIGEST": "sha256:" + "b" * 64,
            "MOMCOZY_BACKEND_OPENAPI_SHA256": "c" * 64,
            "MOMCOZY_AGENT_COMMIT_SHA": "d" * 40,
            "MOMCOZY_AGENT_IMAGE_DIGEST": "sha256:" + "e" * 64,
            "MOMCOZY_AGENT_OPENAPI_SHA256": "f" * 64,
        }
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            backend = root / "backend.json"
            agent = root / "agent.json"
            backend.write_text(
                json.dumps(
                    {
                        "service": "product-backend",
                        "environment": "staging",
                        "commit": "a" * 40,
                        "image_digest": "sha256:" + "b" * 64,
                        "openapi_sha256": "c" * 64,
                    }
                )
            )
            agent_payload = {
                "service": "agent-runtime",
                "environment": "staging",
                "commit": "d" * 40,
                "image_digest": "sha256:" + "e" * 64,
                "openapi_sha256": "f" * 64,
                "product_backend": {
                    "commit": "a" * 40,
                    "image_digest": "sha256:" + "b" * 64,
                    "openapi_sha256": "c" * 64,
                },
            }
            agent.write_text(json.dumps(agent_payload))

            validate_staging_service_manifests(
                backend_path=backend,
                agent_path=agent,
                environment=environment,
            )

            agent_payload["product_backend"]["commit"] = "0" * 40
            agent.write_text(json.dumps(agent_payload))
            with self.assertRaisesRegex(ValueError, "not promoted"):
                validate_staging_service_manifests(
                    backend_path=backend,
                    agent_path=agent,
                    environment=environment,
                )


if __name__ == "__main__":
    unittest.main()
