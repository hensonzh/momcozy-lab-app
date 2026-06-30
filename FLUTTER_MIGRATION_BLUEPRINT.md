# MomCozyApp Flutter 迁移蓝图

> 状态：Phase 0 准入推进版  
> 范围：将当前 Vite + React + Capacitor Android App 迁移为 Flutter-first 移动客户端。  
> 原则：不要把迁移理解为逐页翻译。它应该是一个新的移动客户端，同时保留已经验证过的产品行为、后端合同和原生设备能力。

---

## 1. 执行摘要

当前 `MomCozyApp` 本质上是一个通过 Capacitor 打包到 Android 的 Web App。核心运行时仍然是 React、Vite、浏览器路由、浏览器存储和 Web 侧渲染。Android 原生代码已经存在，但主要承担能力桥接：BLE、通知、前台服务、泵奶会话保活、悬浮窗和后台 Agent 上传。

目标方向是 Flutter-first App：

- Flutter 负责 App shell、导航、状态管理、UI 渲染和业务模块。
- Android 原生代码只保留平台 API 必须原生实现的部分，并通过 Flutter plugin 或 platform channel 暴露。
- 后端合同继续兼容 `MomCozyAgent` 和现有统一 API 网关。
- 迁移按照风险分阶段推进，而不是按照视觉页面顺序推进。

最高风险不在普通 UI，而在这些部分：

- BLE 协议一致性和设备状态同步。
- Pump session 在前台、后台、通知、悬浮窗之间的生命周期。
- Agent Hub 流式输出和 AG-UI artifact 渲染。
- 从 `localStorage`、`sessionStorage`、Capacitor Preferences 迁移到 Flutter 存储。
- Android 后台通知、服务和系统权限行为。

---

## 2. 当前系统地图

### 2.1 运行形态

```text
React/Vite SPA
  -> BrowserRouter routes
  -> src/pages + src/components
  -> src/lib service modules
  -> Vite dev proxy for /api and /v1
  -> Capacitor Android WebView
  -> Android Java plugins/services for native capabilities
```

当前包形态：

- Web 框架：React 18 + Vite。
- 路由：`react-router-dom`。
- 数据查询：`@tanstack/react-query` 和直接 service modules。
- 原生打包：Capacitor Android。
- Android 原生代码：`android/app/src/main/java/com/momcozymai/app` 下的 Java 类。
- 后端网关默认地址：`http://127.0.0.1:8769`。
- 当前 Web 侧主 Agent 聊天流：`ws://127.0.0.1:8769/api/ag-ui-ws`。Flutter 侧不应直接绑定该 transport，应通过 transport-agnostic Agent stream abstraction 适配 SSE 或 WebSocket。

### 2.2 当前路由

当前在 `src/App.tsx` 挂载的路由：

| Route | 当前页面 | 迁移处理 |
|---|---|---|
| `/` | `AgentHub` | 必须迁移，产品优先级最高。 |
| `/calibration` | `ComfortCalibration` | 必须迁移，依赖 BLE 和泵校准 API。 |
| `/pump` | `PumpSession` | 必须早期迁移，原生和设备风险最高。 |
| `/records` | `Records` | 在泵奶和会话数据模型稳定后迁移。 |
| `/schedule` | `Schedule` | API 合同澄清后迁移。 |
| `/status` | `Status` | 妈妈、宝宝、profile 合同澄清后迁移。 |
| `/community` | `Community` | 低风险，后期迁移或替换。 |
| `/device` | `DeviceManagement` | 必须迁移，依赖 BLE 和原生设备状态。 |
| `/device/manage` | `DeviceManageActions` | 随 device module 一起迁移。 |
| `/device/user` | `UserParameterConfig` | 如果仍有价值，可作为 debug/admin settings 保留。 |
| `/w1` | `W1Promo` | 产品决策：迁移、替换或删除。 |
| `/hospital-bag-cart` | `HospitalBagCart` | 产品决策，通常排在核心流程之后。 |
| `/ibclc-chat.html` | `IbclcChat` | 取决于 vendor 流程，迁移为原生或保留 H5/WebView 容器。 |
| `/media-viewer` | `MediaViewer` | 必须迁移为共享媒体能力。 |

### 2.3 Android 原生能力盘点

