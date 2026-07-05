# Flutter Native Bridge 合同清单

> 状态：Phase 0 inventory 版  
> 目标：把当前 Capacitor plugin / Android service 能力映射为 Flutter platform channel/plugin 合同。

---

## 1. 设计原则

- Flutter UI 只调用 typed interfaces，不直接拼 native method name。
- Native bridge payload 必须有 schema、错误模型和 event stream 说明。
- 后台关键能力优先保留 Android service，再逐步抽象。
- 所有 native event 进入 Flutter 前都要脱敏、校验和去重。
- 日志与 failure payload 脱敏规则见 `docs/flutter/security-privacy-gates.md`，Flutter 侧统一使用 `core/privacy/log_redactor.dart`。

---

## 2. Bridge inventory

| Bridge | Current native source | Current methods/events | Flutter target | Priority |
|---|---|---|---|---|
| `MmcBle` | `MmcBlePlugin.java`; `MmcBleProtocol.java` | `initialize`, `requestLEScan`, `stopLEScan`, `getConnectedDevices`, `connect`, `disconnect`, `read`, `write`, `writeWithoutResponse`, `startNotifications`, `stopNotifications`, `openBluetoothSettings`, `openAppSettings`, `nativeSetPumpParams`, `nativePowerOff`, `nativeEndRun`, `nativeGetDeviceInfo`, `nativeSetRtc`, `nativeQueryDeviceStatus`, `nativeAdjustGearForSide`, `nativeSetModeForSide`, `nativeSetSceneForSide`, `nativeSetStartStopForSide`; events `scanResult`, `scanFailed`, GATT notifications | `BlePlatform` + `PumpProtocolPlatform` | P0 |
| `PumpSessionNotification` | `PumpSessionNotificationPlugin.java`; `PumpSessionForegroundService.java`; `PumpSessionNativeController.java` | `consumePendingNavigate`, `start`, `update`, `stop`, `showCompletionNotice`, `showAutoEndNotice`, `requestPermission` | `PumpSessionForegroundServicePlatform` | P0 |
| `PumpSessionKeepAlive` | `PumpSessionKeepAlivePlugin.java` | `acquire`, `release` | `PumpWakeLockPlatform` | P0 |
| `PumpSessionOverlay` | `PumpSessionOverlayPlugin.java`; `PumpSessionOverlayService.java` | `canDrawOverlays`, `openOverlaySettings`, `snapshot`, `update`, `hide` | `PumpOverlayPlatform` | P1/TBD |
| `PumpAgentUpload` | `PumpAgentUploadPlugin.java`; `PumpAgentBackgroundRunner.java`; `PumpAgentNativeStore.java`; `PumpAgentApiClient.java` | `setConfig`, `updateDeviceSnapshot`, `sampleFromSnapshot`, `resetProgress`, `markStepStop`, `markStepPause`, `setOperationSource`, `uploadWorkstate`, `getProcessData`, `uploadProcess`, `uploadMilkRecord` | `PumpAgentUploadPlatform` | P0 |
| `BackgroundNotify` | `BackgroundNotifyPlugin.java`; `Notify*` classes | `setConfig`, `setEnabled`, `isEnabled`, `syncNow`, `showReminder`, `openExactAlarmSettings`, `openOverlaySettings`, `openBatteryOptimizationSettings`, `openAppNotificationSettings`, `isIgnoringBatteryOptimizations`, `canDrawOverlays`, `canScheduleExactAlarms` | `BackgroundNotifyPlatform` | P1 |
| `DeviceReminderWebSocket` | `DeviceReminderWebSocketPlugin.java`; `DeviceReminderWebSocketService.java`; `DeviceReminderWebSocketPrefs.java` | `start`, `stop`; native foreground service reconnect and notification | `DeviceReminderRealtimePlatform` | P1/TBD |
| `NativeDeviceState` | `DeviceNativeStateStore.java` | native left/right snapshot and active pump state | `NativeDeviceStatePlatform` | P0 |
| `PumpNavigationBridge` | `PumpNavigationBridge.java`; `MainActivity.java` | native to Web route events, pending path | `RouteIntentPlatform` | P0 |

