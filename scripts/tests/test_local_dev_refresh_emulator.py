from __future__ import annotations

from datetime import date

import json
import unittest
from pathlib import Path
from unittest.mock import call, patch
from sys import path

path.insert(0, str(Path(__file__).resolve().parents[1]))
from local_dev_refresh_emulator import (
    account_from_output,
    center_of,
    exact_labeled_node,
    find_node,
    is_login_form,
    latin_keyboard,
    labeled_node,
    nodes_from_xml,
    select_mother_flow,
    type_text,
    verify_chat_first_role,
    verify_fresh_chat_first,
    verify_mother_facts,
    wait_for,
    wait_for_field_focus,
)


UI = '''<hierarchy><node class="android.view.View" content-desc="Welcome back" bounds="[0,0][100,100]"/>
<node class="android.widget.EditText" hint="Email&#10;Email" bounds="[10,20][110,60]"/>
<node class="android.widget.EditText" hint="Password" password="true" bounds="[10,80][110,120]"/>
<node class="android.widget.Button" content-desc="Sign in" bounds="[0,130][120,170]"/></hierarchy>'''


class RefreshEmulatorTest(unittest.TestCase):
    def test_baby_knowledge_smoke_checks_unsent_draft_on_conversation_return(self) -> None:
        source = (Path(__file__).resolve().parents[1] / "local_dev_refresh_emulator.py").read_text()
        self.assertIn('tap_label(device, "带着问题去对话", exact=True)', source)
        self.assertIn('node.get("class") == "android.widget.EditText"', source)
        self.assertIn('"unsent baby-knowledge draft"', source)
        self.assertIn('screenshot(device, "baby-knowledge-draft.png")', source)

    def test_knowledge_row_uses_combined_accessibility_label(self) -> None:
        nodes = nodes_from_xml(
            '<hierarchy><node class="android.widget.Button" '
            'content-desc="宝宝安全睡眠&#10;记录睡眠时长的同时，每次睡眠都要留意安全的睡眠环境。" '
            'bounds="[53,975][1028,1188]"/></hierarchy>'
        )
        self.assertIsNone(exact_labeled_node(nodes, "宝宝安全睡眠"))
        self.assertEqual(labeled_node(nodes, "宝宝安全睡眠"), nodes[0])

    def test_accessibility_selectors_find_fields_and_button(self) -> None:
        nodes = nodes_from_xml(UI)
        email = find_node(nodes, class_name="android.widget.EditText", hint="Email")
        password = find_node(nodes, class_name="android.widget.EditText", hint="Password")
        button = find_node(nodes, class_name="android.widget.Button", description="Sign in")
        self.assertEqual(center_of(email), (60, 40))
        self.assertEqual(center_of(password), (60, 100))
        self.assertEqual(center_of(button), (60, 150))
        with self.assertRaisesRegex(RuntimeError, "More"):
            find_node(nodes, description="More")

    def test_refresh_role_locator_matches_the_current_role_entry(self) -> None:
        source = (Path(__file__).resolve().parents[1] / "local_dev_refresh_emulator.py").read_text()
        self.assertIn('labeled_node(nodes, "你是宝宝的哪位家人？")', source)
        self.assertNotIn('labeled_node(nodes, "你在家庭中的角色是？")', source)

    def test_login_form_detection_does_not_depend_on_brand_title(self) -> None:
        new_login = UI.replace("Welcome back", "Momcozy")
        self.assertTrue(is_login_form(nodes_from_xml(new_login)))
        self.assertFalse(is_login_form(nodes_from_xml(new_login.replace("Sign in", "Create account"))))

    def test_wait_for_accepts_leaf_accessibility_element(self) -> None:
        nodes = nodes_from_xml(UI)
        with patch("local_dev_refresh_emulator.ui_nodes", return_value=nodes):
            found = wait_for("emulator-5554", lambda items: find_node(items, description="Welcome back"), "login", seconds=0.01)
        self.assertEqual(found.get("content-desc"), "Welcome back")

    def test_adb_credentials_are_entered_one_character_at_a_time(self) -> None:
        with patch("local_dev_refresh_emulator.adb") as adb, patch("local_dev_refresh_emulator.time.sleep"):
            type_text("emulator-5554", "a@.b")
        self.assertEqual(adb.call_args_list, [
            call("emulator-5554", "shell", "input", "text", char, secret=True)
            for char in "a@.b"
        ])

    def test_latin_keyboard_restores_original_ime_even_on_failure(self) -> None:
        original = "com.tencent.wetype/.plugin.hld.WxHldService"
        latin = "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME"
        with patch("local_dev_refresh_emulator.adb", side_effect=[original, f"{original}\n{latin}", "", latin, ""]) as adb:
            with self.assertRaisesRegex(RuntimeError, "injected"):
                with latin_keyboard("emulator-5554"):
                    raise RuntimeError("injected")
        self.assertEqual(adb.call_args_list[2], call("emulator-5554", "shell", "ime", "set", latin, capture=True))
        self.assertEqual(adb.call_args_list[-1], call("emulator-5554", "shell", "ime", "set", original, capture=True))

    def test_wait_for_field_focus_before_typing(self) -> None:
        focused = nodes_from_xml('<hierarchy><node class="android.widget.EditText" hint="Email" focused="true" bounds="[0,0][10,10]"/></hierarchy>')
        with patch("local_dev_refresh_emulator.ui_nodes", return_value=focused):
            node = wait_for_field_focus("emulator-5554", "Email")
        self.assertEqual(node.get("focused"), "true")

    def test_fresh_account_preflight_rejects_prefilled_role_or_baby(self) -> None:
        fresh = {"status": "required", "can_enter_app": False, "role": None,
                 "profile_scope": "none", "primary_infant_id": None}
        legacy = {"status": "required", "profile_confirmed": False}
        babies = {"items": []}
        with patch("local_dev_refresh_emulator.request_product_json", side_effect=[fresh, legacy, babies]) as request:
            verify_fresh_chat_first("token")
        self.assertEqual(request.call_args_list, [
            call("GET", "/v1/onboarding/me/chat-first", "token"),
            call("GET", "/v1/onboarding/me", "token"),
            call("GET", "/v1/babies", "token"),
        ])
        with patch("local_dev_refresh_emulator.request_product_json", return_value={**fresh, "role": "mother"}):
            with self.assertRaisesRegex(RuntimeError, "not empty"):
                verify_fresh_chat_first("token")
        with patch("local_dev_refresh_emulator.request_product_json", side_effect=[fresh, legacy, {"items": [{"id": "unexpected"}]}]):
            with self.assertRaisesRegex(RuntimeError, "prefilled baby"):
                verify_fresh_chat_first("token")

    def test_saved_role_does_not_complete_legacy_or_fabricate_a_baby(self) -> None:
        role = {"status": "completed", "can_enter_app": True, "role": "father",
                "profile_scope": "chat_first", "primary_infant_id": None}
        legacy = {"status": "required", "profile_confirmed": False}
        with patch("local_dev_refresh_emulator.request_product_json", side_effect=[role, legacy, {"items": []}]) as request:
            verify_chat_first_role("token", "father")
        self.assertEqual([args.args[0] for args in request.call_args_list], ["GET"] * 3)
        with patch("local_dev_refresh_emulator.request_product_json", return_value={**role, "role": "mother"}):
            with self.assertRaisesRegex(RuntimeError, "role did not persist"):
                verify_chat_first_role("token", "father")

    def test_mother_profile_checks_only_actual_saved_answers(self) -> None:
        selected = date(2026, 10, 15)
        def read(method, endpoint, token):
            self.assertEqual((method, token), ("GET", "token"))
            if endpoint == "/v1/profile/me":
                return {"age": 30, "preferred_name": None}
            if endpoint == "/v1/profile/lactation":
                return {"actual_delivery_date": selected.isoformat()}
            self.assertTrue(endpoint.startswith("/v1/profile/me-experience?"))
            return {"profile": {"gestation_weeks": 39, "gestation_days": 0,
                                "baby_count": 1, "delivery_count": 2},
                    "concerns": [{"note": "奶量够不够"}]}
        with patch("local_dev_refresh_emulator.request_product_json", side_effect=read) as request:
            verify_mother_facts("token", selected)
        self.assertEqual([args.args[0] for args in request.call_args_list], ["GET"] * 3)

    def test_mother_delivery_date_comes_from_the_picker_not_a_seed_payload(self) -> None:
        with patch("local_dev_refresh_emulator.date") as clock, \
                patch("local_dev_refresh_emulator.tap_label") as tap, \
                patch("local_dev_refresh_emulator.wait_for", return_value={}), \
                patch("local_dev_refresh_emulator.tap_node"), \
                patch("local_dev_refresh_emulator.screenshot"):
            clock.today.return_value = date(2026, 10, 16)
            selected = select_mother_flow("emulator-5554")
        self.assertEqual(selected, date(2026, 10, 15))
        self.assertIn(call("emulator-5554", "选择分娩日期"), tap.call_args_list)

    def test_account_result_has_unique_local_email_and_safe_input_password(self) -> None:
        data = json.dumps({
            "user_id": "b71883b8-1916-49ee-9c0a-d5149b172107",
            "email": "emulator-123abc123abc123abc123abc123abc12@example.test",
            "password": "Mc123abc123abc123abc123abc123abc12A9",
        })
        self.assertEqual(account_from_output(data)["email"], "emulator-123abc123abc123abc123abc123abc12@example.test")
        with self.assertRaisesRegex(RuntimeError, "invalid fresh account"):
            account_from_output(data.replace("example.test", "example.com"))
        with self.assertRaisesRegex(RuntimeError, "invalid fresh account"):
            account_from_output(data.replace("Mc123abc123abc123abc123abc123abc12A9", "bad password"))


if __name__ == "__main__":
    unittest.main()
