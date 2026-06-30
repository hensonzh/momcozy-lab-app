# Flutter API 合同清单

> 状态：Phase 0 P0/P1 schema + fixtures 版  
> 范围：当前 Web/Capacitor App 使用或文档声明的 HTTP、SSE/WebSocket、上传、语音和后台服务接口。  
> 下一步：把 API fixtures 移植到 Flutter repository contract tests，并接入 mock server。

---

## 1. 通用规则

- Flutter 网络层统一封装 auth、timeout、cancel、retry、日志脱敏和环境 base URL。
- 普通业务请求走 HTTP。
- Agent 文本/工具事件流走 `AgentStreamClient`，由 SSE/WebSocket adapter 实现。
- 实时语音流不要复用 Agent 文本流抽象，单独定义 voice transport。
- Pump session、milk record、Agent context 上传必须具备 dedupe key。
- 所有妈妈、宝宝、泵奶、喂养、成长和健康数据日志必须脱敏。

### 1.1 通用 HTTP 信封

当前 Web 侧 `apiRequest` 约定：

```ts
type ApiEnvelope<T> = {
  status: number;
  message: string;
  data: T;
};
```

- `status === 200`：返回 `data`。
- `status !== 200`：抛业务错误，Flutter 应映射为 `ApiBusinessException(status, message, raw)`.
- HTTP 非 2xx：抛网络/HTTP 错误，保留 status、response body、request id。
- `AbortController` abort：映射为 `RequestCancelled`，不要展示通用失败 toast。
- 默认带 `Authorization: Bearer <token>`；`skipAuth` 只允许在明确登记的接口使用。

例外接口：

| Interface | 当前行为 | Flutter 要求 |
|---|---|---|
| `/api/ag-ui-cancel` | 原生 `fetch`，HTTP 2xx 或 404 视为成功。 | 不解析业务信封；幂等取消。 |
| `/api/ag-ui-prewarm` | `apiRequestRaw`。 | 直接解析根对象。 |
| `/api/ag-ui-timing-log` | `fetch` + `keepalive`，失败只打 warn。 | best effort，不影响主流程。 |
| `/api/client-event` | `apiRequestRaw`。 | best effort，可失败降级。 |
| `/api/hospital-bag/cart-update` | `apiRequestRaw`。 | 直接解析根对象。 |
| `/v1/analysis/create` | `apiRequestRaw`，兼容信封和非信封响应。 | Flutter repository 需要兼容两种响应。 |

### 1.2 默认超时、取消、重试

| 类型 | Timeout | Cancel | Retry |
|---|---:|---|---|
| 普通 HTTP | 10-15s | 用户离页/重复提交时取消 | 默认不自动重试；只对幂等 GET 可重试一次。 |
| multipart upload | 30-60s | 用户取消上传或离页时取消 | 不自动重试，避免重复资源。 |
| Agent text stream | 首帧 15s，idle 由 UI runtime 控制 | 用户打断必须调用 transport cancel + `/api/ag-ui-cancel` | 断流不自动续写同一 run。 |
| Pump summary WS | 当前 12s | 会话结束流程不可静默丢弃 | 可用 `event_id` 做幂等重试。 |
| Device reminder WS | 长连接 | app teardown / logout 停止 | 1s、3s、5s、10s、15s 递增重连。 |

---

## 2. Agent / AG-UI

| Contract | Transport | Method | Current source | Flutter owner | Phase 0 状态 |
|---|---|---|---|---|---|
| `/api/ag-ui` | SSE | POST/stream | `doc/web-api.md`; MomCozyAgent SSE upstream | `features/agent_hub/data` | 需要定义为首选或候选 transport。 |
| `/api/ag-ui-ws` | WebSocket | WS first-frame payload | `src/lib/agentApi.ts`; `doc/web-api.md` | `features/agent_hub/data` | 当前兼容 transport。 |
| `/api/ag-ui-cancel` | HTTP | POST | `src/lib/agentApi.ts` | `features/agent_hub/data` | 需要 cancel ack fixture。 |
| `/api/ag-ui-prewarm` | HTTP | POST | `src/lib/agentApi.ts` | `features/agent_hub/data` | 需要确认 Flutter 是否保留。 |
| `/api/ag-ui-timing-log` | HTTP | POST | `src/lib/agentApi.ts` | `features/agent_hub/data` | 需要决定是否仍采集。 |
| `/api/client-event` | HTTP | POST | `src/lib/analysisContextEvents.ts`; `src/lib/deviceReminderActions.ts`; `src/lib/ibclcConsult.ts` | `core/events` | 需要事件类型矩阵。 |
| `/api/hospital-bag/cart-update` | HTTP | POST | `src/pages/AgentHub.tsx` | `features/hospital_bag/data` | 待产品决策。 |

Agent stream 必须输出统一 domain event：

