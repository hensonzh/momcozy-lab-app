"""B preflight must not reuse A artifacts or silently compile invite login."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
B_TEMPLATE = ROOT / "config/release-lanes/north-america-staging.json.example"


class StoreReleaseLaneTests(unittest.TestCase):
    def check(self, platform: str, fmt: str, config: Path) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.pop("MOMCOZY_API_BASE_URL", None)
        env.pop("MOMCOZY_AGENT_API_BASE_URL", None)
        return subprocess.run([
            "node", "scripts/build-mobile-app.mjs", "--platform", platform,
            "--environment", "staging", "--mode", "release", "--format", fmt,
            "--release-lane", "north-america-staging", "--config", str(config),
            "--check-config",
        ], cwd=ROOT, env=env, text=True, capture_output=True, check=False)

    def test_b_template_is_not_buildable(self) -> None:
        result = self.check("ios", "ipa", B_TEMPLATE)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("TBD", result.stderr)

    def test_b_android_requires_aab_and_separate_native_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "target.json"
            path.write_text(json.dumps({
                "deploymentTarget": "north-america-staging",
                "runtimeEnvironment": "staging",
                "productApiBaseUrl": "https://backend-us-dev.lute-momcozylab.luteos.cloud",
                "agentApiBaseUrl": "https://agent-us-dev.lute-momcozylab.luteos.cloud",
                "androidApplicationId": "com.momcozy.mai",
                "iosBundleId": "com.momcozy.mai.staging",
            }))
            self.assertIn("appbundle", self.check("android", "apk", path).stderr)
            result = self.check("android", "appbundle", path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Android flavor: play", result.stdout)
            self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN=false", result.stdout)
            result = self.check("ios", "ipa", path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN=false", result.stdout)

            env = os.environ.copy()
            env.pop("MOMCOZY_API_BASE_URL", None)
            env.pop("MOMCOZY_AGENT_API_BASE_URL", None)
            result = subprocess.run([
                "node", "scripts/build-mobile-app.mjs", "--platform", "ios",
                "--environment", "staging", "--mode", "release", "--format", "ipa",
                "--release-lane", "north-america-staging", "--config", str(path),
            ], cwd=ROOT, env=env, text=True, capture_output=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("B build is not enabled", result.stderr)
            self.assertNotIn("$ flutter", result.stdout)

            env["MOMCOZY_API_BASE_URL"] = "https://backend-test.lute-momcozylab.luteos.cloud:8443"
            result = subprocess.run([
                "node", "scripts/build-mobile-app.mjs", "--platform", "ios",
                "--environment", "staging", "--mode", "release", "--format", "ipa",
                "--release-lane", "north-america-staging", "--config", str(path),
                "--check-config",
            ], cwd=ROOT, env=env, text=True, capture_output=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must match the B target", result.stderr)

    def test_b_play_builder_accepts_staging_runtime_only_with_explicit_apis(self) -> None:
        base = ["node", "scripts/build-flutter-android-apk.mjs", "--mode", "release", "--flavor", "play", "--format", "appbundle", "--check-config"]
        for has_apis, args in (
            (False, base),
            (True, base + [
                "--dart-define=MOMCOZY_API_BASE_URL=https://backend-us-dev.lute-momcozylab.luteos.cloud",
                "--dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-us-dev.lute-momcozylab.luteos.cloud",
            ]),
        ):
            with self.subTest(apis=has_apis):
                result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=False)
                if has_apis:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("valid for play", result.stdout)
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("MOMCOZY_API_BASE_URL", result.stderr)

    def test_b_android_build_remains_blocked_without_b_services(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "target.json"
            path.write_text(json.dumps({
                "deploymentTarget": "north-america-staging",
                "runtimeEnvironment": "staging",
                "productApiBaseUrl": "https://backend-us-dev.lute-momcozylab.luteos.cloud",
                "agentApiBaseUrl": "https://agent-us-dev.lute-momcozylab.luteos.cloud",
                "androidApplicationId": "com.momcozy.mai",
                "iosBundleId": "com.momcozy.mai.staging",
            }))
            result = subprocess.run([
                "node", "scripts/build-mobile-app.mjs", "--platform", "android",
                "--environment", "staging", "--mode", "release", "--format", "appbundle",
                "--release-lane", "north-america-staging", "--config", str(path),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("B build is not enabled", result.stderr)
            self.assertNotIn("$ node", result.stdout)

    def test_direct_play_builder_cannot_bypass_b_release_gate(self) -> None:
        result = subprocess.run([
            "node", "scripts/build-flutter-android-apk.mjs", "--mode", "release",
            "--flavor", "play", "--format", "appbundle",
            "--dart-define=MOMCOZY_API_BASE_URL=https://backend-us-dev.lute-momcozylab.luteos.cloud",
            "--dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-us-dev.lute-momcozylab.luteos.cloud",
        ], cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("B build is not enabled", result.stderr)
        self.assertNotIn("$ flutter", result.stdout)

    def test_explicit_a_lane_checks_urls_and_invite_mode(self) -> None:
        config = json.loads((ROOT / "config/environments/staging.json").read_text())
        env = os.environ.copy()
        env.pop("MOMCOZY_API_BASE_URL", None)
        env.pop("MOMCOZY_AGENT_API_BASE_URL", None)
        args = [
            "node", "scripts/build-mobile-app.mjs", "--platform", "android",
            "--environment", "staging", "--mode", "release", "--format", "apk",
            "--release-lane", "legacy-staging", "--check-config",
        ]
        result = subprocess.run(args, cwd=ROOT, env=env, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN=true", result.stdout)
        env["MOMCOZY_AGENT_API_BASE_URL"] = "https://not-a-target.na-reviewed.org"
        result = subprocess.run(args, cwd=ROOT, env=env, text=True, capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("staging.json", result.stderr)

        env.pop("MOMCOZY_AGENT_API_BASE_URL")
        for name in (
            "MOMCOZY_FLUTTER_RELEASE_STORE_FILE",
            "MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD",
            "MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS",
            "MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD",
        ):
            env.pop(name, None)
        result = subprocess.run(args[:-1], cwd=ROOT, env=env, text=True, capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release signing", result.stderr)
        self.assertNotIn("$ node", result.stdout)


if __name__ == "__main__":
    unittest.main()
