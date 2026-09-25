import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class EnvironmentNamingContractTest(unittest.TestCase):
    def test_staging_release_uses_canonical_environment_names(self) -> None:
        workflow = (
            ROOT / ".github" / "workflows" / "app-staging-release.yml"
        ).read_text()
        packager = (
            ROOT / "scripts" / "build-flutter-apk-download-site.mjs"
        ).read_text()
        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()

        self.assertIn('create("staging")', gradle)
        self.assertNotIn('create("unified")', gradle)
        self.assertIn('const runtimeEnvironment = flavor;', packager)
        self.assertIn("momcozy-staging-android-", packager)
        self.assertIn("MOMCOZY_STAGING_SMOKE", workflow)
        self.assertNotIn("MOMCOZY_ENV=test", workflow + packager)


if __name__ == "__main__":
    unittest.main()
