# Flutter App 测试方案

> 范围：`MomCozyApp` 从 Vite + React + Capacitor 迁移到 Flutter 的 App 端测试方案。  
> 状态：Phase 0 准入推进版。  
> 负责人：mobile engineering + QA + backend contract owners。

---

## 1. 目的

本文档定义 Flutter 重写的可执行测试策略和迁移准入门槛。

当前 Web/Capacitor App 是行为基线。Flutter 实现必须先证明已保留产品流程的行为一致性，才能替换当前客户端。

这个测试方案故意不只覆盖 unit tests。迁移风险主要集中在原生能力、生命周期、权限、Agent 流式输出、BLE 和后台泵奶行为。

---

## 2. 当前基线要求

在生产级 Flutter 实现开始之前：

- `npm test` 应该绿色，或每个失败测试都必须登记为 baseline defect。
- `npm run build` 应该通过。
- `npm run lint` 应该无 error 和 warning；如必须接受 warning，需要在 baseline defects 中说明原因。
- Feature parity 决策必须记录到 feature baseline matrix。

当前迁移前阻断性 baseline defects：

```text
[x] `npm run build` 通过
[x] `npm test` 通过
[x] `npm run lint` 无 error / warning
```

本轮 Phase 0 已修复的历史 baseline defects：

| ID | 来源 | 现象 | 必要处理 |
|---|---|---|---|
| WEB-BASELINE-001 | `src/lib/androidNotificationIcons.test.ts` | launcher portrait ratio 断言期望 `0.56-0.58`，旧图片约为 `0.802`。 | 已修复资源。 |
| WEB-BASELINE-002 | `src/pages/status/StatusOverviewBody.render.test.tsx` | 测试期望固定 `demo_mama_increase_001`，运行时发送生成的 `demo-user-*`。 | 已修复测试期望。 |

每个 baseline defect 必须包含：

```text
[ ] 负责人
[ ] 严重级别
[ ] 决策：迁移前修复 / 接受为基线 / Flutter 中废弃
[ ] issue 或跟踪文档链接
[ ] 复查命令
```

---

## 3. 测试分层

| 层级 | 范围 | 工具建议 | 必须覆盖 |
|---|---|---|---|
| L0 Unit | 纯逻辑、DTO、协议、reducers、状态机、存储迁移 | `flutter test` | BLE packet、AG-UI parser、pump state machine、API DTO、storage migration |
| L1 Widget/UI | 单个组件/页面、空态、错误态、golden 视觉状态 | Flutter widget tests + golden tests | Agent Hub、Pump、Device、Calibration、Records、Schedule、Status、Media |
| L2 App Interaction | App 进程内的真实导航和用户流程 | `integration_test`、Maestro 或 Patrol | 导航、手势、输入、弹窗、权限拒绝/重试、后台恢复 |
| L3 API Contract | HTTP、SSE/WebSocket、上传、语音、native bridge 合同 | Mock server + fixtures + contract tests | `/api/ag-ui`、`/api/ag-ui-ws`、`/v1/*`、pump summary WS/API、voice WS/API、multipart upload |
| L4 Device Lab | Android 真机和真实泵硬件 | 手工和自动化真机 checklist | BLE、前台服务、通知、悬浮窗、杀进程、Doze、电池优化 |
| L5 Release Gate | 构建、签名、性能、稳定性 | CI + release build + crash/perf tools | Release build、app signing、cold start、jank、crash-free sessions、rollback |

退出规则：

- 所有 P0 保留功能必须具备自动化 L0 和 L3。
- 替换 Capacitor App 前必须在真实设备上执行 L4。

---

## 4. 必备 Fixtures

### 4.1 AG-UI Fixtures

已创建以下 fixture 文件：

```text
test/fixtures/ag_ui/
  README.md
  run_started.json
  text_stream_basic.jsonl
  text_stream_basic.eventstream
  text_stream_basic.websocket.jsonl
  tool_call_lifecycle.jsonl
  activity_snapshot.json
  rich_text_artifact.json
  image_upload_message.json
  run_error.json
  cancel_ack.json
```

必须覆盖：

