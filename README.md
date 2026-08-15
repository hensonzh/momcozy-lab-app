# MomCozy Flutter App

Production Flutter client for MomCozyApp.

The Flutter application now lives directly at the repository root. Supporting
documentation remains under `docs/`, automation under `scripts/`, and Flutter
tests plus shared fixtures under `test/`.

## Toolchain Baseline

The local toolchain is installed under:

```text
/Users/lute/.local/share/momcozy-toolchains
```

Pinned local versions:

```text
Flutter: 3.44.4 stable
Dart: 3.12.2
JDK: Temurin OpenJDK 17.0.19+10
Android SDK platform: android-36
Android build-tools: 36.0.0
Android platform-tools: 36.0.0-13206524
Android NDK: 28.2.13676358
CMake: 3.22.1
```

From the `MomCozyApp/` repository root:

```bash
make flutter-check
make flutter-invite-dev
make flutter-release-gate
make flutter-emulator-smoke
```

Pinned versions live in [`flutter-toolchain.json`](flutter-toolchain.json);
`make flutter-check` validates the local SDK/JDK/Android directories and versions against that file.
`make flutter-release-gate` runs the non-device release gate: format, analyze,
tests, staging smoke harness, local debug APK, and staging release APK. It
requires explicit HTTPS, non-loopback `MOMCOZY_API_BASE_URL` and
`MOMCOZY_AGENT_API_BASE_URL` values for the staging artifact.
`make flutter-emulator-smoke` installs the local debug APK on an online Android emulator, launches the app, captures Agent Hub / Schedule / Device screenshots under `build/emulator-smoke/`, and checks the process/window/crash log.

Direct Flutter commands also run from the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor local
flutter build apk --release --flavor staging \
  --dart-define=MOMCOZY_ENV=staging \
  --dart-define=MOMCOZY_API_BASE_URL=https://product-staging.example.test \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test
```

邀请码登录本地联调用父目录命令：

```bash
make flutter-invite-dev
```

该命令默认将 Product 和 Agent 分别连接到 `http://10.0.2.2:8000` 与
`http://10.0.2.2:8010`，不会传入 `MOMCOZY_API_TOKEN` 或
`MOMCOZY_REFRESH_TOKEN`，并会先清理 local flavor 安装包，确保进入邀请码登录页。
如需覆盖模拟器或后端地址：

```bash
MOMCOZY_FLUTTER_EMULATOR_DEVICE=emulator-5554 \
MOMCOZY_API_BASE_URL=http://10.0.2.2:8000 \
MOMCOZY_AGENT_API_BASE_URL=http://10.0.2.2:8010 \
make flutter-invite-dev
```

Agent Hub 默认使用 SSE transport，并可通过 dart-define 配置：

```bash
flutter run \
  --dart-define=MOMCOZY_API_BASE_URL=http://192.168.x.x:8769 \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=http://192.168.x.x:8010 \
  --dart-define=MOMCOZY_API_TOKEN=APP_API_TEST \
  --dart-define=MOMCOZY_DEFAULT_USER_ID=demo-user
```

Product 请求始终使用 `MOMCOZY_API_BASE_URL`；所有 `/v1/agent/*` HTTP/SSE
请求使用独立的 `MOMCOZY_AGENT_API_BASE_URL`。Android 真机不能使用
`127.0.0.1` 访问电脑上的服务，需要改成手机可访问的局域网或公网地址；
Android emulator 可使用 `10.0.2.2`。

当前部署契约使用 `runtime_pattern: proprietary_runtime`。客户端不会把 Product
和 Agent OpenAPI 合并成一个服务，也不会把 bearer token 放进 URL。

Current Android package IDs:

- `local` applicationId: `com.momcozymai.app.flutterpoc.local`
- `staging` applicationId: `com.momcozymai.app.flutterpoc.staging`
- `production` applicationId: `com.momcozymai.app.flutterpoc`
- Packaging policy: [docs/flutter/android-packaging.md](docs/flutter/android-packaging.md)
- Release gate: [docs/flutter/release-gate.md](docs/flutter/release-gate.md)

## New-user onboarding

Backend-driven onboarding is capability-gated while the split Product contract
is being rolled out. It is disabled by default, so a missing onboarding endpoint
cannot block login or the main App shell. Enable it only in a compatible
environment with `--dart-define=MOMCOZY_ENABLE_ONBOARDING=true`. When enabled,
authenticated users whose backend onboarding state is incomplete are held on
the full-screen `/onboarding` route before the main App shell is available. The
flow collects a stage-exclusive maternal profile, the fields required by that
stage, and one shared delivery/infant set for postpartum users. It then offers
camera or gallery portrait capture, polls the asynchronous avatar job, lets the
user review the result, and keeps the stage-specific MomCozy character as an
explicit fallback.

The client uses `/v1/onboarding/me` and its profile, portrait, generation, and
completion sub-routes. Portraits are sent only through authenticated multipart
transport; the backend normalizes them and applies its temporary privacy
lifecycle.

