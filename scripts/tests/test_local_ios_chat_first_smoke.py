from __future__ import annotations

from datetime import date, datetime, timedelta
from pathlib import Path
from sys import path
from unittest import TestCase
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit
from uuid import UUID
from zoneinfo import ZoneInfo

path.insert(0, str(Path(__file__).resolve().parents[1]))

from local_ios_chat_first_smoke import (
    seed_mother_status,
    verify_app_saved_status,
    verify_mother_trend_and_state,
)


class MotherTrendSmokeTest(TestCase):
    def setUp(self) -> None:
        self.today = date(2026, 10, 16)
        self.calls: list[str] = []
        self.saved_status_id: str | None = None

    def request(self, method: str, path: str, token: str) -> dict:
        self.assertEqual((method, token), ("GET", "owner-token"))
        self.calls.append(path)
        route = urlsplit(path)
        query = parse_qs(route.query)
        if route.path == "/v1/records/milk-trends":
            self.assertEqual(query["start_date"], ["2026-10-10"])
            self.assertEqual(query["days"], ["7"])
            self.assertEqual(query["timezone"], ["Asia/Shanghai"])
            return {
                "items": [
                    {
                        "date": (self.today - timedelta(days=6 - index)).isoformat(),
                        "pumping_count": 1 if index == 6 else 0,
                        "pumped_milk_volume_ml": 45 if index == 6 else 0,
                        "measured_only": True,
                        "complete": True,
                    }
                    for index in range(7)
                ],
            }
        self.assertEqual(route.path, "/v1/profile/me-experience")
        self.assertIn("start", query)
        self.assertIn("end", query)
        if self.saved_status_id and datetime.fromisoformat(query["start"][0]).date() == self.today:
            return {"records": [{"id": self.saved_status_id, "kind": "mood", "value": "一般"}]}
        return {"records": []}

    def test_requires_seven_local_days_and_two_real_empty_status_reads(self) -> None:
        with patch("local_ios_chat_first_smoke.request_product_json", side_effect=self.request):
            verify_mother_trend_and_state("owner-token", today=self.today)
        self.assertEqual(len(self.calls), 3)

    def test_rejects_an_incomplete_trend_or_unexpected_status_record(self) -> None:
        def incomplete(method: str, path: str, token: str) -> dict:
            result = self.request(method, path, token)
            if path.startswith("/v1/records/milk-trends?"):
                result["items"][-1]["complete"] = False
            return result

        with patch("local_ios_chat_first_smoke.request_product_json", side_effect=incomplete):
            with self.assertRaisesRegex(RuntimeError, "trend"):
                verify_mother_trend_and_state("owner-token", today=self.today)

        def saved_status(method: str, path: str, token: str) -> dict:
            result = self.request(method, path, token)
            if path.startswith("/v1/profile/me-experience?"):
                result["records"] = [{"kind": "mood", "value": "calm"}]
            return result

        with patch("local_ios_chat_first_smoke.request_product_json", side_effect=saved_status):
            with self.assertRaisesRegex(RuntimeError, "status"):
                verify_mother_trend_and_state("owner-token", today=self.today)

    def test_a_saved_owner_status_is_read_exactly_once(self) -> None:
        self.saved_status_id = "d7107fd0-8938-48d3-bb1a-aee90ba0d61a"
        with patch("local_ios_chat_first_smoke.request_product_json", side_effect=self.request):
            verify_mother_trend_and_state(
                "owner-token", today=self.today, saved_status_id=self.saved_status_id,
            )
        self.assertEqual(len(self.calls), 3)

    def test_a_seeded_status_uses_the_real_owner_mutation_contract(self) -> None:
        now = datetime(2026, 10, 16, 12, 0, tzinfo=ZoneInfo("Asia/Shanghai"))
        with patch("local_ios_chat_first_smoke.request_product_json", side_effect=lambda method, path, token, payload: payload) as request:
            record_id = seed_mother_status("owner-token", now=now)
        UUID(record_id)
        method, route, token, payload = request.call_args.args
        self.assertEqual((method, route, token), (
            "PUT", f"/v1/profile/me-experience/records/{record_id}", "owner-token",
        ))
        self.assertEqual((payload["id"], payload["kind"], payload["value"], payload["fields"]),
                         (record_id, "mood", "一般", {}))
        self.assertLess(datetime.fromisoformat(payload["occurred_at"]), now)

    def test_app_saved_status_requires_exactly_one_real_owner_record(self) -> None:
        record_id = "d7107fd0-8938-48d3-bb1a-aee90ba0d61a"

        def read(method: str, path: str, token: str) -> dict:
            self.assertEqual((method, token), ("GET", "owner-token"))
            url = urlsplit(path)
            self.assertEqual(url.path, "/v1/profile/me-experience")
            query = parse_qs(url.query)
            self.assertEqual(datetime.fromisoformat(query["start"][0]).date(), self.today)
            self.assertEqual(datetime.fromisoformat(query["end"][0]).date(), self.today + timedelta(days=1))
            return {"records": [{"id": record_id, "kind": "mood", "value": "一般"}]}

        with patch("local_dev_refresh_emulator.request_product_json", side_effect=read):
            self.assertEqual(verify_app_saved_status("owner-token", today=self.today), record_id)
        with patch("local_dev_refresh_emulator.request_product_json", return_value={"records": []}):
            with self.assertRaisesRegex(RuntimeError, "exactly one"):
                verify_app_saved_status("owner-token", today=self.today)
