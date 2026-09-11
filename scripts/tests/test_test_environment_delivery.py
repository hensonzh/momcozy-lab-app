import hashlib
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP_CI = ROOT / ".github" / "workflows" / "app-ci.yml"
TEST_RELEASE = ROOT / ".github" / "workflows" / "app-test-release.yml"


def _literal_run_blocks(workflow: str) -> list[str]:
    lines = workflow.splitlines()
    blocks: list[str] = []
    for index, line in enumerate(lines):
        if line.strip() != "run: |":
            continue
        indentation = len(line) - len(line.lstrip())
        block: list[str] = []
        for candidate in lines[index + 1 :]:
            if candidate and len(candidate) - len(candidate.lstrip()) <= indentation:
                break
            block.append(candidate)
        blocks.append("\n".join(block))
    return blocks


class TestDeliveryContractTest(unittest.TestCase):
    def test_unified_flavor_is_install_and_publish_isolated(self) -> None:
        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
        packaging = (ROOT / "scripts" / "check-flutter-android-packaging.mjs").read_text()
        pubspec = (ROOT / "pubspec.yaml").read_text()

        self.assertRegex(
            gradle,
            r'create\("unified"\)[\s\S]*applicationIdSuffix = "\.unified"',
        )
        self.assertIn("android/app/src/unified/res/values/strings.xml", packaging)
        version_match = re.search(r"^version:\s*[^+\s]+\+(\d+)$", pubspec, re.MULTILINE)
        self.assertIsNotNone(version_match)
        self.assertGreaterEqual(int(version_match.group(1)), 56)

    def test_unified_api_config_uses_test_network_rules(self) -> None:
        env = os.environ.copy()
        env.update(
            {
                "MOMCOZY_APK_FLAVOR": "unified",
                "MOMCOZY_API_BASE_URL": "https://backend.example.test:8443",
                "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test:8443",
            }
        )
        result = subprocess.run(
            ["bash", "scripts/build-flutter-app.sh", "--check-config"],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Variant:     unified release", result.stdout)

    def test_publish_script_never_clobbers_and_only_writes_unified_namespace(self) -> None:
        script = (ROOT / "scripts" / "build-flutter-app.sh").read_text()
        packager = (
            ROOT / "scripts" / "build-flutter-apk-download-site.mjs"
        ).read_text()

        self.assertNotIn("--clobber", script)
        self.assertIn("MOMCOZY_APK_INPUT", script + packager)
        self.assertIn("unified-android-v", packager)
        self.assertIn("momcozy-unified-android-test", packager)
        self.assertIn('pages_namespace="unified"', script)
        self.assertNotIn('"${pages_checkout}/index.html"', script)
        self.assertIn("gh auth git-credential", script)
        self.assertNotIn('repos/${github_release_repo}/pages', script)

    def test_prebuilt_unified_apk_manifest_records_runtime_and_service_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            apk_input = temporary_path / "verified.apk"
            apk_input.write_bytes(b"verified-unified-apk")
            dist = temporary_path / "dist"
            env = os.environ.copy()
            env.update(
                {
                    "MOMCOZY_APK_FLAVOR": "unified",
                    "MOMCOZY_APK_MODE": "release",
                    "MOMCOZY_APK_INPUT": str(apk_input),
                    "MOMCOZY_DOWNLOAD_DIST": str(dist),
                    "MOMCOZY_DOWNLOAD_BASE_URL": "https://download.example.test/unified",
                    "MOMCOZY_GITHUB_RELEASE_REPO": "example/releases",
                    "MOMCOZY_API_BASE_URL": "https://backend.example.test:8443",
                    "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test:8443",
                    "MOMCOZY_BACKEND_COMMIT_SHA": "a" * 40,
                    "MOMCOZY_BACKEND_IMAGE_DIGEST": "sha256:" + "b" * 64,
                    "MOMCOZY_BACKEND_OPENAPI_SHA256": "c" * 64,
                    "MOMCOZY_AGENT_COMMIT_SHA": "d" * 40,
                    "MOMCOZY_AGENT_IMAGE_DIGEST": "sha256:" + "e" * 64,
                    "MOMCOZY_AGENT_OPENAPI_SHA256": "f" * 64,
                    "MOMCOZY_APK_SIGNING_CERT_SHA256": "1" * 64,
                }
            )
            env.pop("MOMCOZY_REQUIRE_RELEASE_SIGNING", None)

            result = subprocess.run(
                ["node", "scripts/build-flutter-apk-download-site.mjs"],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads((dist / "manifest.json").read_text())
            self.assertEqual(manifest["flavor"], "unified")
            self.assertEqual(manifest["runtimeEnvironment"], "test")
            self.assertEqual(
                manifest["githubReleaseTag"], "unified-android-v1.0.0-57"
            )
            self.assertEqual(
                manifest["apkFile"],
                "momcozy-unified-android-test-1.0.0-57.apk",
            )
            self.assertEqual(
                manifest["sha256"], hashlib.sha256(apk_input.read_bytes()).hexdigest()
            )
            self.assertEqual(
                manifest["sourceServices"]["productBackend"]["commit"],
                "a" * 40,
            )
            self.assertEqual(
                manifest["sourceServices"]["agentRuntime"]["imageDigest"],
                "sha256:" + "e" * 64,
            )
            self.assertEqual(manifest["signingCertSha256"], "1" * 64)
            self.assertRegex(manifest["gitCommit"], r"^[0-9a-f]{40}$")
            provenance = json.loads(
                (dist / "releases" / manifest["provenanceFile"]).read_text()
            )
            self.assertNotIn("generatedAt", provenance)
            self.assertEqual(provenance["sha256"], manifest["sha256"])
            self.assertEqual(
                provenance["sourceServices"], manifest["sourceServices"]
            )

    def test_app_ci_runs_flutter_gates_and_builds_a_test_shaped_artifact(self) -> None:
        workflow = APP_CI.read_text()

        for required in (
            "flutter-version: 3.44.4",
            "dart format --output=none --set-exit-if-changed",
            "flutter analyze --no-pub",
            "flutter test --no-pub",
            "--flavor unified",
            "actions/upload-artifact@",
        ):
            self.assertIn(required, workflow)

    def test_android_gradle_properties_do_not_pin_a_host_aapt2_path(self) -> None:
        properties = (ROOT / "android" / "gradle.properties").read_text()

        self.assertNotIn("android.aapt2FromMavenOverride", properties)

    def test_golden_tests_use_the_canonical_macos_lane(self) -> None:
        workflow = APP_CI.read_text()
        release_gate = (ROOT / "scripts" / "run-flutter-release-gate.mjs").read_text()
        test_config = (ROOT / "dart_test.yaml").read_text()
        flutter_test_config = (ROOT / "test" / "flutter_test_config.dart").read_text()

        self.assertIn("flutter test --no-pub --exclude-tags=golden", workflow)
        self.assertIn("runs-on: macos-15", workflow)
        self.assertIn("flutter test --no-pub --tags=golden", workflow)
        self.assertIn(
            'MOMCOZY_GOLDEN_PRECISION_TOLERANCE: "0.011"',
            workflow,
        )
        self.assertIn(
            '["flutter", ["test", "--no-pub", "--exclude-tags=golden"]',
            release_gate,
        )
        self.assertIn("golden: {}", test_config)
        self.assertIn("class _TolerantGoldenFileComparator", flutter_test_config)
        self.assertIn("result.diffPercent <= _precisionTolerance", flutter_test_config)

        pure_golden_tests = sorted((ROOT / "test").rglob("*_golden_test.dart"))
        self.assertTrue(pure_golden_tests)
        for path in pure_golden_tests:
            self.assertIn("@Tags(['golden'])", path.read_text(), str(path))

    def test_live_test_smoke_runs_inside_the_flutter_test_runtime(self) -> None:
        release_gate = (ROOT / "scripts" / "run-flutter-release-gate.mjs").read_text()
        smoke_source = (
            ROOT / "lib" / "core" / "test_environment" / "test_smoke.dart"
        ).read_text()

        self.assertIn(
            '["flutter", ["test", "--no-pub", "tool/test_environment_smoke_test.dart"]',
            release_gate,
        )
        self.assertNotIn('["dart", ["run", "tool/test_environment_smoke.dart"]', release_gate)
        self.assertTrue(
            (ROOT / "tool" / "test_environment_smoke_test.dart").is_file()
        )
        self.assertIn("buildTestSmokeRunCreateContextProvider", smoke_source)

    def test_test_release_requires_signing_live_join_and_prebuilt_publication(self) -> None:
        workflow = TEST_RELEASE.read_text()

        for required in (
            "workflow_dispatch:",
            "name: test",
            "group: momcozy-lab-app-test",
            "MOMCOZY_REQUIRE_RELEASE_SIGNING: \"1\"",
            "MOMCOZY_REQUIRE_TEST_JOIN_BARRIER: \"1\"",
            "MOMCOZY_TEST_SMOKE: \"1\"",
            "MOMCOZY_TEST_SMOKE_MUTATE: \"1\"",
            "MOMCOZY_TEST_SMOKE_AGENT: \"1\"",
            "MOMCOZY_APK_FLAVOR: unified",
            "MOMCOZY_APK_INPUT",
            "backend_openapi_sha256",
            "agent_openapi_sha256",
            "sha256sum",
            "provenanceFile",
            "TEST_SMOKE_INVITE_CODE",
            "TEST_SMOKE_DEVICE_ID",
            "/v1/auth/invite-login",
            "/usr/bin/flock",
            "test-release.lock",
            "Fetch the currently deployed service manifests again under the lock",
            "Wait for independent test approval",
            "TEST_APPROVERS",
            "TEST_APPROVAL_ISSUE",
            "/approve-test",
            "needs: approve",
            "ref: ${{ github.sha }}",
            "mkfifo -m 0600",
            "cat >/dev/null",
            "tail -f /dev/null",
            "lock_stdin_pid",
            'exec tail -f /dev/null > "${lock_stdin}"',
        ):
            self.assertIn(required, workflow)

        self.assertNotIn("TEST_APP_API_TOKEN", workflow)
        self.assertNotIn("TEST_APP_BABY_ID", workflow)
        self.assertNotIn("GITHUB_TRIGGERING_ACTOR", workflow)
        self.assertNotIn("Ignoring self-approval", workflow)
        self.assertNotIn("ref: main", workflow)
        self.assertNotIn("exec sleep 2700", workflow)
        self.assertNotIn("while :; do sleep 60; done", workflow)
        self.assertLess(
            workflow.index('kill "${lock_stdin_pid}"'),
            workflow.index('kill "${lock_pid}"'),
        )
        self.assertIn('rm -f "${lock_stdin}"', workflow)
        self.assertNotIn(
            "MOMCOZY_FLUTTER_RELEASE_STORE_FILE: ${{ runner.temp }}", workflow
        )
        self.assertIn(
            "RELEASE_STORE_FILE: ${{ runner.temp }}/momcozy-release.jks",
            workflow,
        )
        self.assertIn("github.ref == 'refs/heads/main'", workflow)
        for run_block in _literal_run_blocks(workflow):
            self.assertNotIn("${{ inputs.", run_block)
        self.assertNotIn("subosito/flutter-action@v2", workflow)
        self.assertIn("Resolve or provision the isolated smoke infant", workflow)
        self.assertIn("/v1/profile/infants", workflow)
        self.assertIn("Idempotency-Key", workflow)
        self.assertIn(
            "subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2",
            workflow,
        )
        dependabot = (ROOT / ".github" / "dependabot.yml").read_text()
        self.assertIn("package-ecosystem: github-actions", dependabot)

    def test_release_gate_fails_closed_when_live_join_is_required_but_disabled(self) -> None:
        env = os.environ.copy()
        env.update(
            {
                "MOMCOZY_APK_FLAVOR": "unified",
                "MOMCOZY_API_BASE_URL": "https://backend.example.test:8443",
                "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test:8443",
                "MOMCOZY_REQUIRE_TEST_JOIN_BARRIER": "1",
            }
        )
        env.pop("MOMCOZY_TEST_SMOKE", None)
        env.pop("MOMCOZY_TEST_SMOKE_AGENT", None)

        result = subprocess.run(
            ["node", "scripts/run-flutter-release-gate.mjs", "--check-config"],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MOMCOZY_TEST_SMOKE", result.stderr)


if __name__ == "__main__":
    unittest.main()
