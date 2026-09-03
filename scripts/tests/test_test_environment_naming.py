import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class TestEnvironmentNamingContractTest(unittest.TestCase):
    def test_release_contract_uses_test_environment_names(self) -> None:
        self.assertTrue(
            (ROOT / ".github" / "workflows" / "app-test-release.yml").is_file()
        )
        self.assertFalse(
            (ROOT / ".github" / "workflows" / "app-staging-release.yml").exists()
        )
        self.assertTrue(
            (ROOT / "scripts" / "validate_test_service_manifests.py").is_file()
        )

        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
        packager = (
            ROOT / "scripts" / "build-flutter-apk-download-site.mjs"
        ).read_text()
        self.assertNotIn('create("staging")', gradle)
        self.assertNotIn('create("test")', gradle)
        self.assertIn('flavor === "unified" ? "test" : flavor', packager)
        self.assertIn("momcozy-unified-android-test", packager)


if __name__ == "__main__":
    unittest.main()