| 能力组 | 当前 Android 文件 | Flutter 迁移策略 |
|---|---|---|
| Main activity / WebView bridge | `MainActivity`, `PumpNavigationBridge` | 用 Flutter activity 替换 WebView shell；导航事件改成 Flutter route intents。 |
| BLE | `MmcBlePlugin`, `MmcBleProtocol` | 优先用 Flutter plugin 包装现有协议逻辑；也可以在 parity tests 通过后用 Dart 重写协议。 |
| 设备原生状态 | `DeviceNativeStateStore` | 定义唯一的 Flutter device-state repository；只有后台服务必须使用时才保留 Android 状态。 |
| 后台通知 | `BackgroundNotifyPlugin`, `Notify*` classes | 改成 Flutter plugin + Android service/work manager 集成。 |
| 设备提醒 WebSocket | `DeviceReminderWebSocket*` | 决定 socket 归 Dart 前台层管理，还是继续放在 Android 后台服务。 |
| Pump session 前台服务 | `PumpSessionForegroundService`, `PumpSessionNativeController`, `PumpSessionKeepAlivePlugin` | 保留 Android service，通过 platform channel 暴露控制和事件。 |
| Pump 悬浮窗 | `PumpSessionOverlayPlugin`, `PumpSessionOverlayService` | 产品决策：保留 native overlay，或改成 notification/live activity 类体验。 |
| Pump agent 上传 | `PumpAgentUploadPlugin`, `PumpAgentBackgroundRunner`, `PumpAgentNativeStore`, `PumpAgentApiClient` | 初期保留 Android 侧后台关键上传；Flutter 只提供 session snapshot。 |
| 通知图标和渠道 | `NotificationIconHelper`, `PumpNotificationChannels`, resources | 保留 native resources；补充 Flutter 构建阶段的 asset ownership 规则。 |

---

## 3. 迁移目标与非目标

### 3.1 目标

1. 交付一个 Flutter-first 移动 App，核心产品 UI 不再依赖 WebView。
2. 迁移期间保持现有后端 API 和 Agent 通信合同兼容。
3. 在替换视觉页面之前，先保持 BLE、pump、device 行为一致。
4. 用 typed repositories 和 feature state machines 减少跨页面隐式状态。
5. 明确原生能力归属：Flutter UI 调用 typed interfaces，而不是散落的平台细节。
6. 支持按阶段发布，并有可度量的 parity gates。

### 3.2 非目标

1. 首个 Flutter 客户端迁移阶段不重写后端 API。
2. 迁移时不顺手重设计所有产品流程。设计改动必须单独记录和审批。
3. 不搬运所有旧 mock/prototype 行为，除非 feature matrix 明确保留。
4. Flutter 通过设备、通知和 Agent streaming parity gates 前，不移除现有 Capacitor App。

---

## 4. 迁移前必做工作

### 4.1 冻结当前产品基线

在开始 Flutter 页面之前，需要建立 feature baseline matrix：

| Feature | 当前 owner | 保留 | 重建 | 删除 | 备注 |
|---|---|---:|---:|---:|---|
| Agent Hub 主聊天 | `AgentHub.tsx` | 是 | 是 | 否 | 需要 AG-UI stream parity。 |
| Pump session | `PumpSession.tsx` + pump runtime modules | 是 | 是 | 否 | 原生风险最高。 |
| Comfort calibration | `ComfortCalibration.tsx` | 是 | 是 | 否 | BLE + calibration persistence。 |
| Device management | `DeviceManagement.tsx` | 是 | 是 | 否 | BLE + native device state。 |
| Records | `Records.tsx` | 是 | 是 | 否 | 依赖 milk record API/storage。 |
| Schedule | `Schedule.tsx` | 是 | 是 | 否 | 依赖 plan/task API 合同。 |
| Status | `Status.tsx` | 是 | 是 | 否 | 依赖 mom/baby profile 合同。 |
| Media viewer | `MediaViewer.tsx` + media components | 是 | 是 | 否 | PDF/image/video parity。 |
| IBCLC chat | `IbclcChat.tsx` | 待定 | 待定 | 待定 | 澄清 vendor/H5/native 方向。 |
| Community | `Community.tsx` | 待定 | 待定 | 待定 | 产品决策。 |
| W1 promo | `W1Promo.tsx` | 待定 | 待定 | 待定 | 产品决策。 |
| Hospital bag cart | `HospitalBagCart.tsx` | 待定 | 待定 | 待定 | 产品决策。 |
| Debug user/device pages | `UserParameterConfig`, debug drawers | 待定 | 待定 | 待定 | 仅在 QA/dev 有价值时保留。 |

输出产物：

```text
doc/flutter-feature-baseline.csv
```

### 4.2 提取 API 合同

实现前，每个后端合同都要补齐：

- Endpoint / Stream URL，包括普通 HTTP、SSE 和 WebSocket。
- Request body schema。
- Response schema。
- Error schema。
- Auth 要求。
- Retry/cancellation 行为。
- 是否允许后台运行。
- 当前 Web 实现文件。
- Flutter 中负责它的 repository。

合同分组：