```text
RUN_STARTED
TEXT_MESSAGE_START
TEXT_MESSAGE_CONTENT
TEXT_MESSAGE_END
TOOL_CALL_START
TOOL_CALL_ARGS
TOOL_CALL_END
TOOL_CALL_RESULT
ACTIVITY_SNAPSHOT
CUSTOM
RUN_FINISHED
RUN_ERROR
```

### 2.1 Agent Stream Schema

#### 2.1.1 `/api/ag-ui` and `/api/ag-ui-ws`

Flutter 侧统一抽象：

```ts
type AgentRunPayload = {
  threadId: string;
  runId: string;
  state: { locale: string } & Record<string, unknown>;
  messages: Array<{
    id: string;
    role: "user";
    content:
      | string
      | Array<
          | { type: "text"; text: string }
          | {
              type: "image";
              image_url: string; // data URL in current Web client
              mime_type: string;
              name: string;
              size: number;
              detail: "auto" | "low" | "high";
            }
        >;
  }>;
  tools: unknown[];
  context: unknown[];
  forwardedProps: Record<string, unknown>;
};
```

WebSocket 当前发送第一帧 JSON payload；服务端回帧可能是纯 JSON，也可能是 SSE 风格 `data: {...}\n\n`。SSE adapter 应复用同一 domain event parser。

必须解析的事件：

```ts
type AgentStreamEvent =
  | { type: "RUN_STARTED"; threadId?: string; runId?: string }
  | { type: "TEXT_MESSAGE_START"; messageId?: string; role?: string }
  | { type: "TEXT_MESSAGE_CONTENT"; delta?: string; text?: string }
  | { type: "TEXT_MESSAGE_END"; messageId?: string }
  | { type: "TOOL_CALL_START" | "TOOL_CALL_ARGS" | "TOOL_CALL_END" | "TOOL_CALL_RESULT"; [key: string]: unknown }
  | { type: "ACTIVITY_SNAPSHOT"; [key: string]: unknown }
  | { type: "CUSTOM"; name?: string; value?: unknown }
  | { type: "RUN_FINISHED"; [key: string]: unknown }
  | { type: "RUN_ERROR" | "RUN_FAILED" | "ERROR"; message?: string; [key: string]: unknown };
```

错误和取消：

- `RUN_ERROR` / `RUN_FAILED` / `ERROR`：结束当前 run，保留已收到的 partial content。
- transport close without `RUN_FINISHED`：显示可重试错误，不自动拼接到下一轮。
- 用户打断：关闭 stream；如已知 `threadId` / `runId`，调用 `/api/ag-ui-cancel`。

#### 2.1.2 `/api/ag-ui-cancel`

```ts
type AgUiCancelRequest = {
  threadId: string;
  runId?: string;
  user_id?: string;
};
```

成功：

- HTTP 2xx：取消成功。
- HTTP 404：视为已取消或 run 已结束。

失败：

- HTTP 5xx / network error：记录但不阻塞本地 UI 停止态。

#### 2.1.3 `/api/ag-ui-prewarm`

Request 与 `AgentRunPayload` 相同，但：

```ts
forwardedProps.prewarm = true;
messages[0].content = "这是一次隐藏的新会话预热。请只回复“我在。”，不要调用工具，不要生成建议、表单、卡片或面向用户的内容。下一条用户消息才是真实对话。";
```

Response：

```ts
type AgUiPrewarmResponse = {
  status: "warmed" | "already_warm" | "stale" | "no_response_id" | "disabled" | string;
  conversation_id?: string;
  thread_id?: string;
  run_id?: string;
  response_id?: string | null;
  session_state?: unknown;
};
```

#### 2.1.4 `/api/ag-ui-timing-log`

```ts
type AgUiTimingLogEntry = {
  source?: string;
  stage: string;
  run_id?: string;
  runId?: string;
  thread_id?: string;
  threadId?: string;
  client_timing_id?: string;
  clientTimingId?: string;
  user_id?: string;
  userId?: string;
  elapsed_ms?: number;
  elapsedMs?: number;
  client_ts_ms?: number;
  clientTsMs?: number;
  metadata?: Record<string, unknown>;
};
```

该接口只用于性能观测。Flutter 需要把真实 token、user id、thread id 在日志中脱敏；上报失败不得影响 Agent stream。

#### 2.1.5 `/api/client-event`

```ts
type ClientEventRequest = {
  thread_id: string;
  user_id: string;
  event_type: string;
  label?: string;
  occurred_at: string; // ISO
  locale?: string;
  timezone?: string;
  metadata?: Record<string, unknown>;
};
```

当前已知 `event_type`：

- `milk_analysis_generated`
- device reminder action 类事件，详见 `src/lib/deviceReminderActions.ts`
- IBCLC consult 类事件，详见 `src/lib/ibclcConsult.ts`

该接口为 best effort，失败不能阻断通知、AgentHub 或 IBCLC 主流程。

#### 2.1.6 `/api/hospital-bag/cart-update`

