"""B store packages must come from reviewed GitHub CI, never local worktrees."""

import os
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/app-b-store-build.yml"


class BStoreBuildContractTests(unittest.TestCase):
    def test_ipa_entitlements_use_xml_codesign_output(self) -> None:
        text = WORKFLOW.read_text()
        self.assertIn('codesign -d --entitlements :- "${app}" > "${RUNNER_TEMP}/b-exported-entitlements.plist"', text)
        self.assertNotIn('codesign -d --entitlements "${RUNNER_TEMP}/b-exported-entitlements.plist"', text)

    def test_signed_ios_build_pins_xcode_26(self) -> None:
        text = WORKFLOW.read_text()
        self.assertIn("  ios:\n    needs: preflight\n    runs-on: macos-26", text)
        self.assertIn("sudo xcode-select -s /Applications/Xcode_26.6.app/Contents/Developer", text)
        self.assertIn("xcodebuild -version | grep -Fx 'Xcode 26.6'", text)

    def test_workflow_builds_at_exact_remote_dev_commit_after_ci(self) -> None:
        text = WORKFLOW.read_text()
        for required in (
            "tags: ['b-store-v*']", "refs/tags/b-store-v", "github.sha",
            "app-b-ci.yml/runs", "conclusion", "success", "event", "push",
            '.head_branch == "dev"',
            "B tag/version mismatch or previously used build number",
            "CODE_SIGN_STYLE = Manual", "PROVISIONING_PROFILE_SPECIFIER =",
            "CODE_SIGN_IDENTITY = Apple Distribution", "b-export-options.plist",
            "B live OpenAPI differs from reviewed App contract",
            "environment: b-store-build", "concurrency:", "cancel-in-progress: false",
            "contents: read", "actions: read", "ref: ${{ github.sha }}",
            "--release-lane north-america-staging",
            "--config config/release-lanes/north-america-staging.ci.json",
            "MOMCOZY_B_IOS_SIGNING_READY", "MOMCOZY_FLUTTER_RELEASE_STORE_FILE",
            "actions/upload-artifact@v4", "sha256sum", "shasum -a 256",
            "B_PLAY_UPLOAD_CERT_SHA256", "keytool -printcert",
            "Verify clean source before ephemeral iOS signing configuration",
            "build/ios/ipa", "build/app/outputs/bundle/playRelease",
            "codesign --verify --deep --strict", "b-exported-entitlements.plist",
            "b-exported-profile.plist", "B_IOS_TEAM_ID: ${{ vars.B_IOS_TEAM_ID }}",
            "plaintext_sha256=", "(cd output && sha256sum", "(cd output && shasum -a 256",
        ):
            self.assertIn(required, text)
        for forbidden in (
            "branches/dev/protection", "environments/b-store-build",  # GITHUB_TOKEN lacks admin:read.
            "pull_request:", "workflow_dispatch:", "branches: [dev]",
            "gh release", "app-staging-release", "MOMCOZY_INTERNAL_INVITE_LOGIN=true",
            "backend-test.lute-momcozylab", "agent-test.lute-momcozylab",
            "curl -k", "--no-codesign", "flutter build apk",
        ):
            self.assertNotIn(forbidden, text)

    def test_store_version_advances_past_uploaded_build_64(self) -> None:
        text = (ROOT / "pubspec.yaml").read_text()
        version = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", text, re.M)
        self.assertIsNotNone(version)
        self.assertGreater(int(version.group(2)), 64)

    def test_ios_requires_ci_export_options_after_signing_preflight(self) -> None:
        env = os.environ.copy()
        env.pop("MOMCOZY_API_BASE_URL", None)
        env.pop("MOMCOZY_AGENT_API_BASE_URL", None)
        env["MOMCOZY_B_IOS_SIGNING_READY"] = "1"
        env.pop("MOMCOZY_B_EXPORT_OPTIONS_PLIST", None)
        result = subprocess.run([
            "node", "scripts/build-mobile-app.mjs", "--platform", "ios",
            "--environment", "staging", "--mode", "release", "--format", "ipa",
            "--release-lane", "north-america-staging", "--config",
            "config/release-lanes/north-america-staging.ci.json",
        ], cwd=ROOT, env=env, text=True, capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("export options", result.stderr)
        self.assertNotIn("$ flutter", result.stdout)
        self.assertIn("--export-options-plist", (ROOT / "scripts/build-mobile-app.mjs").read_text())

    def test_b_build_guard_refuses_missing_signing_without_building(self) -> None:
        for platform, output in (("android", "appbundle"), ("ios", "ipa")):
            with self.subTest(platform=platform):
                env = os.environ.copy()
                env.pop("MOMCOZY_API_BASE_URL", None)
                env.pop("MOMCOZY_AGENT_API_BASE_URL", None)
                env.pop("MOMCOZY_B_IOS_SIGNING_READY", None)
                for key in ("MOMCOZY_FLUTTER_RELEASE_STORE_FILE", "MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD",
                            "MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS", "MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD"):
                    env.pop(key, None)
                result = subprocess.run([
                    "node", "scripts/build-mobile-app.mjs", "--platform", platform,
                    "--environment", "staging", "--mode", "release", "--format", output,
                    "--release-lane", "north-america-staging", "--config",
                    "config/release-lanes/north-america-staging.ci.json",
                ], cwd=ROOT, env=env, text=True, capture_output=True, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("signing", result.stderr)
                self.assertNotIn("$ flutter", result.stdout)


if __name__ == "__main__":
    unittest.main()