- `RUN_STARTED`
- `CUSTOM`
- `ACTIVITY_SNAPSHOT`
- `TOOL_CALL_START`
- `TOOL_CALL_ARGS`
- `TOOL_CALL_END`
- `TOOL_CALL_RESULT`
- `TEXT_MESSAGE_START`
- `TEXT_MESSAGE_CONTENT`
- `TEXT_MESSAGE_END`
- `RUN_FINISHED`
- `RUN_ERROR`

每个 fixture 需要验证：

```text
[x] raw JSON 可解析
[x] 映射为 typed domain event
[x] 未知字段被保留或安全忽略
[x] 缺失字段有明确 fallback
[x] UI view model 输出稳定
[x] SSE adapter 输出和 WebSocket adapter 输出一致
[x] transport 断线后能产生统一错误/重连事件
```

当前 Web 基线已通过 `src/lib/agUiStreamFixtures.test.ts` 验证。Flutter 侧应先实现 transport adapter，再复用这些 fixtures 验证 SSE/WebSocket 输出等价。

### 4.2 BLE Protocol Fixtures

已创建以下 fixture 文件：

```text
test/fixtures/ble/
  README.md
  req_golden_packets.json
  parse_frames.json
  boundary_cases.json
  side_mapping.json
  cross_platform_parity.json
  f0_get_device_info.hex
  f2_set_rtc.hex
  b0_set_work_mode.hex
  b1_set_pump_params.hex
  b2_set_flexible_force_line.hex
  b3_set_lactation_curve.hex
  bf_end_run.hex
  e1_device_status_input.hex
  e1_device_status_expected.json
```

Fixtures 必须和当前协议行为对齐：

- `src/lib/bleProtocol.ts`
- `src/lib/ble.ts`
- `android/app/src/main/java/com/momcozymai/app/MmcBleProtocol.java`

必须覆盖：

```text
[x] encode 输出和旧实现一致
[x] decode 输出和旧实现一致
[x] invalid checksum fallback
[x] unknown opcode fallback
[x] left/right side mapping
[x] level/mode/rhythm boundary values
[x] 0xFF 或缺省字段处理
```

当前 Web 基线已通过 `src/lib/bleProtocol.fixtures.test.ts` 验证。Flutter/Dart 实现必须先复用这些 fixtures 建立 Dart golden tests，再接入真实 BLE transport。

### 4.3 API Fixtures

已为成功、业务错误、HTTP 错误、空数据、部分数据和 legacy aliases 创建 fixtures：

```text
test/fixtures/api/
  user_profile/
  agent_chat/
  pump/
  mom_baby/
  feeding/
  growth/
  plan/
  pregnancy_diary/
  notify/
  media/
```

每个接口至少准备：

```text
[x] success.json
[x] business_error.json
[x] http_error.json
[x] empty.json
[x] partial.json
[x] legacy_alias.json
```

当前 Web 基线已通过 `src/lib/apiContractFixtures.test.ts` 和 `src/lib/apiTransportFailureFixtures.test.ts` 验证。Flutter 侧应把普通 response fixtures 与 transport failure fixtures 分开接入 repository contract tests。

### 4.4 Storage Migration Fixtures

从以下 legacy 状态创建 fixtures：

- `localStorage`
- `sessionStorage`
- Capacitor Preferences
- Android native stores

每个 fixture 必须定义：

```text
[x] Legacy key
[x] Legacy value
[x] Expected Flutter storage key
[x] Expected parsed value
[x] Invalid value fallback
[x] Idempotency expectation
```

必须覆盖的状态类别：

- chat conversation/session key。
- calibration left/right result。
- device paired/native state。
- notification preferences。
- pump active session snapshot。
- pending navigation key。
- multi-user snapshot。
- sessionStorage pump state。

当前 Flutter dry-run 覆盖 `p0_valid_core_state`、`p0_invalid_values_fallback`、`p0_one_shot_route_intents`、`p0_pump_runtime_not_trusted_without_native_session` 和 `p1_preferences_ibclc_and_multi_user`，并报告 `unhandledLegacyKeys`。

---

## 5. UI 测试范围

### 5.1 Agent Hub

必测：