```ts
type HospitalBagCartUpdateRequest = {
  user_message: string;
  locale: string;
  hospital_bag_cart: { groups: unknown[] };
  args?: {
    action?: "replace_pump_model" | string;
    product_sku_id?: string;
    [key: string]: unknown;
  };
};

type HospitalBagCartUpdateResponse = {
  status?: string;
  summary?: string;
  cart_update?: {
    groups?: unknown[];
    message?: string;
  };
  error?: { message?: string };
};
```

该接口随 Hospital Bag 产品决策保留或下线；若保留，Flutter 必须把 `groups` 作为结构化 DTO，而不是 `unknown[]`。

---

## 3. 文件、语音、聊天历史

| Contract | Transport | Method | Current source | Flutter owner | Notes |
|---|---|---|---|---|---|
| `/v1/files/upload` | HTTP multipart | POST | `src/lib/agentApi.ts`; `src/lib/http.ts` | `core/upload` | 图片上传、media upload。 |
| `/v1/speech/transcribe-chunk` | HTTP multipart | POST | `src/lib/agentApi.ts`; `src/lib/chunkedStt/*` | `features/agent_hub/data` | 需要麦克风权限和失败 fallback。 |
| `/v1/realtime-voice-stream` | streaming HTTP/WS candidate | TBD | `src/lib/agentApi.ts`; `src/lib/focusVoiceTtsPlayback.ts` | `features/agent_hub/data` | 不归入 Agent 文本流抽象。 |
| `/v1/realtime-voice-session` | WebSocket URL | WS | `src/lib/agentApi.ts`; `src/lib/focusVoiceTtsPlayback.ts` | `features/agent_hub/data` | 需要断线、打断、TTS 状态测试。 |
| `/v1/chat-message/history` | HTTP | GET | `src/lib/agentApi.ts` | `features/agent_hub/data` | 需要和本地 chat cache 策略对齐。 |
| `/v1/workflows/tasks/{conversation_id}/stop` | HTTP | POST | `src/lib/agentApi.ts` | `features/agent_hub/data` | V1.2 对话打断路径。 |

### 3.1 文件、语音、聊天历史 Schema

#### 3.1.1 `/v1/files/upload`

Request：`multipart/form-data`

```ts
type FileUploadRequest = {
  user_id: string;
  file: BinaryFile; // field name defaults to "file"
};

type FileUploadData = {
  id: string;
  name: string;
  size: number;
  extension: string;
  mime_type: string;
};
```

当前 Web 上传默认解析标准 `ApiEnvelope<FileUploadData>`。Flutter 原生侧需要支持 Android multipart boundary 和大文件取消。

#### 3.1.2 `/v1/speech/transcribe-chunk`

Request：`multipart/form-data`

```ts
type SpeechChunkRequest = {
  user_id: string;
  file: BinaryFile; // webm/wav/pcm-wav
  language?: string;
};

type SpeechChunkData = {
  text?: string;
  transcript?: string;
} & Record<string, unknown>;
```

单个 chunk 失败时，当前 Web 逻辑返回 `null` 并继续后续分片；abort 例外，需要向上抛出。

#### 3.1.3 `/v1/realtime-voice-stream`

Request：GET query

```ts
type RealtimeVoiceStreamQuery = {
  user_id: string;
  text: string;
};
```

Response：`audio/pcm` binary stream。Flutter 不应复用 Agent text stream parser，应进入独立 voice playback pipeline。

#### 3.1.4 `/v1/realtime-voice-session`

WebSocket URL query：

```ts
type RealtimeVoiceSessionQuery = {
  token?: string;
  user_id?: string;
};
```

当前帧结构由 `focusVoiceTtsPlayback.ts` 解析，Flutter 迁移前需补 voice session fixture：open、audio chunk、done、error、barge-in cancel。

#### 3.1.5 `/v1/chat-message/history`

GET query：

```ts
type ChatHistoryQuery = {
  user_id: string;
  conversation_id: string;
  count: number;
};
```

Response 当前源码暂用 `Record<string, unknown>`；Flutter 前必须由后端确认消息列表 schema。未确认前不得把它作为本地 cache 唯一来源。

#### 3.1.6 `/v1/workflows/tasks/{conversation_id}/stop`

```ts
type WorkflowStopRequest = {
  user_id: string;
};

type WorkflowStopData = {
  error: 0 | -1;
};
```

路径参数 `conversation_id` 不能为空；空值应在客户端直接拒绝请求。

---

## 4. Pump / Device

