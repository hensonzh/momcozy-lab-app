"""Keep every snapshot-comparing Flutter test in the macOS golden CI lane."""

import re
import unittest
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[2]
GOLDEN_MATCHER = re.compile(r"\bmatchesGoldenFile\s*\(")
GOLDEN_FILE_TAG = re.compile(r"^\s*@Tags\s*\(\s*\[\s*['\"]golden['\"]\s*\]\s*\)\s*\n\s*library\s*;", re.MULTILINE)


class GoldenTaggingTest(unittest.TestCase):
    def test_snapshot_tests_are_tagged_for_the_golden_lane(self) -> None:
        missing_tags = []
        snapshot_tests = 0
        for path in (APP_ROOT / "test").rglob("*_test.dart"):
            content = path.read_text(encoding="utf-8")
            if not GOLDEN_MATCHER.search(content):
                continue
            snapshot_tests += 1
            if not GOLDEN_FILE_TAG.search(content):
                missing_tags.append(str(path.relative_to(APP_ROOT)))
        self.assertGreater(snapshot_tests, 0, "The Golden lane needs real snapshot tests")
        self.assertEqual(missing_tags, [], "Add @Tags(['golden']) to each snapshot test library")


if __name__ == "__main__":
    unittest.main()