```text
[x] 首次进入状态
[ ] 历史会话恢复
[ ] 新会话
[x] 文本输入
[x] 图片输入 / AG-UI image payload
[x] 语音输入入口 / STT 回填输入框
[x] 发送 loading 状态
[x] 取消 / 停止生成
[x] AG-UI 文本渐进流式输出
[x] 工具进度 / 工作状态
[x] 工具失败状态
[x] 失败后重试
[x] Rich text block 渲染
[x] Card 渲染
[x] Button action 渲染和点击入口
[x] Doc link 渲染和打开
[ ] Citation/reference link 渲染
[x] Media link 打开
[ ] 自动语音播放
[ ] 通知语音播放
[x] 用户 barge-in / 手动打断 transport cancel contract
[ ] 长消息换行
[x] Empty Agent Hub
[x] 后端超时
[x] Agent stream 断线和重试 UX
[x] 离线发送失败
```

Golden 视觉状态：

```text
[ ] Empty Agent Hub
[ ] Streaming message
[ ] Tool in progress
[ ] Rich text artifact
[ ] Error/retry
[ ] Image attached before send
```

### 5.2 Device

必测：

```text
[ ] 无已配对设备
[ ] 已配对左设备
[ ] 已配对右设备
[ ] 左右设备均已配对
[ ] 设备已连接
[ ] 设备已断开
[ ] 电量展示
[ ] 如保留 RSSI，则信号/RSSI 展示
[ ] BLE permission 未请求
[ ] BLE permission 拒绝
[ ] BLE permission 永久拒绝
[ ] 从系统设置返回后重新授权
[ ] 扫描空结果
[ ] 扫描超时
[ ] 发现单个设备
[ ] 发现多个设备
[ ] 连接失败
[ ] 断线重连
[ ] 恢复 native 已连接设备
[ ] 用户切换时断开或隔离设备
[ ] debug drawer 仅 internal/dev 环境可见
```

### 5.3 Calibration

必测：

```text
[ ] 无设备进入
[ ] 仅左设备
[ ] 仅右设备
[ ] 双侧设备
[ ] 档位调整
[ ] 保存校准
[ ] 退出未保存
[ ] 中断恢复
[ ] legacy calibration 数据合法
[ ] legacy calibration 数据缺字段
[ ] legacy calibration 数据非法
[ ] legacy calibration 包含 0xFF
[ ] 校准后进入 Pump 参数正确
```

### 5.4 Pump Session

必测：

```text
[ ] 启动 session
[ ] 暂停
[ ] 恢复
[ ] 结束
[ ] 左侧独立模式/档位/奶量/进度
[ ] 右侧独立模式/档位/奶量/进度
[ ] 双侧同步运行
[ ] 前后台切换
[ ] 锁屏
[ ] 通知点击恢复
[ ] 悬浮窗显示
[ ] 悬浮窗关闭
[ ] 悬浮窗无权限
[ ] App killed 后重启
[ ] 系统回收后恢复或安全结束
[ ] Doze / battery optimization 场景
[ ] summary 只上传一次
[ ] milk record 只创建一次
[ ] Agent context 只上传一次
[ ] 网络失败后重试
[ ] 结束时并发点击幂等
[ ] 多用户切换保护
```

### 5.5 Records

必测：

```text
[ ] 列表加载
[ ] 空态
[ ] 加载失败
[ ] 图表展示
[ ] 手动补录
[ ] 编辑记录
[ ] 删除记录
[ ] mL/oz 单位切换
[ ] 跨天记录
[ ] 弱网重试
```

### 5.6 Schedule

必测：

```text
[ ] 日期切换
[ ] 今日任务加载
[ ] 添加任务
[ ] 删除任务
[ ] 完成任务
[ ] 提醒开关
[ ] 通知 badge
[ ] 通知点击进入对应任务
[ ] 跨天倒计时
[ ] 时区变化
[ ] 离线/弱网状态
```

### 5.7 Status

必测：

```text
[ ] 孕期/哺乳期切换
[ ] 妈妈 tab
[ ] 宝宝 tab
[ ] 成长记录
[ ] 孕期日记
[ ] 今日状态
[ ] 计划 todo
[ ] 长文本
[ ] 空数据
[ ] API 失败
[ ] demo/runtime user id 一致性
```

### 5.8 Media、IBCLC、Hospital Bag

Media 必测：