The destructive internal-test release reset is disabled by default and runs
only when **both** `MOMCOZY_ENABLE_ONBOARDING=true` and
`MOMCOZY_ENABLE_RELEASE_RESET=true` are supplied as `--dart-define` values.
Enabling the reset flag alone has no effect. With both flags enabled, startup
compares the installed runtime version and build number (for example
`1.0.0+55`) with the last launched release. A changed release clears the local
session, all user-scoped secure storage, generated-card/product media caches,
and prior onboarding completion markers while preserving the device ID and
last invite code. After the user signs in, the App performs the matching
idempotent cloud reset before loading onboarding. Reset failure keeps the user
behind the onboarding gate. Completion is recorded per user, so another
account on the same device still receives its own reset and onboarding flow.

Two additional rollout flags fail closed until their backend schemas are
available in staging:

- `MOMCOZY_ENABLE_AGENT_HISTORY` must remain disabled: the frozen Agent Runtime
  contract does not expose `GET /v1/agent/threads/{thread_id}/history` yet.
- `MOMCOZY_ENABLE_EXTENDED_PRODUCT_API=true` enables Body Profile and Motion
  Assessment routes and extended Me/Baby resources that depend on the extended
  Product API. By default, the supported profile, feeding, growth, milk-trend,
  and plan data remains available while unsupported summaries show an explicit
  unavailable state.

See [the integration baseline](docs/flutter/unified-app-integration.md) for
contract ownership and verification gates.

## Contract and Regression Tests

Current Dart test coverage:

- Agent event fixtures parse equivalently across JSONL and SSE eventstream forms.
- Agent stream reducer fixtures cover reconnect replay idempotency by `event_id` and `sequence`.
- API envelope fixtures distinguish success, business errors, HTTP errors, and legacy snake/camel aliases.
- Agent voice fixtures cover STT multipart chunk transcription, timeout fallback, realtime PCM stream cancellation, realtime voice session frames, and WebSocket disconnect behavior.
- Agent Hub widget tests cover composer text send, image attachment payloads, voice transcription fill-in, stop, retry, and user-facing work progress.
- Staging smoke CLI validates env parsing, safe default skip, optional staging HTTP/client-event/media upload probes, and optional Agent SSE probe.
- Privacy fixtures cover shared log redaction for sensitive keys and URL query parameters.
- BLE fixtures cover request packet goldens, standalone hex files, valid/invalid frame parsing, parser edge cases, cross-platform parity cases, and side mapping.
- Route intent fixtures cover native notification navigation plus unsafe/unknown fallback routes.
- Pump device snapshot reducer fixtures cover E1/D0/D6/0x80/BF protocol frames and left/right side isolation.
- Pump device snapshot binding fixtures cover BLE notification stream consumption and notify subscription seeding.
- Pump agent upload snapshot sync fixtures cover forwarding live pump snapshots into `PumpAgentUploadPlatform.updateDeviceSnapshot`.
- BLE pump protocol platform fixtures cover command packet goldens over `BlePlatform.writeWithoutResponse`.
- Pump native runtime coordinator fixtures cover snapshot, upload sync, and BLE protocol state resolver wiring.
- Android pump agent upload body builder maintains the native process `cap_data` frame history.
- Android pump agent background runner shell refreshes native progress while the foreground service is active.
- Pump agent upload adapter fixtures cover native process progress and process reply event streams.
- Android pump foreground notification click writes a one-shot `/pump` pending route and restore snapshot.
- Android pump completion and auto-end notices are backed by local notifications.
- Android route intent adapter covers pending route consumption and native active route events.
- P0 native fake platform interfaces cover BLE permission/settings/scan failure/notification/read/write/subscribe flows, pump protocol command schemas, pump foreground lifecycle/notice events, wake lock reference counting, and one-shot route consumption/active dispatch.
- Android MethodChannel adapter fixtures cover `MmcBle` BLE method schemas/events and `PumpSessionNotification` foreground method schemas.
- Onboarding fixtures cover stage-exclusive serialization, postpartum delivery/infant collection, route gating, portrait upload, avatar selection, and completed-user bypass.
- Pump agent upload MethodChannel adapter fixtures cover native method schemas and failure events.
- Pump agent upload fake platform fixtures cover method schemas, call/failure streams, sensitive failure redaction, and duplicate upload dedupe keys.
- Agent Hub runtime fixtures cover default SSE runner injection, production run payload generation, and route-shell composer send-ready state.

Remaining device-lab gap:

- Run Android real-device P0 smoke for BLE, foreground service, background runner uploads, and notification recovery.

## Engineering Notes

- Add fixtures before feature UI: BLE protocol, Agent SSE stream, API envelope, and route intents.
- Keep native Android capabilities behind typed platform interfaces.
- `android/gradle.properties` pins `android.aapt2FromMavenOverride` to SDK build-tools 36.0.0 because Maven AAPT2 9.0.1 fails to start on this machine.
