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
STAGING_RELEASE = ROOT / ".github" / "workflows" / "app-staging-release.yml"


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


class StagingDeliveryContractTest(unittest.TestCase):
    def test_manual_release_operator_gate(self) -> None:
        workflow = STAGING_RELEASE.read_text()
        self.assertIn("secrets.STAGING_SSH_PRIVATE_KEY", workflow)
        script = _literal_run_blocks(workflow)[0]
        cases = [
            ("Operator, Second", "operator", "SECOND", True),
            ("operator", "stranger", "operator", False),
            ("operator", "operator", "stranger", False),
            ("operator", "oper", "oper", False),
            ("", "operator", "operator", False),
            ("operator,invalid!", "operator", "operator", False),
        ]
        for allowlist, actor, rerun_actor, allowed in cases:
            with self.subTest(allowlist=allowlist, actor=actor, rerun=rerun_actor):
                result = subprocess.run(
                    ["bash", "-c", script],
                    env={**os.environ, "STAGING_APPROVERS": allowlist,
                         "GITHUB_ACTOR": actor, "GITHUB_TRIGGERING_ACTOR": rerun_actor},
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode == 0, allowed, result.stderr)

    def test_staging_release_gate_builds_only_the_distribution_apk(self) -> None:
        script = (ROOT / "scripts/run-flutter-release-gate.mjs").read_text()
        self.assertEqual(script.count('"scripts/build-flutter-android-apk.mjs"'), 1)
        self.assertNotIn('"debug"', script)

    def test_staging_flavor_is_install_and_publish_isolated(self) -> None:
        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
        packaging = (ROOT / "scripts" / "check-flutter-android-packaging.mjs").read_text()
        pubspec = (ROOT / "pubspec.yaml").read_text()

        self.assertRegex(
            gradle,
            r'create\("staging"\)[\s\S]*applicationIdSuffix = "\.staging"',
        )
        self.assertIn("android/app/src/staging/res/values/strings.xml", packaging)
        version_match = re.search(r"^version:\s*[^+\s]+\+(\d+)$", pubspec, re.MULTILINE)
        self.assertIsNotNone(version_match)
        self.assertGreaterEqual(int(version_match.group(1)), 56)

    def test_staging_api_config_uses_https_network_rules(self) -> None:
        env = os.environ.copy()
        env.update(
            {
                "MOMCOZY_APK_FLAVOR": "staging",
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
        self.assertIn("Variant:     staging release", result.stdout)

    def test_publish_script_never_clobbers_and_only_writes_staging_namespace(self) -> None:
        script = (ROOT / "scripts" / "build-flutter-app.sh").read_text()
        packager = (
            ROOT / "scripts" / "build-flutter-apk-download-site.mjs"
        ).read_text()

        self.assertNotIn("--clobber", script)
        self.assertIn("MOMCOZY_APK_INPUT", script + packager)
        self.assertIn("staging-android-v", packager)
        self.assertIn("momcozy-staging-android", packager)
        self.assertIn('pages_namespace="staging"', script)
        self.assertNotIn('"${pages_checkout}/index.html"', script)
        self.assertIn("gh auth git-credential", script)
        self.assertNotIn('repos/${github_release_repo}/pages', script)

    def test_prebuilt_staging_apk_manifest_records_runtime_and_service_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            apk_input = temporary_path / "verified.apk"
            apk_input.write_bytes(b"verified-staging-apk")
            (temporary_path / "verified.apk.build-config.json").write_text(json.dumps({
                "schemaVersion": 1,
                "sha256": hashlib.sha256(apk_input.read_bytes()).hexdigest(),
                "releaseLane": "legacy-staging",
                "flavor": "staging",
                "mode": "release",
                "dartDefines": [
                    "MOMCOZY_API_BASE_URL=https://backend.example.test:8443",
                    "MOMCOZY_AGENT_API_BASE_URL=https://agent.example.test:8443",
                    "MOMCOZY_INTERNAL_INVITE_LOGIN=true",
                ],
            }))
            dist = temporary_path / "dist"
            env = os.environ.copy()
            env.update(
                {
                    "MOMCOZY_APK_FLAVOR": "staging",
                    "MOMCOZY_APK_MODE": "release",
                    "MOMCOZY_RELEASE_LANE": "legacy-staging",
                    "MOMCOZY_APK_DART_DEFINES": "MOMCOZY_INTERNAL_INVITE_LOGIN=true",
                    "MOMCOZY_APK_INPUT": str(apk_input),
                    "MOMCOZY_DOWNLOAD_DIST": str(dist),
                    "MOMCOZY_DOWNLOAD_BASE_URL": "https://download.example.test/staging",
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
            self.assertEqual(manifest["flavor"], "staging")
            self.assertEqual(manifest["runtimeEnvironment"], "staging")
            self.assertEqual(manifest["releaseLane"], "legacy-staging")
            self.assertIs(manifest["inviteLoginOnly"], True)
            version = re.search(
                r"^version:\s*([^+\s]+)\+(\d+)$",
                (ROOT / "pubspec.yaml").read_text(),
                re.MULTILINE,
            )
            self.assertIsNotNone(version)
            name, build = version.groups()
            self.assertEqual(
                manifest["githubReleaseTag"], f"staging-android-v{name}-{build}"
            )
            self.assertEqual(
                manifest["apkFile"],
                f"momcozy-staging-android-{name}-{build}.apk",
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

    def test_app_ci_runs_flutter_gates_and_builds_local_artifact(self) -> None:
        workflow = APP_CI.read_text()

        for required in (
            "flutter-version: 3.44.4",
            "dart format --output=none --set-exit-if-changed",
            "flutter analyze --no-pub",
            "flutter test --no-pub",
            "scripts/build-mobile-app.mjs",
            "--environment local",
            "Build the local debug APK",
        ):
            self.assertIn(required, workflow)
        self.assertNotIn("actions/upload-artifact@", workflow)
        self.assertNotIn("actions/upload-artifact@", STAGING_RELEASE.read_text())

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


    def test_live_staging_smoke_runs_inside_the_flutter_test_runtime(self) -> None:
        release_gate = (ROOT / "scripts" / "run-flutter-release-gate.mjs").read_text()
        smoke_source = (
            ROOT / "lib" / "core" / "staging_environment" / "staging_smoke.dart"
        ).read_text()

        self.assertIn(
            '["flutter", ["test", "--no-pub", "tool/staging_environment_smoke_test.dart"]',
            release_gate,
        )
        self.assertNotIn('["dart", ["run", "tool/test_environment_smoke.dart"]', release_gate)
        self.assertTrue(
            (ROOT / "tool" / "staging_environment_smoke_test.dart").is_file()
        )
        self.assertIn("buildStagingSmokeRunCreateContextProvider", smoke_source)

    def test_staging_release_requires_signing_live_join_and_prebuilt_publication(self) -> None:
        workflow = STAGING_RELEASE.read_text()

        for required in (
            "workflow_dispatch:",
            "name: staging",
            "group: momcozy-lab-app-staging",
            "MOMCOZY_REQUIRE_RELEASE_SIGNING: \"1\"",
            "MOMCOZY_REQUIRE_STAGING_JOIN_BARRIER: \"1\"",
            "MOMCOZY_STAGING_SMOKE: \"1\"",
            "MOMCOZY_STAGING_SMOKE_MUTATE: \"1\"",
            "MOMCOZY_STAGING_SMOKE_AGENT: \"1\"",
            "MOMCOZY_APK_FLAVOR: staging",
            "MOMCOZY_APK_INPUT",
            "backend_openapi_sha256",
            "agent_openapi_sha256",
            "sha256sum",
            "provenanceFile",
            "STAGING_SMOKE_INVITE_CODE",
            "STAGING_SMOKE_DEVICE_ID",
            "/v1/auth/invite-login",
            "/usr/bin/flock",
            "RELEASE_LOCK_PATH",
            "Fetch the currently deployed service manifests again under the lock",
            "Validate the manual release operator",
            "STAGING_APPROVERS",
            "needs: authorize",
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
        self.assertIn("GITHUB_TRIGGERING_ACTOR", workflow)
        self.assertNotIn("/approve-test", workflow)
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
        self.assertIn("Resolve the isolated smoke account onboarding state", workflow)
        smoke_infant = (ROOT / "scripts/prepare_staging_smoke_infant.py").read_text()
        self.assertIn("/v1/onboarding/me/profile", smoke_infant)
        self.assertIn("/v1/babies", smoke_infant)
        self.assertNotIn("/v1/profile/infants", workflow)
        self.assertIn("MOMCOZY_DEFAULT_BABY_ID", smoke_infant)
        self.assertIn(
            "subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2",
            workflow,
        )
        dependabot = (ROOT / ".github" / "dependabot.yml").read_text()
        self.assertIn("package-ecosystem: github-actions", dependabot)

    def test_staging_release_gate_fails_closed_when_live_join_is_required_but_disabled(self) -> None:
        env = os.environ.copy()
        env.update(
            {
                "MOMCOZY_APK_FLAVOR": "staging",
                "MOMCOZY_API_BASE_URL": "https://backend.example.test:8443",
                "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.test:8443",
                "MOMCOZY_REQUIRE_STAGING_JOIN_BARRIER": "1",
            }
        )
        env.pop("MOMCOZY_STAGING_SMOKE", None)
        env.pop("MOMCOZY_STAGING_SMOKE_AGENT", None)

        result = subprocess.run(
            ["node", "scripts/run-flutter-release-gate.mjs", "--check-config"],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MOMCOZY_STAGING_SMOKE", result.stderr)


if __name__ == "__main__":
    unittest.main()