```text
[ ] PDF 打开
[ ] Image 打开
[ ] Video 打开
[ ] 加载失败
[ ] 返回上一页
[ ] 横竖屏或尺寸变化
[ ] 缓存清理
```

IBCLC 必测：

```text
[ ] 协议勾选
[ ] 未勾选时阻止继续
[ ] 跳转 vendor/H5/native flow
[ ] 返回后 viewport 和 route 状态正确
[ ] 网络失败
```

Hospital Bag 必测：

```text
[ ] card 列表加载
[ ] cart update
[ ] 删除 item
[ ] 恢复默认
[ ] API 失败
```

---

## 6. 交互与生命周期测试矩阵

| 场景 | 必测点 |
|---|---|
| 底部导航 | 状态保持、badge 转移、中心 Agent 动效、Pump/Calibration/Media 隐藏底栏。 |
| 通知跳转 | pump、daily summary、milk analysis、growth、health issue、schedule reminder。 |
| App 生命周期 | 冷启动、热启动、后台 5 分钟、锁屏、杀进程、系统回收。 |
| 权限流 | BLE、通知、麦克风、悬浮窗、精确闹钟、电池优化。 |
| 弱网/离线 | HTTP 失败、Agent stream 断线重连、上传重试、用户可见错误。 |
| 多用户 | 切换用户时断开 BLE、隔离 chat/calibration/device/storage。 |
| 时间相关 | 跨天、时区、计划倒计时、泵奶结束时间、通知定时。 |
| 并发交互 | 双击结束、重复点击发送、页面切换中 cancel、上传中退出。 |

---

## 7. API 合同测试范围

每个接口都需要覆盖：

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

### 7.1 HTTP、SSE 和 WebSocket 合同

至少覆盖：

- `/api/ag-ui`
- `/api/ag-ui-ws`
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

### 7.2 Agent 文本流 transport 合同

Agent 文本和工具事件流必须设计成 transport-agnostic。测试目标不是证明某个 WebSocket client 可用，而是证明 SSE 和 WebSocket adapter 都能输出同一组 domain events。

必须覆盖：

