# Momcozy App 与 Agent 通信说明

本文档说明当前 `MomCozyApp` 与 `MomCozyAgent` 的通信边界。旧的 `MomCozyAgent/web/` 静态测试页面已经移除；App 是主前端，Agent 后端提供统一 API 与内部 SSE agent stream。

---

## 一、入口总览

| 入口 | 默认地址 | 用途 |
|------|----------|------|
| App 统一 API | `http://127.0.0.1:8769` | App 访问的业务与 Agent 网关；`/`、`/health` 返回 JSON 服务信息 |
| App 聊天 WebSocket | `ws://127.0.0.1:8769/api/ag-ui-ws` | AgentHub 主聊天流 |
| Agent SSE 上游 | `http://127.0.0.1:8768/api/ag-ui` | 后端调试和 WebSocket 桥接上游 |
| Agent SSE 健康检查 | `http://127.0.0.1:8768/`、`/health` | 返回 JSON 服务信息，不提供 HTML demo |

本地常用启动方式：

```bash
cd MomCozyAgent
.venv/bin/python -u scripts/run_all.py
```

单独启动 SSE 服务时使用：

```bash
cd MomCozyAgent
.venv/bin/python -u scripts/run_chat_sse.py
```

`momcozy-chat-sse` 是当前命令名；`momcozy-chat-ui` 仅作为旧脚本兼容 alias，实际启动的仍是 SSE 服务，不会恢复旧 web demo。

---

## 二、主聊天链路

当前主链路是：

```text
MomCozyApp AgentHub
  -> WS /api/ag-ui-ws
  -> FastAPI bridge
  -> POST /api/ag-ui
  -> Responses API agent loop
  -> AG-UI events
  -> WebSocket JSON text frame
  -> MomCozyApp 渲染
```

App 侧主要文件：

- `src/pages/AgentHub.tsx`
- `src/lib/agentApi.ts`
- `src/lib/agUiStreamSideEffects.ts`
- `src/pages/agentHub/AgentHubRichTextBlock.tsx`
- `src/components/chat/ChatMarkdown.tsx`

后端主要文件：

- `MomCozyAgent/src/momcozy_agent/api_app.py`
- `MomCozyAgent/src/momcozy_agent/api/chat_ws_bridge.py`
- `MomCozyAgent/src/momcozy_agent/server.py`

---

## 三、`WS /api/ag-ui-ws`

App 建立 WebSocket 后，第一帧发送 AG-UI 请求体。该请求体与 `POST /api/ag-ui` 使用同一结构，常见字段包括：

| 字段 | 说明 |
|------|------|
| `threadId` | 会话 ID；App 侧通过会话存储维护 |
| `runId` | 单次运行 ID |
| `state` | locale、timezone、页面状态等运行上下文 |
| `messages` | 当前用户消息；可包含文本与图片 data URL |
| `forwardedProps` | App 侧转发给 agent 的业务上下文 |

鉴权使用 `ENTRY_API_KEY`。App 通常通过 `VITE_API_TOKEN` 配置，并以查询参数或 `Authorization: Bearer ...` 方式传给统一 API。

WebSocket 返回的每一帧都是一个 AG-UI event JSON，典型类型包括：

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

App 不读取旧静态测试脚本。事件解析、work panel 更新、artifact 渲染和副作用处理都在 `MomCozyApp/src` 内完成。

---

## 四、`POST /api/ag-ui`

`/api/ag-ui` 是 Agent SSE 服务入口，供后端调试和 `/api/ag-ui-ws` 桥接复用。响应类型是 `text/event-stream`。

服务端会把 AG-UI 请求转成 `RuntimeInputs`：

- 从最后一条 user message 中提取文本。
- 支持 `content` 为字符串或多 part 数组。
- 支持最多 4 张图片输入。
- 合并 `state`、`forwardedProps`、`locale`、`timezone`、`message_sent_at` 等上下文。
- 通过 `threadId` / `thread_id` / `conversation_id` 维护 `ChatSession`。

SSE 服务根路径 `/` 和 `/health` 只返回服务 JSON 信息；旧 `/app.js`、`/styles.css` 和 HTML 页面不会再被服务。

---

## 五、辅助接口

### `POST /api/ag-ui-prewarm`

App 新建会话后可调用预热接口。统一 API 校验 `ENTRY_API_KEY` 后转发到 SSE 服务的同名接口，只保存后端 session 状态，不向前端生成可见消息。

### `POST /api/client-event`

用于把 App 页面事件写回 agent session，例如 IBCLC 咨询结束、提醒点击、分析上下文事件等。

IBCLC 页面现在由 App 路由承接：

```text
/ibclc-chat.html
```

对应组件是 `src/pages/IbclcChat.tsx`。结束咨询时，App 调用 `/api/client-event`，统一 API 再转发到 SSE 服务，最终写入 `context_state.client_events`。

### `POST /api/support-ticket-submit`

用于售后工单模拟提交。App artifact 收集表单后调用该接口，再把提交结果作为用户消息继续送回 Agent。

---

## 六、静态资源

旧 web demo 静态文件已经删除，不再通过 `/`、`/app.js`、`/styles.css` 提供页面。

Agent 仍提供 skill 资产访问：

```text
/skill-assets/{skill_id}/{asset_path}
```

Air1 FAQ 图片迁移到了：

```text
/skill-assets/device-guidance/air1/faq-images/...
```

为了兼容历史消息中的旧图片链接，后端保留：

```text
/images/Air_img/...
```

该兼容路径只映射到 `device-guidance` 的 Air1 FAQ 图片资产，不代表旧 web demo 仍存在。

---

## 七、维护检查

改动 Agent 通信链路时，至少检查：

- `MomCozyAgent` 后端测试：`env PYTHONPATH=src .venv/bin/python -m unittest discover -s tests`
- App 相关测试：`npm test -- ibclcConsult AgentHubRichTextBlock ChatMarkdown chatAssetUrl`
- 旧 demo 引用扫描：按迁移检查清单扫描旧测试 UI 关键词，确认只剩兼容 alias 和“已删除”说明。
- 路由 smoke test：`GET /`、`GET /health`、`HEAD /skill-assets/...`
