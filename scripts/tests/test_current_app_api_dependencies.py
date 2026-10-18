"""Old UI product APIs must not be reintroduced into the shipped App source."""

import unittest
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[2]
LEGACY_COMPATIBILITY_PATHS = ('/v1/plans', '/v1/support/tickets')


class CurrentAppApiDependenciesTest(unittest.TestCase):
    def test_shipped_dart_sources_do_not_call_legacy_ui_apis(self) -> None:
        for path in (APP_ROOT / 'lib').rglob('*.dart'):
            with self.subTest(path=path.relative_to(APP_ROOT)):
                source = path.read_text(encoding='utf-8')
                for legacy_path in LEGACY_COMPATIBILITY_PATHS:
                    self.assertNotIn(legacy_path, source)


if __name__ == '__main__':
    unittest.main()
