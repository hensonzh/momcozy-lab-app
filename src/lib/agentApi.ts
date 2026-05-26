/**
 * 业务 API：与后端 `/v1/*` 文档一一对应，统一经 apiRequest / uploadMultipart，默认 Bearer 鉴权。
 */

import {
  apiRequest,
  apiRequestRaw,
  appendQueryParams,
  getTtsStream,
  resolveHttpRequestUrl,
  uploadMultipart,
  type GetTtsStreamOptions,
  type GetTtsStreamResult,
} from "./http";
import { log } from "./logger";
import { resolveChatAssetUrl } from "@/lib/chatAssetUrl";
import type {
  ChatHistoryData,
  ChatActionContentPayload,
  ChatHistoryParams,
  ChatRichTextButtonItem,
  ChatRichTextCardContentItem,
  ChatRichTextCardItem,
  ChatRichTextPayload,
  AddPlanTaskBody,
  DeletePlanTaskBody,
  DeviceInfoBody,
  DeviceInfoData,
  FileUploadResponseData,
  NotifyQueryData,
  NotifyQueryParams,
  PlanMilkPeriodData,
  PlanMilkPeriodParams,
  PlanTaskMutationData,
  PlanPumpTodayParams,
  PlanQueryData,
  PlanQueryParams,
  PumpProcessBody,
  PumpProcessDataBody,
  PumpProcessDataResponseData,
  PumpSessionSummaryBody,
  PumpSessionSummaryResponse,
  PumpThresholdData,
  PumpThresholdUploadBody,
  PumpWorkstateBody,
  RevisePlanTaskBody,
  StatusCreateBody,
  StatusCreateData,
  AnalysisCreateBody,
  AnalysisCreateData,
  UploadPumpProcessResponseData,
  UploadPumpWorkstateResponse,
  WorkflowStopBody,
  WorkflowStopData,
} from "./agentApiTypes";

export * from "./agentApiTypes";

/** v1 路径前缀（与 {base_url}/v1 一致） */
export const API_V1_PREFIX = "/v1" as const;

/**
 * V1.2 对话打断路径：`POST /v1/workflows/tasks/{conversation_id}/stop`
 */
export function workflowsTasksStopPath(conversationId: string): string {
  const id = String(conversationId ?? "").trim();
  return `${API_V1_PREFIX}/workflows/tasks/${encodeURIComponent(id)}/stop`;
}

/** 集中维护的路径，便于联调替换 */
export const API_PATHS = {
  FILES_UPLOAD: `${API_V1_PREFIX}/files/upload`,
  TTS_STREAM: `${API_V1_PREFIX}/tts-stream`,
  CHAT_MESSAGE_HISTORY: `${API_V1_PREFIX}/chat-message/history`,
  PUMP_THRESHOLD_UPLOAD: `${API_V1_PREFIX}/pump/threshold/upload`,
  PUMP_THRESHOLD_GET: `${API_V1_PREFIX}/pump/threshold/get`,
  PUMP_WORKSTATE: `${API_V1_PREFIX}/pump/workstate`,
  PUMP_PROCESS: `${API_V1_PREFIX}/pump/process`,
  PUMP_PROCESS_DATA: `${API_V1_PREFIX}/pump/process/data`,
  PUMP_SESSION_SUMMARY_WS: `${API_V1_PREFIX}/pump/session-summary`,
  PLAN_QUERY_TASK: `${API_V1_PREFIX}/plan/query-task`,
  PLAN_ADD_TASK: `${API_V1_PREFIX}/plan/add-task`,
  PLAN_DELETE_TASK: `${API_V1_PREFIX}/plan/delete-task`,
  PLAN_REVISE_TASK: `${API_V1_PREFIX}/plan/revise-task`,
  DEVICE_INFO: `${API_V1_PREFIX}/device/info`,
  NOTIFY_QUERY: `${API_V1_PREFIX}/notify/query`,
  STATUS_CREATE: `${API_V1_PREFIX}/status/create`,
  ANALYSIS_CREATE: `${API_V1_PREFIX}/analysis/create`,
  /** 语音分片转写（multipart 音频）；需后端实现，或由 `VITE_STT_CHUNK_PATH` 覆盖完整路径 */
  SPEECH_TRANSCRIBE_CHUNK: `${API_V1_PREFIX}/speech/transcribe-chunk`,
} as const;

