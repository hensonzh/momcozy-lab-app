"""B App dev CI must compile isolated, non-distributable artifacts only."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/app-b-ci.yml"
TARGET = ROOT / "config/release-lanes/north-america-staging.ci.json"


class BDevCIContractTests(unittest.TestCase):
    def test_dev_pr_and_push_run_all_b_gates_without_release_permissions(self) -> None:
        text = WORKFLOW.read_text()
        self.assertIn("pull_request:\n    branches: [dev]", text)
        self.assertIn("push:\n    branches: [dev]", text)
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("permissions:\n  contents: read", text)
        for name in ("quality", "android-compile", "ios-compile", "golden", "b-ci"):
            self.assertIn(f"  {name}:", text)
        self.assertIn("if: always()", text)
        self.assertIn("needs.quality.result", text)
        self.assertIn("needs.android-compile.result", text)
        self.assertIn("needs.ios-compile.result", text)
        self.assertIn("needs.golden.result", text)
        # Flutter needs root pubspec.yaml/lock and all referenced assets in compile jobs.
        self.assertNotIn("sparse-checkout: |", text)
        for command in (
            "python3 -m unittest discover -s scripts/tests",
            "python3 scripts/validate_backend_contract.py",
            "node scripts/check-flutter-android-packaging.mjs",
            "node scripts/check-flutter-security-privacy.mjs",
            "dart format --output=none --set-exit-if-changed",
            "flutter analyze --no-pub",
            "flutter test --no-pub --exclude-tags=golden",
            "flutter test --no-pub --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=false test/features/auth/release_lane_auth_mode_test.dart",
            "flutter test --no-pub --tags=golden",
            "--flavor play", "--flavor staging", "--simulator", "--no-codesign",
            "prepare_b_ci_config.py",
        ):
            self.assertIn(command, text)
        for forbidden in (
            "secrets.", "packages: write", "contents: write", "docker login",
            "gh release", "app-staging-release", "workflow_run:",
            "momcozy-staging-internal-ca.pem", "backend-test.lute-momcozylab",
            "agent-test.lute-momcozylab", "flutter build appbundle", "flutter build ipa",
            "actions/upload-artifact@",
        ):
            self.assertNotIn(forbidden, text)

    def test_ci_config_compiles_normal_login_against_approved_b_hosts(self) -> None:
        target = json.loads(TARGET.read_text())
        self.assertEqual(target["deploymentTarget"], "north-america-staging")
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "defines.json"
            result = subprocess.run(
                [sys.executable, "scripts/prepare_b_ci_config.py", "--output", str(output)],
                cwd=ROOT, text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            defines = json.loads(output.read_text())
            self.assertEqual(defines, {
                "MOMCOZY_ENV": "staging",
                "MOMCOZY_API_BASE_URL": target["productApiBaseUrl"],
                "MOMCOZY_AGENT_API_BASE_URL": target["agentApiBaseUrl"],
                "MOMCOZY_INTERNAL_INVITE_LOGIN": "false",
            })
            self.assertNotIn("-test.", json.dumps(defines))
        self.assertNotIn(".example", json.dumps(defines))


if __name__ == "__main__":
    unittest.main()
