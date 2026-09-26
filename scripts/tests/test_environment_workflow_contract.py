import json
import os
import shutil
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class EnvironmentWorkflowContractTest(unittest.TestCase):
    def test_mobile_environments_are_local_staging_production(self) -> None:
        for environment in ("local", "staging"):
            path = ROOT / "config" / "environments" / f"{environment}.json"
            self.assertTrue(path.is_file(), path)
            payload = json.loads(path.read_text())
            self.assertEqual(payload["MOMCOZY_ENV"], environment)
        self.assertTrue(
            (ROOT / "config" / "environments" / "production.json.example").is_file()
        )

    def test_android_flavors_use_canonical_environment_names(self) -> None:
        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
        self.assertIn('create("local")', gradle)
        self.assertIn('create("staging")', gradle)
        self.assertIn('applicationIdSuffix = ".staging"', gradle)
        self.assertIn('create("production")', gradle)
        self.assertNotIn('create("unified")', gradle)
        self.assertFalse((ROOT / "android" / "app" / "src" / "unified").exists())

    def test_build_and_delivery_entrypoints_are_canonical(self) -> None:
        self.assertTrue((ROOT / "scripts" / "build-mobile-app.mjs").is_file())
        self.assertTrue(
            (ROOT / "scripts" / "validate-workspace-environments.mjs").is_file()
        )
        self.assertTrue(
            (ROOT / "scripts" / "validate_deployed_service_manifests.py").is_file()
        )
        self.assertTrue(
            (ROOT / ".github" / "workflows" / "app-staging-release.yml").is_file()
        )
        self.assertFalse(
            (ROOT / ".github" / "workflows" / "app-test-release.yml").exists()
        )
        self.assertFalse((ROOT / "scripts" / "validate_test_service_manifests.py").exists())

    def test_ios_staging_scheme_uses_an_install_isolated_bundle_id(self) -> None:
        scheme_path = (
            ROOT / "ios" / "Runner.xcodeproj" / "xcshareddata" / "xcschemes" / "staging.xcscheme"
        )
        scheme = ET.parse(scheme_path).getroot()
        for action, configuration in (
            ("LaunchAction", "Debug-staging"),
            ("TestAction", "Debug-staging"),
            ("ProfileAction", "Profile-staging"),
            ("ArchiveAction", "Release-staging"),
        ):
            self.assertEqual(scheme.find(action).attrib["buildConfiguration"], configuration)

        project = (ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj").read_text()
        self.assertEqual(project.count("PRODUCT_BUNDLE_IDENTIFIER = com.momcozy.mai.staging;"), 3)
        self.assertEqual(project.count("DEVELOPMENT_TEAM = YP9F4937J4;"), 6)
        self.assertEqual(
            project.count("PRODUCT_BUNDLE_IDENTIFIER = com.momcozy.mai.staging.RunnerTests;"), 3
        )
        self.assertNotIn("com.momcozymai.app.staging", project)
        for configuration in ("Debug-staging", "Profile-staging", "Release-staging"):
            self.assertEqual(project.count(f"name = {configuration};"), 3)
        self.assertEqual(project.count("PRODUCT_BUNDLE_IDENTIFIER = com.momcozymai.app.flutterpoc;"), 3)

    def test_ios_staging_entrypoint_selects_staging_xcode_scheme(self) -> None:
        import subprocess

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            flutter = root / "flutter" / "bin" / "flutter"
            flutter.parent.mkdir(parents=True)
            flutter.write_text('#!/bin/sh\nprintf "%s\n" "$@" > "$MOMCOZY_CAPTURE_ARGS"\n')
            flutter.chmod(0o755)
            capture = root / "flutter-args.txt"
            env = os.environ | {
                "MOMCOZY_TOOLCHAIN_ROOT": str(root),
                "MOMCOZY_CAPTURE_ARGS": str(capture),
            }
            result = subprocess.run(
                ["node", "scripts/build-mobile-app.mjs", "--platform", "ios",
                 "--environment", "staging", "--mode", "release", "--format", "ios", "--unsigned"],
                cwd=ROOT, env=env, capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = capture.read_text().splitlines()
            self.assertEqual(args[:6], ["build", "ios", "--release", "--no-codesign", "--flavor", "staging"])
            self.assertIn("--dart-define=MOMCOZY_ENV=staging", args)

    def test_standard_build_entrypoint_covers_store_artifacts_and_blocks_provisional_ios_id(self) -> None:
        script = (ROOT / "scripts" / "build-mobile-app.mjs").read_text()
        makefile = (ROOT / "Makefile").read_text()

        self.assertIn('new Set(["apk", "appbundle"])', script)
        self.assertNotIn("App Bundle output is not yet implemented", script)
        self.assertIn("Production iOS build is blocked until the final Bundle ID", script)
        self.assertIn("app-build-production-aab", makefile)
        self.assertIn("app-build-production-ipa", makefile)

    def test_production_ios_stays_blocked_until_bundle_id_is_final(self) -> None:
        import subprocess

        result = subprocess.run(
            [
                "node",
                "scripts/build-mobile-app.mjs",
                "--platform",
                "ios",
                "--environment",
                "production",
                "--mode",
                "release",
                "--format",
                "ipa",
                "--config",
                "config/environments/production.json.example",
                "--check-config",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("final Bundle ID", result.stderr)

    def test_production_example_urls_cannot_be_built(self) -> None:
        import subprocess

        result = subprocess.run(
            [
                "node", "scripts/build-mobile-app.mjs",
                "--platform", "android",
                "--environment", "production",
                "--mode", "debug",
                "--format", "apk",
                "--config", "config/environments/production.json.example",
                "--check-config",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("placeholder", result.stderr)
        self.assertNotIn("$ flutter", result.stdout)

    @unittest.skipUnless(sys.platform == "darwin", "AAPT2 override is macOS-specific")
    def test_android_entrypoint_uses_pinned_local_aapt2(self) -> None:
        import subprocess

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sdk = root / "android-sdk"
            aapt2 = sdk / "build-tools" / "36.0.0" / "aapt2"
            aapt2.parent.mkdir(parents=True)
            aapt2.touch()
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_node = fake_bin / "node"
            # The Gradle property name contains a dot, so use env(1) to inspect it.
            fake_node.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$JAVA_HOME" > "$MOMCOZY_CAPTURE_ENV"\n'
                'env | grep "^ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride=" '
                '>> "$MOMCOZY_CAPTURE_ENV"\n'
            )
            fake_node.chmod(0o755)
            capture = root / "captured.txt"
            env = os.environ.copy()
            env.pop("JAVA_HOME", None)
            env.pop("ANDROID_SDK_ROOT", None)
            env.pop("ANDROID_HOME", None)
            env.pop("ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride", None)
            env.update({
                "MOMCOZY_TOOLCHAIN_ROOT": str(root),
                "MOMCOZY_CAPTURE_ENV": str(capture),
                "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
            })
            result = subprocess.run(
                [shutil.which("node", path=os.environ["PATH"]) or "node",
                 "scripts/build-mobile-app.mjs", "--platform", "android",
                 "--environment", "local", "--mode", "debug", "--format", "apk"],
                cwd=ROOT, env=env, capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(capture.read_text().splitlines(), [
                str(root / "jdk/jdk-17.0.19+10/Contents/Home"),
                f"ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride={aapt2}",
            ])

    def test_active_build_configuration_does_not_use_unified_or_deployable_test(self) -> None:
        paths = [
            ROOT / "scripts" / "flutter-api-config.mjs",
            ROOT / "scripts" / "build-flutter-android-apk.mjs",
            ROOT / "scripts" / "build-flutter-app.sh",
            ROOT / "scripts" / "build-flutter-apk-download-site.mjs",
            ROOT / "scripts" / "run-flutter-release-gate.mjs",
            ROOT / "android" / "app" / "build.gradle.kts",
        ]
        text = "\n".join(path.read_text() for path in paths)
        self.assertNotIn('"unified"', text)
        self.assertNotIn("MOMCOZY_ENV=test", text)


if __name__ == "__main__":
    unittest.main()
