#!/usr/bin/env python3
"""Resolve a staging smoke infant through the App's onboarding contract.

Only a dedicated invitation account may be used. A previously provisioned account
keeps its baby; an unconfirmed one gets exactly one onboarding confirmation. Any
conflicting pre-existing profile fails closed rather than making a second infant.
"""
from __future__ import annotations

import argparse
import json
import os
import ssl
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from uuid import UUID


def _request(base_url: str, token: str, ca_file: Path, path: str, *, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    context = ssl.create_default_context(cafile=str(ca_file))
    body = json.dumps(payload).encode() if payload is not None else None
    request = Request(
        f"{base_url.rstrip('/')}{path}",
        data=body,
        method="PUT" if body is not None else "GET",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json", **({"Content-Type": "application/json"} if body is not None else {})},
    )
    try:
        with urlopen(request, timeout=12, context=context) as response:
            if response.status != 200:
                raise RuntimeError(f"{path} returned HTTP {response.status}")
            value = json.load(response)
    except HTTPError as exc:
        raise RuntimeError(f"{path} returned HTTP {exc.code}; use a compatible backend and isolated smoke account") from None
    if not isinstance(value, dict):
        raise RuntimeError(f"{path} did not return a JSON object")
    return value


def resolve_infant(base_url: str, token: str, ca_file: Path) -> str:
    state = _request(base_url, token, ca_file, "/v1/onboarding/me")
    if state.get("status") == "required" and state.get("profile_confirmed") is False:
        today = datetime.now(timezone.utc).date().isoformat()
        state = _request(base_url, token, ca_file, "/v1/onboarding/me/profile", payload={
            "stage": "postpartum", "display_name": "Staging Smoke User", "age": 32,
            "delivery_date": today, "client_timezone_offset_minutes": 0,
            "delivery_count": 1, "has_cesarean_history": False,
            "delivery_type": "vaginal", "gestation_weeks": 39, "gestation_days": 2,
            "feeding_methods": ["direct"], "infant_count": 1,
            "infants": [{"nickname": "Staging Smoke Baby", "sex": "female"}],
        })
    if state.get("status") != "completed" or state.get("profile_confirmed") is not True:
        raise RuntimeError("Smoke account onboarding is not confirmed")
    try:
        baby_id = str(UUID(str(state["primary_infant_id"])))
    except (KeyError, TypeError, ValueError) as exc:
        raise RuntimeError("Onboarding returned no valid primary infant") from exc
    babies = _request(base_url, token, ca_file, "/v1/babies")
    items = babies.get("items")
    if not isinstance(items, list) or not any(
        isinstance(baby, dict) and baby.get("id") == baby_id for baby in items
    ):
        raise RuntimeError("Primary infant is not visible in the authenticated owner's baby list")
    return baby_id


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--github-env", type=Path, required=True)
    args = parser.parse_args()
    base_url = os.environ["MOMCOZY_API_BASE_URL"]
    if not base_url.startswith("https://"):
        raise SystemExit("Staging smoke requires HTTPS")
    baby_id = resolve_infant(
        base_url,
        os.environ["MOMCOZY_API_TOKEN"],
        Path(os.environ["SSL_CERT_FILE"]),
    )
    with args.github_env.open("a", encoding="utf-8") as output:
        output.write(f"MOMCOZY_DEFAULT_BABY_ID={baby_id}\n")
    print("Staging smoke account onboarding and infant verified.")


if __name__ == "__main__":
    main()
