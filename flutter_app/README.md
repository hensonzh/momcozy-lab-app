# MomCozy Flutter App

Phase 0 Flutter shell for the MomCozyApp migration.

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

From the parent `MomCozyApp/` directory:

```bash
npm run flutter:check
npm run flutter:init
```

Pinned versions live in [`flutter-toolchain.json`](../flutter-toolchain.json);
`npm run flutter:check` validates the local SDK/JDK/Android directories and versions against that file.

From this `flutter_app/` directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Agent Hub 默认使用 SSE transport，并可通过 dart-define 配置：

```bash
flutter run \
  --dart-define=MOMCOZY_AGENT_SSE_URL=http://192.168.x.x:8768/api/ag-ui \
  --dart-define=MOMCOZY_API_TOKEN=APP_API_TEST \
  --dart-define=MOMCOZY_DEFAULT_USER_ID=demo-user \
  --dart-define=MOMCOZY_AGENT_THREAD_ID=thread-demo
```

Android 真机不能使用 `127.0.0.1` 访问电脑上的 Agent 服务，需要改成手机可访问的局域网或公网地址。Android emulator 可使用 `10.0.2.2`。

Current Android PoC package:

- `applicationId`: `com.momcozymai.app.flutterpoc`
- Packaging policy: [doc/flutter-android-packaging.md](../doc/flutter-android-packaging.md)

## Phase 0 Contract Tests

Current Dart test coverage:

- AG-UI stream fixtures parse equivalently across JSONL, SSE eventstream, and WebSocket frame forms.
- API envelope fixtures distinguish success, business errors, HTTP errors, and legacy snake/camel aliases.
- Privacy fixtures cover shared log redaction for sensitive keys and URL query parameters.
- BLE fixtures cover request packet goldens, standalone hex files, valid/invalid frame parsing, parser edge cases, cross-platform parity cases, and side mapping.
- Storage migration fixtures cover valid core state and malformed legacy fallback.
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
- Pump agent upload MethodChannel adapter fixtures cover native method schemas and failure events.
- Pump agent upload fake platform fixtures cover method schemas, call/failure streams, sensitive failure redaction, and duplicate upload dedupe keys.
- Agent Hub runtime fixtures cover default SSE runner injection, AG-UI payload generation, and route-shell composer send-ready state.

Next migration gap:

- Run Android real-device P0 smoke for BLE, foreground service, background runner uploads, and notification recovery.

## Migration Notes

- Keep the existing Web/Capacitor app as the behavior baseline until Flutter parity gates pass.
- Add fixtures before feature UI: BLE protocol, AG-UI stream, API envelope, storage migration, and route intents.
- Keep native Android capabilities behind typed platform interfaces.
- `android/gradle.properties` pins `android.aapt2FromMavenOverride` to SDK build-tools 36.0.0 because Maven AAPT2 9.0.1 fails to start on this machine.
