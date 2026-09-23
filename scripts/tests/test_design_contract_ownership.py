from __future__ import annotations

import json
from pathlib import Path
import re
import unittest


APP_ROOT = Path(__file__).resolve().parents[2]
EXTERNAL_ARCHIVE_PATTERN = re.compile(r"(?:\.\./)+design-assets/")
TEXT_SUFFIXES = {".dart", ".json", ".md", ".mjs", ".py", ".yaml", ".yml"}


class DesignContractOwnershipTest(unittest.TestCase):
    def test_current_design_contracts_are_repository_owned(self) -> None:
        for module in ("baby", "cozymate", "schedule"):
            contract_root = APP_ROOT / "design-contract" / module
            self.assertTrue((contract_root / "contract.json").is_file())
            self.assertTrue((contract_root / "evidence.json").is_file())

    def test_app_does_not_depend_on_workspace_design_archive(self) -> None:
        failures: list[str] = []
        for root_name in ("lib", "test", "integration_test", "docs", "design-contract"):
            root = APP_ROOT / root_name
            for path in root.rglob("*"):
                if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                if "/Users/lute/project/momcozy-lab/design-assets" in text:
                    failures.append(str(path.relative_to(APP_ROOT)))
                    continue
                if EXTERNAL_ARCHIVE_PATTERN.search(text):
                    # Policy documentation may name the forbidden path literally.
                    if path not in {
                        APP_ROOT / "README.md",
                        APP_ROOT / "design-contract" / "README.md",
                        APP_ROOT / "design-contract" / "cozymate" / "README.md",
                    }:
                        failures.append(str(path.relative_to(APP_ROOT)))
        self.assertEqual(failures, [])

    def test_committed_me_comparison_paths_are_portable(self) -> None:
        for path in (APP_ROOT / "docs" / "ui-reference" / "me" / "comparisons").rglob("comparison.json"):
            payload = json.loads(path.read_text(encoding="utf-8"))
            for key in ("reference", "actual"):
                value = payload[key]
                self.assertFalse(Path(value).is_absolute(), f"{path}: {key}")
                self.assertTrue((APP_ROOT / value).is_file(), f"{path}: {value}")


if __name__ == "__main__":
    unittest.main()
