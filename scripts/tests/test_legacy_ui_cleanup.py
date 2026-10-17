"""Prevent the retired screenshot inventory harness from re-entering App CI."""

import unittest
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[2]
RETIRED_REFERENCES = (
    'MOMCOZY_UI_INVENTORY_DIR',
    'ui_inventory_capture.dart',
    'goldens/ui_inventory/',
    'goldens/ui_refactor/',
)


class LegacyUiCleanupTest(unittest.TestCase):
    def test_retired_goldens_and_capture_harness_are_not_executable(self) -> None:
        for directory in ('ui_inventory', 'ui_refactor'):
            self.assertFalse((APP_ROOT / 'test' / 'goldens' / directory).exists())
        self.assertFalse((APP_ROOT / 'test' / 'support' / 'ui_inventory_capture.dart').exists())

        for path in (APP_ROOT / 'test').rglob('*.dart'):
            with self.subTest(path=path.relative_to(APP_ROOT)):
                content = path.read_text(encoding='utf-8')
                for reference in RETIRED_REFERENCES:
                    self.assertNotIn(reference, content)


if __name__ == '__main__':
    unittest.main()