```text
[x] `AgentStreamClient` interface 不暴露 SSE/WebSocket 细节
[x] `SseAgentStreamClient` 能解析 event-stream payload
[x] `WebSocketAgentStreamClient` 能解析 JSON/JSONL payload
[x] 同一 AG-UI fixture 下两个 adapter 输出一致的 `AgentStreamEvent`
[x] `RUN_STARTED` / `TEXT_MESSAGE_*` / `TOOL_CALL_*` / `RUN_FINISHED` 顺序一致
[x] `RUN_ERROR` 映射为统一错误事件
[x] AG-UI 首帧 payload builder 对齐文本和图片 fixture
[x] SSE/WebSocket IO transport shell 复用同一 auth injection 和 redacted log context
[x] terminal event 后停止消费底层 stream，并关闭 WebSocket transport
[x] `/api/ag-ui-cancel` 2xx/404 ack、5xx/network non-blocking failure 已覆盖
[x] `/api/ag-ui-prewarm` hidden payload、envelope/root response、legacy aliases 和 failure contract 已覆盖
[x] `/api/ag-ui-timing-log` best-effort 上报、auth/header contract 和日志脱敏检查已覆盖
[x] `/api/client-event` IBCLC completion payload、auth/header contract 和 best-effort failure 已覆盖
[x] transport disconnect 映射为统一断线状态，并保留 partial content
[x] reconnect 不重复已完成 message chunk
[x] cancel ack 和本地 cancel 状态一致
[x] UI/view model 不依赖 transport 类型判断
[x] Agent Hub composer fixture send、streaming finished 和 local stop widget flow 已覆盖
[x] App root 默认 Agent Hub runner 注入已覆盖，composer 输入后可进入 send-ready 状态
[x] Agent Hub stop best-effort cancel body、endpoint 和本地停止态已覆盖
[x] Agent Hub disconnect 后 retry 复用上一轮 request 并进入完成态已覆盖
[x] Agent Hub tool progress、artifact created 和 confirmation required fixture UI 已覆盖，且不展示内部 tool name / raw JSON
[x] Agent Hub tool failure work step 已覆盖，同一 tool_call_id 失败事件覆盖进行中状态且不展示 raw error / tool name
[x] Agent Hub rich text artifact、card rows 和 button/doc/media action 已覆盖；doc/media action 经白名单 route handler 打开 `/media-viewer`
[x] Agent Hub timeout/offline send failure 已映射为用户可读 retry copy，原始异常、host 和 transport 细节不进入 UI
[x] Flutter 非 Agent route 页面骨架已覆盖全量 route map，并验证 Status、Schedule、Device、Pump、Calibration、Media 的关键区块和专注页底栏规则
[x] Flutter 非 Agent route 已增加紧凑手机视口渲染和滚动 smoke，防止小屏 overflow 与底栏遮挡回归
[x] Status/Schedule typed repository contract tests 已覆盖 success、legacy alias、empty、partial、business error 和 HTTP error fixtures
[x] Pump workstate typed repository contract tests 已覆盖 `/v1/pump/workstate` request body、reply aliases、empty/partial、business error 和 HTTP error fixtures
[x] Records feeding/growth typed repository contract tests 已覆盖 request query、legacy aliases、partial/empty、business error 和 HTTP error fixtures
[x] Records pump_milk typed repository contract tests 已覆盖 `/v1/pump-milk/query` request query、legacy aliases、partial/empty、business error 和 HTTP error fixtures
[x] Hospital Bag cart typed repository contract tests 已覆盖 `/api/hospital-bag/cart-update` body schema、success、business error 和 HTTP error
[x] Media upload typed repository contract tests 已覆盖 multipart metadata、legacy aliases、partial/empty、business error、HTTP error、cancel 和 timeout fixtures
[x] Flutter 通用 JSON HTTP transport tests 已覆盖 GET/POST、auth/header 注入、query merge、HTTP error 和 malformed body
[x] Flutter staging smoke CLI 已覆盖 env 解析、mutating/agent gating、失败脱敏和默认 skip；真实 staging 运行见 `doc/flutter-staging-smoke.md`
[x] Flutter 通用 multipart transport 已接入 runtime，Media 页面可复用 `/v1/files/upload` repository contract
[x] Flutter App API runtime tests 已覆盖 dart-define 默认配置、secure session bootstrap、注入 transport 的 repository factory 和 runtime scope
[x] Flutter App API runtime 已暴露 `/api/client-event` best-effort client，页面测试可注入 recording connector 验证事件写回
[x] Flutter App API runtime tests 已覆盖 lazy BLE platform 注入和 connected device fixture
[x] Flutter App API runtime tests 已覆盖 `PumpProtocolPlatform` 注入和 native coordinator 经 BLE fake 写出协议命令
[x] Flutter `/status` widget tests 已覆盖 runtime repository fixture、妈妈/宝宝切换和异步状态渲染
[x] Flutter `/schedule` widget tests 已覆盖 runtime repository fixture、day plan 渲染和本地 checkbox 草稿交互
[x] Flutter `/records` widget tests 已覆盖 runtime repository fixture、泵奶/喂养/成长筛选和动态汇总渲染
[x] Flutter `/pump` widget tests 已覆盖 session 控制触发 `/v1/pump/workstate` runtime repository 同步和后端回复展示
[x] Flutter `/device` widget tests 已覆盖 BLE runtime fake、已连接设备恢复和扫描状态切换
[x] Flutter `/device/manage` 与 `/device/user` widget tests 已覆盖 BLE runtime 已连接设备读取/解绑和 runtime user context 展示
[x] Flutter `/calibration` widget tests 已覆盖保存左右舒适档位时通过 `PumpProtocolPlatform` 下发命令并进入 Pump
[x] Flutter `/media-viewer` widget tests 已覆盖示例媒体上传的 multipart path、fields、file metadata 和成功状态渲染
[x] Flutter `/ibclc-chat.html` widget tests 已覆盖进入咨询时上报 `ibclc_consult_started` client event，并保持 best-effort UI
[x] Flutter `/hospital-bag-cart` widget tests 已覆盖清单勾选后通过 runtime repository 同步购物车状态
[x] Flutter `/community` 与 `/w1` widget tests 已覆盖内容打开事件写回和 W1 教程跳转
[x] Flutter Agent voice typed repository tests 已覆盖 STT multipart 分片、timeout fallback、barge-in cancel、realtime PCM stream、realtime voice session frames 和 WS disconnect
```

