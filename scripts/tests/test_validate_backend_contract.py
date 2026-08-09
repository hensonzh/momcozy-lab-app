from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from scripts.validate_backend_contract import _compare_snapshot


class CompareSnapshotTest(unittest.TestCase):
    def test_accepts_byte_identical_snapshot(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.json"
            local = root / "local.json"
            source.write_bytes(b'{"version": 1}\n')
            local.write_bytes(source.read_bytes())

            self.assertEqual(
                _compare_snapshot(local=local, source=source, label="OpenAPI"),
                [],
            )

    def test_rejects_semantically_similar_but_nonidentical_snapshot(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.json"
            local = root / "local.json"
            source.write_bytes(b'{"version": 1}\n')
            local.write_bytes(b'{"version":1}\n')

            self.assertEqual(
                _compare_snapshot(local=local, source=source, label="OpenAPI"),
                [f"OpenAPI snapshot differs from Agent source: {source}"],
            )

    def test_reports_missing_source_snapshot(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "missing.json"
            local = root / "local.json"
            local.write_text("{}\n")

            self.assertEqual(
                _compare_snapshot(local=local, source=source, label="OpenAPI"),
                [f"Agent source snapshot is missing: {source}"],
            )


if __name__ == "__main__":
    unittest.main()