| Contract | Transport | Method | Current source | Flutter owner | Notes |
|---|---|---|---|---|---|
| `/v1/pump/threshold/upload` | HTTP | POST | `src/lib/agentApi.ts` | `features/calibration/data` | 上传校准阈值。 |
| `/v1/pump/threshold/get` | HTTP | GET | `src/lib/agentApi.ts` | `features/calibration/data` | Hub/Pump 入口可能兜底读取。 |
| `/v1/pump/workstate` | HTTP | POST | `src/lib/agentApi.ts`; Android `PumpAgentUploadPlugin` | `features/pump_session/data` | 后台上传也会调用。 |
| `/v1/pump/process` | HTTP | POST | `src/lib/agentApi.ts`; Android `PumpAgentUploadPlugin` | `features/pump_session/data` | 需要 dedupe 和重试。 |
| `/v1/pump/process/data` | HTTP | POST | `src/lib/agentApi.ts`; Android `PumpAgentUploadPlugin` | `features/pump_session/data` | 查询/回填 pump process。 |
| `/v1/pump/session-summary` | WebSocket | WS | `src/lib/agentApi.ts`; `doc/websocket接口说明文档.md` | `features/pump_session/data` | 需确认 Flutter 是否继续 WS 或改 HTTP。 |
| `/v1/pump/info/get` | HTTP | GET | `src/lib/momPumpTwinAgentApi.ts` | `features/status/data` | Status breast/pump summary。 |
| `/v1/device/info` | HTTP | POST | `src/lib/agentApi.ts`; `src/lib/deviceInfoReport.ts` | `features/device/data` | 左右设备状态上报。 |

### 4.1 Pump / Device Schema

#### 4.1.1 Calibration threshold

```ts
type PumpThresholdUploadRequest = {
  user_id: string;
  stimulate_level_l: number;
  deep_level_l: number;
  stimulate_level_r: number;
  deep_level_r: number;
};

type PumpThresholdData = {
  error: 0 | -1;
  stimulate_level_l?: number;
  deep_level_l?: number;
  stimulate_level_r?: number;
  deep_level_r?: number;
};
```

- Upload：`POST /v1/pump/threshold/upload`
- Get：`GET /v1/pump/threshold/get?user_id=...`
- Flutter storage migration 必须兼容本地 `calibration` key 和远端阈值兜底。

#### 4.1.2 `/v1/pump/workstate`

```ts
type PumpDeviceState = {
  state: number; // 0 paused, 1 running, 2 powered off, 3 offline, 4 unpaired
  scene?: "auto" | "manual" | string;
  mode?: "stimulate" | "deep" | "mix" | string;
  level?: number;
  process?: number;
  timestamp?: string;
  change_type?: "app" | "agent" | "device" | string;
};

type PumpWorkstateRequest = {
  user_id: string;
  device_left: PumpDeviceState;
  device_right: PumpDeviceState;
};

type PumpAgentUploadResponse = {
  error: number;
  need_reply: boolean;
  output: string;
  reply_code?: string;
  reply_side?: string;
  direct_rich_text?: Record<string, unknown>;
};
```

该接口可由 Flutter 前台和 Android 后台服务调用；必须有 session/run 级 dedupe 保护，避免后台恢复时重复触发 Agent 回复。

#### 4.1.3 `/v1/pump/process`

```ts
type PumpProcessSide = {
  time: string;
  process: number;
  cap_data: number;
  milk_reel: number;
  bandpower: number;
  milk: number;
};

type PumpProcessRequest = {
  user_id: string;
  process_left: PumpProcessSide;
  process_right: PumpProcessSide;
};
```

Response 同 `PumpAgentUploadResponse`。Flutter 侧采样、节流和后台 flush 必须归入 pump session state machine。

#### 4.1.4 `/v1/pump/process/data`

```ts
type PumpProcessDataSide = {
  step: "start" | "running" | "pause" | "stop" | string;
  cap_data: number[];
  time: string;
  milk_reel: number;
  bandpower: number;
  milk: number;
};

type PumpProcessDataRequest = {
  user_id: string;
  device_left: PumpProcessDataSide;
  device_right: PumpProcessDataSide;
};

type PumpProcessDataResponse = {
  error: 0 | -1;
  text: string;
  process_l: number;
  process_r: number;
  process_all: number;
};
```

#### 4.1.5 `/v1/pump/session-summary`

WebSocket first frame：

```ts
type PumpSessionSummaryRequest = {
  user_id: string;
  conversation_id: string;
  ended_at?: string;
  started_at?: string;
  end_reason?: string;
  process_all?: number;
  total_milk_ml?: number;
  duration_seconds?: number;
  event_id?: string; // dedupe key
  left?: PumpSessionSummarySide;
  right?: PumpSessionSummarySide;
};

type PumpSessionSummarySide = {
  connected?: boolean;
  milk_ml?: number;
  process?: number;
  mode?: string;
  level?: number;
  duration_seconds?: number;
  has_milk?: boolean;
  has_letdown?: boolean;
  letdown_count?: number;
};
```

Response：

```ts
type PumpSessionSummaryResponse = {
  status?: number;
  message?: string;
  data?: {
    error?: number;
    message?: string;
    session?: Record<string, unknown>;
    chat_message?: {
      id?: string;
      role?: string;
      content?: string;
      timestamp?: string;
      cardType?: string;
      cardData?: Record<string, unknown>;
    };
    context?: Record<string, unknown>;
  };
};
```