### 7.3 语音合同

语音相关接口不能作为可选边角功能处理。Agent Hub 当前已经包含语音输入、实时语音播放、通知语音、分片转写。

必须覆盖：

```text
[ ] 麦克风 permission 未请求
[ ] 麦克风 permission 拒绝
[ ] 开始录音
[ ] 停止录音
[x] 分片上传
[x] 分片转写成功
[x] 分片转写失败
[x] realtime voice session 创建
[x] realtime voice stream cancel / barge-in
[ ] TTS 播放
[ ] 通知语音打断当前播放
[x] 用户手动打断播放的 transport cancel 合同
[x] 语音状态和文本 stream 状态不互相污染
```

---

## 8. Native Bridge 合同测试

必须定义并测试 Flutter platform channel 契约：

| Bridge | 必须测试 |
|---|---|
| `MmcBle` | scan、connect、disconnect、write command、status event、permission state。 |
| `BackgroundNotify` | channel 创建、通知展示、点击 intent、权限拒绝 fallback。 |
| `DeviceReminderWebSocket` | start、stop、reconnect、auth expired、notification fallback。 |
| `PumpSessionForegroundService` | start、update、pause、resume、end、restore snapshot。 |
| `PumpSessionOverlay` | permission、show、update、hide、tap action、denied fallback。 |
| `PumpAgentUpload` | snapshot persist、upload、retry、dedupe、failure record。 |
| `NativeDeviceState` | paired state、connected state、left/right isolation、clear on user switch。 |

当前本地 P0 platform channel smoke 命令：

```bash
npm run flutter:p0:platform-smoke
```

该命令覆盖 fake interfaces、Android MethodChannel schema、BLE protocol、snapshot sync 与 native runtime coordinator。真机 BLE/通知/后台服务仍以 L4 device lab 为准。

每个 bridge 的合同必须写清楚：

```text
[ ] Method name
[ ] Request payload
[ ] Success response
[ ] Error response
[ ] Event stream payload
[ ] Threading expectation
[ ] Background availability
[ ] Idempotency expectation
```

---

## 9. 权限与 Android 版本矩阵

| 能力 | Android 11 及以下 | Android 12 | Android 13+ | Android 14+ |
|---|---|---|---|---|
| BLE scan/connect | 旧蓝牙/定位权限模型 | `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` | 同 Android 12 | 同 Android 12，注意后台限制 |
| Notifications | 默认较宽松 | 渠道和后台限制 | `POST_NOTIFICATIONS` | foreground service 类型更严格 |
| Microphone | runtime permission | runtime permission | runtime permission | runtime permission + 后台限制 |
| Overlay | `SYSTEM_ALERT_WINDOW` | 同左 | 同左 | 同左，后台启动更敏感 |
| Exact alarm | 较宽松 | 需要关注精确闹钟限制 | 需要设置页 fallback | 更严格 |
| Battery optimization | 厂商差异 | 厂商差异 | 厂商差异 | 厂商差异 + FGS 限制 |

每个权限流必须覆盖：

```text
[ ] 未请求
[ ] 首次允许
[ ] 首次拒绝
[ ] 永久拒绝
[ ] 打开系统设置
[ ] 从系统设置返回
[ ] 功能降级提示
[ ] 不可用状态下不崩溃
```

---

## 10. 安全与隐私测试门槛

妈妈、宝宝、泵奶、喂养、成长和健康数据都应按敏感数据处理。

必须覆盖：

```text
[x] Flutter 统一日志脱敏工具和测试已落地：`core/privacy/log_redactor.dart`
[x] 上传失败日志脱敏：`PumpAgentUploadPlatform` fake failure stream
[x] token / refresh token 已接入 `flutter_secure_storage` session store，并保留内存 store 供测试注入
[ ] HTTP/SSE 使用 HTTPS，WebSocket 使用 WSS，开发环境例外必须隔离
[ ] 日志不输出 token
[ ] 日志不输出完整健康数据 payload
[ ] crash report 不包含敏感字段
[ ] 多用户切换时清理 scoped cache
[x] 登出后清理 secure session 中的 token / refresh token 敏感状态
[ ] screenshot/golden fixtures 不包含真实用户数据
```

