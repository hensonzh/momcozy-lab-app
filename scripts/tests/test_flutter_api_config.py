import os
import subprocess
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BUILD_APP_SCRIPT = PROJECT_ROOT / "scripts" / "build-flutter-app.sh"


class FlutterApiConfigScriptTest(unittest.TestCase):
    def clean_env(self) -> dict[str, str]:
        env = os.environ.copy()
        for name in (
            "MOMCOZY_API_BASE_URL",
            "MOMCOZY_AGENT_API_BASE_URL",
            "MOMCOZY_APK_DART_DEFINES",
            "MOMCOZY_EXTRA_DART_DEFINES",
        ):
            env.pop(name, None)
        return env

    def run_build_config(
        self,
        *,
        flavor: str,
        product_url: str | None = None,
        agent_url: str | None = None,
        extra_defines: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = self.clean_env()
        env["MOMCOZY_APK_FLAVOR"] = flavor
        if product_url is not None:
            env["MOMCOZY_API_BASE_URL"] = product_url
        if agent_url is not None:
            env["MOMCOZY_AGENT_API_BASE_URL"] = agent_url
        if extra_defines is not None:
            env["MOMCOZY_EXTRA_DART_DEFINES"] = extra_defines

        return subprocess.run(
            ["bash", str(BUILD_APP_SCRIPT), "--check-config"],
            cwd=PROJECT_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_local_uses_product_and_agent_defaults(self) -> None:
        result = self.run_build_config(flavor="local")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "Product Backend API: http://127.0.0.1:8769", result.stdout
        )
        self.assertIn(
            "Agent Runtime API:   http://127.0.0.1:8010", result.stdout
        )

    def test_unified_and_production_require_both_urls(self) -> None:
        cases = (
            ("unified", "https://product.example.test", None, "MOMCOZY_AGENT_API_BASE_URL"),
            ("unified", None, "https://agent.example.test", "MOMCOZY_API_BASE_URL"),
            ("production", None, "https://agent.example.test", "MOMCOZY_API_BASE_URL"),
            ("production", "https://product.example.test", None, "MOMCOZY_AGENT_API_BASE_URL"),
        )

        for flavor, product_url, agent_url, missing_name in cases:
            with self.subTest(flavor=flavor, missing_name=missing_name):
                result = self.run_build_config(
                    flavor=flavor,
                    product_url=product_url,
                    agent_url=agent_url,
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(missing_name, result.stderr)

    def test_unified_and_production_reject_loopback_for_either_url(self) -> None:
        cases = (
            (
                "unified",
                "http://127.42.0.7:8769",
                "https://services.example.test/agent",
                "MOMCOZY_API_BASE_URL",
            ),
            (
                "production",
                "https://services.example.test/product",
                "http://[::1]:8010",
                "MOMCOZY_AGENT_API_BASE_URL",
            ),
            (
                "unified",
                "https://services.example.test/product",
                "http://0.0.0.0:8010",
                "MOMCOZY_AGENT_API_BASE_URL",
            ),
            (
                "production",
                "http://localhost:8769",
                "https://services.example.test/agent",
                "MOMCOZY_API_BASE_URL",
            ),
        )

        for flavor, product_url, agent_url, rejected_name in cases:
            with self.subTest(flavor=flavor, rejected_name=rejected_name):
                result = self.run_build_config(
                    flavor=flavor,
                    product_url=product_url,
                    agent_url=agent_url,
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(rejected_name, result.stderr)
                self.assertIn("loopback", result.stderr.lower())

    def test_unified_and_production_require_https_for_both_urls(self) -> None:
        cases = (
            (
                "unified",
                "http://product.example.test",
                "https://agent.example.test",
                "MOMCOZY_API_BASE_URL",
            ),
            (
                "production",
                "https://product.example.test",
                "http://agent.example.test",
                "MOMCOZY_AGENT_API_BASE_URL",
            ),
        )

        for flavor, product_url, agent_url, rejected_name in cases:
            with self.subTest(flavor=flavor, rejected_name=rejected_name):
                result = self.run_build_config(
                    flavor=flavor,
                    product_url=product_url,
                    agent_url=agent_url,
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(rejected_name, result.stderr)
                self.assertIn("HTTPS", result.stderr)

    def test_unified_accepts_valid_product_and_agent_urls_on_same_host(self) -> None:
        result = self.run_build_config(
            flavor="unified",
            product_url="https://services.example.test/product",
            agent_url="https://services.example.test/agent",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "Product Backend API: https://services.example.test/product",
            result.stdout,
        )
        self.assertIn(
            "Agent Runtime API:   https://services.example.test/agent",
            result.stdout,
        )

    def test_extra_defines_cannot_override_reserved_api_urls(self) -> None:
        for reserved_name in (
            "MOMCOZY_API_BASE_URL",
            "MOMCOZY_AGENT_API_BASE_URL",
        ):
            with self.subTest(reserved_name=reserved_name):
                result = self.run_build_config(
                    flavor="unified",
                    product_url="https://product.example.test",
                    agent_url="https://agent.example.test",
                    extra_defines=f"FEATURE_FLAG=1,{reserved_name}=http://127.0.0.1:1",
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn("MOMCOZY_EXTRA_DART_DEFINES", result.stderr)
                self.assertIn(reserved_name, result.stderr)

    def test_low_level_apk_wrapper_validates_before_building(self) -> None:
        result = subprocess.run(
            [
                "node",
                "scripts/build-flutter-android-apk.mjs",
                "--check-config",
                "--mode",
                "release",
                "--flavor",
                "unified",
            ],
            cwd=PROJECT_ROOT,
            env=self.clean_env(),
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MOMCOZY_API_BASE_URL", result.stderr)
        self.assertNotIn("flutter clean", result.stdout)

    def test_download_site_wrapper_validates_before_packaging(self) -> None:
        env = self.clean_env()
        env["MOMCOZY_APK_FLAVOR"] = "production"
        result = subprocess.run(
            ["node", "scripts/build-flutter-apk-download-site.mjs", "--check-config"],
            cwd=PROJECT_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MOMCOZY_API_BASE_URL", result.stderr)
        self.assertNotIn("Missing Node build dependencies", result.stderr)

    def test_release_gate_requires_explicit_test_urls_before_steps(self) -> None:
        result = subprocess.run(
            ["node", "scripts/run-flutter-release-gate.mjs", "--check-config"],
            cwd=PROJECT_ROOT,
            env=self.clean_env(),
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MOMCOZY_API_BASE_URL", result.stderr)
        self.assertNotIn("check-flutter-android-packaging", result.stdout)

    def test_wrappers_accept_valid_configs_without_starting_builds(self) -> None:
        local_apk = subprocess.run(
            [
                "node",
                "scripts/build-flutter-android-apk.mjs",
                "--check-config",
                "--mode",
                "debug",
                "--flavor",
                "local",
            ],
            cwd=PROJECT_ROOT,
            env=self.clean_env(),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(local_apk.returncode, 0, local_apk.stderr)

        download_env = self.clean_env()
        download_env["MOMCOZY_APK_FLAVOR"] = "unified"
        download_env["MOMCOZY_API_BASE_URL"] = (
            "https://services.example.test/product"
        )
        download_env["MOMCOZY_AGENT_API_BASE_URL"] = (
            "https://services.example.test/agent"
        )
        download_site = subprocess.run(
            ["node", "scripts/build-flutter-apk-download-site.mjs", "--check-config"],
            cwd=PROJECT_ROOT,
            env=download_env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(download_site.returncode, 0, download_site.stderr)

        release_env = self.clean_env()
        release_env["MOMCOZY_API_BASE_URL"] = "https://services.example.test/product"
        release_env["MOMCOZY_AGENT_API_BASE_URL"] = (
            "https://services.example.test/agent"
        )
        release_gate = subprocess.run(
            ["node", "scripts/run-flutter-release-gate.mjs", "--check-config"],
            cwd=PROJECT_ROOT,
            env=release_env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(release_gate.returncode, 0, release_gate.stderr)

    def test_download_wrapper_rejects_duplicate_reserved_defines(self) -> None:
        env = self.clean_env()
        env["MOMCOZY_APK_FLAVOR"] = "unified"
        env["MOMCOZY_API_BASE_URL"] = "https://product.example.test"
        env["MOMCOZY_AGENT_API_BASE_URL"] = "https://agent.example.test"
        env["MOMCOZY_APK_DART_DEFINES"] = (
            "FEATURE_FLAG=1,"
            "MOMCOZY_AGENT_API_BASE_URL=http://127.0.0.1:8010"
        )
        result = subprocess.run(
            ["node", "scripts/build-flutter-apk-download-site.mjs", "--check-config"],
            cwd=PROJECT_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MOMCOZY_APK_DART_DEFINES", result.stderr)
        self.assertIn("MOMCOZY_AGENT_API_BASE_URL", result.stderr)


if __name__ == "__main__":
    unittest.main()
