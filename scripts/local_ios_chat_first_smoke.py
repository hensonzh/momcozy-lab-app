#!/usr/bin/env python3
"""Exercise a fresh local account through the iOS Simulator chat-first flow."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from datetime import date, datetime, timedelta
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from uuid import uuid4
from zoneinfo import ZoneInfo

from local_dev_refresh_emulator import (
    APP,
    create_account,
    verify_account,
    verify_chat_first_role,
    verify_fresh_chat_first,
    verify_mother_facts,
    verify_app_saved_status,
    request_product_json,
)

BUNDLE_ID = "com.momcozymai.app.flutterpoc"
SCREENSHOTS = APP / "build/ios/chat-first-smoke"
AGENT_URL = os.environ.get("MOMCOZY_AGENT_API_BASE_URL", "http://127.0.0.1:8010").rstrip("/")
WELCOME_MARKER = re.compile(r"^\[Momcozy Chat 欢迎引导\]\[([0-9a-f]{24})\]")


def request_agent_json(path: str, token: str) -> dict:
    request = Request(f"{AGENT_URL}{path}", headers={"Authorization": f"Bearer {token}"})
    try:
        with urlopen(request, timeout=15) as response:
            body = json.load(response)
    except HTTPError as error:
        raise RuntimeError(f"Local Agent history failed (HTTP {error.code}, GET {path})") from None
    if not isinstance(body, dict):
        raise RuntimeError("Local Agent history returned invalid JSON")
    return body


def welcome_runs_from_messages(thread_id: str, messages: list) -> dict[tuple[str, str], tuple[str, str]]:
    triggers: dict[str, str] = {}
    replies: dict[str, str] = {}
    for message in messages:
        if not isinstance(message, dict) or not isinstance(message.get("run_id"), str):
            continue
        content = message.get("content")
        if not isinstance(content, dict) or not isinstance(content.get("text"), str):
            continue
        run_id, text = message["run_id"], content["text"]
        if message.get("role") == "user":
            context = content.get("client_context")
            marker = WELCOME_MARKER.match(text.strip())
            if isinstance(context, dict) and context.get("source") == "chat_first_welcome" and marker:
                triggers[run_id] = marker.group(1)
        elif message.get("role") == "assistant" and text.strip():
            replies[run_id] = text
    return {
        (thread_id, run_id): (signature, replies.get(run_id, ""))
        for run_id, signature in triggers.items()
    }


def read_welcome_runs(token: str) -> dict[tuple[str, str], tuple[str, str]]:
    threads = request_agent_json("/v1/agent/threads?limit=20", token).get("items")
    if not isinstance(threads, list) or len(threads) > 1:
        raise RuntimeError("Fresh account Agent thread list is invalid")
    runs: dict[tuple[str, str], tuple[str, str]] = {}
    for thread in threads:
        thread_id = thread.get("id") if isinstance(thread, dict) else None
        if not isinstance(thread_id, str) or not thread_id:
            raise RuntimeError("Fresh account Agent thread is invalid")
        cursor = None
        messages = []
        for _ in range(20):
            query = urlencode({"limit": 50, **({"before_sequence": cursor} if cursor else {})})
            page = request_agent_json(
                f"/v1/agent/threads/{quote(thread_id, safe='')}/history?{query}", token,
            )
            items = page.get("items")
            if not isinstance(items, list):
                raise RuntimeError("Fresh account Agent history is invalid")
            messages.extend(items)
            next_cursor = page.get("next_before_sequence")
            if next_cursor is None:
                break
            if not isinstance(next_cursor, int) or next_cursor <= 0 or next_cursor == cursor:
                raise RuntimeError("Fresh account Agent history cursor is invalid")
            cursor = next_cursor
        else:
            raise RuntimeError("Fresh account Agent history is too long to verify")
        runs.update(welcome_runs_from_messages(thread_id, messages))
    return runs


def wait_for_welcome_runs(token: str, expected: int, *, timeout: int = 120) -> dict[tuple[str, str], tuple[str, str]]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        runs = read_welcome_runs(token)
        if len(runs) > expected:
            raise RuntimeError("App created duplicate welcome runs")
        if len(runs) == expected and all(answer for _, answer in runs.values()):
            return runs
        time.sleep(2)
    raise RuntimeError(f"Expected {expected} completed real welcome runs")


def verify_welcome_refresh(before: dict, after: dict) -> None:
    if len(before) != 1 or len(after) != 2 or not set(before).issubset(after):
        raise RuntimeError("Welcome refresh did not preserve exactly the first run")
    old = next(iter(before))
    new = next(key for key in after if key not in before)
    if old[0] != new[0] or before[old] != after[old] or before[old][0] == after[new][0]:
        raise RuntimeError("Welcome refresh did not use the same thread and a new profile key")


def booted_simulator() -> str:
    listing = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "booted", "-j"], text=True))
    booted = [device["udid"] for devices in listing["devices"].values() for device in devices if device["state"] == "Booted"]
    selected = os.environ.get("MOMCOZY_IOS_SIMULATOR") or (booted[0] if len(booted) == 1 else "")
    if selected not in booted:
        raise RuntimeError("Select one booted iOS Simulator with MOMCOZY_IOS_SIMULATOR")
    return selected


def copy_screenshots(device: str, role: str, output: Path) -> date | None:
    container = subprocess.check_output(["xcrun", "simctl", "get_app_container", device, BUNDLE_ID, "data"], text=True).strip()
    output.mkdir(parents=True, exist_ok=True)
    names = (
        "role", "home", "drawer", "mother-profile", "records", "mother-pumping",
        "mother-trend", "mother-trend-details",
        "mother-wellbeing-saved" if output.name in {"mother-with-status", "mother-status-in-app"} else "mother-wellbeing-empty",
    ) if role == "mother" else ("role", "home", "drawer")
    if output.name == "mother-with-baby":
        names += ("baby-profile", "baby-records", "baby-details", "baby-details-saved", "baby-knowledge")
    if output.name == "mother-status-in-app":
        names += ("mother-status-editor", "mother-status-saved")
    for name in names:
        image = Path(container) / "Documents" / f"ios-chat-first-{name}.png"
        if not image.is_file():
            raise RuntimeError(f"Missing iOS screenshot: {name}")
        shutil.copy2(image, output / image.name)
    if role == "mother":
        selected = Path(container) / "Documents/ios-chat-first-delivery-date.txt"
        return date.fromisoformat(selected.read_text().strip())
    return None


def verify_mother_records(token: str, owner_user_id: str) -> None:
    feeding = request_product_json("GET", "/v1/records/feeding", token).get("items")
    pumping = request_product_json("GET", "/v1/records/pumping", token).get("items")
    growth = request_product_json("GET", "/v1/records/growth", token).get("items")
    if not all(isinstance(rows, list) for rows in (feeding, pumping, growth)):
        raise RuntimeError("Local record lists are invalid")
    if (len(feeding), len(pumping), len(growth)) != (3, 1, 1):
        raise RuntimeError("Local App record writes were not persisted exactly once")
    for item in [*feeding, *pumping, *growth]:
        if (not isinstance(item, dict) or not item.get("id")
                or item.get("owner_user_id") != owner_user_id or item.get("status") != "active"
                or item.get("infant_id") is not None):
            raise RuntimeError("Local App record has an unexpected owner, baby or status")
    by_type = {item.get("feed_type"): item for item in feeding}
    if (set(by_type) != {"breastfeeding", "formula", "expressed_milk"}
            or by_type["breastfeeding"].get("feed_action") != "left"
            or by_type["breastfeeding"].get("duration_seconds") != 720
            or by_type["formula"].get("volume_ml") != 60
            or by_type["expressed_milk"].get("volume_ml") != 75
            or pumping[0].get("milk_volume_ml") != 45
            or growth[0].get("weight_kg") != 3.4
            or growth[0].get("height_cm") != 50.5):
        raise RuntimeError("Local App records do not match the actual form input")
    print("Five account-owned App records persisted exactly once for the current owner.", flush=True)


def seed_mother_status(token: str, *, now: datetime) -> str:
    if now.tzinfo is None:
        raise ValueError("A timezone-aware local test clock is required")
    record_id = str(uuid4())
    payload = {
        "id": record_id,
        "kind": "mood",
        "occurred_at": (now - timedelta(minutes=1)).isoformat(),
        "value": "一般",
        "fields": {},
    }
    saved = request_product_json(
        "PUT", f"/v1/profile/me-experience/records/{record_id}", token, payload,
    )
    if (saved.get("id") != record_id or saved.get("kind") != "mood" or saved.get("value") != "一般"):
        raise RuntimeError("The real owner-scoped status record was not persisted")
    print("A real self-reported status record was persisted for this test owner.", flush=True)
    return record_id


def verify_mother_trend_and_state(
    token: str, *, today: date, saved_status_id: str | None = None,
) -> None:
    query = urlencode({
        "start_date": (today - timedelta(days=6)).isoformat(),
        "days": 7,
        "timezone": "Asia/Shanghai",
    })
    rows = request_product_json("GET", f"/v1/records/milk-trends?{query}", token).get("items")
    if not isinstance(rows, list) or len(rows) != 7:
        raise RuntimeError("Fresh account milk trend did not return seven days")
    saved_days = 0
    for index, row in enumerate(rows):
        expected = (today - timedelta(days=6 - index)).isoformat()
        if not isinstance(row, dict) or row.get("date") != expected or row.get("complete") is not True or row.get("measured_only") is not True:
            raise RuntimeError("Fresh account milk trend has an incomplete or unexpected local day")
        count, volume = row.get("pumping_count"), row.get("pumped_milk_volume_ml")
        if count == 1 and volume == 45:
            saved_days += 1
        elif count != 0 or volume != 0:
            raise RuntimeError("Fresh account milk trend contains unexpected pumping data")
    if saved_days != 1:
        raise RuntimeError("Fresh account milk trend did not reflect the App's single pumping save")

    zone = ZoneInfo("Asia/Shanghai")
    saved_statuses = []
    for offset in (-1, 0):
        day = today + timedelta(days=offset)
        start = datetime(day.year, day.month, day.day, tzinfo=zone)
        next_day = day + timedelta(days=1)
        end = datetime(next_day.year, next_day.month, next_day.day, tzinfo=zone)
        window = urlencode({"start": start.isoformat(), "end": end.isoformat()})
        status = request_product_json("GET", f"/v1/profile/me-experience?{window}", token).get("records")
        if not isinstance(status, list):
            raise RuntimeError("Fresh account status history is unavailable")
        saved_statuses.extend(status)
    if saved_status_id is None:
        if saved_statuses:
            raise RuntimeError("Fresh account status history is not empty")
        print("Seven local trend days and two empty owner-scoped status days verified.", flush=True)
    else:
        if (len(saved_statuses) != 1 or not isinstance(saved_statuses[0], dict)
                or saved_statuses[0].get("id") != saved_status_id
                or saved_statuses[0].get("kind") != "mood"
                or saved_statuses[0].get("value") != "一般"):
            raise RuntimeError("Saved owner status did not appear exactly once in the two-day window")
        print("Seven local trend days and one real owner-scoped status read verified.", flush=True)


def verify_mother_baby(token: str) -> str:
    state = request_product_json("GET", "/v1/onboarding/me/chat-first", token)
    if (state.get("status") != "completed" or state.get("can_enter_app") is not True
            or state.get("role") != "mother" or state.get("profile_scope") != "chat_first"):
        raise RuntimeError("Mother role did not persist after creating a baby")
    legacy = request_product_json("GET", "/v1/onboarding/me", token)
    if legacy.get("status") != "required" or legacy.get("profile_confirmed") is not False:
        raise RuntimeError("Partial mother profile unexpectedly completed legacy onboarding")
    babies = request_product_json("GET", "/v1/babies", token).get("items")
    if (not isinstance(babies, list) or len(babies) != 1
            or babies[0].get("name") != "Local Test Baby" or not babies[0].get("id")):
        raise RuntimeError("A single real baby profile was not created in the App")
    return babies[0]["id"]


def verify_baby_records(token: str, baby_id: str) -> None:
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    query = urlencode({
        "start_date": (today - timedelta(days=2)).isoformat(),
        "end_date": (today + timedelta(days=2)).isoformat(),
        "timezone": "Asia/Shanghai",
    })
    page = request_product_json("GET", f"/v1/babies/{baby_id}/records?{query}", token)
    items = page.get("items")
    if not isinstance(items, list) or page.get("total") != 3 or len(items) != 3:
        raise RuntimeError("Baby-only App records were not persisted exactly once")
    by_kind = {item.get("observation", {}).get("kind"): item for item in items}
    if set(by_kind) != {"diaper", "sleep", "daily_status"}:
        raise RuntimeError("The baby-only record categories do not match the App forms")
    if any(item.get("baby_id") != baby_id or not item.get("id") for item in items):
        raise RuntimeError("A baby-only record has the wrong baby identity")
    if by_kind["diaper"]["observation"].get("diaper_kind") != "wet":
        raise RuntimeError("Diaper form state was not persisted")
    daily = by_kind["daily_status"]["observation"]
    if daily.get("mental_state") != "content" or daily.get("recorded_on") != today.isoformat():
        raise RuntimeError("Baby detail's mood was not saved for the selected baby and day")
    sleep = by_kind["sleep"]["observation"]
    if (not sleep.get("ended_at") or not sleep.get("occurred_at")
            or sleep["ended_at"] <= sleep["occurred_at"]):
        raise RuntimeError("Sleep start and end were not persisted in order")
    print("Three baby-only App records persisted exactly once for the selected baby.", flush=True)


def main() -> None:
    role = os.environ.get("MOMCOZY_IOS_SMOKE_ROLE", "father")
    baby_records = os.environ.get("MOMCOZY_IOS_SMOKE_BABY_RECORDS") == "1"
    welcome_refresh = os.environ.get("MOMCOZY_IOS_SMOKE_WELCOME_REFRESH") == "1"
    saved_status = os.environ.get("MOMCOZY_IOS_SMOKE_SAVED_STATUS") == "1"
    status_in_app = os.environ.get("MOMCOZY_IOS_SMOKE_STATUS_IN_APP") == "1"
    if role not in {"father", "mother"}:
        raise RuntimeError("MOMCOZY_IOS_SMOKE_ROLE must be father or mother")
    if baby_records and role != "mother":
        raise RuntimeError("The baby-record smoke requires MOMCOZY_IOS_SMOKE_ROLE=mother")
    if welcome_refresh and (role != "mother" or baby_records):
        raise RuntimeError("The welcome-refresh smoke requires mother without baby records")
    if saved_status and (role != "mother" or baby_records or welcome_refresh):
        raise RuntimeError("The saved-status smoke requires only the mother role")
    if status_in_app and (role != "mother" or baby_records or welcome_refresh or saved_status):
        raise RuntimeError("The App status smoke requires only a fresh mother account")
    output = SCREENSHOTS / (
        "mother-status-in-app" if status_in_app else
        "mother-with-status" if saved_status else
        "mother-with-baby" if baby_records else
        "mother-welcome-refresh" if welcome_refresh else "mother"
    ) if role == "mother" else SCREENSHOTS
    device = booted_simulator()
    account = create_account()
    token = verify_account(account)
    verify_fresh_chat_first(token)
    print("Fresh iOS test account and backend identity verified.", flush=True)
    saved_status_id = seed_mother_status(
        token, now=datetime.now(ZoneInfo("Asia/Shanghai")),
    ) if saved_status else None

    fd, defines = tempfile.mkstemp(prefix="momcozy-ios-smoke-", suffix=".json")
    os.fchmod(fd, 0o600)
    restored_normal_app = False
    try:
        with os.fdopen(fd, "w") as defines_file:
            json.dump({
                "MOMCOZY_IOS_SMOKE_EMAIL": account["email"],
                "MOMCOZY_IOS_SMOKE_PASSWORD": account["password"],
                "MOMCOZY_IOS_SMOKE_ROLE": role,
                "MOMCOZY_IOS_SMOKE_BABY_RECORDS": str(baby_records).lower(),
                "MOMCOZY_IOS_SMOKE_SAVED_STATUS": str(saved_status).lower(),
                "MOMCOZY_IOS_SMOKE_STATUS_IN_APP": str(status_in_app).lower(),
                "MOMCOZY_ENV": "local",
                "MOMCOZY_API_BASE_URL": "http://127.0.0.1:8769",
                "MOMCOZY_AGENT_API_BASE_URL": "http://127.0.0.1:8010",
            }, defines_file)
        # A prior simulator session must never bypass the new account's login.
        subprocess.run(["xcrun", "simctl", "uninstall", device, BUNDLE_ID], capture_output=True)
        subprocess.run([
            "flutter", "test", "--no-pub", "--no-uninstall", "-d", device,
            f"--dart-define-from-file={defines}",
            "integration_test/chat_first_ios_local_smoke_test.dart", "-r", "expanded",
        ], cwd=APP, check=True)
        baby_id = verify_mother_baby(token) if baby_records else None
        if baby_id is None:
            verify_chat_first_role(token, role)
        selected_date = copy_screenshots(device, role, output)
        if selected_date is not None:
            verify_mother_facts(token, selected_date)
            verify_mother_records(token, account["user_id"])
            if status_in_app:
                saved_status_id = verify_app_saved_status(
                    token, today=datetime.now(ZoneInfo("Asia/Shanghai")).date(),
                )
            verify_mother_trend_and_state(
                token, today=datetime.now(ZoneInfo("Asia/Shanghai")).date(),
                saved_status_id=saved_status_id,
            )
        if baby_id is not None:
            verify_baby_records(token, baby_id)
        # A test binary contains ephemeral Dart defines. Replace it with the
        # normal locally signed app and verify a cold start against the saved
        # account. --no-codesign cannot read the test app's iOS Keychain item.
        subprocess.run(["flutter", "build", "ios", "--simulator", "--debug", "--no-pub"], cwd=APP, check=True)
        subprocess.run(["xcrun", "simctl", "install", device, str(APP / "build/ios/iphonesimulator/Runner.app")], check=True)
        restored_normal_app = True
        subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE_ID], check=True)
        time.sleep(5)
        subprocess.run(["xcrun", "simctl", "io", device, "screenshot", str(output / "ios-chat-first-cold-start.png")], check=True)
        print(f"iOS login, {role} profile, signed cold start and screenshots verified: {output}", flush=True)
        if welcome_refresh:
            before = wait_for_welcome_runs(token, 1)
            saved = request_product_json("PATCH", "/v1/profile/me-experience/profile", token, {"age": 31})
            if saved.get("age") != 31 or saved.get("preferred_name") is not None:
                raise RuntimeError("Local mother profile update was not persisted")
            subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE_ID], check=True)
            after = wait_for_welcome_runs(token, 2)
            verify_welcome_refresh(before, after)
            time.sleep(3)
            subprocess.run(["xcrun", "simctl", "io", device, "screenshot", str(output / "ios-chat-first-welcome-refresh.png")], check=True)
            subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE_ID], check=True)
            time.sleep(5)
            if read_welcome_runs(token) != after:
                raise RuntimeError("Cold start changed a completed welcome run")
            print("Two profile-specific real welcome runs and no cold-start duplicate verified.", flush=True)
    finally:
        Path(defines).unlink(missing_ok=True)
        if not restored_normal_app:
            # Never leave a test binary containing temporary credentials on
            # the simulator if any verification or normal rebuild fails.
            subprocess.run(["xcrun", "simctl", "uninstall", device, BUNDLE_ID], capture_output=True)


if __name__ == "__main__":
    main()