// ─── 通用 ────────────────────────────────────────────────────────────

/**
 * 上传文件（图片等），multipart：`user_id` + `file`。
 * @param userId 用户 id
 * @param file 文件
 * @param opts token 覆盖等
 * @returns 解包后的 data
 */
export async function uploadFile(
  userId: string,
  file: Blob | File,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<FileUploadResponseData> {
  return uploadMultipart<FileUploadResponseData>({
    url: API_PATHS.FILES_UPLOAD,
    userId,
    file,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 上传单段音频分片并取转写文本；失败或空结果返回 null（供 chunked 管线忽略单次错误）。
 * 路径默认 {@link API_PATHS.SPEECH_TRANSCRIBE_CHUNK}，可通过 `VITE_STT_CHUNK_PATH` 覆盖（相对或绝对）。
 * @param userId 用户 id
 * @param audio 音频 Blob（如 webm、wav）
 * @param opts 鉴权、中断信号；可选 `fileName` / `mimeType` 覆盖 multipart 文件名与类型（如 16k PCM 封装为 wav）
 * @returns 非空转写或 null
 */
export async function transcribeSpeechAudioChunk(
  userId: string,
  audio: Blob,
  opts?: {
    token?: string;
    skipAuth?: boolean;
    signal?: AbortSignal;
    fileName?: string;
    mimeType?: string;
  },
): Promise<string | null> {
  const pathOverride =
    (typeof import.meta !== "undefined" && (import.meta.env.VITE_STT_CHUNK_PATH as string | undefined)?.trim()) || "";
  const url = pathOverride || API_PATHS.SPEECH_TRANSCRIBE_CHUNK;
  const fileName = opts?.fileName ?? `speech-chunk-${Date.now()}.webm`;
  const mimeType = opts?.mimeType ?? (audio.type && audio.type.length > 0 ? audio.type : "audio/webm");
  const file =
    audio instanceof File
      ? audio
      : new File([audio], fileName, {
          type: mimeType,
        });
  try {
    const data = await uploadMultipart<{ text?: string; transcript?: string } & Record<string, unknown>>({
      url,
      userId,
      file,
      token: opts?.token,
      skipAuth: opts?.skipAuth,
      signal: opts?.signal,
    });
    const text = data.text ?? data.transcript;
    return typeof text === "string" && text.trim() ? text.trim() : null;
  } catch (e: unknown) {
    const aborted =
      opts?.signal?.aborted ||
      (typeof e === "object" &&
        e != null &&
        "name" in e &&
        (e as { name?: string }).name === "AbortError");
    if (aborted) throw e;
    log("[STT chunk] 单次请求失败", e instanceof Error ? e.message : e);
    return null;
  }
}

/**
 * TTS：GET 流式音频，query：`user_id`、`text`。
 * @param userId 用户 id
 * @param text 待合成文本
 * @param opts 鉴权与其它选项
 * @returns Blob 与可选文件名
 */
export async function fetchTtsAudio(
  userId: string,
  text: string,
  opts?: Omit<GetTtsStreamOptions, "params">,
): Promise<GetTtsStreamResult> {
  const params: GetTtsStreamOptions["params"] = { user_id: userId, text };
  return getTtsStream(API_PATHS.TTS_STREAM, { ...opts, params });
}

// ─── 对话 ────────────────────────────────────────────────────────────

/**
 * 将服务端返回的 rich_text 对象规范为 ChatRichTextPayload。
 * @param raw rich_text 原始对象
 * @returns 带默认空数组/空字符串的结构
 */
function normalizeChatRichTextPayload(raw: Record<string, unknown>): ChatRichTextPayload {
  const title = typeof raw.title === "string" ? raw.title : "";
  const content = typeof raw.content === "string" ? raw.content : "";
  const buttonsRaw = Array.isArray(raw.button) ? raw.button : [];
  const button: ChatRichTextButtonItem[] = buttonsRaw.map((b) => {
    const o = b && typeof b === "object" ? (b as Record<string, unknown>) : {};
    const typeStr = typeof o.type === "string" ? o.type : "";
    let value = typeof o.value === "string" ? o.value : "";
    // open 类型一般为文件相对路径，拼聊天资源服务基址供客户端 HTTP 访问
    if (typeStr.toLowerCase() === "open" && value.trim()) {
      value = resolveChatAssetUrl(value);
    }
    return {
      text: typeof o.text === "string" ? o.text : "",
      value,
      type: typeStr,
      highlight: Boolean(o.highlight),
      icon: typeof o.icon === "string" ? o.icon : "",
    };
  });
  const cardRaw = Array.isArray(raw.card) ? raw.card : [];
  const card: ChatRichTextCardItem[] = cardRaw.map((it) => {
    const o = it && typeof it === "object" ? (it as Record<string, unknown>) : {};
    const contentRaw = Array.isArray(o.content) ? o.content : [];
    const content: ChatRichTextCardContentItem[] = contentRaw.map((row) => {
      const r = row && typeof row === "object" ? (row as Record<string, unknown>) : {};
      return {
        title: typeof r.title === "string" ? r.title : "",
        content: typeof r.content === "string" ? r.content : "",
      };
    });
    return {
      text: typeof o.text === "string" ? o.text : "",
      type: typeof o.type === "string" ? o.type : "",
      highlight: Boolean(o.highlight),
      content,
    };
  });
  const action = Array.isArray(raw.action) ? raw.action : [];
  return { title, content, button, card, action };
}

/**
 * 从 chat-messages SSE 单条 JSON 中解析富文本（event 为 rich_text，或根级含 rich_text）。
 * @param data streamSSE 解析后的 data 行
 * @returns 可展示的富文本；无法解析时为 null
 */
export function parseChatRichTextFromSseData(data: string | object): ChatRichTextPayload | null {
  if (typeof data !== "object" || data === null) return null;
  const d = data as Record<string, unknown>;
  const raw = d.rich_text;
  if (raw == null || typeof raw !== "object") return null;
  return normalizeChatRichTextPayload(raw as Record<string, unknown>);
}

/**
 * 从 chat-messages SSE 单条 data JSON 中解析 action_content（根级字段，可为 JSON 字符串）。
 */
export function parseActionContentFromSseData(data: string | object): ChatActionContentPayload | null {
  if (typeof data !== "object" || data === null) return null;
  const d = data as Record<string, unknown>;
  const raw = d.action_content;
  if (raw == null) return null;
  let o: Record<string, unknown>;
  if (typeof raw === "string") {
    try {
      o = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return null;
    }
  } else if (typeof raw === "object") {
    o = raw as Record<string, unknown>;
  } else {
    return null;
  }
  const val = typeof o.val === "string" ? o.val.trim() : "";
  const target_scope = typeof o.target_scope === "string" ? o.target_scope.trim() : "";
  if (!val || !target_scope) return null;
  const payload: ChatActionContentPayload = { val, target_scope };
  const levelRaw = o.level;
  if (typeof levelRaw === "number" && Number.isFinite(levelRaw)) {
    payload.level = levelRaw;
  } else if (typeof levelRaw === "string" && levelRaw.trim() !== "") {
    const n = Number(levelRaw.trim());
    if (!Number.isNaN(n)) payload.level = n;
  }
  return payload;
}

function httpLikeUrlToWebSocketUrl(url: string): string {
  if (url.startsWith("https://")) return `wss://${url.slice(8)}`;
  if (url.startsWith("http://")) return `ws://${url.slice(7)}`;
  if (url.startsWith("/") && typeof window !== "undefined") {
    const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
    return `${proto}//${window.location.host}${url}`;
  }
  return url;
}

function isWebSocketUrl(url: string): boolean {
  return /^wss?:\/\//i.test(url);
}

/** HTTPS 页面（含 Android WebView 安全上下文）不允许发起 `ws://`，需升级为 `wss://`。 */
function enforceSecureWebSocketInSecureContext(wsUrl: string): string {
  if (typeof window === "undefined") return wsUrl;
  if (window.location.protocol !== "https:") return wsUrl;
  if (!wsUrl.startsWith("ws://")) return wsUrl;
  return `wss://${wsUrl.slice(5)}`;
}

function redactWebSocketUrl(url: string): string {
  try {
    const u = new URL(url);
    if (u.searchParams.has("token")) u.searchParams.set("token", "***");
    return `${u.origin}${u.pathname}${u.search}`;
  } catch {
    return url.replace(/([?&]token=)[^&]*/i, "$1***");
  }
}

export interface AgUiPayloadImageItem {
  dataUrl: string;
  mimeType: string;
  name: string;
  size: number;
  detail?: "auto" | "low" | "high";
}

interface AgUiPayloadContentTextItem {
  type: "text";
  text: string;
}

interface AgUiPayloadContentImageItem {
  type: "image";
  image_url: string;
  mime_type: string;
  name: string;
  size: number;
  detail: "auto" | "low" | "high";
}

type AgUiPayloadMessageContent =
  | string
  | Array<AgUiPayloadContentTextItem | AgUiPayloadContentImageItem>;

export interface AgUiPayload {
  threadId: string;
  runId: string;
  state: { locale: string } & Record<string, unknown>;
  messages: Array<{
    id: string;
    role: "user";
    content: AgUiPayloadMessageContent;
  }>;
  tools: unknown[];
  context: unknown[];
  forwardedProps: Record<string, unknown>;
}

const AG_UI_WS_PATH = "/api/ag-ui-ws" as const;
const ENV_API_BASE_URL =
  (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim()) || "";
const ENV_AG_UI_WS_URL =
  (typeof import.meta !== "undefined" && (import.meta.env.VITE_AG_UI_WS_URL as string | undefined)?.trim()) || "";

function normalizeAgUiWsUrl(raw: string): string {
  const value = raw.trim();
  if (!value) return AG_UI_WS_PATH;
  if (value.startsWith("/")) return value;
  try {
    const u = new URL(value);
    if (u.pathname === "/" || !u.pathname.trim()) {
      u.pathname = AG_UI_WS_PATH;
      return u.toString();
    }
    if (u.pathname.endsWith("/")) {
      u.pathname = `${u.pathname.slice(0, -1)}${AG_UI_WS_PATH}`;
      return u.toString();
    }
    if (!u.pathname.includes("api/ag-ui-ws")) {
      u.pathname = `${u.pathname}${AG_UI_WS_PATH}`;
      return u.toString();
    }
    return u.toString();
  } catch {
    return value;
  }
}

const AG_UI_WS_URL = normalizeAgUiWsUrl(ENV_AG_UI_WS_URL || ENV_API_BASE_URL || AG_UI_WS_PATH);
let agUiRunCount = 0;

export function resolveAgUiWebSocketRequestUrl(raw?: string): string {
  const normalized = normalizeAgUiWsUrl(raw?.trim() || AG_UI_WS_URL);
  const baseResolved = normalized.startsWith("/") && ENV_API_BASE_URL ? normalizeAgUiWsUrl(ENV_API_BASE_URL) : normalized;
  const resolved = isWebSocketUrl(baseResolved) ? baseResolved : resolveHttpRequestUrl(baseResolved);
  return enforceSecureWebSocketInSecureContext(httpLikeUrlToWebSocketUrl(resolved));
}

function buildAgUiRunId(): string {
  agUiRunCount += 1;
  return `run_${Date.now()}_${agUiRunCount}`;
}

function buildAgUiMessageId(): string {
  return `msg_${Date.now()}`;
}

export function buildAgUiPayload(
  text: string,
  images: AgUiPayloadImageItem[],
  opts: { threadId: string; locale?: string; forwardedProps?: Record<string, unknown> },
): AgUiPayload {
  const locale =
    opts.locale?.trim() ||
    (typeof navigator !== "undefined" && navigator.language?.trim()) ||
    "en-US";
  const normalizedText = String(text ?? "").trim();
  const content: AgUiPayloadMessageContent =
    images.length > 0
      ? [
          { type: "text", text: normalizedText },
          ...images.map((img) => ({
            type: "image" as const,
            image_url: img.dataUrl,
            mime_type: img.mimeType || "image/png",
            name: img.name || "image.png",
            size: Number.isFinite(img.size) ? img.size : 0,
            detail: img.detail ?? "auto",
          })),
        ]
      : normalizedText;
  return {
    threadId: opts.threadId,
    runId: buildAgUiRunId(),
    state: { ...opts.forwardedProps, locale },
    messages: [
      {
        id: buildAgUiMessageId(),
        role: "user",
        content,
      },
    ],
    tools: [],
    context: [],
    forwardedProps: opts.forwardedProps ?? {},
  };
}

export interface PostAgUiWebSocketStreamParams {
  text: string;
  threadId: string;
  locale?: string;
  images?: AgUiPayloadImageItem[];
  forwardedProps?: Record<string, unknown>;
  wsUrl?: string;
  signal?: AbortSignal;
  onMessage: (data: string | object) => void;
  onDone?: () => void;
  onError?: (err: Error) => void;
  parseJSON?: boolean;
}

/**
 * ag-ui 对话流（WebSocket）：发送 `buildAgUiPayload(text, images)`，服务端以 SSE 风格 `data: {...}\n\n` 回推事件。
 * 兼容两种消息帧：纯 JSON 或 SSE data block；在收到 `RUN_FINISHED` 时触发 onDone 并主动关闭连接。
 */
export function postAgUiWebSocketStream(params: PostAgUiWebSocketStreamParams): () => void {
  const { text, threadId, locale, images = [], forwardedProps, wsUrl, signal, onMessage, onDone, onError, parseJSON = true } =
    params;
  const authToken =
    (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_TOKEN as string | undefined)?.trim()) || "";
  let resolvedWsUrl = resolveAgUiWebSocketRequestUrl(wsUrl);
  if (authToken) {
    resolvedWsUrl = appendQueryParams(resolvedWsUrl, { token: authToken });
  }
  let ws: WebSocket | null = null;
  let cancelled = false;
  let doneEmitted = false;
  let failed = false;
  let sseBuffer = "";

  const emitDoneOnce = () => {
    if (doneEmitted) return;
    doneEmitted = true;
    onDone?.();
  };

  const closeSocket = () => {
    try {
      ws?.close();
    } catch {
      /* ignore */
    }
  };

  const cancel = () => {
    cancelled = true;
    closeSocket();
  };

  if (signal) {
    signal.addEventListener("abort", () => {
      cancelled = true;
      closeSocket();
    });
  }

  const emitPayload = (raw: string) => {
    const t = raw.trim();
    if (!t) return;
    if (!parseJSON) {
      onMessage(t);
      return;
    }
    try {
      const obj = JSON.parse(t) as unknown;
      if (typeof obj === "object" && obj != null) {
        const rec = obj as Record<string, unknown>;
        const type = typeof rec.type === "string" ? rec.type : "";
        if (type === "RUN_FINISHED") {
          onMessage(rec);
          emitDoneOnce();
          closeSocket();
          return;
        }
        if (type === "RUN_FAILED" || type === "ERROR" || type === "RUN_ERROR") {
          failed = true;
          const msg =
            typeof rec.message === "string" && rec.message.trim()
              ? rec.message.trim()
              : "ag-ui websocket error";
          onError?.(new Error(msg));
          closeSocket();
          return;
        }
      }
      onMessage(obj as object);
    } catch {
      onMessage(t);
    }
  };

  const consumeSseLikeChunk = (chunk: string) => {
    sseBuffer += chunk;
    const blocks = sseBuffer.split(/\r?\n\r?\n/);
    sseBuffer = blocks.pop() ?? "";
    for (const block of blocks) {
      const lines = block.split(/\r?\n/);
      const dataLines = lines
        .filter((line) => line.startsWith("data:"))
        .map((line) => line.slice(5).trim());
      if (dataLines.length > 0) {
        emitPayload(dataLines.join("\n"));
      }
    }
  };

  try {
    ws = new WebSocket(resolvedWsUrl);
  } catch (e: unknown) {
    onError?.(e instanceof Error ? e : new Error(String(e)));
    return () => {
      cancelled = true;
    };
  }

  ws.onopen = () => {
    if (cancelled) return;
    try {
      const payload = buildAgUiPayload(text, images, { threadId, locale, forwardedProps });
      const serializedPayload = JSON.stringify(payload);
      log("[AG_UI_WS] send", {
        url: redactWebSocketUrl(resolvedWsUrl),
        threadId: payload.threadId,
        runId: payload.runId,
        hasImages: images.length > 0,
      });
      log("[AG_UI_WS] send-payload-full", {
        url: redactWebSocketUrl(resolvedWsUrl),
        payload,
        serializedPayload,
      });
      ws?.send(serializedPayload);
    } catch (e: unknown) {
      failed = true;
      onError?.(e instanceof Error ? e : new Error(String(e)));
      closeSocket();
    }
  };

  ws.onmessage = (ev: MessageEvent) => {
    if (cancelled) return;
    const raw = ev.data;
    if (typeof raw !== "string") {
      log("[AG_UI_WS] recv-non-string", {
        url: redactWebSocketUrl(resolvedWsUrl),
        dataType: raw == null ? String(raw) : Object.prototype.toString.call(raw),
      });
      return;
    }
    log("[AG_UI_WS] recv-frame-raw-full", {
      url: redactWebSocketUrl(resolvedWsUrl),
      rawLength: raw.length,
      raw,
    });
    if (raw.includes("data:")) {
      consumeSseLikeChunk(raw);
      return;
    }
    emitPayload(raw);
  };

  ws.onerror = () => {
    if (cancelled) return;
    failed = true;
    onError?.(new Error(`ag-ui websocket connection error url=${redactWebSocketUrl(resolvedWsUrl)}`));
  };

  ws.onclose = (ev: CloseEvent) => {
    log("[AG_UI_WS] close", {
      code: ev.code,
      reason: ev.reason || undefined,
      wasClean: ev.wasClean,
      doneEmitted,
      failed,
      cancelled,
    });
    if (cancelled || failed) return;
    if (!doneEmitted && sseBuffer.trim()) {
      emitPayload(sseBuffer);
      sseBuffer = "";
    }
    if (!doneEmitted && ev.code !== 1000) {
      const reason = ev.reason?.trim() ? ` reason=${ev.reason.trim()}` : "";
      onError?.(new Error(`ag-ui websocket closed unexpectedly: code=${ev.code}${reason}`));
      return;
    }
    if (!doneEmitted) emitDoneOnce();
  };

  return cancel;
}

function parseWebSocketJsonFrame(raw: string): unknown {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith("data:")) {
    const data = trimmed
      .split(/\r?\n/)
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice(5).trim())
      .join("\n")
      .trim();
    if (!data) return null;
    return JSON.parse(data);
  }
  return JSON.parse(trimmed);
}

/**
 * 吸乳会话结束小结：连接 `/v1/pump/session-summary`，发送结束快照，返回完整 JSON 响应。
 * @param body 文档定义的吸乳结束数据
 * @returns 后端响应，含 `data.chat_message.content`
 */
export function postPumpSessionSummaryWebSocket(
  body: PumpSessionSummaryBody,
  opts?: { timeoutMs?: number; token?: string; skipAuth?: boolean },
): Promise<PumpSessionSummaryResponse> {
  const resolved = resolveHttpRequestUrl(API_PATHS.PUMP_SESSION_SUMMARY_WS);
  let wsUrl = enforceSecureWebSocketInSecureContext(httpLikeUrlToWebSocketUrl(resolved));
  const fallbackToken =
    (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_TOKEN as string | undefined)?.trim()) || "";
  const authToken = opts?.token ?? fallbackToken;
  if (authToken && !opts?.skipAuth) {
    wsUrl = appendQueryParams(wsUrl, { token: authToken });
  }
  const wsLogUrl = redactWebSocketUrl(wsUrl);
  const timeoutMs = Math.max(1000, opts?.timeoutMs ?? 12000);

  return new Promise<PumpSessionSummaryResponse>((resolve, reject) => {
    let settled = false;
    let ws: WebSocket | undefined;
    const timer = window.setTimeout(() => {
      settle(() => reject(new Error(`pump session summary websocket timeout url=${wsLogUrl}`)));
    }, timeoutMs);

    const settle = (fn: () => void) => {
      if (settled) return;
      settled = true;
      window.clearTimeout(timer);
      try {
        ws?.close();
      } catch {
        /* ignore */
      }
      fn();
    };

    try {
      ws = new WebSocket(wsUrl);
      log("[PUMP_SESSION_SUMMARY][WS] connect", { url: wsLogUrl, hasToken: Boolean(authToken && !opts?.skipAuth) });
    } catch (e) {
      reject(e instanceof Error ? e : new Error(String(e)));
      return;
    }

    ws.onopen = () => {
      try {
        log("[PUMP_SESSION_SUMMARY][WS] send", {
          url: wsLogUrl,
          user_id: body.user_id,
          conversation_id: body.conversation_id,
          event_id: body.event_id,
          end_reason: body.end_reason,
        });
        ws.send(JSON.stringify(body));
      } catch (e) {
        settle(() => reject(e instanceof Error ? e : new Error(String(e))));
      }
    };

    ws.onmessage = (ev: MessageEvent) => {
      if (typeof ev.data !== "string") return;
      try {
        const parsed = parseWebSocketJsonFrame(ev.data);
        if (!parsed || typeof parsed !== "object") return;
        settle(() => resolve(parsed as PumpSessionSummaryResponse));
      } catch (e) {
        settle(() => reject(e instanceof Error ? e : new Error(String(e))));
      }
    };

    ws.onerror = () => {
      settle(() => reject(new Error(`pump session summary websocket connection error url=${wsLogUrl}`)));
    };

    ws.onclose = (ev: CloseEvent) => {
      if (settled) return;
      const reason = ev.reason?.trim() ? ` reason=${ev.reason.trim()}` : "";
      settle(() => reject(new Error(`pump session summary websocket closed unexpectedly: code=${ev.code}${reason}`)));
    };
  });
}