---

## 3. Required contract fields

每个 bridge 必须补齐：

```text
[x] Method name
[x] Request payload schema
[x] Success response schema
[x] Error response schema
[x] Event names and payload schema
[x] Threading expectation
[x] Background availability
[x] Permission preconditions
[x] Idempotency expectation
[x] Test fixture
```

完成矩阵：

| Bridge | Method / request schema | Success schema | Error schema | Events | Threading | Background availability | Permission preconditions | Idempotency | Test fixture |
|---|---|---|---|---|---|---|---|---|---|
| `MmcBle` | `AndroidBlePlatform` maps typed calls to `initialize`, `requestLEScan`, `stopLEScan`, `getConnectedDevices`, `connect`, `disconnect`, `read`, `write`, `writeWithoutResponse`, `startNotifications`, `stopNotifications`; payload uses `deviceId`, `serviceUUID`, `characteristicUUID`, `value`. | `permissionState` returns `{state}`; connected devices return `{devices:[{side,deviceId,name,connected,battery,rssi}]}`; reads return `{value}`. | Permission aliases map to `unknown/denied/permanentlyDenied/granted`; fake throws when scanning without grant or reading disconnected device. | `scanResult`, `scanFailed`, `notification`. | Flutter adapter calls are async; scan and notification events are broadcast streams. | BLE connection state is native-owned; Flutter runtime only treats snapshots as live when native reports them. | BLE runtime permission required before scan/connect/write/notify. | `stopScan`, `disconnect`, `stopNotifications` are repeat-safe; reconnect clears stale subscriptions. | `test/native/android_p0_platform_channels_test.dart`; `test/native/p0_platform_interfaces_test.dart`; `test/core/ble/ble_protocol_test.dart`. |
| `PumpSessionNotification` | `start`, `update`, `stop`, `showCompletionNotice`, `showAutoEndNotice`, `enqueuePendingNavigate`, `consumePendingNavigate`, `restoreSnapshot`, `requestPermission`; snapshot payload includes active/state/elapsed/milk/paused/process. | Permission returns `{granted}`; pending route returns `{path,notifyJson,autoEndTeardown}`; restore returns snapshot or null. | Android MethodChannel errors bubble as typed async failures; fake enforces update after start. | `PumpSessionNativeEventType.started/updated/stopped/completionNotice/autoEndNotice`. | MethodChannel calls are async; native foreground service owns long-running work. | Foreground service and pending route survive background/killed-app paths subject to device lab validation. | Android 13+ notification permission required for visible notices. | `consumePendingNavigate` consumes once; `stop` clears current snapshot. | `test/native/android_p0_platform_channels_test.dart`; `test/native/p0_platform_interfaces_test.dart`; `test/native/pump_native_runtime_coordinator_test.dart`. |
| `PumpSessionKeepAlive` | `acquire`, `release`. | Void success. | Release failure is logged native-side and not surfaced to UI. | None. | Native wake lock calls run on plugin method thread. | Partial wake lock is native-owned while pump session is active. | Requires Android wake lock capability declared in manifest. | Reference-count fake makes extra release safe. | `test/native/p0_platform_interfaces_test.dart`. |
| `PumpSessionOverlay` | `canDrawOverlays`, `openOverlaySettings`, `snapshot`, `update`, `hide`; payload is limited to display state/process, not token/user/conversation. | Boolean permission/snapshot/update status. | Overlay unavailable/permission denied routes to recoverable UI state. | Service update/hide intents only; no Flutter event stream required for P1. | Native service updates are async and UI-triggered. | Overlay service is optional P1/TBD; foreground notification remains P0 source of truth. | `SYSTEM_ALERT_WINDOW` if feature retained. | `hide` and repeated `update` are safe. | Covered by contract inventory and Android source review; true overlay UX remains device lab. |
| `PumpAgentUpload` | `setConfig`, `updateDeviceSnapshot`, `sampleFromSnapshot`, `resetProgress`, `markStepStop`, `markStepPause`, `setOperationSource`, `uploadWorkstate`, `getProcessData`, `uploadProcess`, `uploadMilkRecord`; payloads use user/device snapshot/process fields. | Upload methods return `{body,response,processAll,deduped}`; progress returns `{processL,processR,processAll,elapsedSeconds}`. | `uploadFailure` emits `{method,code,message,retryable,payload}` with payload redacted. | `uploadFailure`, `processProgress`, `processReply`; fake also records method calls. | Upload transport runs on background thread; progress/reply events broadcast to Flutter. | Background runner continues workstate/process-data/process uploads through foreground-service-backed loop. | Requires configured HTTPS API base URL, bearer token, user id, and active native pump/device snapshot. | Summary/workstate/milk upload keys dedupe duplicate completion calls. | `test/native/android_p0_platform_channels_test.dart`; `test/native/p0_platform_interfaces_test.dart`; `test/native/pump_native_runtime_coordinator_test.dart`. |
| `BackgroundNotify` | `setConfig`, `setEnabled`, `isEnabled`, `syncNow`, `showReminder`, settings-open and capability-check methods. | Enabled/capability calls return booleans; sync/show methods return void or status. | Missing config returns retry/success-safe native state; logs omit token/user payload. | Native alarm/notification route intent goes through `RouteIntentPlatform`. | WorkManager/AlarmManager work runs native-side. | P1 background notifications can run without Flutter isolate. | Notification, exact alarm, battery optimization, and optional overlay permissions. | Repeated enable/sync reschedules by unique work/alarm id. | `docs/migration/flutter-permission-lifecycle-matrix.md`; Android `Notify*` source; true permission behavior in device lab. |
| `DeviceReminderWebSocket` | `start`, `stop` with `wsUrl`, `apiBaseUrl`, bearer token, user id config. | Start/stop resolve after native service command dispatch. | Connect/parse/execute failures log redacted failure class/code; no raw URL token. | Native `reminderHandled` event maps reminder type/action/notifyJson into route intent. | OkHttp WS and reconnect loop run native service-side. | P1/TBD native service can reconnect while app is backgrounded. | Foreground service notification permission and network availability. | `start` while running is ignored; `stop` closes socket and removes callbacks. | Android `DeviceReminderWebSocket*` source; true reconnect remains device lab. |
| `NativeDeviceState` | JavaScript bridge legacy surface exposes snapshot/current active pump state; Flutter target is typed native device repository. | Left/right snapshot with paired/connected/runtime pump fields. | Invalid JSON or stale state falls back to disconnected/idle. | Snapshot updates are consumed through BLE notification and pump runtime coordinator streams. | Native state mutation is synchronized on Android lock. | Native store can survive foreground service lifetime. | BLE/device permission before trusting live connection state. | Stale `connected` is never trusted across cold migration without native validation. | `test/core/ble/pump_device_snapshot_test.dart`; storage migration fixtures; Android `DeviceNativeStateStore.java`. |
| `PumpNavigationBridge` / `RouteIntentPlatform` | `enqueuePendingNavigate`, `consumePendingNavigate`, active `activeRoute` event; payload `{path,notifyJson,autoEndTeardown}`. | Pending route returns once or null. | Unsafe/unknown route maps to `RejectUnsafeRoute` or 404 fallback. | `activeRoute` stream while app is foreground. | MethodChannel call/event stream on Flutter UI isolate; native intent handling in `MainActivity`. | Pending route survives notification tap and app cold start subject to Android lifecycle. | No direct permission; caller must re-authorize route content after navigation. | Pending route consumption is one-shot. | `test/native/android_p0_platform_channels_test.dart`; `test/core/routing/route_intent_test.dart`. |