| Domain | 当前来源 | Flutter owner |
|---|---|---|
| Agent / AG-UI chat | `doc/web-api.md`, `src/lib/agentApi.ts` | `features/agent_hub/data` |
| Pump session summary | `doc/websocket接口说明文档.md`, `src/lib/pumpAutoEndSession.ts` | `features/pump_session/data` |
| Pump agent upload | `src/lib/pumpAgentUpload.ts`, Android `PumpAgent*` | `features/pump_session/native` |
| BLE protocol | `doc/设备APP蓝牙通信协议.md`, `src/lib/bleProtocol.ts`, `MmcBleProtocol.java` | `features/device/native` |
| Device state/report | `src/lib/deviceStore.ts`, `DeviceNativeStateStore.java` | `features/device/data` |
| Notifications | `src/lib/mmcBackgroundNotify.ts`, `src/lib/pumpSessionNotification.ts`, Android `Notify*` | `core/notifications` |
| Schedule/plan | `src/pages/Schedule.tsx`, `src/lib/planNotification.ts`, `src/lib/agentApi.ts` | `features/schedule/data` |
| Status/mom/baby | `src/pages/status`, `src/lib/momBabyDelivery.ts`, `src/lib/babyTwinAgentApi.ts` | `features/status/data` |
| Media | `src/lib/mediaCache.ts`, `src/lib/openMediaViewer.ts`, media components | `features/media/data` |
| IBCLC | `src/lib/ibclcConsult.ts`, `src/pages/IbclcChat.tsx` | `features/ibclc/data` |

必须补全的接口清单至少包括：

- `/api/ag-ui`，SSE 形态的 Agent event stream。
- `/api/ag-ui-ws`，当前兼容形态的 Agent event stream。
- `/api/ag-ui-cancel`
- `/api/ag-ui-prewarm`
- `/api/client-event`
- `/api/hospital-bag/cart-update`
- `/v1/files/upload`
- `/v1/realtime-voice-stream`
- `/v1/realtime-voice-session`
- `/v1/speech/transcribe-chunk`
- `/v1/chat-message/history`
- `/v1/pump/threshold/upload`
- `/v1/pump/threshold/get`
- `/v1/pump/workstate`
- `/v1/pump/process`
- `/v1/pump/process/data`
- `/v1/pump/session-summary`
- `/v1/pump-milk/upload`
- `/v1/pump-milk/delete`
- `/v1/pump-milk/query`
- `/v1/mom-baby/info/query`
- `/v1/mom-baby/today/query`
- `/v1/feeding/*`
- `/v1/growth/*`
- `/v1/plan/*`
- `/v1/pregnancy-diary/*`
- `/v1/notify/query`
- `/v1/analysis/create`
- Device reminder WebSocket

### 4.3 定义状态迁移规则

当前状态来源：

- `localStorage`
- `sessionStorage`
- Capacitor Preferences
- Android native SharedPreferences / services
- In-memory module singletons

Flutter 目标状态必须显式定义：

| 状态类别 | 建议 Flutter 存储 | 迁移说明 |
|---|---|---|
| User/runtime config | `shared_preferences` 或必要时 secure storage | 迁移 user ID 和 runtime stage。 |
| Chat conversation id | Local key-value storage | 保留后端 thread/session 连续性。 |
| Chat history cache | 如保留则用 local database | 迁移前定义保留策略。 |
| Device connection state | In-memory repository + Android service state | 不要盲目持久化陈旧 BLE 连接。 |
| Calibration result | Local key-value storage | 保留 left/right + stim/deep schema。 |
| Pump active session | Native service + Flutter state machine | 必须跨前后台切换存活。 |
| Media cache | App documents/cache dir | 需要清理策略。 |
| Notification preferences | Shared preferences + Android service prefs | 后台服务仍 native 时，Android 暂为 source of truth。 |
| Multi-user snapshot | Local database or scoped key-value | 必须按 user 隔离，切换用户时不能串数据。 |
| Pending navigation key | Ephemeral key-value / route intent queue | 通知跳转和后台恢复后要只消费一次。 |
| SessionStorage pump state | Native session snapshot + local recovery key | 只用于恢复，不作为长期事实来源。 |

---

## 5. 目标 Flutter 架构

### 5.1 推荐项目结构

```text
flutter_app/
  lib/
    main.dart
    app/
      app.dart
      router.dart
      lifecycle.dart
    core/
      config/
      design_system/
      errors/
      logging/
      network/
      storage/
      native/
      notifications/
      media/
    features/
      agent_hub/
        data/
        domain/
        presentation/
      device/
        data/
        domain/
        native/
        presentation/
      calibration/
        data/
        domain/
        presentation/
      pump_session/
        data/
        domain/
        native/
        presentation/
      records/
      schedule/
      status/
      media_viewer/
      ibclc/
      hospital_bag/
  test/
  integration_test/
  android/
```

### 5.2 架构边界

