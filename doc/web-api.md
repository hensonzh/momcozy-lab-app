# Momcozy Agent Web 端请求 / 响应与渲染说明

本文档说明默认测试 UI（`python -m momcozy_agent.server`，默认 `http://127.0.0.1:8768`）中 **Web 端发起的 HTTP 接口**、**请求与响应字段**、**解析方式**以及 **前端如何渲染**。

---

## 一、接口总览

| 方法 | 路径 | 用途 | 响应类型 |
|------|------|------|----------|
| `POST` | `/api/ag-ui` | 主对话：用户消息与图片 → Agent 流式输出 | `text/event-stream`（SSE） |
| `POST` | `/api/support-ticket-submit` | 提交售后工单（当前为模拟） | `application/json` |
| `POST` | `/api/client-event` | 记录客户端事件（如 IBCLC 咨询结束） | `application/json` |

静态页面由同一进程的 `ThreadingHTTPServer` 提供（见 `server.py` 中 `STATIC_FILES`），主聊天页为 `/` → `index.html`，IBCLC 子页为 `/ibclc-chat.html`。

---

## 二、`POST /api/ag-ui`（主对话）

### 2.1 前端发出的请求体（JSON）

由 `buildAgUiPayload` 构造（`web/app.js`），主要字段如下：

| 字段 | 类型 | 说明 |
|------|------|------|
| `threadId` | string | 会话 ID；首次为 `thread_${uuid}`，之后会写入 `localStorage.momcozy_conversation_id` |
| `runId` | string | 单次运行 ID，形如 `run_${Date.now()}_${runCount}` |
| `state` | object | 当前含 `locale`（`navigator.language`） |
| `messages` | array | 仅一条用户消息：`{ id, role: "user", content }` |
| `content`（在 `messages[0]` 内） | string 或 array | 纯文本时为字符串；带图时为数组：可选 `{ type: "text", text }` + 若干 `{ type: "image", image_url, mime_type, name, size, detail }`（`image_url` 常用 `data:image/...` base64） |
| `tools` | array | 测试 UI 中为空数组 |
| `context` | array | 测试 UI 中为空数组 |
| `forwardedProps` | object | 测试 UI 中为空对象 |

请求头：`Content-Type: application/json`，`Accept: text/event-stream`。

### 2.2 服务端如何把请求转成 Agent 输入

`server.py` 中 `_runtime_inputs_from_ag_ui` 负责解析：

- **用户文本**：从 `messages` 里 **最后一条** `role === "user"` 的 `content` 取字符串，或为 list 时合并其中 `type` 为文本的 `text` 片段。
- **无文字仅有图**：自动设为固定提示「请根据我发送的图片提供帮助。」
- **图片**：从用户消息 `content` 数组里取 `type` 为 `image` 或 `input_image` 的项，读取 `image_url` / `url` / `data_url`，校验为 `data:image/`、`http(s)://`，附带 `detail`（`low`/`high`/`auto`）、可选 `mime_type`、`name`、`size`；最多 4 张（与 `MAX_IMAGE_ATTACHMENTS` 一致）。
- **上下文扩展**：若请求体存在 `state`、`forwardedProps`（或蛇形 `forwarded_props`），会把其中的 `user_profile`、`baby_profile`、`service_state`、`retrieved_records`、`retrieved_knowledge` 以及 `locale`、`timezone`、`message_sent_at`、`previous_response_id` 合并进 Agent 的 `inputs`。测试 UI 当前主要只传 `state.locale`。

线程 ID：`thread_id` / `threadId` 与 `conversation_id` 等价用法中的会话键。

### 2.3 响应：SSE 事件流

`Content-Type: text/event-stream`。每一帧为：

```text
data: <单行 JSON>\n\n
```

服务端除 Agent 发出的事件外，还会包装 **助手文本流** 为（`server.py`）：

- `TEXT_MESSAGE_START`：`message_id`、`role`
- `TEXT_MESSAGE_CONTENT`：`delta`（文本增量）
- `TEXT_MESSAGE_END`：`message_id`