/**
 * 打断当前对话任务（API V1.2）。
 * @param conversationId 路径参数，与对话建立接口返回的 conversation_id 一致
 * @param body 仅 `{ user_id }`
 */
export async function stopWorkflowTask(
  conversationId: string,
  body: WorkflowStopBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<WorkflowStopData> {
  const id = String(conversationId ?? "").trim();
  if (!id) {
    return Promise.reject(new Error("stopWorkflowTask: conversation_id 不能为空"));
  }
  return apiRequest<WorkflowStopData>(workflowsTasksStopPath(id), {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 拉取历史对话（GET + query）。
 * @param params user_id、conversation_id、count
 */
export async function getChatMessageHistory(
  params: ChatHistoryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<ChatHistoryData> {
  return apiRequest<ChatHistoryData>(API_PATHS.CHAT_MESSAGE_HISTORY, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

// ─── 吸乳 ────────────────────────────────────────────────────────────

/**
 * 上报耐受度滴定阈值。
 */
export async function uploadPumpThreshold(
  body: PumpThresholdUploadBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpThresholdData> {
  return apiRequest<PumpThresholdData>(API_PATHS.PUMP_THRESHOLD_UPLOAD, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 查询耐受度滴定阈值。
 * @param user_id 用户 id
 */
export async function getPumpThreshold(
  user_id: string,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpThresholdData> {
  return apiRequest<PumpThresholdData>(API_PATHS.PUMP_THRESHOLD_GET, {
    method: "GET",
    params: { user_id },
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 上报设备工作状态。
 */
export async function uploadPumpWorkstate(
  body: PumpWorkstateBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<UploadPumpWorkstateResponse> {
  log("[uploadPumpWorkstate] request", body);
  const response = await apiRequest<UploadPumpWorkstateResponse>(API_PATHS.PUMP_WORKSTATE, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
  log("[uploadPumpWorkstate] response", response);
  return response;
}

/**
 * 上报吸乳进程数据。
 */
export async function uploadPumpProcess(
  body: PumpProcessBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<UploadPumpProcessResponseData> {
  log("[uploadPumpProcess] request", body);
  const response = await apiRequest<UploadPumpProcessResponseData>(API_PATHS.PUMP_PROCESS, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
  log("[uploadPumpProcess] response", response);
  return response;
}

/**
 * 获取设备吸乳进程。
 */
export async function getPumpProcessData(
  body: PumpProcessDataBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpProcessDataResponseData> {
  log("[getPumpProcessData] request", body);
  const response = await apiRequest<PumpProcessDataResponseData>(API_PATHS.PUMP_PROCESS_DATA, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
  log("[getPumpProcessData] response", response);
  return response;
}

// ─── 计划 ───────────────────────────────────────────────────────────

/**
 * 查询某一天的呵护计划任务（GET `/v1/plan/query-task` + query `user_id`、`timestamp`）。
 */
export async function queryCarePlan(
  params: PlanQueryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanQueryData> {
  return apiRequest<PlanQueryData>(API_PATHS.PLAN_QUERY_TASK, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 查询某一天的呵护计划任务。
 */
export async function queryPlanTasks(
  params: PlanQueryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanQueryData> {
  return queryCarePlan(params, opts);
}

/**
 * 增加呵护计划临时任务。
 */
export async function addPlanTasks(
  body: AddPlanTaskBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanTaskMutationData> {
  return apiRequest<PlanTaskMutationData>(API_PATHS.PLAN_ADD_TASK, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 删除呵护计划任务。
 */
export async function deletePlanTask(
  body: DeletePlanTaskBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanTaskMutationData> {
  return apiRequest<PlanTaskMutationData>(API_PATHS.PLAN_DELETE_TASK, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 修改呵护计划临时任务。
 */
export async function revisePlanTask(
  body: RevisePlanTaskBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanTaskMutationData> {
  return apiRequest<PlanTaskMutationData>(API_PATHS.PLAN_REVISE_TASK, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * V1.3 文档已移除泌乳周期接口，保留函数名供旧调用方编译；运行时明确报错，避免误打已废弃端点。
 */
export async function getPlanMilkPeriod(
  _params: PlanMilkPeriodParams,
  _opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanMilkPeriodData> {
  return Promise.reject(new Error("getPlanMilkPeriod: /v1/plan/milk_period is not available in API V1.3"));
}

/**
 * 查询当日呵护计划任务。V1.3 使用 `/v1/plan/query-task`，调用方需传 `timestamp`。
 */
export async function getPlanPumpToday(
  params: PlanPumpTodayParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanQueryData> {
  return apiRequest<PlanQueryData>(API_PATHS.PLAN_QUERY_TASK, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 增加呵护计划临时任务。
 */
export async function addPlanPumpAvoidPeriod(
  body: AddPlanTaskBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanTaskMutationData> {
  return addPlanTasks(body, opts);
}

/**
 * 删除呵护计划任务。
 */
export async function deletePlanPumpAvoidPeriod(
  body: DeletePlanTaskBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PlanTaskMutationData> {
  return deletePlanTask(body, opts);
}

// ─── 设备 ───────────────────────────────────────────────────────────

/**
 * 上报设备连接信息。
 */
export async function uploadDeviceInfo(
  body: DeviceInfoBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<DeviceInfoData> {
  return apiRequest<DeviceInfoData>(API_PATHS.DEVICE_INFO, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

// ─── 系统级后台任务 ─────────────────────────────────────────────────

/**
 * 查询推送消息。
 */
export async function queryNotify(
  params: NotifyQueryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<NotifyQueryData> {
  return apiRequest<NotifyQueryData>(API_PATHS.NOTIFY_QUERY, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 触发泌乳和喂养数据分析。
 */
export async function createStatusAnalysis(
  body: StatusCreateBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<StatusCreateData> {
  return apiRequest<StatusCreateData>(API_PATHS.STATUS_CREATE, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

/**
 * 执行每日奶量总结或每日泌乳建议（POST `/v1/analysis/create`）。
 */
export async function createDailyAndMomBabyAnalysis(
  body: AnalysisCreateBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<AnalysisCreateData> {
  const raw = await apiRequestRaw<{
    status?: number;
    message?: string;
    data?: {
      error?: number;
      result?: boolean;
      message?: string;
      analysis_card?: AnalysisCreateData["analysis_card"];
    };
    error?: number;
    result?: boolean;
  }>(API_PATHS.ANALYSIS_CREATE, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });

  if (typeof raw?.status === "number" && raw.status !== 200) {
    throw new Error((raw.message ?? "").trim() || "分析请求失败");
  }

  const data = raw?.data;
  const message =
    (typeof data?.message === "string" && data.message.trim()) ||
    (typeof raw?.message === "string" && raw.message.trim()) ||
    "";

  const error =
    typeof data?.error === "number"
      ? data.error
      : typeof raw?.error === "number"
        ? raw.error
        : 0;

  const result =
    typeof data?.result === "boolean"
      ? data.result
      : typeof raw?.result === "boolean"
        ? raw.result
        : undefined;

  if (error !== 0) {
    throw new Error(message || "分析请求失败");
  }

  return { error: error as AnalysisCreateData["error"], result, message, analysis_card: data?.analysis_card };
}