- `presentation` 只处理 UI 状态、交互和 view models。
- `domain` 放业务规则、状态机、协议模型和 use cases。
- `data` 负责 HTTP、SSE/WebSocket stream、local storage、DTO mapping。
- `native` 负责 platform channel、Android service、BLE plugin 和权限桥接。
- `core/network` 统一处理 auth、timeout、retry、cancel、日志脱敏。
- `core/storage` 统一处理 legacy key 迁移和多用户隔离。

### 5.3 建议技术选型

| 领域 | 建议 | 说明 |
|---|---|---|
| State management | Riverpod 或 Bloc | 选择团队更熟的一种，避免混用。 |
| Routing | `go_router` | route intents、deep link、通知跳转比较清晰。 |
| HTTP | `dio` 或 `http` + wrapper | 需要 timeout、cancel、interceptor、日志脱敏。 |
| Agent stream transport | `AgentStreamClient` + SSE/WebSocket adapters | Agent 文本和工具事件必须 transport-agnostic，UI 不能感知底层是 SSE 还是 WebSocket。 |
| Device reminder realtime | WebSocket 或 native/push fallback | 不建议在移动后台长期依赖 Dart 层 WebSocket。 |
| Local KV | `shared_preferences` | 适合轻量 key 和迁移标记。 |
| Secure storage | `flutter_secure_storage` | token 或敏感配置。 |
| Local DB | Drift / Isar / Hive | 仅在 chat/history/records 离线缓存确有需要时引入。 |
| BLE | Flutter BLE package 或自定义 plugin | 关键是 protocol parity，不是 package 名字。 |
| PDF/video/image | 平台成熟库 + media abstraction | `MediaViewer` 作为共享能力。 |
| Platform channel | 自定义 typed interface | Pump service、overlay、后台上传、native device state。 |

---

## 6. 原生能力迁移策略

### 6.1 BLE 与泵协议

推荐路线：

1. 先从当前 TypeScript 和 Java 实现提取协议 fixture。
2. 建立 Dart BLE protocol golden tests。
3. 决定 protocol 放在 Dart 还是 Android plugin：
   - 如果要跨平台到 iOS，协议更适合放 Dart。
   - 如果 Android 已经验证稳定，短期可包装现有 Java。
4. 用真泵做 P0 smoke 后再接入 UI。

必须验证：

```text
[ ] F0 获取设备信息
[ ] F2 设置 RTC
[ ] B0 设置工作模式
[ ] B1 设置吸奶参数
[ ] B2 设置 flexible force line
[ ] B3 设置 lactation curve
[ ] BF 结束运行
[ ] E1 设备状态解析
[ ] 左右设备状态隔离
[ ] 断线重连
[ ] app killed 后恢复 native 已连接设备
```

### 6.2 Pump Session 生命周期

Pump session 不应只作为一个 Flutter 页面来实现。它需要是一个业务状态机，并且由 native foreground service 支撑。

推荐边界：

- Flutter：发起、暂停、恢复、结束、展示状态、用户确认。
- Android service：后台计时、通知、系统回收后的最小可恢复状态。
- Shared native store：当前 session snapshot、side 状态、上传状态。
- Backend repository：summary、milk record、Agent context 上传。

必须保证：

```text
[ ] summary 只上传一次
[ ] milk record 只创建一次
[ ] Agent context 只上传一次
[ ] 前后台切换不丢失计时
[ ] 锁屏后通知仍可恢复
[ ] App killed 后重启可恢复或安全结束
[ ] 多用户切换不会沿用上一用户 session
```

### 6.3 通知与后台任务

需要建立权限和版本矩阵：

| Android 版本 | 关注点 |
|---|---|
| Android 11 及以下 | 旧权限模型、后台服务限制、overlay permission。 |
| Android 12 | BLE `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`，精确闹钟限制。 |
| Android 13+ | `POST_NOTIFICATIONS`，通知拒绝后的降级体验。 |
| Android 14+ | foreground service 类型和后台启动限制。 |

必须覆盖：

- Pump foreground service notification。
- Schedule reminder。
- Daily summary / analysis notification。
- Device reminder WebSocket 推送。
- 通知点击后的 route intent。
- 权限拒绝、永久拒绝、系统设置返回。

### 6.4 Agent Streaming

Agent Hub 不只是聊天气泡。它包含：

- AG-UI event stream。
- Tool lifecycle。
- Rich artifacts。
- Card/button/doc/media actions。
- 图片上传。
- 语音输入、TTS/STT、实时语音流。
- Cancel / retry / reconnect。
- 通知语音和用户打断。

迁移方式：

1. 建立 AG-UI parser 的 fixture tests。
2. 定义 `AgentStreamClient` 抽象，输出统一的 `Stream<AgentStreamEvent>`。
3. 实现 `SseAgentStreamClient` 和 `WebSocketAgentStreamClient`，两者共享同一套 AG-UI parser 和 fixtures。
4. UI 只订阅 view model，不直接解析 SSE、WebSocket 或 raw JSON。
5. Artifact renderer 做成可注册组件，避免 feature code 和 Agent protocol 缠在一起。
6. 自动语音播放、通知语音、用户 barge-in 要作为一等交互测试覆盖。

