from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import call, patch
from sys import path

path.insert(0, str(Path(__file__).resolve().parents[1]))
from local_dev_refresh_emulator import account_from_output, center_of, find_node, is_login_form, latin_keyboard, nodes_from_xml, type_text, wait_for, wait_for_field_focus


UI = '''<hierarchy><node class="android.view.View" content-desc="Welcome back" bounds="[0,0][100,100]"/>
<node class="android.widget.EditText" hint="Email&#10;Email" bounds="[10,20][110,60]"/>
<node class="android.widget.EditText" hint="Password" password="true" bounds="[10,80][110,120]"/>
<node class="android.widget.Button" content-desc="Sign in" bounds="[0,130][120,170]"/></hierarchy>'''


class RefreshEmulatorTest(unittest.TestCase):
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
