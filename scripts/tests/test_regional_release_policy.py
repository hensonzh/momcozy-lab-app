import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RegionalReleasePolicyTest(unittest.TestCase):
    def test_main_push_ci_replaces_pr_quality(self) -> None:
        self.assertFalse((ROOT / ".github/workflows/app-pr-verify.yml").exists())
        workflow = (ROOT / ".github/workflows/app-ci.yml").read_text()
        self.assertIn("push:", workflow)
        self.assertIn("main", workflow)
        self.assertNotIn("pull_request:", workflow)
        self.assertIn("flutter analyze", workflow)
        self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN=true", workflow)
        north_america = (ROOT / ".github/workflows/app-north-america-ci.yml").read_text()
        self.assertIn("MOMCOZY_INTERNAL_INVITE_LOGIN=false", north_america)

    def test_build_workflows_are_main_only(self) -> None:
        for name in ("app-ci.yml", "app-north-america-ci.yml"):
            workflow = (ROOT / ".github/workflows" / name).read_text()
            self.assertNotIn("pull_request:", workflow)
            self.assertIn("main", workflow)
        store = (ROOT / ".github/workflows/app-north-america-store-build.yml").read_text()
        self.assertIn("branches/main", store)
        self.assertIn('.head_branch == "main"', store)
        singapore = (ROOT / ".github/workflows/app-singapore-staging-release.yml").read_text()
        self.assertIn("github.ref == 'refs/heads/main'", singapore)

    def test_existing_package_identities_are_preserved_without_production_target(self) -> None:
        gradle = (ROOT / "android/app/build.gradle.kts").read_text()
        project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        self.assertIn('applicationId = "com.momcozymai.app.flutterpoc"', gradle)
        self.assertIn('applicationIdSuffix = ".staging"', gradle)
        self.assertIn('applicationId = "momcozy.com.mai"', gradle)
        self.assertIn('PRODUCT_BUNDLE_IDENTIFIER = com.momcozy.mai.staging;', project)
        self.assertNotIn('create("production")', gradle)
        self.assertFalse((ROOT / "config/environments/production.json.example").exists())

    def test_staging_without_region_requires_explicit_non_distributable_smoke_mode(self) -> None:
        import os
        import subprocess

        for platform, mode, fmt, extra in (
            ("android", "debug", "apk", []),
            ("android", "release", "apk", []),
            ("ios", "release", "ios", ["--unsigned"]),
        ):
            with self.subTest(platform=platform, mode=mode):
                command = ["node", "scripts/build-mobile-app.mjs", "--platform", platform,
                           "--environment", "staging", "--mode", mode, "--format", fmt,
                           *extra, "--check-config"]
                rejected = subprocess.run(command, cwd=ROOT, env=os.environ.copy(), capture_output=True, text=True)
                self.assertNotEqual(rejected.returncode, 0)
                self.assertIn("--smoke", rejected.stderr)
                allowed = subprocess.run([*command, "--smoke"], cwd=ROOT, env=os.environ.copy(), capture_output=True, text=True)
                self.assertEqual(allowed.returncode == 0, mode != "release" or platform == "ios", allowed.stderr)
                if allowed.returncode == 0:
                    self.assertIn("NON-DISTRIBUTABLE", allowed.stdout)

    def test_smoke_mode_rejects_distributable_outputs_and_region_mixing(self) -> None:
        import subprocess

        for platform, mode, fmt, extra in (
            ("android", "debug", "appbundle", []),
            ("android", "release", "apk", []),
            ("ios", "release", "ipa", ["--unsigned"]),
            ("ios", "release", "ios", []),
            ("android", "release", "apk", ["--release-target", "singapore-staging"]),
        ):
            with self.subTest(platform=platform, fmt=fmt, extra=extra):
                result = subprocess.run(
                    ["node", "scripts/build-mobile-app.mjs", "--platform", platform,
                     "--environment", "staging", "--mode", mode, "--format", fmt,
                     *extra, "--smoke", "--check-config"],
                    cwd=ROOT, capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("$ flutter", result.stdout)

    def test_make_exposes_smoke_targets_instead_of_ambiguous_staging_targets(self) -> None:
        makefile = (ROOT / "Makefile").read_text()
        self.assertIn("app-build-staging-smoke-apk:", makefile)
        self.assertIn("app-build-staging-smoke-ios:", makefile)
        self.assertNotIn("app-build-staging-apk:", makefile)
        self.assertNotIn("app-build-staging-ios:", makefile)