当前 timeout 12s。Flutter 必须保证 `event_id` 单次会话只上传一次，后台服务和前台 UI 不能并发提交。

#### 4.1.6 `/v1/device/info`

```ts
type DeviceConnectionSide = {
  model: string;
  state: "online" | "offline" | string;
  battery: number;
  sn: string;
  rssi: number;
  version: string;
};

type DeviceInfoRequest = {
  user_id: string;
  device_left: DeviceConnectionSide;
  device_right: DeviceConnectionSide;
};

type DeviceInfoData = {
  error: 0 | -1;
};
```

上报时机：BLE connected、F0/E1/notify 后、D6 电量刷新后、物理断连后。日志需脱敏 SN 或只保留后 4 位。

#### 4.1.7 `/v1/pump/info/get`

GET query：

```ts
type PumpInfoQuery = { user_id: string };

type PumpInfoData = {
  error: 0 | -1;
  delivery_week?: number;
  delivery_tage?: string;
  lactation_advice?: string;
  target_progress?: number;
  lactation_info_list?: Array<{
    total_milk: number;
    total_milk_estimate: number;
    totol_milk_estimate?: number;
    reference_upper: number;
    reference_lower: number;
    delivery_date: string;
  }>;
};
```

`totol_milk_estimate` 是历史拼写兼容字段，Flutter DTO 必须保留 alias。

---

## 5. Records / Feeding / Growth

| Contract | Transport | Method | Current source | Flutter owner | Notes |
|---|---|---|---|---|---|
| `/v1/pump-milk/upload` | HTTP | POST | `src/lib/momPumpTwinAgentApi.ts`; Android `PumpAgentUploadPlugin` | `features/records/data` | 手动和自动记录都可能写入。 |
| `/v1/pump-milk/delete` | HTTP | POST | `src/lib/momPumpTwinAgentApi.ts` | `features/records/data` | 删除后需要刷新 Records/Status。 |
| `/v1/pump-milk/query` | HTTP | GET | `src/lib/momPumpTwinAgentApi.ts` | `features/records/data` | 列表和图表。 |
| `/v1/feeding/add` | HTTP | POST | `src/lib/babyTwinAgentApi.ts` | `features/status/data` | 喂养记录。 |
| `/v1/feeding/delete` | HTTP | POST | `src/lib/babyTwinAgentApi.ts` | `features/status/data` | 喂养记录删除。 |
| `/v1/feeding/query` | HTTP | GET | `src/lib/babyTwinAgentApi.ts` | `features/status/data` | 喂养列表。 |
| `/v1/growth/add` | HTTP | POST | `src/lib/babyTwinAgentApi.ts` | `features/status/data` | 成长记录新增。 |
| `/v1/growth/query` | HTTP | GET | `src/lib/babyTwinAgentApi.ts` | `features/status/data` | 最新成长数据。 |
| `/v1/growth/revise` | HTTP | POST | `src/lib/babyTwinAgentApi.ts` | `features/status/data` | 成长记录编辑。 |
| `/v1/growth/history` | HTTP | GET | `src/lib/babyTwinAgentApi.ts`; `src/pages/status/StatusOverviewBody.tsx` | `features/status/data` | 成长曲线。 |

### 5.1 Records / Feeding / Growth Schema

#### 5.1.1 Pump milk records

```ts
type PumpMilkUploadRequest = {
  user_id: string;
  pump_type: number;   // V1.2: 0 device, 1 manual, 2 breastfeed
  pump_source: number; // V1.3: 0 device, 1 manual, 2 plan
  pump_time: string;
  pump_title?: string;
  pump_milk_volum?: number;
};

type PumpMilkUploadData = {
  error: 0 | -1;
  pump_id?: number;
};

type PumpMilkDeleteRequest = {
  user_id: string;
  pump_id: number;
};

type PumpMilkQuery = {
  user_id: string;
  timestamp?: string;
};

type PumpMilkQueryData = {
  error: 0 | -1;
  pump_milk_list: Array<{
    pump_id: number;
    pump_type: number;
    pump_source: number;
    pump_time: string;
    pump_title?: string;
    title?: string;
    pump_milk_volum: number;
  }>;
};
```

删除或新增成功后，需要通知 Records / Schedule / Status 刷新。Flutter 可用 repository event bus 或 cache invalidation。

#### 5.1.2 Feeding records

```ts
type FeedingAddRequest = {
  user_id: string;
  feed_type: number;
  feed_action: number;
  feed_time: string;
  feeding_title?: string;
  feed_milk_volum: number;
};

type FeedingDeleteRequest = {
  user_id: string;
  feeding_id: number;
};

type FeedingQuery = {
  user_id: string;
  timestamp?: string;
};

type FeedingQueryData = {
  error: 0 | -1;
  total_feed: number;
  feed_list: Array<{
    feeding_id: number;
    infant_id: number;
    feed_type: number;
    feed_action: number;
    feed_time: string;
    feeding_title?: string;
    title?: string;
    feed_milk_volum?: number;
    feed_duration?: number;
  }>;
};
```