推荐边界：

```text
AgentHub UI
  -> AgentHubController / ViewModel
  -> AgentRepository
  -> AgentStreamClient
       -> SseAgentStreamClient
       -> WebSocketAgentStreamClient
  -> AgUiEventParser
  -> AgentStreamEvent / AgentMessage / Artifact
```

设计约束：

- 文本、tool progress、artifact、run status 统一表达为 domain events。
- `POST /api/agent/runs` 或现有发送接口负责创建/提交用户输入。
- `GET /api/agent/runs/{run_id}/events` 或 `/api/ag-ui` 可作为 SSE stream。
- `/api/ag-ui-ws` 可作为兼容 WebSocket stream。
- `cancel`、`client-event`、`prewarm` 仍走普通 HTTP，更容易做幂等和重试。
- 实时语音流不强行塞进文本流抽象；它应有独立的 voice transport。

---

## 7. 数据与 API 合同 checklist

每个接口至少验证：

```text
[ ] 成功响应
[ ] 业务错误响应
[ ] HTTP 错误
[ ] 超时
[ ] 取消
[ ] token 缺失
[ ] token 过期
[ ] 重试 / 不重试规则
[ ] DTO 映射
[ ] 空字段
[ ] 兼容旧字段
[ ] 日志脱敏
```

特别注意：

- `/api/ag-ui` / `/api/ag-ui-ws` 是 Agent event stream 合同，不是普通 request/response；Flutter 侧必须通过 `AgentStreamClient` 适配，不能让 UI 绑定具体 transport。
- `/v1/files/upload` 必须覆盖 multipart、失败重试和用户取消。
- `/v1/realtime-voice-stream` 和 `/v1/realtime-voice-session` 必须覆盖麦克风权限、打断和断线。
- `/v1/pump/session-summary` 与 `/v1/pump-milk/*` 要防止重复上传。
- `/v1/feeding/*`、`/v1/growth/*`、`/v1/plan/*`、`/v1/pregnancy-diary/*` 要补完整 inventory，不能只迁移首页用到的字段。
- Device reminder WebSocket 需要定义后台存活、重连、auth 过期和通知 fallback。

---

## 8. 迁移阶段

### Phase 0: 基线与合同冻结

目标：在写 Flutter 主功能前，把当前行为、接口和测试准入固定下来。

产物：

- `doc/flutter-feature-baseline.csv`
- `doc/flutter-api-contracts.md`
- `doc/flutter-storage-migration.md`
- `doc/flutter-route-intents.md`
- `doc/flutter-permission-lifecycle-matrix.md`
- `doc/flutter-native-bridge-contracts.md`
- `doc/flutter-baseline-defects.md`
- `doc/flutter-app-test-plan.md`
- `doc/flutter-architecture-decision.md`
- `doc/flutter-p0-smoke-checklist.md`
- `test/fixtures/ble/*`
- `src/lib/bleProtocol.fixtures.test.ts`
- `test/fixtures/ag_ui/*`
- `src/lib/agUiStreamFixtures.test.ts`
- `test/fixtures/api/*`
- `src/lib/apiContractFixtures.test.ts`
- `src/lib/apiTransportFailureFixtures.test.ts`

退出条件：

```text
[x] `npm run build` 通过
[x] `npm test` 绿色，或所有失败登记为 baseline defect
[x] `npm run lint` 无 error / warning，已接受项有局部说明
[x] Feature parity matrix 完成
[x] API contract inventory 完成
[x] API contract fixtures 完成
[x] Storage key inventory 完成
[x] Route/notification intent matrix 完成
[x] BLE protocol fixtures 完成
[x] AG-UI stream fixtures 完成，并覆盖 SSE 和 WebSocket adapter
[ ] 至少 3 类 Android 真机完成 P0 smoke 计划
[x] 真泵 P0 smoke checklist 确认可执行
```

### Phase 1: Flutter Shell 与核心基础设施

目标：搭起 Flutter App 骨架，但不急着重写高风险业务。

内容：

- Flutter project 初始化。
- App theme、design tokens、字体、图标和安全区策略。
- `go_router` route map。
- 网络层、日志、错误模型、auth injection。
- storage migration framework。
- platform channel typed interfaces。
- basic CI：analyze、format、unit tests、Android debug/release build。

退出条件：

```text
[ ] Flutter debug build 可安装
[ ] Android release build 可生成并签名
[ ] 核心 route shell 可导航
[ ] 本地 storage migration 可 dry-run
[ ] Platform channel smoke test 可跑通
```

### Phase 2: 原生能力 PoC

目标：在真实 Android 设备上证明 Flutter 与原生能力的边界可行。

