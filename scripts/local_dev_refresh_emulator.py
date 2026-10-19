#!/usr/bin/env python3
"""Rebuild the local Android app, sign in a fresh account, and stop at onboarding."""
from __future__ import annotations

import json
from contextlib import contextmanager
from datetime import date, datetime, timedelta, timezone
import os
import re
import subprocess
import time
from pathlib import Path
from uuid import UUID
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from xml.etree import ElementTree
from zoneinfo import ZoneInfo

APP = Path(__file__).resolve().parents[1]
BACKEND = APP.parent / "backend"
PACKAGE = "com.momcozymai.app.flutterpoc.local"
APK = APP / "build/app/outputs/flutter-apk/app-local-debug.apk"
SCREENSHOTS = APP / "build/emulator-refresh"
PRODUCT_URL = "http://127.0.0.1:8769"


def run(args, *, cwd=APP, input_text=None, capture=False):
    result = subprocess.run(
        args, cwd=cwd, input=input_text, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if result.returncode != 0:
        # Never put a typed password or API token in an exception or log.
        raise RuntimeError(f"{args[0]} operation failed: {result.stderr or result.returncode}")
    return result.stdout if capture else ""


def account_from_output(output):
    try:
        account = json.loads(output.strip().splitlines()[-1])
        UUID(account["user_id"])
        if not re.fullmatch(r"emulator-[0-9a-f]{32}@example\.test", account["email"]):
            raise ValueError("invalid email")
        if not re.fullmatch(r"Mc[0-9a-f]{32}A9", account["password"]):
            raise ValueError("invalid password")
        return account
    except (IndexError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise RuntimeError("invalid fresh account result from local Product Backend") from exc


def nodes_from_xml(xml):
    return list(ElementTree.fromstring(xml).iter("node"))


def find_node(nodes, *, class_name=None, hint=None, description=None):
    for node in nodes:
        if class_name and node.get("class") != class_name:
            continue
        if hint and hint not in node.get("hint", ""):
            continue
        if description and description not in node.get("content-desc", ""):
            continue
        return node
    raise RuntimeError(f"UI element not found: {description or hint or class_name}")


def center_of(node):
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if not match:
        raise RuntimeError("UI element has no usable bounds")
    left, top, right, bottom = map(int, match.groups())
    return (left + right) // 2, (top + bottom) // 2


def adb(device, *args, capture=False, secret=False):
    if secret:
        result = subprocess.run(["adb", "-s", device, *args], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError("Could not enter local test credentials in emulator")
        return result.stdout
    return run(["adb", "-s", device, *args], capture=capture)


@contextmanager
def latin_keyboard(device):
    # Emulator owners may use an IME with CJK composition, which corrupts
    # `adb shell input text` even when characters are sent one at a time.
    original = adb(device, "shell", "settings", "get", "secure", "default_input_method", capture=True).strip()
    available = adb(device, "shell", "ime", "list", "-s", capture=True).splitlines()
    latin_options = (
        "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME",
        "com.android.inputmethod.latin/.LatinIME",
    )
    latin = original if original in latin_options and original in available else next(
        (ime for ime in latin_options if ime in available), None
    )
    if latin is None:
        raise RuntimeError("The emulator has no Latin input method for test credentials")
    changed = original != latin
    try:
        if changed:
            adb(device, "shell", "ime", "set", latin, capture=True)
        active = adb(device, "shell", "settings", "get", "secure", "default_input_method", capture=True).strip()
        if active != latin:
            raise RuntimeError("Could not activate the emulator Latin input method")
        yield
    finally:
        if changed and original and original != "null":
            adb(device, "shell", "ime", "set", original, capture=True)


def type_text(device, text):
    # Android's input tool can reorder/drop a burst of key events in Flutter.
    for char in text:
        adb(device, "shell", "input", "text", char, secret=True)
        time.sleep(0.07)


def ui_nodes(device):
    # UIAutomator can briefly leave an empty/truncated dump while an Activity
    # launches. Retry only that transient parse failure, not ADB failures.
    for attempt in range(3):
        adb(device, "shell", "uiautomator", "dump", "/sdcard/window.xml", capture=True)
        xml = adb(device, "exec-out", "cat", "/sdcard/window.xml", capture=True)
        try:
            return nodes_from_xml(xml)
        except ElementTree.ParseError:
            if attempt == 2:
                raise RuntimeError("Could not read a valid UI hierarchy from emulator") from None
            time.sleep(0.5)


def wait_for(device, predicate, description, seconds=45):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        nodes = ui_nodes(device)
        result = predicate(nodes)
        if result is not None and result is not False:
            return result
        time.sleep(1)
    raise RuntimeError(f"Timed out waiting for {description}")


def is_login_form(nodes):
    # The title/brand is presentation copy; the fields and action define the screen.
    return (
        any(node.get("class") == "android.widget.EditText" and "Email" in node.get("hint", "") for node in nodes)
        and any(node.get("class") == "android.widget.EditText" and "Password" in node.get("hint", "") for node in nodes)
        and any(node.get("class") == "android.widget.Button" and node.get("content-desc") == "Sign in" for node in nodes)
    )


def wait_for_field_focus(device, hint):
    return wait_for(
        device,
        lambda nodes: next(
            (node for node in nodes if node.get("class") == "android.widget.EditText"
             and hint in node.get("hint", "") and node.get("focused") == "true"),
            None,
        ),
        f"{hint} field focus",
        seconds=15,
    )


def tap_node(device, node):
    x, y = center_of(node)
    adb(device, "shell", "input", "tap", str(x), str(y))


def emulator():
    output = run(["adb", "devices"], capture=True)
    devices = re.findall(r"^(emulator-\d+)\s+device$", output, re.MULTILINE)
    requested = os.environ.get("MOMCOZY_FLUTTER_EMULATOR_DEVICE")
    if requested and requested not in devices:
        raise RuntimeError(f"Emulator {requested} is not online")
    if not devices:
        raise RuntimeError("No online Android Studio emulator")
    return requested or devices[0]


def create_account():
    source = (BACKEND / "scripts/seed_local_test_account.py").read_text()
    output = run(
        ["docker", "compose", "-f", "docker-compose.local.yml", "exec", "-T", "api", "python", "-", "--fresh"],
        cwd=BACKEND, input_text=source, capture=True,
    )
    return account_from_output(output)


def verify_account(account):
    body = json.dumps({"email": account["email"], "password": account["password"], "device_id": "local-emulator-preflight"}).encode()
    with urlopen(Request(f"{PRODUCT_URL}/v1/auth/login", data=body, headers={"Content-Type": "application/json"}), timeout=15) as response:
        token = json.load(response)["access_token"]
    with urlopen(Request(f"{PRODUCT_URL}/v1/auth/me", headers={"Authorization": f"Bearer {token}"}), timeout=15) as response:
        profile = json.load(response)
    if profile.get("id") != account["user_id"] or profile.get("email") != account["email"]:
        raise RuntimeError("Fresh account identity check failed")
    return token


def request_product_json(method, path, token, payload=None):
    body = json.dumps(payload).encode() if payload is not None else None
    request = Request(
        f"{PRODUCT_URL}{path}", data=body, method=method,
        headers={"Authorization": f"Bearer {token}",
                 **({"Content-Type": "application/json"} if body is not None else {})},
    )
    try:
        with urlopen(request, timeout=15) as response:
            result = json.load(response)
    except HTTPError as error:
        raise RuntimeError(f"Local onboarding request failed (HTTP {error.code}, {method} {path})") from None
    if not isinstance(result, dict):
        raise RuntimeError(f"Local onboarding returned invalid JSON ({method} {path})")
    return result


def verify_fresh_chat_first(token):
    state = request_product_json("GET", "/v1/onboarding/me/chat-first", token)
    if (state.get("status") != "required" or state.get("can_enter_app") is not False
            or state.get("role") is not None or state.get("profile_scope") != "none"
            or state.get("primary_infant_id") is not None):
        raise RuntimeError("Fresh account onboarding is not empty")
    legacy = request_product_json("GET", "/v1/onboarding/me", token)
    if legacy.get("status") != "required" or legacy.get("profile_confirmed") is not False:
        raise RuntimeError("Fresh account has a legacy onboarding profile")
    babies = request_product_json("GET", "/v1/babies", token)
    if babies.get("items") != []:
        raise RuntimeError("Fresh account has a prefilled baby profile")


def verify_chat_first_role(token, role):
    state = request_product_json("GET", "/v1/onboarding/me/chat-first", token)
    if (state.get("status") != "completed" or state.get("can_enter_app") is not True
            or state.get("role") != role or state.get("profile_scope") != "chat_first"
            or state.get("primary_infant_id") is not None):
        raise RuntimeError("Local chat-first role did not persist")
    legacy = request_product_json("GET", "/v1/onboarding/me", token)
    if legacy.get("status") != "required" or legacy.get("profile_confirmed") is not False:
        raise RuntimeError("Role-only account unexpectedly completed legacy onboarding")
    babies = request_product_json("GET", "/v1/babies", token)
    if babies.get("items") != []:
        raise RuntimeError("Role-only account has a fabricated baby profile")


def verify_mother_facts(token, delivery_date):
    personal = request_product_json("GET", "/v1/profile/me", token)
    if personal.get("age") != 30 or personal.get("preferred_name") is not None:
        raise RuntimeError("Mother profile has missing answers or a sample name")
    maternal = request_product_json("GET", "/v1/profile/lactation", token)
    if maternal.get("actual_delivery_date") != delivery_date.isoformat():
        raise RuntimeError("Mother delivery date did not persist")
    # Use a one-day UTC window; the endpoint returns the owner's profile
    # independently of whether there are records in that window.
    today = datetime.now(timezone.utc).date()
    start = datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
    query = urlencode({
        "start": start.isoformat(),
        "end": (start + timedelta(days=1)).isoformat(),
    })
    experience = request_product_json("GET", f"/v1/profile/me-experience?{query}", token)
    profile = experience.get("profile")
    if (not isinstance(profile, dict) or profile.get("gestation_weeks") != 39
            or profile.get("gestation_days") != 0 or profile.get("baby_count") != 1
            or profile.get("delivery_count") != 2):
        raise RuntimeError("Mother answers did not persist in the owner profile")
    concerns = experience.get("concerns")
    if not isinstance(concerns, list) or [item.get("note") for item in concerns] != ["奶量够不够"]:
        raise RuntimeError("Mother concern did not persist")


def verify_app_saved_status(token, *, today):
    zone = ZoneInfo("Asia/Shanghai")
    start = datetime(today.year, today.month, today.day, tzinfo=zone)
    end_day = today + timedelta(days=1)
    end = datetime(end_day.year, end_day.month, end_day.day, tzinfo=zone)
    query = urlencode({"start": start.isoformat(), "end": end.isoformat()})
    records = request_product_json("GET", f"/v1/profile/me-experience?{query}", token).get("records")
    if (not isinstance(records, list) or len(records) != 1 or not isinstance(records[0], dict)
            or records[0].get("kind") != "mood" or records[0].get("value") != "一般"):
        raise RuntimeError("The App did not persist exactly one owner-scoped mood record")
    record_id = records[0].get("id")
    try:
        UUID(record_id)
    except (TypeError, ValueError):
        raise RuntimeError("The App status record has no valid ID") from None
    print("A fresh App status save was read back exactly once for its owner.", flush=True)
    return record_id


def labeled_node(nodes, text):
    return next((node for node in nodes
                 if text in node.get("content-desc", "") or text in node.get("text", "")), None)


def exact_labeled_node(nodes, text):
    return next((node for node in nodes
                 if text in (node.get("content-desc"), node.get("text"))), None)


def first_exact_labeled_node(nodes, labels):
    for label in labels:
        node = exact_labeled_node(nodes, label)
        if node is not None:
            return node
    return None


def tap_label(device, label, *, exact=False):
    finder = exact_labeled_node if exact else labeled_node
    tap_node(device, wait_for(device, lambda nodes: finder(nodes, label), label))


def refresh_role():
    role = os.environ.get("MOMCOZY_LOCAL_REFRESH_ROLE", "father")
    if role not in ("father", "mother"):
        raise RuntimeError("MOMCOZY_LOCAL_REFRESH_ROLE must be father or mother")
    return role


def date_picker_day(nodes, day):
    suffix = f"{day.strftime('%B')} {day.day}, {day.year}"
    return next((node for node in nodes
                 if node.get("class") == "android.widget.Button"
                 and node.get("content-desc", "").startswith(f"{day.day}, ")
                 and suffix in node.get("content-desc", "")), None)


def is_chat_first_home(nodes):
    return all(labeled_node(nodes, label) is not None
               for label in ("记录", "听哭闹", "看便便"))


def baby_profile_name_field(nodes):
    return next((node for node in nodes
                 if node.get("class") == "android.widget.EditText"
                 and "如何称呼宝宝？" in node.get("hint", "")), None)


def screenshot(device, name):
    SCREENSHOTS.mkdir(parents=True, exist_ok=True)
    (SCREENSHOTS / name).write_bytes(
        subprocess.check_output(["adb", "-s", device, "exec-out", "screencap", "-p"])
    )


def select_mother_flow(device):
    tap_label(device, "妈妈", exact=True)
    wait_for(device, lambda nodes: labeled_node(nodes, "你现在处于哪个阶段？"), "mother stage")
    screenshot(device, "mother-stage.png")
    tap_label(device, "产后", exact=True)
    wait_for(device, lambda nodes: labeled_node(nodes, "先了解一些基本信息"), "mother basics")
    screenshot(device, "mother-basics.png")
    tap_label(device, "30岁")
    tap_label(device, "2次")
    tap_label(device, "继续", exact=True)
    wait_for(device, lambda nodes: labeled_node(nodes, "关于这次分娩"), "mother delivery")
    tap_label(device, "选择分娩日期")
    today = date.today()
    day = today - timedelta(days=1)
    if day.month != today.month:
        tap_label(device, "Previous month")
    tap_node(device, wait_for(device, lambda nodes: date_picker_day(nodes, day), "recent delivery date"))
    tap_node(device, wait_for(device,
        lambda nodes: first_exact_labeled_node(nodes, ("OK", "确定")),
        "date picker confirmation"))
    tap_label(device, "39周")
    tap_label(device, "1个宝宝")
    screenshot(device, "mother-delivery.png")
    tap_label(device, "继续", exact=True)
    wait_for(device, lambda nodes: labeled_node(nodes, "现在你最在意什么？"), "mother concerns")
    screenshot(device, "mother-concerns.png")
    tap_label(device, "奶量够不够")
    tap_label(device, "继续", exact=True)
    wait_for(device, lambda nodes: labeled_node(nodes, "为你推荐"), "mother service introduction")
    screenshot(device, "mother-services.png")
    tap_label(device, "进入首页", exact=True)
    return day


def save_mother_status_in_app(device, token):
    tap_node(device, wait_for(device, lambda nodes: labeled_node(nodes, "打开侧边栏"), "drawer button"))
    tap_node(device, wait_for(device, lambda nodes: labeled_node(nodes, "我的"), "mother destination"))
    wait_for(device, lambda nodes: labeled_node(nodes, "最近 2 天没有已保存状态记录"), "empty mother status")
    tap_label(device, "记录我的状态")
    wait_for(device, lambda nodes: labeled_node(nodes, "今天想记录哪一项？"), "status editor")
    tap_label(device, "心情")
    tap_label(device, "一般")
    screenshot(device, "mother-status-editor.png")
    tap_label(device, "保存状态")
    wait_for(device, lambda nodes: labeled_node(nodes, "最近 2 天有 1 条已保存状态记录"), "saved status overview")
    screenshot(device, "mother-status-saved.png")
    verify_app_saved_status(token, today=datetime.now(ZoneInfo("Asia/Shanghai")).date())
    tap_label(device, "查看最近状态")
    wait_for(device, lambda nodes: labeled_node(nodes, "心情") and labeled_node(nodes, "一般"), "saved status detail")
    screenshot(device, "mother-status-readback.png")
    tap_label(device, "关闭身体与状态")
    tap_node(device, wait_for(device, lambda nodes: labeled_node(nodes, "返回对话"), "chat return"))
    wait_for(device, is_chat_first_home, "chat-first home after status save")


def create_and_open_baby_details(device, token, delivery_date):
    tap_node(device, wait_for(device, lambda nodes: labeled_node(nodes, "打开侧边栏"), "drawer button"))
    tap_node(device, wait_for(device, lambda nodes: exact_labeled_node(nodes, "宝宝"), "baby destination"))
    wait_for(device, lambda nodes: labeled_node(nodes, "当前账号还没有宝宝资料"), "empty real baby overview")
    tap_label(device, "添加宝宝资料")
    tap_node(device, wait_for(device, baby_profile_name_field, "baby profile editor"))
    wait_for_field_focus(device, "如何称呼宝宝？")
    type_text(device, "LocalTestBaby")
    adb(device, "shell", "input", "keyevent", "KEYCODE_BACK")
    tap_label(device, "女孩", exact=True)
    tap_label(device, "保存宝宝资料")
    wait_for(device, lambda nodes: labeled_node(nodes, "LocalTestBaby"), "saved baby profile")
    tap_label(device, "查看完整记录与管理")
    wait_for(device, lambda nodes: labeled_node(nodes, "宝宝记录与管理"), "Chinese baby details")
    screenshot(device, "baby-details.png")
    tap_label(device, "照护知识", exact=True)
    tap_node(device, wait_for(
        device,
        lambda nodes: next((node for node in nodes
                            if node.get("class") == "android.widget.Button"
                            and "宝宝安全睡眠" in node.get("content-desc", "")), None),
        "general baby knowledge",
    ))
    wait_for(device, lambda nodes: labeled_node(nodes, "每次睡眠都让宝宝仰卧"), "general safe-sleep guidance")
    screenshot(device, "baby-knowledge.png")
    babies = request_product_json("GET", "/v1/babies", token).get("items")
    if (not isinstance(babies, list) or len(babies) != 1
            or babies[0].get("name") != "LocalTestBaby"
            or babies[0].get("birth_date") != delivery_date.isoformat()
            or babies[0].get("sex") != "female"):
        raise RuntimeError("Baby profile was not persisted for the current owner")
    tap_label(device, "带着问题去对话", exact=True)
    wait_for(device, lambda nodes: next((node for node in nodes
                                         if node.get("class") == "android.widget.EditText"
                                         and node.get("text") == "关于宝宝安全睡眠，我想了解哪些基本注意事项？"), None),
             "unsent baby-knowledge draft")
    screenshot(device, "baby-knowledge-draft.png")
    if not is_chat_first_home(ui_nodes(device)):
        raise RuntimeError("Knowledge draft did not return to the conversation home")


def install_and_login(device, account, token):
    # Replace rather than update the package so secure storage cannot restore
    # another account's authenticated session on this emulator.
    if adb(device, "shell", "pm", "path", PACKAGE, capture=True).strip():
        adb(device, "uninstall", PACKAGE)
    adb(device, "install", str(APK))
    adb(device, "shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1", capture=True)
    wait_for(device, is_login_form, "login form")
    tap_node(device, find_node(ui_nodes(device), class_name="android.widget.EditText", hint="Email"))
    wait_for_field_focus(device, "Email")
    time.sleep(0.8)
    type_text(device, account["email"])
    wait_for(device, lambda nodes: next((n for n in nodes if n.get("class") == "android.widget.EditText" and n.get("text") == account["email"]), None), "email entry", seconds=15)
    # UI proof of this refresh's identity, before typing the password.
    screenshot(device, "login-account.png")
    tap_node(device, find_node(ui_nodes(device), class_name="android.widget.EditText", hint="Password"))
    wait_for_field_focus(device, "Password")
    time.sleep(0.8)
    type_text(device, account["password"])
    adb(device, "shell", "input", "keyevent", "KEYCODE_BACK")
    tap_node(device, find_node(ui_nodes(device), class_name="android.widget.Button", description="Sign in"))
    wait_for(device, lambda nodes: labeled_node(nodes, "你是宝宝的哪位家人？"), "fresh-account role selection")
    verify_fresh_chat_first(token)
    # Confirm that the authenticated onboarding gate survives a cold start;
    # do not choose a role or complete any of the user's onboarding answers.
    adb(device, "shell", "am", "force-stop", PACKAGE)
    adb(device, "shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1", capture=True)
    wait_for(device, lambda nodes: labeled_node(nodes, "你是宝宝的哪位家人？"), "restored fresh-account role selection")
    verify_fresh_chat_first(token)
    screenshot(device, "role.png")
    if not adb(device, "shell", "pidof", PACKAGE, capture=True).strip():
        raise RuntimeError("App is no longer running on emulator")


def main():
    if any(os.environ.get(key) for key in (
        "MOMCOZY_LOCAL_REFRESH_ROLE", "MOMCOZY_LOCAL_REFRESH_STATUS",
        "MOMCOZY_LOCAL_REFRESH_BABY_DETAILS",
    )):
        raise RuntimeError("Local refresh now stops at onboarding; remove old role/status/baby smoke flags")
    device = emulator()
    print(f"Emulator: {device}", flush=True)
    run(["node", "scripts/local-dev-stack.mjs", "up"])
    print("Local Product Backend and Agent Runtime are ready.", flush=True)
    toolchain = json.loads((APP / "flutter-toolchain.json").read_text())
    toolchain_root = Path(os.environ.get("MOMCOZY_TOOLCHAIN_ROOT", toolchain["toolchainRootDefault"])).expanduser()
    sdk_root = Path(os.environ.get("ANDROID_SDK_ROOT", toolchain_root / toolchain["android"]["sdkPath"]))
    aapt2 = sdk_root / "build-tools" / toolchain["android"]["buildTools"] / "aapt2"
    if aapt2.exists():
        os.environ.setdefault("ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride", str(aapt2))
    run(["flutter", "build", "apk", "--debug", "--flavor", "local",
         "--dart-define=MOMCOZY_ENV=local",
         "--dart-define=MOMCOZY_API_BASE_URL=http://10.0.2.2:8769",
         "--dart-define=MOMCOZY_AGENT_API_BASE_URL=http://10.0.2.2:8010"])
    print(f"Local APK built: {APK}", flush=True)
    account = create_account()
    token = verify_account(account)
    verify_fresh_chat_first(token)
    with latin_keyboard(device):
        install_and_login(device, account, token)
    print(f"Emulator login and fresh onboarding verified for user {account['user_id']}.", flush=True)
    print(f"Email: {account['email']}", flush=True)
    print(f"Screenshots: {SCREENSHOTS / 'login-account.png'}, {SCREENSHOTS / 'role.png'}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        raise SystemExit(f"FAIL {error}") from None