#### 5.1.3 Growth records

```ts
type GrowthAddRequest = {
  user_id: string;
  height_cm: number;
  weight_kg: number;
  head_cm: number;
};

type GrowthReviseRequest = {
  user_id: string;
  growth_id: number;
  height_cm?: number;
  weight_kg?: number;
  head_cm?: number;
};

type GrowthQuery = { user_id: string };

type GrowthRecord = {
  growth_id: number;
  date: string;
  height_cm: number;
  weight_kg: number;
  head_cm: number;
  height_mes_time?: string;
  weight_mes_time?: string;
  head_mes_time?: string;
};

type GrowthQueryData = GrowthRecord & { error: 0 | -1 };
type GrowthHistoryData = { error: 0 | -1; growth_data: GrowthRecord[] };
```

Growth chart 必须测试空数组、缺测量时间、单点、多点和单位/小数格式。

---

## 6. Mom/Baby/Profile/Status

| Contract | Transport | Method | Current source | Flutter owner | Notes |
|---|---|---|---|---|---|
| `/v1/mom-baby/info/query` | HTTP | GET | `src/lib/momPumpTwinAgentApi.ts` | `features/status/data` | profile/status 基础信息。 |
| `/v1/mom-baby/today/query` | HTTP | GET | `src/lib/momPumpTwinAgentApi.ts` | `features/status/data` | 今日汇总。 |
| `/v1/user/profile/query` | HTTP | GET | `src/lib/agentApi.ts` | `features/status/data` | 需要确认与 mom-baby info 的边界。 |
| `/v1/status/create` | HTTP | POST | `src/lib/agentApi.ts` | `features/status/data` | 触发状态分析。 |
| `/v1/analysis/create` | HTTP | POST | `src/lib/agentApi.ts`; Android `DeviceReminderWebSocketService` | `features/status/data` | daily summary / mom_baby / milk_analysis / health_issue。 |

### 6.1 Mom / Baby / Profile / Status Schema

#### 6.1.1 `/v1/mom-baby/info/query`

```ts
type MomBabyInfoQuery = { user_id: string };

type MomBabyInfoData = {
  error: 0 | -1;
  delivery_date: string;
  deliveryDate?: string;
  deliverydate?: string;
  lactation_advice: string;
  feeding_advice: string;
};
```

Flutter DTO 必须兼容 `delivery_date`、`deliveryDate`、`deliverydate` 三种字段。

#### 6.1.2 `/v1/mom-baby/today/query`

```ts
type MomBabyTodayQuery = {
  user_id: string;
  timestamp?: string;
};

type MomBabyTodayData = {
  error: 0 | -1;
  pump_milk_volum: number;
  feeding_volum: number;
  feeding_forecast_volum: number;
  pumping_count?: number;
  device_pumping_count?: number;
  manual_pumping_count?: number;
  plan_pumping_count?: number;
};
```

#### 6.1.3 `/v1/user/profile/query`

```ts
type UserProfileQuery = { user_id: string };

type UserProfileData = {
  error: 0 | -1;
  user_id: string;
  display_name?: string;
  age?: number | null;
  profile_onboarding_complete?: boolean;
  profile_onboarding_skipped?: boolean;
  current_care_stage?: "pregnancy" | "postpartum" | "";
  current_care_stage_source?: string;
  [birthPrepField: string]: unknown;
};
```

当前 Agent greeting 和 Status care-stage 都依赖该接口。Flutter 切用户时必须清理旧 profile cache。

#### 6.1.4 `/v1/status/create`

```ts
type StatusCreateRequest = { user_id: string };
type StatusCreateData = { error: 0 | -1 };
```

#### 6.1.5 `/v1/analysis/create`

```ts
type AnalysisCreateRequest = {
  user_id: string;
  type: "mom_baby" | "daily_summary" | "milk_analysis" | "health_issue" | string;
};

type AnalysisCreateData = {
  error: 0 | -1;
  result?: boolean;
  message: string;
  analysis_card?: AgentAnalysisCard;
  analysis_context?: AgentAnalysisCard;
};
```

当前 Web 兼容两种响应：

```ts
type AnalysisRawResponse =
  | { status?: number; message?: string; data?: Partial<AnalysisCreateData> }
  | Partial<AnalysisCreateData>;
```

`milk_analysis` 通知链会把 `analysis_context` 写入 Agent context event，Flutter 需要保留该链路。

---

## 7. Plan / Schedule / Pregnancy Diary