内容：

- BLE scan/connect/read/write PoC。
- Pump foreground service control PoC。
- Notification channel/click intent PoC。
- Overlay permission PoC，如果产品保留悬浮窗。
- Background upload PoC。
- AG-UI transport-agnostic streaming parser PoC。

退出条件：

```text
[ ] 真机 BLE scan/connect 通过
[ ] 真泵基本命令可发送和解析
[ ] Pump foreground service 可启动、更新、停止
[ ] 通知点击能跳转 Flutter route intent
[ ] AG-UI fixture 和真实 stream 均可解析
```

### Phase 3: Device + Pump Foundation

目标：优先迁移设备和泵奶底座，因为它们决定 App 是否真正 native-ready。

内容：

- Device repository。
- BLE permission flow。
- Pair/connect/disconnect/reconnect。
- Calibration state and persistence。
- Pump session state machine。
- Pump notification and restore flow。
- Summary/milk record/Agent context idempotency。

退出条件：

```text
[ ] 单侧设备可连接和控制
[ ] 双侧设备状态不串扰
[ ] 校准数据可保存并用于 Pump
[ ] Pump session 前后台恢复通过
[ ] summary/milk record/Agent context 只上传一次
[ ] 真泵 P0 smoke 通过
```

### Phase 4: Agent Hub

目标：迁移主入口 Agent Hub。

内容：

- AG-UI stream client abstraction。
- SSE adapter。
- WebSocket adapter。
- Message timeline。
- Rich artifact rendering。
- Tool lifecycle UI。
- Image upload。
- Voice input / TTS / STT。
- Cancel/retry/reconnect。
- Notification voice and manual interruption。

退出条件：

```text
[ ] AG-UI fixture golden tests 通过
[ ] 文本、图片、语音输入可用
[ ] Tool progress、失败、重试可用
[ ] 长消息、弱网、断线恢复可用
[ ] Agent Hub P0 widget/integration tests 通过
```

### Phase 5: Records、Schedule、Status

目标：迁移主要数据页面，并完成业务合同覆盖。

内容：

- Records list/chart/manual edit/delete/unit。
- Schedule date navigation/task add/delete/complete/reminder。
- Status 孕期/哺乳期切换、妈妈/宝宝 tab、成长记录、孕期日记。
- Notification badge 和 route intent。

退出条件：

```text
[ ] records/schedule/status API contract tests 通过
[ ] mL/oz、跨天、时区、长文本测试通过
[ ] 通知跳转和 badge 状态通过
```

### Phase 6: 扩展功能与 WebView 替换

目标：处理核心流程外的页面和 H5 依赖。

内容：

- Media viewer。
- IBCLC flow。
- Hospital bag cart。
- Community。
- W1 promo。
- Debug/admin tools。

退出条件：

```text
[ ] 每个功能有明确 retain/rebuild/drop 决策
[ ] 保留的功能完成 parity tests
[ ] H5/WebView 依赖有产品和技术 owner
```

### Phase 7: Release Hardening

目标：准备替换 Capacitor App。

内容：

- Crash/performance monitoring。
- Cold start、jank、memory。
- Android signing/flavor/appId。
- Rollback package strategy。
- Store compliance and privacy review。
- Device lab regression。

退出条件：

```text
[ ] release build 通过并可安装
[ ] P0 真实设备矩阵通过
[ ] 真泵回归通过
[ ] 回滚包和回滚流程确认
[ ] 隐私、安全、日志脱敏检查通过
```

---

## 9. Flutter 功能模块设计

### 9.1 Agent Hub

建议拆分：

```text
features/agent_hub/
  data/
    agent_api.dart
    agent_stream_client.dart
    ag_ui_sse_client.dart
    ag_ui_websocket_client.dart
    voice_api.dart
    upload_api.dart
  domain/
    ag_ui_event.dart
    agent_stream_event.dart
    agent_message.dart
    artifact.dart
    agent_session_state.dart
  presentation/
    agent_hub_page.dart
    message_timeline.dart
    artifact_renderers/
    input_bar.dart
    voice_controls.dart
```

关键规则：

- `AgentStreamClient` 是 UI 和 transport 的唯一边界。
- SSE 和 WebSocket adapter 必须共享 parser fixtures。
- UI 不直接依赖 raw JSON。
- Artifact renderer 支持未知类型 fallback。
- 语音播放状态和文本 stream 状态不能互相覆盖。
- 用户打断要取消语音和必要的生成任务。

### 9.2 Pump Session

建议拆分：

```text
features/pump_session/
  data/
    pump_api.dart
    milk_record_api.dart
    pump_session_repository.dart
  domain/
    pump_session_state.dart
    pump_side_state.dart
    pump_session_machine.dart
    pump_upload_deduper.dart
  native/
    pump_foreground_service.dart
    pump_overlay_channel.dart
    pump_agent_upload_channel.dart
  presentation/
    pump_session_page.dart
    side_control_panel.dart
    session_timer.dart
```

