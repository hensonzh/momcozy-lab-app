# Flutter 架构技术栈决策

> 状态：Phase 0 ADR，PoC 执行前可复核。  
> 范围：MomCozyApp 从 Web/Capacitor 迁移到 Flutter-first Android App 的首版技术栈。  
> 当前本机状态：Flutter / JDK / Android SDK 已安装，`flutter_app/` shell 已创建，`flutter test` 和 debug APK 构建已通过；iOS/Xcode/CocoaPods 暂不作为 P0 gate。

---

## 1. 决策摘要

首版 Flutter 迁移采用 Android-first、typed boundary、fixture-first 的架构：

- Flutter 负责 App shell、路由、UI、feature state 和普通网络请求。
- Android 原生继续负责 BLE、前台服务、通知、悬浮窗、后台上传等必须原生存活的能力。
- Flutter 与 Android 之间使用 typed platform channel；P0 能力优先保留现有 Java 实现，再逐步重写。
- 所有高风险协议先跑 fixtures，再接真实设备或真实后端。

---

## 2. 工程布局

建议在当前仓库下新增独立 Flutter 工程：

```text
MomCozyApp/
  flutter_app/
    lib/
      app/
      core/
      features/
      native/
      l10n/
    test/
      fixtures/
    integration_test/
    android/
```

迁移期间保留现有 Web/Capacitor App，作为行为基线和 rollback 包来源。

---

## 3. 技术栈选择

| 层 | 决策 | 原因 |
|---|---|---|
| 路由 | `go_router` | route intent、通知跳转、深链和 tab shell 都需要统一入口。 |
| Feature state | Riverpod 优先 | 更贴近当前 hooks/repository 思维，便于按 feature 注入 mock repository 和 platform adapter。 |
| 高风险状态机 | 显式 reducer/state machine | Pump session、BLE connection、Agent stream 不依赖隐式 mutable store。 |
| DTO / JSON | typed DTO + generated JSON mapper | API、AG-UI、BLE/native event 都必须可测试、可兼容 legacy alias。 |
| HTTP | `NetworkClient` wrapper | 外层统一 auth、timeout、cancel、retry、日志脱敏；具体实现可在 PoC 阶段固定。 |
| Agent stream | `AgentStreamClient` 抽象 | SSE 和 WebSocket adapter 共享 parser、fixtures 和 UI reducer。 |
| WebSocket | 独立 adapter | Agent stream、pump summary、device reminder 不混用同一生命周期策略。 |
| Secure data | secure storage | token 和敏感用户标识不得落普通 preferences。 |
| Preferences | shared preferences | feature flags、已迁移标记、非敏感设置。 |
| Local cache | P0 暂缓，必要时引入本地 DB | chat/media/records 是否离线缓存需要产品决策。 |
| Native bridge | typed platform interfaces | `MmcBle`、Pump service、notifications、overlay、background upload 必须 schema 化。 |
| BLE protocol | 先包装 Java，Dart parity 后再重写 | 降低真泵控制风险。 |
| 测试 | `flutter_test` + integration tests + device checklist | Unit/fixture 先行，真机和真泵作为 release gate。 |

---

## 4. 模块边界

```text
core/
  network/
  storage/
  logging/
  auth/
  routing/
  permissions/
  time/

native/
  ble_platform.dart
  pump_session_service_platform.dart
  notification_platform.dart
  overlay_platform.dart
  background_upload_platform.dart
  route_intent_platform.dart

features/
  agent_hub/
  device/
  calibration/
  pump_session/
  records/
  schedule/
  status/
  media/
  ibclc/
  hospital_bag/
```

规则：

- feature UI 不直接调用 platform channel。
- feature UI 不直接拼 URL。
- repository 不直接读 widget context。
- native event 进入 feature 前必须先转成 typed domain event。
- 所有 user-facing state 都要有 loading、empty、error、retry 或 fallback。

---

## 5. P0 实现顺序

1. 初始化 Flutter shell、theme、routing、logging。
2. 移植 fixtures：
   - [x] `test/fixtures/ble/*`
   - [x] `test/fixtures/ag_ui/*`
   - [x] `test/fixtures/api/*`
   - [x] `test/fixtures/storage_migration/*`
   - [x] `test/fixtures/route_intents/*`
3. 实现 core network/storage/router skeleton。
4. 实现 native platform interfaces 的 fake adapter。
5. 接入 Android `MmcBle` 和 Pump foreground service PoC。
6. 接入 Agent `AgentStreamClient`，先跑 fixture parser，再连真实 SSE/WebSocket。
7. 迁移 Device + Calibration + Pump session foundation。

---

## 6. Flutter Shell 初始化准入

初始化前必须满足：

```text
[x] `npm run flutter:check` 通过
[x] Flutter/Dart 版本写入工程 README 或 toolchain 文件
[x] Android SDK / JDK / Gradle 环境可构建 debug APK
[x] 明确 appId / flavor / signing 的临时策略，Flutter PoC 使用 `com.momcozymai.app.flutterpoc`
[x] 决定使用 `flutter-toolchain.json` + `npm run flutter:check`，P0 不引入 FVM
[x] Security/privacy gates 已定义，Flutter 日志脱敏工具与 P0 tests 已落地
[x] 现有 Web baseline 仍可测试和构建
```

当前状态：

```text
[x] 工具链检查/初始化脚本已准备：`npm run flutter:check`、`npm run flutter:init`
[x] `npm run flutter:check` 通过
[x] Java runtime 可用：Temurin OpenJDK 17.0.19+10
[x] adb / Android platform-tools 可用：36.0.0-13206524
[x] Flutter shell 已初始化：`flutter_app/`
[x] `flutter_app` 单测通过
[x] `flutter build apk --debug` 通过
[x] Flutter Android PoC appId / flavor / signing 策略已记录：`doc/flutter-android-packaging.md`
[x] Flutter / Android / JDK 版本固定源已记录：`flutter-toolchain.json`
[x] Flutter 安全隐私准入已记录：`doc/flutter-security-privacy-gates.md`
[x] Web baseline 可测试和构建
[x] BLE / AG-UI / API / storage / route fixtures 已准备
[x] Flutter BLE / AG-UI / API / storage / route fixture tests 已开始落地
[x] P0 native fake platform interfaces 已开始落地
[x] Flutter BLE golden/parity tests 已移植
[x] BLE / PumpProtocol / Pump foreground / Route fake method schemas 与 event streams 已测试
[x] `PumpAgentUploadPlatform` fake method schema、失败脱敏与 dedupe tests 已补齐
[x] Flutter 侧 Android MethodChannel adapters 已覆盖 `MmcBle` BLE 与 Pump foreground schema tests
[x] Android Kotlin MethodChannel handler shell 已接入 `MmcBle` 与 Pump foreground channel，debug APK 构建通过
[x] Android Pump foreground notification service 已接入 Flutter MethodChannel，debug APK 构建通过
[x] Android `MmcBle` scan/getConnectedDevices 已接入 Flutter MethodChannel，debug APK 构建通过
[ ] iOS/Xcode/CocoaPods 环境可用（非 P0 Android gate）
```

工具链安装和初始化流程见 `doc/flutter-toolchain-bootstrap.md`。

---

## 7. 待复核决策

1. Riverpod 是否作为最终状态管理，或改用 Bloc。
2. HTTP wrapper 的底层实现固定为 Dio 还是 package:http。
3. typed platform channel 是否使用 Pigeon 生成，还是先手写 MethodChannel facade。
4. chat history 是否需要本地 DB 离线缓存。
5. iOS 是否进入本轮架构约束。
6. Flutter toolchain 版本和 CI 镜像版本。