| Contract | Transport | Method | Current source | Flutter owner | Notes |
|---|---|---|---|---|---|
| `/v1/plan/query-task` | HTTP | GET | `src/lib/agentApi.ts`; `src/pages/Schedule.tsx` | `features/schedule/data` | 今日任务和日期切换。 |
| `/v1/plan/list` | HTTP | GET | `src/lib/agentApi.ts` | `features/schedule/data` | 当前源码有封装，API 文档需复核。 |
| `/v1/plan/detail` | HTTP | GET | `src/lib/agentApi.ts` | `features/schedule/data` | 当前源码有封装，API 文档需复核。 |
| `/v1/plan/delete-artifact` | HTTP | POST | `src/lib/agentApi.ts` | `features/schedule/data` | Agent artifact 删除。 |
| `/v1/plan/birth-journey/todo-completion` | HTTP | POST | `src/lib/agentApi.ts`; failing test references it | `features/status/data` | 需要 user_id 基线修复或登记。 |
| `/v1/plan/add-task` | HTTP | POST | `src/lib/agentApi.ts` | `features/schedule/data` | 手动新增任务。 |
| `/v1/plan/delete-task` | HTTP | POST | `src/lib/agentApi.ts` | `features/schedule/data` | 删除任务。 |
| `/v1/plan/revise-task` | HTTP | POST | `src/lib/agentApi.ts` | `features/schedule/data` | 修改任务。 |
| `/v1/pregnancy-diary/list` | HTTP | GET | `src/lib/agentApi.ts` | `features/status/data` | 孕期日记列表。 |
| `/v1/pregnancy-diary/today` | HTTP | GET | `src/lib/agentApi.ts` | `features/status/data` | 今日孕期日记。 |
| `/v1/pregnancy-diary/create` | HTTP | POST | `src/lib/agentApi.ts` | `features/status/data` | 创建日记。 |
| `/v1/pregnancy-diary/update` | HTTP | POST | `src/lib/agentApi.ts` | `features/status/data` | 更新日记。 |
| `/v1/pregnancy-diary/delete` | HTTP | POST | `src/lib/agentApi.ts` | `features/status/data` | 删除日记。 |

### 7.1 Plan / Schedule / Pregnancy Diary Schema

#### 7.1.1 Plan task query and mutations

```ts
type PlanQuery = {
  user_id: string;
  timestamp: string;
};

type PlanTaskItem = {
  task_id: number;
  task_time: string;
  task_content: string;
  task_type: number;
  task_source: string;
  task_done: string;
};

type PlanQueryData = {
  error: 0 | -1;
  plan_type: string;
  task_list: PlanTaskItem[];
};

type PlanTaskInputItem = {
  task_time: string;
  task_content: string;
  task_type: number;
  task_source: string;
};

type AddPlanTaskRequest = {
  user_id: string;
  timestamp: string;
  task_list: PlanTaskInputItem[];
};

type DeletePlanTaskRequest = {
  user_id: string;
  timestamp: string;
  task_id: number;
};

type RevisePlanTaskRequest = {
  user_id: string;
  task_id: number;
  timestamp: string;
  task_time: string;
  task_content: string;
  task_done: string;
};

type PlanTaskMutationData = {
  error: 0 | -1;
  task_list: PlanTaskItem[];
};
```

`task_done` 当前为 string，Flutter 不应先验改成 boolean；需要在 mapper 层集中转换。

#### 7.1.2 Plan artifacts

```ts
type CarePlanArtifact = {
  plan_id: number;
  user_id: string;
  plan_type: string;
  title: string;
  summary: string;
  status: string;
  source_artifact_type?: string;
  created_at: string;
  updated_at: string;
  payload: Record<string, unknown>;
};

type PlanListQuery = {
  user_id: string;
  status?: string;
};

type PlanDetailQuery = {
  user_id: string;
  plan_id: number;
};

type PlanArtifactDeleteRequest = {
  user_id: string;
  plan_id: number;
};

type PlanListData = {
  error: 0 | -1;
  plan_list: CarePlanArtifact[];
};

type PlanDetailData = {
  error: 0 | -1;
  plan: CarePlanArtifact | null;
};

type PlanArtifactDeleteData = {
  error: 0 | -1;
};
```

#### 7.1.3 Birth journey todo completion

```ts
type BirthJourneyTodoCompletionRequest = {
  user_id: string;
  plan_id: number;
  item_id: string;
  completed: boolean;
};

type BirthJourneyTodoCompletionData = {
  error: 0 | -1;
  status?: string;
  message?: string;
  plan: CarePlanArtifact | null;
  todo_items?: Record<string, unknown>[];
  updated_items?: Record<string, unknown>[];
};
```

#### 7.1.4 Pregnancy diary

