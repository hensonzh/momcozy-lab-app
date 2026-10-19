"""The emulator refresh must exercise a genuinely new account and role gate."""

import unittest
from unittest.mock import call, patch
from xml.etree.ElementTree import Element

from scripts import local_dev_refresh_emulator as refresh


class ChatFirstRefreshContractTest(unittest.TestCase):
    def test_default_refresh_stops_at_fresh_onboarding(self):
        account = {'email': 'emulator-new@example.test', 'password': 'local-secret', 'user_id': 'fresh-user'}
        login = [Element('node', {'class': 'android.widget.EditText', 'hint': 'Email'}),
                 Element('node', {'class': 'android.widget.EditText', 'hint': 'Password'}),
                 Element('node', {'class': 'android.widget.Button', 'content-desc': 'Sign in'})]
        email_entered = [Element('node', {'class': 'android.widget.EditText', 'hint': 'Email',
                                        'text': account['email']})]
        role = [Element('node', {'content-desc': '你是宝宝的哪位家人？'})]
        def wait(_, predicate, description, **kwargs):
            self.assertNotIn(description, ('chat-first home', 'mother stage'))
            return predicate(login if description == 'login form' else
                             email_entered if description == 'email entry' else role)
        with patch.object(refresh, 'adb', side_effect=lambda _, *args, **kwargs: 'app-pid' if 'pidof' in args else '') as adb, \
             patch.object(refresh, 'wait_for', side_effect=wait) as waited, \
             patch.object(refresh, 'ui_nodes', return_value=login), \
             patch.object(refresh, 'find_node', return_value=login[0]), \
             patch.object(refresh, 'wait_for_field_focus'), \
             patch.object(refresh, 'tap_node'), \
             patch.object(refresh, 'type_text'), \
             patch.object(refresh, 'screenshot') as screenshot, \
             patch.object(refresh, 'verify_fresh_chat_first') as verify, \
             patch.object(refresh.time, 'sleep'):
            refresh.install_and_login('emulator-5556', account, 'token')
        self.assertEqual([x.args[2] for x in waited.call_args_list],
                         ['login form', 'email entry', 'fresh-account role selection',
                          'restored fresh-account role selection'])
        self.assertEqual([c.args for c in screenshot.call_args_list],
                         [('emulator-5556', 'login-account.png'), ('emulator-5556', 'role.png')])
        self.assertEqual(verify.call_count, 2)
        self.assertFalse(any('role-father' in str(x) for x in adb.call_args_list))

    def test_ui_nodes_retries_transient_invalid_dump(self):
        valid = "<hierarchy><node class='android.widget.Button' content-desc='Sign in'/></hierarchy>"
        with patch.object(refresh, 'adb', side_effect=['', 'not xml', '', valid]) as adb, \
             patch.object(refresh.time, 'sleep') as sleep:
            nodes = refresh.ui_nodes('emulator-5556')
        self.assertEqual(nodes[0].get('content-desc'), 'Sign in')
        self.assertEqual(adb.call_count, 4)
        sleep.assert_called_once()

    def test_ui_nodes_fails_cleanly_after_bounded_invalid_dumps(self):
        with patch.object(refresh, 'adb', side_effect=['', 'not xml'] * 3), \
             patch.object(refresh.time, 'sleep') as sleep:
            with self.assertRaisesRegex(RuntimeError, 'valid UI hierarchy'):
                refresh.ui_nodes('emulator-5556')
        self.assertEqual(sleep.call_count, 2)

    def test_numeric_onboarding_choice_uses_unit_not_just_digit(self):
        nodes = [Element('node', {'content-desc': '2026 年'}),
                 Element('node', {'content-desc': '2次\n2'})]
        self.assertIs(refresh.labeled_node(nodes, '2次'), nodes[1])

    def test_baby_name_is_exposed_as_an_edit_hint_not_accessibility_text(self):
        node = Element('node', {'class': 'android.widget.EditText',
                                'hint': '宝宝称呼, required\n如何称呼宝宝？\n出生日期, required'})
        self.assertIsNone(refresh.labeled_node([node], '宝宝称呼'))
        self.assertIs(refresh.baby_profile_name_field([node]), node)

    def test_picker_confirmation_accepts_leaf_node_even_when_falsey(self):
        node = Element('node', {'content-desc': 'OK'})
        self.assertFalse(bool(node))
        self.assertIs(refresh.first_exact_labeled_node([node], ('OK', '确定')), node)

    def test_date_picker_matches_exact_day_month_and_year(self):
        from datetime import date
        nodes = [Element('node', {'class': 'android.widget.Button',
                                  'content-desc': '15, Tuesday, October 15, 2024'}),
                 Element('node', {'class': 'android.widget.Button',
                                  'content-desc': '15, Thursday, October 15, 2026'})]
        self.assertIs(refresh.date_picker_day(nodes, date(2026, 10, 15)), nodes[1])

    def test_refresh_role_is_explicitly_bounded(self):
        with patch.dict('os.environ', {'MOMCOZY_LOCAL_REFRESH_ROLE': 'mother'}):
            self.assertEqual(refresh.refresh_role(), 'mother')
        with patch.dict('os.environ', {'MOMCOZY_LOCAL_REFRESH_ROLE': 'invalid'}):
            with self.assertRaisesRegex(RuntimeError, 'MOMCOZY_LOCAL_REFRESH_ROLE'):
                refresh.refresh_role()

    def test_chat_home_detection_uses_visible_actions_not_visual_header(self):
        nodes = [Element("node", {"content-desc": label})
                 for label in ("记录", "听哭闹", "看便便")]
        self.assertTrue(refresh.is_chat_first_home(nodes))
        self.assertFalse(refresh.is_chat_first_home(nodes[:2]))

    def test_mother_refresh_follows_stage_basics_delivery_then_concerns(self):
        steps = []

        def wait(_, predicate, description):
            steps.append(description)
            return Element('node')

        def tap(_, label, **kwargs):
            steps.append(f'tap {label}')

        with patch.object(refresh, 'wait_for', side_effect=wait), \
             patch.object(refresh, 'tap_label', side_effect=tap), \
             patch.object(refresh, 'tap_node'), \
             patch.object(refresh, 'screenshot'):
            refresh.select_mother_flow('emulator-5554')
        self.assertLess(steps.index('mother stage'), steps.index('mother basics'))
        self.assertLess(steps.index('mother basics'), steps.index('mother delivery'))
        self.assertLess(steps.index('mother delivery'), steps.index('mother concerns'))
        self.assertLess(steps.index('mother concerns'), steps.index('tap 奶量够不够'))
        self.assertLess(steps.index('tap 奶量够不够'), steps.index('mother service introduction'))

    def test_emulator_native_latin_keyboard_is_accepted(self):
        native = "com.android.inputmethod.latin/.LatinIME"
        with patch.object(refresh, "adb", side_effect=[native, native, native]) as adb:
            with refresh.latin_keyboard("emulator-5554"):
                pass
        self.assertEqual(adb.call_count, 3)

    def test_fresh_account_has_no_completed_onboarding_or_baby(self):
        responses = [
            {"status": "required", "can_enter_app": False, "role": None,
             "profile_scope": "none", "primary_infant_id": None},
            {"status": "required", "profile_confirmed": False},
            {"items": []},
        ]
        with patch.object(refresh, "request_product_json", side_effect=responses) as request:
            refresh.verify_fresh_chat_first("token")
        self.assertEqual(request.call_args_list, [
            call("GET", "/v1/onboarding/me/chat-first", "token"),
            call("GET", "/v1/onboarding/me", "token"),
            call("GET", "/v1/babies", "token"),
        ])

    def test_fresh_account_rejects_demo_facts_or_premature_confirmation(self):
        with patch.object(refresh, "request_product_json", return_value={
            "status": "completed", "can_enter_app": True,
            "role": "mother", "profile_scope": "legacy_full",
        }):
            with self.assertRaisesRegex(RuntimeError, "not empty"):
                refresh.verify_fresh_chat_first("token")

    def test_role_selection_only_completes_new_contract(self):
        responses = [
            {"status": "completed", "can_enter_app": True, "role": "father",
             "profile_scope": "chat_first", "primary_infant_id": None},
            {"status": "required", "profile_confirmed": False},
            {"items": []},
        ]
        with patch.object(refresh, "request_product_json", side_effect=responses) as request:
            refresh.verify_chat_first_role("token", "father")
        self.assertEqual(len(request.call_args_list), 3)
        self.assertTrue(all(args.args[0] == "GET" for args in request.call_args_list))

    def test_role_selection_rejects_fabricated_legacy_profile(self):
        responses = [
            {"status": "completed", "can_enter_app": True, "role": "father",
             "profile_scope": "chat_first", "primary_infant_id": None},
            {"status": "completed", "profile_confirmed": True},
        ]
        with patch.object(refresh, "request_product_json", side_effect=responses):
            with self.assertRaisesRegex(RuntimeError, "legacy"):
                refresh.verify_chat_first_role("token", "father")

    def test_mother_answers_are_server_owned_without_sample_name(self):
        from datetime import date
        responses = [
            {'age': 30, 'preferred_name': None},
            {'actual_delivery_date': '2026-10-15'},
            {'profile': {'gestation_weeks': 39, 'gestation_days': 0,
                         'baby_count': 1, 'delivery_count': 2},
             'concerns': [{'note': '奶量够不够'}]},
        ]
        with patch.object(refresh, 'request_product_json', side_effect=responses) as request:
            refresh.verify_mother_facts('token', date(2026, 10, 15))
        self.assertEqual(len(request.call_args_list), 3)
        self.assertTrue(request.call_args_list[2].args[1].startswith(
            '/v1/profile/me-experience?start='))

    def test_mother_answers_reject_invented_name(self):
        from datetime import date
        with patch.object(refresh, 'request_product_json',
                          return_value={'age': 30, 'preferred_name': 'Mia'}):
            with self.assertRaisesRegex(RuntimeError, 'sample'):
                refresh.verify_mother_facts('token', date(2026, 10, 15))

    def test_baby_details_smoke_creates_and_reads_back_current_owner_baby(self):
        from datetime import date
        selected = date(2026, 10, 15)
        steps = []

        def wait(_, predicate, description):
            steps.append(description)
            return Element('node')

        draft_nodes = [
            Element('node', {'content-desc': label})
            for label in ('记录', '听哭闹', '看便便')
        ] + [Element('node', {
            'class': 'android.widget.EditText',
            'text': '关于宝宝安全睡眠，我想了解哪些基本注意事项？',
        })]

        with patch.object(refresh, 'wait_for', side_effect=wait), \
             patch.object(refresh, 'tap_label', side_effect=lambda _, text, **kw: steps.append(f'tap {text}')), \
             patch.object(refresh, 'tap_node'), \
             patch.object(refresh, 'wait_for_field_focus'), \
             patch.object(refresh, 'type_text', side_effect=lambda _, text: steps.append(f'typed {text}')), \
             patch.object(refresh, 'adb'), \
             patch.object(refresh, 'ui_nodes', return_value=draft_nodes), \
             patch.object(refresh, 'screenshot', side_effect=lambda _, name: steps.append(f'image {name}')), \
             patch.object(refresh, 'request_product_json', return_value={
                 'items': [{'id': 'baby-1', 'name': 'LocalTestBaby',
                            'birth_date': selected.isoformat(), 'sex': 'female'}],
             }) as request:
            refresh.create_and_open_baby_details('emulator-5554', 'token', selected)
        request.assert_called_once_with('GET', '/v1/babies', 'token')
        self.assertLess(steps.index('empty real baby overview'), steps.index('typed LocalTestBaby'))
        self.assertLess(steps.index('typed LocalTestBaby'), steps.index('Chinese baby details'))
        self.assertLess(steps.index('Chinese baby details'), steps.index('image baby-details.png'))
        self.assertLess(steps.index('tap 带着问题去对话'), steps.index('unsent baby-knowledge draft'))
        self.assertIn('image baby-knowledge-draft.png', steps)

    def test_baby_details_smoke_rejects_unverified_profile(self):
        from datetime import date
        with patch.object(refresh, 'wait_for', return_value=Element('node')), \
             patch.object(refresh, 'tap_label'), \
             patch.object(refresh, 'tap_node'), \
             patch.object(refresh, 'wait_for_field_focus'), \
             patch.object(refresh, 'type_text'), \
             patch.object(refresh, 'adb'), \
             patch.object(refresh, 'ui_nodes', return_value=[Element('node', {'class': 'android.widget.EditText', 'hint': '如何称呼宝宝？'})]), \
             patch.object(refresh, 'screenshot'), \
             patch.object(refresh, 'request_product_json', return_value={'items': []}):
            with self.assertRaisesRegex(RuntimeError, 'not persisted'):
                refresh.create_and_open_baby_details('emulator-5554', 'token', date(2026, 10, 15))


if __name__ == "__main__":
    unittest.main()