---

## 4. P0 bridge details

### 4.1 `BlePlatform`

必须支持：

```text
[x] permission state
[x] request permission
[x] open Bluetooth settings
[x] open app settings
[x] scan start/stop
[x] scan result stream
[x] scan failure stream
[x] connect/disconnect
[x] get connected devices
[x] read/write/writeWithoutResponse
[x] notification subscribe/unsubscribe
[x] notification event stream
[x] left/right device mapping
```

协议 fixture 必须覆盖：

```text
[x] F0 get device info
[x] F2 set RTC
[x] B0 set work mode
[x] B1 set pump params
[x] B2 set flexible force line
[x] B3 set lactation curve
[x] BF end run
[x] E1 device status decode
```

Fake contract status:

```text
[x] `BlePlatform` fake method schema and streams
[x] `PumpProtocolPlatform` fake command schema for native pump protocol methods
[x] Flutter MethodChannel adapter tests for `MmcBle` BLE method schema and events
[x] Android Kotlin MethodChannel handler shell for `MmcBle`
[x] Android real BLE scan/getConnectedDevices transport implementation for `MmcBle`
[x] Android real GATT connect/read/write/notify transport implementation for `MmcBle`
[x] Flutter `BlePumpProtocolPlatform` sends pump protocol command goldens through `BlePlatform.writeWithoutResponse`
[x] Flutter `PumpNativeRuntimeCoordinator` resolves pump protocol side state from live snapshots
```

