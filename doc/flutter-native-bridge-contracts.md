# Flutter Native Bridge 合同清单

> 状态：Phase 0 inventory 版  
> 目标：把当前 Capacitor plugin / Android service 能力映射为 Flutter platform channel/plugin 合同。

---

## 1. 设计原则

- Flutter UI 只调用 typed interfaces，不直接拼 native method name。
- Native bridge payload 必须有 schema、错误模型和 event stream 说明。
- 后台关键能力优先保留 Android service，再逐步抽象。
- 所有 native event 进入 Flutter 前都要脱敏、校验和去重。
- 日志与 failure payload 脱敏规则见 `doc/flutter-security-privacy-gates.md`，Flutter 侧统一使用 `core/privacy/log_redactor.dart`。

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
[ ] Method name
[ ] Request payload schema
[ ] Success response schema
[ ] Error response schema
[ ] Event names and payload schema
[ ] Threading expectation
[ ] Background availability
[ ] Permission preconditions
[ ] Idempotency expectation
[ ] Test fixture
```

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
[ ] Android service-backed background runner parity with legacy `PumpAgentBackgroundRunner`
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
[ ] Android route event channel implementation
```

---

## 5. Open decisions

1. `MmcBleProtocol` 是否保持 Java 实现，还是迁移到 Dart 后只把 BLE transport 留在 native。
2. `PumpSessionOverlay` 是否作为 Flutter 首版保留能力。
3. `DeviceReminderWebSocket` 是否继续 native WS，还是替换成 push/periodic sync。
4. `Pump session summary` 是否继续 WebSocket，还是改为 HTTP + idempotency。
5. 是否需要为 iOS 预留同一 platform interface。
