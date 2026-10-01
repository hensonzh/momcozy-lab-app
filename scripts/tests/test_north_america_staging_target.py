"""B target is a distinct, fail-closed declaration, not an A staging alias."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "scripts/check-north-america-staging-target.mjs"
EXAMPLE = ROOT / "config/release-lanes/north-america-staging.json.example"
A_CONFIG = json.loads((ROOT / "config/environments/staging.json").read_text())


class NorthAmericaStagingTargetTests(unittest.TestCase):
    def check(self, data: dict[str, str]) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "target.json"
            config.write_text(json.dumps(data))
            return subprocess.run(
                ["node", SCRIPT, "--config", str(config)], cwd=ROOT,
                text=True, capture_output=True, check=False,
            )

    def test_template_is_explicitly_unready(self) -> None:
        template = json.loads(EXAMPLE.read_text())
        self.assertEqual(template["productApiBaseUrl"], "https://backend-us-dev.lute-momcozylab.luteos.cloud")
        self.assertEqual(template["agentApiBaseUrl"], "https://agent-us-dev.lute-momcozylab.luteos.cloud")
        result = self.check(template)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("TBD", result.stderr)

    def test_b_cannot_reuse_a_product_or_agent_host(self) -> None:
        data = {
            "deploymentTarget": "north-america-staging",
            "runtimeEnvironment": "staging",
            "productApiBaseUrl": "https://backend-us-dev.lute-momcozylab.luteos.cloud",
            "agentApiBaseUrl": "https://agent-us-dev.lute-momcozylab.luteos.cloud",
            "androidApplicationId": "com.momcozy.mai",
            "iosBundleId": "com.momcozy.mai.staging",
        }
        for field, a_field in (
            ("productApiBaseUrl", "MOMCOZY_API_BASE_URL"),
            ("agentApiBaseUrl", "MOMCOZY_AGENT_API_BASE_URL"),
        ):
            with self.subTest(field=field):
                swapped = data | {field: A_CONFIG[a_field]}
                result = self.check(swapped)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(field, result.stderr)
        result = self.check(data)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("remain unverified", result.stdout)
        self.assertIn("com.momcozy.mai", result.stdout)

        wrong_play_app = data | {"androidApplicationId": "com.momcozy.mai.other"}
        self.assertIn("play flavor", self.check(wrong_play_app).stderr)

        for name in ("productApiBaseUrl", "agentApiBaseUrl"):
            with self.subTest(name=name):
                wrong_origin = data | {name: "https://unapproved.na-reviewed.org"}
                self.assertIn("approved B HTTPS origin", self.check(wrong_origin).stderr)

    def test_b_cannot_reuse_a_android_identity_or_placeholder_domains(self) -> None:
        data = {
            "deploymentTarget": "north-america-staging",
            "runtimeEnvironment": "staging",
            "productApiBaseUrl": "https://backend-us-dev.lute-momcozylab.luteos.cloud",
            "agentApiBaseUrl": "https://agent-us-dev.lute-momcozylab.luteos.cloud",
            "androidApplicationId": "com.momcozymai.app.flutterpoc.staging",
            "iosBundleId": "com.momcozy.mai.staging",
        }
        self.assertIn("androidApplicationId", self.check(data).stderr)
        data["androidApplicationId"] = "com.momcozy.mai"
        data["agentApiBaseUrl"] = "https://agent.example.test"
        self.assertIn("agentApiBaseUrl", self.check(data).stderr)


if __name__ == "__main__":
    unittest.main()