详细准入见 `doc/flutter-security-privacy-gates.md`。

---

## 11. Release 与 CI Gates

CI 最低要求：

```text
[x] `npm run flutter:release-gate` 已固定非真机 gate
[x] flutter analyze
[x] dart format check
[x] flutter test
[x] contract fixture tests
[ ] golden tests
[x] staging smoke harness 默认安全 skip，凭证齐全时可直连 staging
[x] storage migration dry-run
[x] Android debug build：local flavor
[x] Android release build：staging flavor
[x] signing check：CI 可用 `MOMCOZY_REQUIRE_RELEASE_SIGNING=1` 强制 release signing env
```

发布门槛最低要求：

```text
[ ] 冷启动指标达标
[ ] 首屏 Agent Hub 可交互时间达标
[ ] Pump session 页面无明显 jank
[ ] Agent stream reconnect 不造成 UI 卡死
[ ] 大图片上传不阻塞主线程
[ ] 前后台切换无 crash
[ ] 24h smoke 无后台服务异常
[ ] crash-free sessions 达到发布阈值
[ ] rollback package 可用
```

建议 device lab：

```text
[ ] Android 11 或以下真机
[ ] Android 12 真机
[ ] Android 13+ 真机
[ ] 至少一台低端设备
[ ] 至少一台厂商深度定制系统设备
[ ] 真泵左设备
[ ] 真泵右设备
[ ] 真泵双侧设备
```

---

## 12. 迁移准入 Checklist

正式进入核心 Flutter 迁移前必须满足：

```text
[x] 当前 `npm test` 绿色，或失败项已登记为 baseline defect
[x] 当前 `npm run build` 通过
[x] 当前 `npm run lint` 无 error / warning，或已显式登记接受原因
[x] feature parity matrix 完成
[x] API contract inventory 完成
[x] API contract fixtures 完成
[x] storage key inventory 完成
[x] route/notification intent matrix 完成
[x] permission/lifecycle matrix 完成
[x] BLE protocol fixtures 完成
[x] AG-UI stream fixtures 完成，并覆盖 SSE/WebSocket adapter
[x] Native bridge contracts 完成
[x] Security/privacy gates 已定义，P0 redaction tests 已落地
[x] P0 真机 smoke checklist 可执行
[x] 真泵验证计划确认
[x] Flutter Agent Hub run-state UI shell 已覆盖 idle、streaming、finished 和 disconnected 状态
[x] Flutter 主要页面 skeleton 已替换通用 route 占位页，真机和后端数据联调后置
```

---

## 13. P0 真机 Smoke Checklist

真机 smoke 至少覆盖：

```text
[ ] 安装 release/debug build
[ ] 冷启动
[ ] 登录或 demo user 初始化
[ ] Agent Hub 打开
[ ] Agent Hub 发送文本
[ ] AG-UI stream 展示
[ ] 图片上传
[ ] 语音输入
[ ] BLE permission flow
[ ] 扫描设备
[ ] 连接左设备
[ ] 连接右设备
[ ] 启动 Pump session
[ ] 暂停 Pump session
[ ] 恢复 Pump session
[ ] 结束 Pump session
[ ] 前后台切换
[ ] 锁屏恢复
[ ] 通知点击恢复
[ ] App killed 后恢复
[ ] summary/milk record/Agent context 只上传一次
[ ] Schedule reminder notification
[ ] Records 查询
[ ] Status 查询
[ ] 登出或切换用户后状态隔离
```

---

## 14. 需要创建的跟踪产物

Phase 0 至少补齐这些文件或等价追踪系统：

```text
doc/flutter-feature-baseline.csv
doc/flutter-api-contracts.md
doc/flutter-storage-migration.md
doc/flutter-route-intents.md
doc/flutter-permission-lifecycle-matrix.md
doc/flutter-native-bridge-contracts.md
doc/flutter-baseline-defects.md
doc/flutter-architecture-decision.md
doc/flutter-p0-smoke-checklist.md
```

建议每个追踪产物都有：

```text
[ ] 负责人
[ ] Last reviewed date
[ ] Source files
[ ] Open decisions
[ ] Test coverage
[ ] Exit criteria
```