```ts
type PregnancyDiaryEntry = {
  entry_id: number;
  user_id: string;
  entry_date: string;
  gestational_week: string;
  mood: string;
  energy_level: string;
  sleep_summary: string;
  fetal_movement: string;
  symptom_tags: string[];
  appointment_note: string;
  nutrition_note: string;
  content: string;
  attachments: Record<string, unknown>[];
  health_notes: PregnancyDiaryHealthNote[];
  created_at: string;
  updated_at: string;
};

type PregnancyDiaryCreateRequest = {
  user_id: string;
  entry_date: string;
  gestational_week?: string;
  mood?: string;
  energy_level?: string;
  sleep_summary?: string;
  fetal_movement?: string;
  symptom_tags?: string[];
  appointment_note?: string;
  nutrition_note?: string;
  content?: string;
  attachments?: Record<string, unknown>[];
};

type PregnancyDiaryUpdateRequest = PregnancyDiaryCreateRequest & {
  entry_id: number;
};

type PregnancyDiaryDeleteRequest = {
  user_id: string;
  entry_id: number;
};

type PregnancyDiaryListData = {
  error: 0 | -1;
  diary_list: PregnancyDiaryEntry[];
};

type PregnancyDiaryEntryData = {
  error: 0 | -1;
  diary: PregnancyDiaryEntry | null;
};
```

List query：`user_id`，可选 `start_date`、`end_date`、`limit`。Today query：`user_id`，可选 `timestamp`。

---

## 8. Notifications / Background

| Contract | Transport | Method | Current source | Flutter owner | Notes |
|---|---|---|---|---|---|
| `/v1/notify/query` | HTTP | GET | `src/lib/agentApi.ts`; Android `NotifyApiClient` | `core/notifications` | 原生周期同步和展示提醒。 |
| Device reminder `/api/ws?token=...` | WebSocket | WS | `src/lib/deviceReminderWebSocket.ts`; Android `DeviceReminderWebSocketService` | `core/notifications/native` | 需要决定 push/native/WS 策略。 |
| `/v1/vision/events/stream` | WebSocket | WS | `src/components/schedule/AddTaskDialog.tsx` | `features/schedule/data` | 当前用于 schedule 视觉/事件流，需确认是否保留。 |

### 8.1 Notifications / Background Schema

#### 8.1.1 `/v1/notify/query`

```ts
type NotifyQuery = {
  user_id: string;
  timestamp: string;
};

type NotifyQueryData = {
  error: 0 | -1;
  notify_list: Array<{
    event: "pump" | "warning" | "grown" | "summary" | "health_issue" | string;
    time: string;
    message: string;
  }>;
};
```

#### 8.1.2 Device reminder WebSocket

URL 当前默认：`ws://.../api/ws?token=...&user_id=...`

消息帧可为 JSON 或 SSE 风格 `data:`，需要递归查找：

```ts
type DeviceReminderPayload = {
  reminder_type?:
    | "task_reminder"
    | "lactation_feeding_reminder"
    | "daily_summary_reminder"
    | "milk_analysis_reminder"
    | "baby_growth_update_reminder"
    | "health_issue_reminder";
  data?: unknown;
  payload?: unknown;
  message?: unknown;
  body?: unknown;
};
```

Flutter 决策点：

- 如果继续保留 Android 后台 WS，Flutter 只消费 platform channel 事件。
- 如果迁到 Dart 层，必须证明后台、Doze、杀进程恢复策略不降级。
- `milk_analysis_reminder` 需要继续生成 Agent context event 和 follow-up task。

#### 8.1.3 `/v1/vision/events/stream`

WebSocket first frame：

```ts
type VisionEventsRequest = {
  user_id: string;
  file_id: string;
};

type VisionStreamEvent =
  | { type: "event"; event_type: "pump" | "breastfeed" | string; event?: string; time: string }
  | { type: "done" }
  | { type: "error"; message?: string };
```

该功能依赖 screenshot upload + WS parser，迁移优先级低于核心 schedule CRUD。

---

## 9. 已知废弃或不可用接口

| Interface | Current source | Disposition |
|---|---|---|
| `/v1/baby-info/create` | `src/lib/babyTwinAgentApi.ts` | V1.3 不可用，Flutter 不应调用。 |
| `/v1/baby-info/query` | `src/lib/babyTwinAgentApi.ts` | V1.3 不可用，Flutter 不应调用。 |
| `/v1/pump/health/upload` | `src/lib/momPumpTwinAgentApi.ts` | V1.3 不可用，Flutter 不应调用。 |
| `/v1/pump/health/get` | `src/lib/momPumpTwinAgentApi.ts` | V1.3 不可用，Flutter 不应调用。 |
| `/v1/plan/milk_period` | `src/lib/agentApi.ts` | V1.3 不可用，Flutter 不应调用。 |

---

## 10. Phase 0 补全 checklist

```text
[x] 为 P0/P1 endpoint 补 request schema
[x] 为 P0/P1 endpoint 补 response schema
[x] 为 P0/P1 endpoint 补 error schema
[x] 标注 auth/token/skipAuth 规则
[x] 标注 timeout/cancel/retry 规则
[x] 标注是否可在后台服务调用
[x] 创建 success/business_error/http_error/empty/partial/legacy fixtures
[x] 对 Agent stream 创建 SSE 和 WebSocket adapter fixtures
[x] 对 upload/voice/pump summary 创建取消和断线 fixtures
```
