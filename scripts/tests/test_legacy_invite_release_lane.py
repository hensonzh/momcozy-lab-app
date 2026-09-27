"""A-lane APK publication must be compiled for invite login only."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import json

ROOT = Path(__file__).resolve().parents[2]


class LegacyInviteReleaseLaneTests(unittest.TestCase):
    def _check(self, script: str, *, defines: str, lane: str = "legacy-staging") -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update({
            "MOMCOZY_APK_FLAVOR": "staging",
            "MOMCOZY_APK_MODE": "release",
            "MOMCOZY_API_BASE_URL": "https://product.example.test",
            "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test",
            "MOMCOZY_APK_DART_DEFINES": defines,
            "MOMCOZY_RELEASE_LANE": lane,
        })
        return subprocess.run(["node", script, "--check-config"], cwd=ROOT, env=env, text=True, capture_output=True, check=False)

    def test_release_gate_and_packager_require_invite_mode(self) -> None:
        for script in ("scripts/run-flutter-release-gate.mjs", "scripts/build-flutter-apk-download-site.mjs"):
            with self.subTest(script=script):
                for defines in ("", "MOMCOZY_INTERNAL_INVITE_LOGIN=false", "MOMCOZY_INTERNAL_INVITE_LOGIN=true,MOMCOZY_INTERNAL_INVITE_LOGIN=false"):
                    result = self._check(script, defines=defines)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN", result.stderr)
                result = self._check(script, defines="MOMCOZY_INTERNAL_INVITE_LOGIN=true")
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_manual_legacy_wrapper_forces_invite_mode(self) -> None:
        env = os.environ.copy()
        env.update({
            "MOMCOZY_APK_FLAVOR": "staging",
            "MOMCOZY_API_BASE_URL": "https://product.example.test",
            "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test",
        })
        for extras, ok in (("", True), ("MOMCOZY_INTERNAL_INVITE_LOGIN=false", False), ("MOMCOZY_INTERNAL_INVITE_LOGIN=true", False)):
            with self.subTest(extras=extras):
                env["MOMCOZY_EXTRA_DART_DEFINES"] = extras
                result = subprocess.run(["bash", "scripts/build-flutter-app.sh", "--check-config"], cwd=ROOT, env=env, text=True, capture_output=True, check=False)
                self.assertEqual(result.returncode == 0, ok, result.stderr)
                if not ok:
                    self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN", result.stderr)

    def test_staging_release_workflow_declares_invite_lane(self) -> None:
        workflow = (ROOT / ".github/workflows/app-staging-release.yml").read_text()
        self.assertIn("MOMCOZY_RELEASE_LANE: legacy-staging", workflow)
        self.assertIn("MOMCOZY_APK_DART_DEFINES: MOMCOZY_INTERNAL_INVITE_LOGIN=true", workflow)

    def test_prebuilt_a_apk_without_release_gate_record_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            apk = Path(temporary) / "prebuilt.apk"
            apk.write_bytes(b"unverified apk")
            env = os.environ.copy()
            env.update({
                "MOMCOZY_APK_FLAVOR": "staging",
                "MOMCOZY_APK_MODE": "release",
                "MOMCOZY_API_BASE_URL": "https://product.example.test",
                "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test",
                "MOMCOZY_APK_DART_DEFINES": "MOMCOZY_INTERNAL_INVITE_LOGIN=true",
                "MOMCOZY_RELEASE_LANE": "legacy-staging",
                "MOMCOZY_APK_INPUT": str(apk),
                "MOMCOZY_DOWNLOAD_DIST": str(Path(temporary) / "dist"),
            })
            result = subprocess.run(
                ["node", "scripts/build-flutter-apk-download-site.mjs"],
                cwd=ROOT, env=env, text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("release gate build record", result.stderr)
            self.assertFalse((Path(temporary) / "dist").exists())

    def test_a_publication_cannot_point_at_a_different_target(self) -> None:
        config = json.loads((ROOT / "config/environments/staging.json").read_text())
        env = os.environ.copy()
        env["MOMCOZY_ENFORCE_LEGACY_TARGET"] = "1"
        args = [
            "node", "scripts/flutter-api-config.mjs", "validate",
            "--flavor", "staging",
            "--product-url", config["MOMCOZY_API_BASE_URL"],
            "--agent-url", config["MOMCOZY_AGENT_API_BASE_URL"],
        ]
        result = subprocess.run(args, cwd=ROOT, env=env, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        args[-1] = "https://unrelated-host.na-reviewed.org"
        result = subprocess.run(args, cwd=ROOT, env=env, text=True, capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("config/environments/staging.json", result.stderr)

    def test_a_publication_rejects_missing_release_signing_before_build(self) -> None:
        config = json.loads((ROOT / "config/environments/staging.json").read_text())
        env = os.environ.copy()
        env.update({
            "MOMCOZY_APK_FLAVOR": "staging",
            "MOMCOZY_APK_MODE": "release",
            "MOMCOZY_API_BASE_URL": config["MOMCOZY_API_BASE_URL"],
            "MOMCOZY_AGENT_API_BASE_URL": config["MOMCOZY_AGENT_API_BASE_URL"],
            "MOMCOZY_SKIP_UPLOAD": "0",
        })
        for name in (
            "MOMCOZY_FLUTTER_RELEASE_STORE_FILE",
            "MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD",
            "MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS",
            "MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD",
        ):
            env.pop(name, None)
        result = subprocess.run(
            ["bash", "scripts/build-flutter-app.sh"], cwd=ROOT, env=env,
            text=True, capture_output=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release signing", result.stderr)
        self.assertNotIn("Building momcozy AI Flutter App", result.stdout)


if __name__ == "__main__":
    unittest.main()
