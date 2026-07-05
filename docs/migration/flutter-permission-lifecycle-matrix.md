# Flutter 权限与生命周期矩阵

> 状态：Phase 0 inventory 版  
> 目标：迁移前明确 Android 权限、版本差异、后台生命周期和真机验收范围。

---

## 1. 当前 Android manifest 权限

当前旧 Capacitor manifest `legacy_web/android/app/src/main/AndroidManifest.xml` 声明：

```text
INTERNET
FOREGROUND_SERVICE
FOREGROUND_SERVICE_CONNECTED_DEVICE
FOREGROUND_SERVICE_DATA_SYNC
POST_NOTIFICATIONS
SYSTEM_ALERT_WINDOW
RECORD_AUDIO
MODIFY_AUDIO_SETTINGS
RECEIVE_BOOT_COMPLETED
WAKE_LOCK
USE_FULL_SCREEN_INTENT
SCHEDULE_EXACT_ALARM
REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
BLUETOOTH / BLUETOOTH_ADMIN / ACCESS_FINE_LOCATION, maxSdkVersion=30
BLUETOOTH_SCAN
BLUETOOTH_CONNECT
```

---

## 2. 权限矩阵

| Capability | Permission | Android 11 及以下 | Android 12 | Android 13+ | Android 14+ | Current owner |
|---|---|---|---|---|---|---|
| BLE scan/connect | `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` | 位置/旧蓝牙权限 | 新 BLE runtime permissions | 同 Android 12 | 同 Android 12，注意后台限制 | `MmcBlePlugin` |
| Notifications | `POST_NOTIFICATIONS` | 不需要 runtime notification permission | 不需要 runtime notification permission | 需要 runtime grant | 需要 runtime grant + FGS 限制 | `BackgroundNotifyPlugin`, `PumpSessionNotificationPlugin` |
| Foreground service | `FOREGROUND_SERVICE*` | 需要通知 channel | FGS 限制增强 | 通知权限影响展示 | FGS type 更严格 | `PumpSessionForegroundService`, `DeviceReminderWebSocketService` |
| Overlay | `SYSTEM_ALERT_WINDOW` | 设置页授权 | 设置页授权 | 设置页授权 | 后台启动更敏感 | `PumpSessionOverlayPlugin` |
| Microphone | `RECORD_AUDIO` | runtime permission | runtime permission | runtime permission | runtime permission + 后台限制 | voice/STT/TTS |
| Exact alarm | `SCHEDULE_EXACT_ALARM` | 较宽松 | 设置页授权/限制 | 设置页授权/限制 | 更严格 | `BackgroundNotifyPlugin`, `NotifyAlarmScheduler` |
| Battery optimization | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | 厂商差异 | 厂商差异 | 厂商差异 | 厂商差异 + FGS 限制 | `BackgroundNotifyPlugin` |
| Boot restore | `RECEIVE_BOOT_COMPLETED` | boot receiver | boot receiver | boot receiver | boot receiver + background limits | `NotifyBootReceiver` |
| Wake lock | `WAKE_LOCK` | partial wake lock | partial wake lock | partial wake lock | partial wake lock with FGS care | `PumpSessionKeepAlivePlugin`, `PumpSessionNativeController` |

---

## 3. 权限流验收

本地 fake/platform contract 已覆盖通用权限状态；真实系统弹窗、设置页回跳、厂商差异和 Android 版本差异仍按第 5、6 节的 device lab 清单执行。

```text
[x] 未请求
[x] 首次允许
[x] 首次拒绝
[x] 永久拒绝
[x] 打开系统设置
[x] 从系统设置返回
[x] 功能降级提示
[x] 不可用状态下不崩溃
```

当前本地覆盖来源：BLE 权限与设置页 handoff 使用 `momcozy_feature_pages_test.dart`、`p0_platform_interfaces_test.dart` 和 `android_p0_platform_channels_test.dart`；麦克风权限使用 Agent voice controller/page tests；overlay permission fallback 使用 `pump_overlay_route_action_test.dart`；foreground notification permission 使用 Android MethodChannel schema tests。

---

## 4. App 生命周期矩阵

| Scenario | Agent Hub | Device/BLE | Pump session | Notifications | Required result |
|---|---|---|---|---|---|
| 冷启动 | 恢复会话 id 和必要 chat cache | 不信任 stale connected | 从 native snapshot 恢复或 idle | 恢复 pending intent | 不崩溃，不重复消费 intent。 |
| 热启动 | 保留 UI state | 继续显示 repository state | 继续 session | 无重复通知 | 状态一致。 |
| 后台 5 分钟 | stream 可断开并恢复 | BLE 状态由 native 校验 | foreground service 继续 | 通知可点击 | 不丢计时。 |
| 锁屏 | 语音可安全暂停/恢复 | native BLE 不被 UI 销毁影响 | foreground notification 可恢复 | 通知 channel 正常 | 泵奶不丢失。 |
| 杀进程 | 不能依赖 Dart memory | native 连接需校验 | native service snapshot 决定恢复 | pending intent 只消费一次 | 不重复上传。 |
| 系统回收 | 同杀进程 | 同杀进程 | 同杀进程 | 同杀进程 | 安全恢复或安全结束。 |
| 用户切换 | 清理/隔离 chat | 断开或隔离设备 | 禁止沿用上个用户 session | 清理 scoped pending | 不串用户。 |

---

## 5. 真机矩阵

最小 P0 真机组合：

```text
[ ] Android 11 或以下：旧蓝牙/定位权限模型
[ ] Android 12：BLE_SCAN / BLE_CONNECT
[ ] Android 13+：POST_NOTIFICATIONS
[ ] 至少一台低端设备：性能和后台回收
[ ] 至少一台厂商深度定制系统：电池优化和后台限制
[ ] 真泵左设备
[ ] 真泵右设备
[ ] 真泵双侧设备
```

---

## 6. Pump session P0 smoke

```text
[ ] BLE permission allow/deny/permanent deny
[ ] 连接左设备
[ ] 连接右设备
[ ] 双侧连接
[ ] 启动 session
[ ] 暂停 session
[ ] 恢复 session
[ ] 结束 session
[ ] 后台运行 5 分钟
[ ] 锁屏后通知恢复
[ ] App killed 后恢复或安全结束
[ ] summary 只上传一次
[ ] milk record 只创建一次
[ ] Agent context 只上传一次
[ ] 电池优化开启/关闭差异
[ ] overlay permission allow/deny，如果保留 overlay
```
