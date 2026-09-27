import unittest
from unittest.mock import patch

from scripts.prepare_staging_smoke_infant import resolve_infant


BABY_ID = "88f0e03b-6f87-43cb-b485-6339214a8f93"


class StagingSmokeInfantTest(unittest.TestCase):
    def test_fresh_account_confirms_and_checks_its_baby(self) -> None:
        calls = []

        def request(_base, _token, _ca, path, *, payload=None):
            calls.append((path, payload))
            if path == "/v1/onboarding/me":
                return {"status": "required", "profile_confirmed": False}
            if path == "/v1/onboarding/me/profile":
                self.assertEqual(payload["infant_count"], 1)
                self.assertEqual(payload["feeding_methods"], ["direct"])
                return {"status": "completed", "profile_confirmed": True, "primary_infant_id": BABY_ID}
            return {"items": [{"id": BABY_ID}]}

        with patch("scripts.prepare_staging_smoke_infant._request", request):
            self.assertEqual(resolve_infant("https://product.test", "token", "ca.pem"), BABY_ID)
        self.assertEqual([path for path, _ in calls], [
            "/v1/onboarding/me", "/v1/onboarding/me/profile", "/v1/babies",
        ])

    def test_confirmed_account_does_not_write_again(self) -> None:
        calls = []

        def request(_base, _token, _ca, path, *, payload=None):
            calls.append(path)
            if path == "/v1/onboarding/me":
                return {"status": "completed", "profile_confirmed": True, "primary_infant_id": BABY_ID}
            return {"items": [{"id": BABY_ID}]}

        with patch("scripts.prepare_staging_smoke_infant._request", request):
            self.assertEqual(resolve_infant("https://product.test", "token", "ca.pem"), BABY_ID)
        self.assertEqual(calls, ["/v1/onboarding/me", "/v1/babies"])

    def test_mismatched_primary_infant_fails_closed(self) -> None:
        def request(_base, _token, _ca, path, *, payload=None):
            if path == "/v1/onboarding/me":
                return {"status": "completed", "profile_confirmed": True, "primary_infant_id": BABY_ID}
            return {"items": []}

        with patch("scripts.prepare_staging_smoke_infant._request", request):
            with self.assertRaisesRegex(RuntimeError, "Primary infant is not visible"):
                resolve_infant("https://product.test", "token", "ca.pem")


if __name__ == "__main__":
    unittest.main()