关键规则：

- session state machine 是核心，页面只是展示和触发动作。
- `end session` 必须幂等。
- 后台服务状态要能和 Flutter state reconciliate。
- 任何上传都必须有 dedupe key。

### 9.3 Device

建议拆分：

```text
features/device/
  data/
    device_repository.dart
    device_state_store.dart
  domain/
    device.dart
    pump_device_side.dart
    ble_command.dart
    ble_status.dart
  native/
    mmc_ble_channel.dart
    ble_permission_service.dart
  presentation/
    device_page.dart
    device_card.dart
    scan_sheet.dart
```

关键规则：

- 左右设备必须显式建模。
- permission state、scan state、connection state 分开。
- native connected device 恢复必须经过校验，不直接相信旧缓存。
- debug drawer 只能在 internal/dev 环境显示。

---

## 10. 测试策略

可执行测试方案见：

```text
doc/flutter-app-test-plan.md
```

本节只保留迁移蓝图级别的测试原则。

### 10.1 Unit Tests

必须覆盖：

- BLE packet encoding/decoding。
- AG-UI event parsing。
- Pump session state machine。
- Storage migration。
- API DTO mapping。
- Retry/cancel/idempotency helpers。

### 10.2 Integration Tests

必须覆盖：

- Agent Hub send/cancel/retry。
- Device permission/scan/connect。
- Calibration save and recovery。
- Pump start/pause/resume/end。
- Notification route intent。
- Records/Schedule/Status 关键流程。

### 10.3 Device Tests

必须覆盖：

- Android 11 或以下权限模型。
- Android 12 BLE 新权限模型。
- Android 13+ 通知权限模型。
- 真泵连接、启动、暂停、恢复、结束。
- 前后台、锁屏、杀进程、系统回收。
- Doze、电池优化、overlay permission。

### 10.4 迁移准入门槛

正式开始核心迁移前建议满足：

1. 当前 `npm test`、`npm run lint`、`npm run build` 绿色，或失败项已登记为 baseline defect。
2. 完成 feature parity matrix。
3. 完成 API contract inventory。
4. 完成 storage key inventory。
5. 完成 route/notification intent matrix。
6. 完成 BLE protocol fixture/golden tests。
7. 完成 AG-UI stream fixture/golden tests，并覆盖 SSE/WebSocket adapter。
8. 至少 3 类 Android 真机完成 P0 smoke。
9. 真泵验证通过连接、启动、暂停、恢复、结束、后台运行、通知恢复、只上传一次。

---

## 11. 风险登记表

| 风险 | 影响 | 缓解 |
|---|---|---|
| BLE 行为和旧实现不一致 | 泵无法稳定控制 | 先做 protocol fixtures 和真泵 smoke。 |
| Pump session 后台生命周期丢失 | 数据丢失或重复上传 | 保留 native service，状态机和 dedupe key 双保险。 |
| AG-UI stream 解析不完整 | Agent Hub 体验回退 | fixture/golden tests 覆盖所有 event types。 |
| 权限差异未覆盖 | Android 版本碎片化问题 | 建立 Android version permission matrix。 |
| 存储迁移遗漏 | 老用户数据丢失或串用户 | storage key inventory + migration fixtures。 |
| 语音能力低估 | 核心 Agent 体验缺失 | 把 STT/TTS/realtime voice 作为 P1/P0 流程评估。 |
| 安全隐私不足 | 敏感健康数据泄露 | secure storage、HTTPS/WSS、日志脱敏、数据清理。 |
| 迁移期间基线不清 | 无法判断回归来源 | 先冻结 Web/Capacitor baseline。 |

---

## 12. 兼容与迁移计划

### 12.1 用户数据兼容

迁移必须支持：

- 识别 legacy storage。
- 迁移后写入 Flutter storage。
- 迁移过程可重入和幂等。
- 迁移失败可回退到安全默认值。
- 用户切换时清理或隔离 scoped state。
- 提供内部 debug 页面查看迁移状态。

不要迁移：

- 陈旧 BLE connected flag。
- 已过期 pending navigation。
- 未完成且无法校验的旧 session。
- 旧 demo/mock/prototype 数据，除非产品明确要求。

### 12.2 发布兼容

发布策略：

- 初期保留 Capacitor App 作为 rollback。
- Flutter 使用独立 flavor 或内部测试渠道。
- 后端保持对 Web/Capacitor 和 Flutter 的合同兼容。
- 关键上传接口需要支持 Flutter dedupe key。
- 监控 release build 的 crash、cold start、network failures、background failures。

---

## 13. 待决策问题