Agent 侧在 `agents.py` 中定义并推送的典型事件类型包括：

| `type` | 主要字段（节选） | 作用 |
|--------|------------------|------|
| `RUN_STARTED` | `thread_id`, `run_id`, 可选 `parent_run_id`, `input` | 运行开始 |
| `RUN_FINISHED` | `thread_id`, `run_id`, 可选 `result` | 运行结束（服务端会延后到最后再下发，避免顺序问题） |
| `RUN_ERROR` | `message`, 可选 `code` | 错误 |
| `ACTIVITY_SNAPSHOT` | `content`（内含 `metadata` 等） | 状态快照 |
| `CUSTOM` | `name` 为 `momcozy.agent.status` 或 `momcozy.agent.thinking`，`value` | 状态条 /「思考中」UI |
| `TOOL_CALL_START` | `tool_call_id`, `tool_call_name`, 可选 `response_id`, `output_index`, `item_id` | 工具开始 |
| `TOOL_CALL_ARGS` | `tool_call_id`, `delta`（JSON 字符串化的参数摘要） | 工具参数 |
| `TOOL_CALL_END` | `tool_call_id` | 工具调用结束 |
| `TOOL_CALL_RESULT` | `content` 为 **JSON 字符串**（工具结果经 `safe_tool_result` 脱敏后的对象） | 工具结果 |

`TOOL_CALL_RESULT` 的 `content` 解析后常见字段：`ok`, `tool_name`, 以及按工具类型的 `form` / `card` / `ticket` / `skill_id` 等（见 `safe_tool_result`）。

### 2.4 前端如何解析 SSE

1. `fetch` 得到 `response.body`，`ReadableStream` + `TextDecoder` 读块。
2. 按 `\n\n` 切分事件块；每块内取以 `data:` 开头的行，去掉前缀后 **拼接**（支持多行 `data:`），再 `JSON.parse` 得到事件对象（`parseSseEvent`）。

### 2.5 前端如何根据事件渲染 UI

- **元信息**：`RUN_STARTED`、部分 `CUSTOM`/`ACTIVITY_SNAPSHOT`/`STEP_*` 会调用 `updateMeta`，更新页面上会话简称与已加载 `loaded_skill_ids`（并回写 `localStorage` 中的 `conversation_id`）。
- **状态行**：`addStatusNode` 生成的 `.status-note`，`updateStatus` 把英文内部状态映射成简短标签，并列出已用工具名。
- **工作面板**（`.work-panel`）：`TOOL_CALL_*` 系列进入 `addWorkToolStart` / `addWorkToolArgs` / `addWorkToolEnd` / `addWorkToolResult`，在 `ol.work-list` 里用 `upsertWorkItem` 更新同一工具的 running/completed 状态；工具中途产生的助手正文会先 `moveProvisionalTextToWorkPanel`，用 `setAssistantMarkdown` 放进工作区叙述条。
- **助手正文**：`TEXT_MESSAGE_CONTENT` 对 **当前助手气泡** 调用 `appendAssistantMarkdown`：把增量拼到 `node._rawMarkdown`，再用 **marked** 转 HTML，**DOMPurify** 消毒后写入 `innerHTML`；图片可点击打开放大层。
- **思考提示**：`CUSTOM` + `momcozy.agent.thinking` 在特定 `status` 下显示 `.thinking-note`。
- **`TOOL_CALL_RESULT` 特例**（根据解析后的 `tool_name` 与载荷）：
  - `ui_form_create` 且含 `result.form` → `addFormCard`：渲染表单 artifact，提交后拼装确认文案再 `sendUserText`。
  - `ui_card_create` 且含 `result.card` → `addCard`：按 `card_type` / `schema_version` 渲染卡片（如 birth plan、hospital bag），否则 `renderUnsupportedCard`。
  - `ibclc_consult_card_create` → `addIbclcConsultCard`：顾问信息 + 「在线咨询」链接。
  - `support_ticket_draft_create` → `addSupportTicketDraft`：售后工单表单，提交再走 `/api/support-ticket-submit`。
