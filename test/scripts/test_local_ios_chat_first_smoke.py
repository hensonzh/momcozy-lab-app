"""The optional simulator refresh must verify server-owned runs, not UI text guesses."""

import sys
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import call, patch
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import local_ios_chat_first_smoke as smoke


class WelcomeRefreshSmokeContractTest(unittest.TestCase):
    def test_baby_detail_state_is_read_back_for_the_same_baby(self):
        day = datetime.now(ZoneInfo('Asia/Shanghai')).date().isoformat()
        baby_id = 'current-baby'
        records = [
            {'id': 'diaper-1', 'baby_id': baby_id,
             'observation': {'kind': 'diaper', 'diaper_kind': 'wet'}},
            {'id': 'sleep-1', 'baby_id': baby_id,
             'observation': {'kind': 'sleep', 'occurred_at': '2026-10-15T10:00:00Z',
                             'ended_at': '2026-10-15T11:00:00Z'}},
            {'id': 'mood-1', 'baby_id': baby_id,
             'observation': {'kind': 'daily_status', 'recorded_on': day,
                             'mental_state': 'content'}},
        ]
        with patch.object(smoke, 'request_product_json',
                          return_value={'items': records, 'total': 3}):
            smoke.verify_baby_records('token', baby_id)
        with patch.object(smoke, 'request_product_json',
                          return_value={'items': records[:2], 'total': 2}):
            with self.assertRaisesRegex(RuntimeError, 'exactly once'):
                smoke.verify_baby_records('token', baby_id)
        records[-1] = {**records[-1], 'baby_id': 'another-baby'}
        with patch.object(smoke, 'request_product_json',
                          return_value={'items': records, 'total': 3}):
            with self.assertRaisesRegex(RuntimeError, 'wrong baby identity'):
                smoke.verify_baby_records('token', baby_id)

    def test_classifies_completed_welcome_by_source_run_and_signed_marker(self):
        old = "a" * 24
        new = "b" * 24
        messages = [
            {"role": "user", "run_id": "old", "content": {
                "text": f"[Momcozy Chat 欢迎引导][{old}] first",
                "client_context": {"source": "chat_first_welcome"}}},
            {"role": "assistant", "run_id": "old", "content": {"text": "旧资料回复"}},
            {"role": "user", "run_id": "ordinary", "content": {
                "text": "普通对话", "client_context": {}}},
            {"role": "assistant", "run_id": "ordinary", "content": {"text": "普通回答"}},
            {"role": "user", "run_id": "new", "content": {
                "text": f"[Momcozy Chat 欢迎引导][{new}] updated",
                "client_context": {"source": "chat_first_welcome"}}},
            {"role": "assistant", "run_id": "new", "content": {"text": "新资料回复"}},
            {"role": "user", "run_id": "fake", "content": {
                "text": f"[Momcozy Chat 欢迎引导][{old}] untrusted text",
                "client_context": {}}},
        ]
        self.assertEqual(smoke.welcome_runs_from_messages("thread", messages), {
            ("thread", "old"): (old, "旧资料回复"),
            ("thread", "new"): (new, "新资料回复"),
        })

    def test_history_pagination_keeps_the_trigger_and_reply_together(self):
        thread = {"id": "thread-1"}
        replies = [
            {"items": [thread]},
            {"items": [{"role": "assistant", "run_id": "run-1",
                        "content": {"text": "欢迎回复"}}], "next_before_sequence": 2},
            {"items": [{"role": "user", "run_id": "run-1", "content": {
                "text": f"[Momcozy Chat 欢迎引导][{'a' * 24}] hello",
                "client_context": {"source": "chat_first_welcome"}}}],
             "next_before_sequence": None},
        ]
        with patch.object(smoke, "request_agent_json", side_effect=replies) as request:
            runs = smoke.read_welcome_runs("token")
        self.assertEqual(runs, {("thread-1", "run-1"): ("a" * 24, "欢迎回复")})
        self.assertEqual(request.call_args_list, [
            call("/v1/agent/threads?limit=20", "token"),
            call("/v1/agent/threads/thread-1/history?limit=50", "token"),
            call("/v1/agent/threads/thread-1/history?limit=50&before_sequence=2", "token"),
        ])

    def test_refresh_rejects_extra_same_key_and_another_thread(self):
        old = {("thread", "first"): ("a" * 24, "旧回复")}
        smoke.verify_welcome_refresh(old, {
            **old, ("thread", "second"): ("b" * 24, "新回复")})
        for invalid in (
            {**old, ("thread", "second"): ("a" * 24, "重复回复")},
            {**old, ("another", "second"): ("b" * 24, "其他会话")},
            {**old, ("thread", "second"): ("b" * 24, "新回复"),
             ("thread", "third"): ("c" * 24, "多余回复")},
        ):
            with self.assertRaises(RuntimeError):
                smoke.verify_welcome_refresh(old, invalid)


if __name__ == "__main__":
    unittest.main()
