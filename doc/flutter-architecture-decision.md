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
[x] Android `MmcBle` GATT connect/read/write/notify 已接入 Flutter MethodChannel，debug APK 构建通过
[x] Flutter 侧 `PumpAgentUploadPlatform` MethodChannel adapter 已覆盖 method schema 与 failure events
[x] Android `PumpAgentUploadPlatform` Kotlin MethodChannel handler shell 已接入，debug APK 构建通过
[x] Android `PumpAgentUploadPlatform` HTTP transport 已接入；真实 pump snapshot/body parity 和 service-backed runner 仍是下一步
[x] Flutter `PumpDeviceSnapshot` reducer 已落地并覆盖 legacy BLE protocol frame 到设备快照的字段更新
[x] Flutter `PumpDeviceSnapshotBleBinding` 已接入 `BlePlatform.notifications`，为后续 PumpAgentUpload body parity 提供实时快照源
[x] `PumpAgentUploadPlatform.updateDeviceSnapshot` 与 Android upload body builder 已接入 Flutter pump snapshot contract
[x] `PumpAgentUploadSnapshotSync` 已接入，把实时 pump snapshot 串行同步给 upload platform
[x] `BlePumpProtocolPlatform` 已接入 Flutter BLE transport，覆盖 protocol command golden writes 与缺失状态 guard
[x] `PumpNativeRuntimeCoordinator` 已组合 snapshot binding、upload sync 与 BLE protocol state resolver
[x] Android pump process frame history 已与 legacy `PumpAgentNativeStore` 20 帧窗口对齐
[x] Android service-backed runner shell 已接入 foreground service 生命周期与 1 秒采样刷新
[x] Android service-backed runner 已接入 network tick 与 process progress/reply typed streams
[x] Flutter `go_router` 核心 route shell 已接入，底部导航、专注流程隐藏底栏和 unknown route fallback 已有 widget tests
[x] Flutter feature page skeletons 已覆盖主要 route map，不再使用通用路径占位页
[x] Flutter Status/Schedule typed repository contracts 已开始落地，UI 后续通过 repository/use case 读取后端权威状态
[x] Flutter `AgentStreamClient` 抽象已落地，SSE/WebSocket adapters 共享 parser/fixtures 并通过 client tests
[x] Flutter AG-UI outbound payload builder 已对齐首帧 fixture，后续真实 SSE/WS transport 只负责传输
[x] Flutter Agent stream IO transport shell 已落地，SSE POST 与 WebSocket first-frame adapter 共用 endpoint/auth/redaction config
[x] Flutter `/api/ag-ui-cancel` control client 已落地，2xx/404 视为 ack，5xx/network 不阻塞本地停止态
[x] Flutter `AgentStreamRunState` reducer 已落地，UI/view model 可复用统一 streaming/finished/error/disconnected/cancelled 状态
[x] Flutter `AgentStreamRunner` 已落地，UI/view model 只依赖 `AgentStreamClient` 和统一 run state，不判断 SSE/WebSocket transport
[x] Flutter `/api/ag-ui-prewarm` control client 已落地，兼容 envelope/root object 和 snake/camel legacy aliases
[x] Flutter `/api/ag-ui-timing-log` control client 已落地，best-effort failure 不影响 Agent stream 主流程
[x] Flutter `/api/client-event` control client 已落地，IBCLC/通知/分析类事件可复用 best-effort 写回通道
[x] Flutter Agent Hub 页面骨架已接入根路由，状态 badge、transcript 和 composer 均消费统一 `AgentStreamRunState`
[x] Flutter Agent Hub composer 已接入 injected `AgentStreamRunner`，真实 transport 仍可通过 `AgentStreamClient` 替换
[x] Flutter App root 已注入默认 Agent Hub SSE runner，endpoint/token/user/thread 通过 dart-define 配置
[x] Flutter Agent Hub stop 已接入 best-effort cancel client，保持 UI cancellation 与服务端 cancel 解耦
[x] Flutter Agent Hub retry 已在 UI 层复用缓存 request，不向 transport 暴露重试策略细节
[x] Flutter Agent Hub work panel 已从统一 stream events 派生，不直接消费 provider/raw tool JSON
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