- **结束**：`RUN_FINISHED` 时若无表单/卡片且助手无正文，会显示 `(No text response)`；`RUN_ERROR` 抛错并在界面显示 error 消息。

---

## 三、`POST /api/support-ticket-submit`（售后工单）

### 3.1 请求体

由 `submitSupportTicket` 发送：

| 字段 | 说明 |
|------|------|
| `ticket` | 工单对象（见下） |
| `locale` | `navigator.language` |
| `message_sent_at` | ISO 时间 |
| `idempotency_key` | `crypto.randomUUID()` |

`ticket` 来自表单收集，经 `normalizeSupportTicketValues` 后通常含：`issue_type`, `issue_summary`, `product_model`, `urgency`, `troubleshooting_done`（数组）等。

### 3.2 响应体（JSON，当前为模拟）

`server.py` 中 `_submit_support_ticket` 返回：

| 字段 | 说明 |
|------|------|
| `status` | 如 `"mock_submitted"` |
| `ticket_id` | 模拟工单号 |
| `side_effect_performed` | `false` |
| `mock` | `true` |
| `message` | 提示文案 |
| `ticket` | 回显提交的工单对象 |

### 3.3 前端渲染

成功后按钮文案变为「已提交」，并 `sendUserText(buildSupportTicketSubmittedMessage(values, result), …)`，让 Agent 基于工单结果再回复用户（文案里包含工单号、问题类型等）。

---

## 四、`POST /api/client-event`（IBCLC 咨询结束等）

### 4.1 调用场景

`ibclc-chat.html` 在用户点击结束咨询时 `fetch`，用于把事件记入服务端会话的 `context_state.client_events`（保留最近 10 条）。

### 4.2 请求体示例字段

| 字段 | 说明 |
|------|------|
| `thread_id` | 与主会话一致（URL `thread_id` 或 localStorage） |
| `event_type` | 如 `ibclc_consult_completed` |
| `label` | 展示用短描述 |
| `occurred_at` | ISO 时间 |
| `metadata` | 可含 `consultant_name`, `consultant_credentials`, `source`, `consult_id` 等 |

服务端也接受 `conversation_id`、`type`、`consult_id` / `consultId` 等别名（见 `_format_client_event`、`_client_event_consult_id`）。

### 4.3 响应体

| 字段 | 说明 |
|------|------|
| `status` | `"recorded"` |
| `conversation_id` | 会话 ID |
| `consult_id` | 咨询 ID |
| `event` | 格式化后的单条事件字符串（用于上下文） |
| `session_state` | 含 `conversation_id`、`previous_response_id`、`loaded_skill_ids`、`context_state`（含 `client_events` 等） |

### 4.4 与主页面的联动

子窗口 `postMessage` 向 opener 发送 `type: "momcozy.ibclc_consult_completed"` 等载荷；主页面 `handleIbclcConsultCompleted` 更新 meta，并对对应 `.ibclc-card` 将按钮改为「咨询结束」并禁用链接。

---

## 五、辅助：静态资源与其它请求

- **图片附件预览**：本地用 `FileReader.readAsDataURL`，不经过独立上传接口（除非未来改为 URL）。
- **卡片导出 PNG**：`html-to-image`（`index.html` 引入）在 `attachCardDownload` 流程中使用。
- **Markdown**：`marked` + `DOMPurify`（CDN，见 `index.html`）。

---

## 六、与「应用侧 FastAPI」的关系说明

仓库另有 `api_app.py`（`FastAPI`）挂载 `/v1/...` 等设备与业务接口；**当前这套静态测试 UI（`web/`）未直接调用这些 `/v1` 路由**，主路径是上述三个 `/api/*` 与内置静态文件。若生产环境通过网关把同一前端挂到不同后端，字段应以实际部署的代理与 OpenAPI 为准。