1. Flutter 状态管理最终选 Riverpod 还是 Bloc。
2. BLE protocol 是否重写为 Dart，还是先包装 Java。
3. Pump overlay 是否作为产品能力保留。
4. IBCLC 是否保留 H5 vendor flow。
5. Community、W1 promo、Hospital bag cart 是否进入首版 Flutter parity。
6. Chat history 是否需要本地 DB 离线缓存。
7. iOS 是否进入本轮架构约束，如果进入，native boundary 要提前抽象。
8. Android minSdk、targetSdk、appId、flavor、签名策略。
9. Flutter/Dart 版本和 CI 镜像版本。
10. Agent 文本流首发默认 transport 选 SSE 还是 WebSocket；无论选哪个，Flutter 侧都必须保持 `AgentStreamClient` 抽象。

---

## 14. 立即下一步

建议按这个顺序推进：

1. 将 pump protocol state machine 接到 Flutter BLE transport。
2. 补齐 process frame history 与 service-backed background runner parity。

已完成的本机准入：

```text
[x] Flutter / Dart / JDK / Android SDK 已安装到用户目录工具链
[x] `npm run flutter:check` 通过
[x] `npm run flutter:init` 已创建 `flutter_app/`
[x] `flutter_app` 单测通过
[x] `flutter build apk --debug` 通过
[x] 临时 appId / flavor / signing 策略已明确，Flutter PoC 使用 `com.momcozymai.app.flutterpoc`
[x] P0 工具链固定方案已明确：不引入 FVM，使用 `flutter-toolchain.json` + `npm run flutter:check`
[x] Security/privacy gates 已定义，Flutter 日志脱敏工具与 P0 tests 已落地
[x] BLE fixtures 已接入 Flutter golden/parity tests
[x] AG-UI / API / storage / route fixtures 已接入 Flutter tests
[x] P0 native fake platform interfaces 已接入 Flutter tests
[x] BLE / PumpProtocol / Pump foreground / Route fake method schemas 与 event streams 已接入 Flutter tests
[x] `PumpAgentUploadPlatform` fake method schema、失败脱敏与 dedupe tests 已补齐
[x] Flutter 侧 Android MethodChannel adapters 已覆盖 `MmcBle` BLE 与 Pump foreground schema tests
[x] Android Kotlin MethodChannel handler shell 已接入 `MmcBle` 与 Pump foreground channel，debug APK 构建通过
[x] Android Pump foreground notification service 已接入 Flutter MethodChannel，debug APK 构建通过
[x] Android `MmcBle` scan/getConnectedDevices 已接入 Flutter MethodChannel，debug APK 构建通过
[x] Android `MmcBle` GATT connect/read/write/notify 已接入 Flutter MethodChannel，debug APK 构建通过
[x] Flutter 侧 `PumpAgentUploadPlatform` MethodChannel adapter 已覆盖 method schema 与 failure events
[x] Android `PumpAgentUploadPlatform` Kotlin MethodChannel handler shell 已接入，debug APK 构建通过
[x] Android `PumpAgentUploadPlatform` HTTP transport 已接入：按 method 映射 `/v1/pump/workstate`、`/v1/pump/process/data`、`/v1/pump/process`、`/v1/pump-milk/upload`，保留 dedupe/failure event 返回契约
[x] Flutter `PumpDeviceSnapshot` reducer 已覆盖 E1/D0/D6/0x80/BF frame 更新、左右设备隔离与 legacy timestamp/milk 字段
[x] Flutter `PumpDeviceSnapshotBleBinding` 已接入 `BlePlatform.notifications`，覆盖 connected device seed、notify subscription 与 unknown device ignore
[x] `PumpAgentUploadPlatform.updateDeviceSnapshot` MethodChannel contract 已接入，Android upload body builder 已消费 Flutter snapshot 的 workstate/process/milk 字段
[x] `PumpAgentUploadSnapshotSync` 已将 `PumpDeviceSnapshotBleBinding` updates 串行同步到 `PumpAgentUploadPlatform.updateDeviceSnapshot`
```

---

## 15. 迁移准备完成定义

满足以下条件后，才建议正式进入 Flutter 核心功能实现：

```text
[x] Web/Capacitor 当前行为已冻结
[x] 已知测试和 lint 问题已修复或登记
[ ] 保留、重建、删除的功能边界明确
[x] API 合同可测试
[x] Storage migration 可测试
[x] BLE protocol 有 fixture/golden tests
[x] AG-UI stream 有 fixture/golden tests
[x] Native bridge contract 已定义
[x] Flutter P0 native fake adapter 初版已定义
[x] 权限和生命周期矩阵已定义
[x] Flutter 工具链检查/初始化命令已准备
[x] `npm run flutter:check` 通过
[x] Flutter shell debug APK 可构建
[x] 真机和真泵 P0 smoke 计划可执行
[ ] Flutter shell 可以安装、运行，并完成真机 smoke
```
