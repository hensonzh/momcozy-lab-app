#!/usr/bin/env python3
"""Rebuild the local Android app and sign in with a new local-only account."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from contextlib import contextmanager
import os
import re
import subprocess
import time
from pathlib import Path
from uuid import UUID
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from xml.etree import ElementTree

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
    latin = "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME"
    original = adb(device, "shell", "settings", "get", "secure", "default_input_method", capture=True).strip()
    available = adb(device, "shell", "ime", "list", "-s", capture=True).splitlines()
    if latin not in available:
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
    adb(device, "shell", "uiautomator", "dump", "/sdcard/window.xml", capture=True)
    return nodes_from_xml(adb(device, "exec-out", "cat", "/sdcard/window.xml", capture=True))


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


def local_onboarding_payload():
    return {
        "stage": "postpartum", "display_name": "Local App Test", "age": 32,
        "delivery_date": datetime.now(timezone.utc).date().isoformat(),
        "client_timezone_offset_minutes": 0,
        "delivery_count": 1, "has_cesarean_history": False,
        "delivery_type": "vaginal", "gestation_weeks": 39, "gestation_days": 2,
        "feeding_methods": ["direct"], "infant_count": 1,
        "infants": [{"nickname": "Local Baby", "sex": "female"}],
    }


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


def ensure_onboarding(token):
    state = request_product_json("GET", "/v1/onboarding/me", token)
    if state.get("status") == "required" and state.get("profile_confirmed") is False:
        state = request_product_json(
            "PUT", "/v1/onboarding/me/profile", token, local_onboarding_payload()
        )
        confirmed = request_product_json("GET", "/v1/onboarding/me", token)
        if state != confirmed:
            raise RuntimeError("Local onboarding confirmation did not persist")
    if state.get("status") != "completed" or state.get("profile_confirmed") is not True:
        raise RuntimeError("Local onboarding is not confirmed")
    try:
        baby_id = str(UUID(str(state["primary_infant_id"])))
    except (KeyError, TypeError, ValueError) as error:
        raise RuntimeError("Local onboarding returned no primary infant") from error
    babies = request_product_json("GET", "/v1/babies", token)
    if not isinstance(babies.get("items"), list) or not any(
        isinstance(baby, dict) and baby.get("id") == baby_id
        for baby in babies["items"]
    ):
        raise RuntimeError("Local onboarding baby is not owned by the fresh account")
    return baby_id


def install_and_login(device, account, token):
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
    tap_node(device, find_node(ui_nodes(device), class_name="android.widget.EditText", hint="Password"))
    wait_for_field_focus(device, "Password")
    time.sleep(0.8)
    type_text(device, account["password"])
    adb(device, "shell", "input", "keyevent", "KEYCODE_BACK")
    tap_node(device, find_node(ui_nodes(device), class_name="android.widget.Button", description="Sign in"))
    wait_for(
        device,
        lambda nodes: next((n for n in nodes if "Your setup" in n.get("content-desc", "") or "Your setup" in n.get("text", "")), None),
        "first-login onboarding gate",
    )
    ensure_onboarding(token)
    # Re-bootstrap the retained App session so the onboarding gate re-fetches
    # the server confirmation. No credentials are entered a second time.
    adb(device, "shell", "am", "force-stop", PACKAGE)
    adb(device, "shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1", capture=True)
    wait_for(device, lambda nodes: next((n for n in nodes if n.get("content-desc", "").split("\n")[0] == "More"), None), "authenticated home")
    tap_node(device, find_node(ui_nodes(device), description="More"))
    wait_for(device, lambda nodes: any(account["email"] in (n.get("content-desc", "") + n.get("text", "")) for n in nodes), "new email on More page")
    SCREENSHOTS.mkdir(parents=True, exist_ok=True)
    (SCREENSHOTS / "account.png").write_bytes(subprocess.check_output(["adb", "-s", device, "exec-out", "screencap", "-p"]))
    tap_node(device, find_node(ui_nodes(device), class_name="android.widget.Button", description="Me"))
    wait_for(device, lambda nodes: next((n for n in nodes if n.get("class") == "android.widget.Button" and n.get("content-desc") == "Me" and n.get("selected") == "true"), None), "Me home tab")
    (SCREENSHOTS / "home.png").write_bytes(subprocess.check_output(["adb", "-s", device, "exec-out", "screencap", "-p"]))
    if not adb(device, "shell", "pidof", PACKAGE, capture=True).strip():
        raise RuntimeError("App is no longer running on emulator")


def main():
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
    with latin_keyboard(device):
        install_and_login(device, account, token)
    print(f"Emulator login verified for user {account['user_id']}.", flush=True)
    print(f"Email: {account['email']}", flush=True)
    print(f"Screenshots: {SCREENSHOTS / 'account.png'}, {SCREENSHOTS / 'home.png'}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        raise SystemExit(f"FAIL {error}") from None