### 4.2 `PumpSessionForegroundServicePlatform`

必须支持：

```text
[x] start session notification
[x] update notification snapshot
[x] pause/resume reflected in notification
[x] stop notification
[x] consume pending navigation once
[x] show completion notice
[x] show auto-end notice
[x] request notification permission
[x] restore native snapshot after app killed
[x] foreground service event stream
[x] Flutter MethodChannel adapter tests for `PumpSessionNotification` method schema
[x] Android Kotlin MethodChannel handler shell for pump foreground service
[x] Android real foreground notification/service implementation
[x] Android pending route queue for foreground notification click and snapshot restore
[x] Android real completion and auto-end local notice implementation
```

### 4.3 `PumpAgentUploadPlatform`

必须支持：

```text
[x] fake method schema for configure base URL/token/user id
[x] fake method schema for update Flutter pump device snapshot
[x] fake method schema for sample current pump snapshot
[x] fake method schema for reset progress
[x] fake method schema for mark stop/pause source
[x] fake method schema for upload workstate
[x] fake method schema for get process data
[x] fake method schema for upload process
[x] fake method schema for upload milk record
[x] fake dedupe key coverage for summary/milk record/Agent context upload calls
[x] fake failure stream reports upload failure without leaking sensitive payload
[x] Flutter MethodChannel adapter tests for `PumpAgentUpload` method schema and failure events
[x] Android Kotlin MethodChannel handler shell with progress reset and dedupe response
[x] Android HTTP upload transport on a background thread when `apiBaseUrl` is configured
[x] Android upload failure event avoids token/user id leakage and keeps retry metadata
[x] Android upload body builder consumes `updateDeviceSnapshot` payload for workstate/process/milk fields
[x] Flutter runtime sync forwards `PumpDeviceSnapshotBleBinding` updates into `updateDeviceSnapshot`
[x] Android process frame history parity with legacy `PumpAgentNativeStore`
[x] Android foreground-service-backed progress runner shell for `sampleFromSnapshot`
[x] Android service-backed network tick for workstate/process-data/process uploads
[x] Android service-backed process progress/reply event bridge
[x] Android service-backed background runner parity with legacy `PumpAgentBackgroundRunner`
```

### 4.4 `RouteIntentPlatform`

必须支持：

```text
[x] consume pending route path
[x] consume pending notifyJson
[x] consume autoEndTeardown flag
[x] dispatch native route event while app is active
[x] unknown path fallback
[x] one-shot consumption
[x] Android route event channel implementation
```

---

## 5. Open decisions

1. `MmcBleProtocol` 是否保持 Java 实现，还是迁移到 Dart 后只把 BLE transport 留在 native。
2. `PumpSessionOverlay` 是否作为 Flutter 首版保留能力。
3. `DeviceReminderWebSocket` 是否继续 native WS，还是替换成 push/periodic sync。
4. `Pump session summary` 是否继续 WebSocket，还是改为 HTTP + idempotency。
5. 是否需要为 iOS 预留同一 platform interface。
