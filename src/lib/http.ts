import { Capacitor, CapacitorHttp } from "@capacitor/core";
import type { HttpParams } from "@capacitor/core";
import { capacitorHttpInterceptorResourceSrc } from "@/lib/capacitorHttpInterceptorUrl";
import { resolveFetchUrlForAbsoluteHttp } from "@/lib/mediaUrlResolve";
import { log, warn, stringifyLogArg } from "@/lib/logger";

/**
 * HTTP 请求模块：普通请求 + 流式回复（分块 chunked / SSE）
 * 原生环境使用 CapacitorHttp 绕过 WebView 同源与混合内容限制；Web 使用 fetch。
 * SSE（`streamSSE`）在原生端依赖 `capacitor.config` 中 `CapacitorHttp.enabled: true`，使 `fetch` 走原生网络并保留 ReadableStream。
 * 支持 VITE_API_BASE_URL、VITE_API_TOKEN 配置。
 */

const BASE_URL = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE_URL) || "";

/** 开发/构建时注入的 Bearer Token，勿将真实密钥提交到仓库 */
const DEFAULT_API_TOKEN =
  (typeof import.meta !== "undefined" && (import.meta.env?.VITE_API_TOKEN as string | undefined)) || "";

function isNative(): boolean {
  try {
    return Capacitor.isNativePlatform();
  } catch {
    return false;
  }
}

/** 将相对 API 路径或绝对 URL 解析为请求用完整地址（Web / 原生与 `VITE_API_BASE_URL` 一致）；供 SSE、WebSocket 等复用。 */
export function resolveHttpRequestUrl(url: string): string {
  return resolveUrl(url);
}

function resolveUrl(url: string): string {
  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  // 原生环境无 Vite 代理，必须使用完整 URL
  if (isNative()) {
    if (!BASE_URL) return url;
    const base = BASE_URL.replace(/\/$/, "");
    const path = url.startsWith("/") ? url : `/${url}`;
    return `${base}${path}`;
  }
  // Web 开发环境下，根路径请求交给 Vite proxy，避免浏览器直连后端触发 CORS
  if (typeof import.meta !== "undefined" && import.meta.env?.DEV && url.startsWith("/")) return url;
  if (!BASE_URL) return url;
  const base = BASE_URL.replace(/\/$/, "");
  const path = url.startsWith("/") ? url : `/${url}`;
  return `${base}${path}`;
}

/** 查询参数：值会转为字符串并做 URL 编码（undefined/null 省略） */
export type HttpQueryParams = Record<string, string | number | boolean | undefined | null>;

/**
 * 将查询参数拼接到 URL（Web 与通用逻辑）。
 * @param url 原始 URL（可含已有 query）
 * @param params 查询键值
 * @returns 拼接后的完整 URL 字符串
 */
export function appendQueryParams(url: string, params?: HttpQueryParams): string {
  if (!params) return url;
  const u = new URL(url, "http://_");
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null) continue;
    u.searchParams.set(k, String(v));
  }
  const path = u.pathname + u.search + u.hash;
  if (
    url.startsWith("http://") ||
    url.startsWith("https://") ||
    url.startsWith("ws://") ||
    url.startsWith("wss://")
  ) {
    const origin = new URL(url).origin;
    return origin + path;
  }
  return path.startsWith("/") ? path : `/${path}`;
}

/**
 * 转为 Capacitor HttpParams（仅字符串值）。
 * @param params 业务查询参数
 */
export function toCapacitorParams(params?: HttpQueryParams): HttpParams | undefined {
  if (!params) return undefined;
  const out: HttpParams = {};
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null) continue;
    out[k] = String(v);
  }
  return Object.keys(out).length ? out : undefined;
}

// ─── 联调：打印 API 请求 / 响应（url、params、body、status、data）────────

/**
 * 是否打印 HTTP 请求的发出与对应的响应概要（不含 SSE 整条流）。
 * `VITE_DEBUG_API_REQUEST=true` 时生产构建也会打印；`false` 强制关闭。
 * 未设置时：Web 仅开发模式；**Capacitor 原生（Android/iOS）默认开启**，便于在 Logcat/Xcode 中联调（无需再配 DEV）。
 */
function shouldLogHttpApiRequestPayload(): boolean {
  try {
    if (typeof import.meta === "undefined") return false;
    const raw = (import.meta.env?.VITE_DEBUG_API_REQUEST as string | undefined)?.trim().toLowerCase();
    if (raw === "false" || raw === "0" || raw === "off") return false;
    if (raw === "true" || raw === "1" || raw === "on") return true;
    if (isNative()) return true;
    return Boolean(import.meta.env?.DEV);
  } catch {
    return false;
  }
}

/**
 * HTTP 联调日志：原生走 `console.warn`（不经 {@link log} 的 VITE_LOG_LEVEL 过滤），便于 Android Logcat / 系统日志查看；Web 仍用 `log` 保留 DevTools 对象展开。
 */
function emitHttpPayloadDebug(label: string, line: Record<string, unknown>): void {
  if (isNative()) {
    globalThis.console?.warn?.(`[HTTP] ${label}`, stringifyLogArg(line));
  } else {
    log(`[HTTP] ${label}`, line);
  }
}

const HTTP_DEBUG_RESPONSE_PREVIEW_MAX = 16000;

function truncateHttpDebugString(s: string, max = HTTP_DEBUG_RESPONSE_PREVIEW_MAX): string {
  if (s.length <= max) return s;
  return `${s.slice(0, max)}…(共${s.length}字符)`;
}

/** 响应体快照：超长 JSON 转字符串截断；二进制/Blob 只记元信息（与请求的 body 快照策略一致）。 */
function snapshotResponsePayloadForHttpDebug(data: unknown): unknown {
  if (data == null) return undefined;
  if (typeof data === "string") return truncateHttpDebugString(data);
  if (typeof Blob !== "undefined" && data instanceof Blob) return { _type: "Blob", size: data.size, type: data.type };
  if (data instanceof ArrayBuffer) return { _type: "ArrayBuffer", byteLength: data.byteLength };
  if (ArrayBuffer.isView(data)) return { _type: "ArrayBufferView", byteLength: data.byteLength };
  if (typeof data === "object") {
    try {
      return truncateHttpDebugString(JSON.stringify(data));
    } catch {
      return "[response: unserializable]";
    }
  }
  return data;
}

/** 同步 JSON/API 请求的响应：`[HTTP] API 响应`，与 {@link logHttpApiRequestPayload} 相同门控与输出通道。 */
function logHttpApiResponseDebug(input: {
  method: string;
  url: string;
  params?: HttpQueryParams;
  status: number;
  ok: boolean;
  data?: unknown;
}): void {
  if (!shouldLogHttpApiRequestPayload()) return;
  const effective = appendQueryParams(input.url, input.params);
  const line: Record<string, unknown> = {
    method: String(input.method || "GET").toUpperCase(),
    url: input.url,
    status: input.status,
    ok: input.ok,
  };
  const paramSnap = snapshotParamsForLog(input.params);
  if (paramSnap) line.params = paramSnap;
  if (effective !== input.url) line.effectiveUrl = effective;
  if (input.data !== undefined) line.data = snapshotResponsePayloadForHttpDebug(input.data);
  emitHttpPayloadDebug("API 响应", line);
}

/**
 * 将查询参数转为平铺字符串表，便于与后端约定对照。
 * @param params 与 {@link request} 相同的查询对象
 * @returns 非空键值；无查询参数时返回 undefined
 */
function snapshotParamsForLog(params?: HttpQueryParams): Record<string, string> | undefined {
  const cap = toCapacitorParams(params);
  if (!cap || Object.keys(cap).length === 0) return undefined;
  return { ...cap };
}

/**
 * 将请求体转为可打印结构（FormData / 二进制用占位说明）。
 * @param body {@link RequestInitExt} 中的 body
 * @returns 日志用值
 */
function serializeBodyForHttpDebugLog(body: RequestInitExt["body"]): unknown {
  if (body == null) return undefined;
  if (typeof body === "string") {
    const max = 16000;
    return body.length > max ? `${body.slice(0, max)}…(共${body.length}字符)` : body;
  }
  if (body instanceof FormData) {
    const keys: string[] = [];
    body.forEach((_v, k) => {
      if (!keys.includes(k)) keys.push(k);
    });
    return { _type: "FormData", keys };
  }
  if (body instanceof ArrayBuffer) return { _type: "ArrayBuffer", byteLength: body.byteLength };
  if (ArrayBuffer.isView(body)) {
    const v = body as ArrayBufferView;
    return { _type: "ArrayBufferView", byteLength: v.byteLength };
  }
  if (typeof body === "object") return body;
  return String(body);
}

/**
 * 输出单次 HTTP 请求的 method、url、params（GET 等）、body（POST 等）；含 query 时附加 effectiveUrl。
 * @param input.method HTTP 方法
 * @param input.url 已 resolve、不含业务 query 的 URL
 * @param input.params 查询参数对象（会出现在日志的 `params` 字段）
 * @param input.body 已序列化或对象形式的请求体（非 GET 时出现在 `body` 字段）
 */
function logHttpApiRequestPayload(input: {
  method: string;
  url: string;
  params?: HttpQueryParams;
  body?: unknown;
}): void {
  if (!shouldLogHttpApiRequestPayload()) return;
  const method = String(input.method || "GET").toUpperCase();
  const paramSnap = snapshotParamsForLog(input.params);
  const line: Record<string, unknown> = { method, url: input.url };
  if (paramSnap) line.params = paramSnap;
  if (method !== "GET" && input.body !== undefined) line.body = input.body;
  const effective = appendQueryParams(input.url, input.params);
  if (effective !== input.url) line.effectiveUrl = effective;
  emitHttpPayloadDebug("API 请求", line);
}

/**
 * POST `.../workflows/tasks/{conversation_id}/stop`（打断对话）。
 * 不经 {@link shouldLogHttpApiRequestPayload} 门控；原生侧同样走 `console.warn` 以便 Logcat 可见。
 */
function warnWorkflowConversationStopRequest(method: string, resolvedBaseUrl: string, params: HttpQueryParams | undefined, body: unknown): void {
  if (String(method || "GET").toUpperCase() !== "POST") return;
  const effective = appendQueryParams(resolvedBaseUrl, params);
  let pathname = "";
  try {
    pathname = effective.includes("://") ? new URL(effective).pathname : new URL(effective, "http://_").pathname;
  } catch {
    return;
  }
  const stopMatch = /\/workflows\/tasks\/([^/]+)\/stop(?:\/)?$/i.exec(pathname);
  if (!stopMatch) return;
  let conversationId = stopMatch[1];
  try {
    conversationId = decodeURIComponent(conversationId);
  } catch {
    /* keep encoded segment */
  }
  const snap = snapshotParamsForLog(params);
  const line: Record<string, unknown> = {
    url: resolvedBaseUrl,
    conversation_id: conversationId,
    body,
  };
  if (snap) line.params = snap;
  if (effective !== resolvedBaseUrl) line.effectiveUrl = effective;
  if (isNative()) {
    globalThis.console?.warn?.("[HTTP] 打断对话请求", stringifyLogArg(line));
  } else {
    warn("[HTTP] 打断对话请求", line);
  }
}

// ─── 基础请求 ───────────────────────────────────────────────────────

export interface RequestInitExt extends Omit<RequestInit, "body"> {
  body?: BodyInit | object;
  /** GET 等请求的 URL 查询参数（Web 会拼接到 URL；原生传给 CapacitorHttp.params） */
  params?: HttpQueryParams;
}

/**
 * 封装 HTTP 请求：原生用 CapacitorHttp，Web 用 fetch。
 * 支持 base URL、JSON 请求体、查询参数与响应解析。
 */
export async function request<T = unknown>(url: string, options?: RequestInitExt): Promise<T> {
  const params = options?.params;
  const resolvedBase = resolveUrl(url);
  const method = (options?.method as string) || "GET";
  const headers: Record<string, string> = { ...(options?.headers as Record<string, string>) };

  const upperMethod = String(method).toUpperCase();
  const bodyForPayloadLog =
    options?.body != null && upperMethod !== "GET" ? serializeBodyForHttpDebugLog(options.body) : undefined;
  warnWorkflowConversationStopRequest(method, resolvedBase, params, bodyForPayloadLog);
  logHttpApiRequestPayload({
    method,
    url: resolvedBase,
    params,
    body: bodyForPayloadLog,
  });

  if (isNative()) {
    const capOptions: {
      url: string;
      method: string;
      headers: Record<string, string>;
      data?: object | string;
      params?: HttpParams;
      responseType?: "arraybuffer" | "blob" | "json" | "text" | "document";
      dataType?: "file" | "formData";
    } = {
      url: resolvedBase,
      method,
      headers,
    };
    const capParams = toCapacitorParams(params);
    if (capParams) capOptions.params = capParams;
    if (options?.body != null && method !== "GET") {
      if (typeof options.body === "object" && !(options.body instanceof FormData) && !(options.body instanceof ArrayBuffer) && !ArrayBuffer.isView(options.body)) {
        capOptions.data = options.body as object;
        if (!headers["Content-Type"]) capOptions.headers["Content-Type"] = "application/json";
      } else if (typeof options.body === "string") {
        capOptions.data = options.body;
      }
    }
    const res = await CapacitorHttp.request(capOptions);
    if (res.status < 200 || res.status >= 300) {
      logHttpApiResponseDebug({
        method,
        url: resolvedBase,
        params,
        status: res.status,
        ok: false,
        data: res.data,
      });
      const text = typeof res.data === "string" ? res.data : (res.data ? JSON.stringify(res.data) : "");
      throw new Error(`HTTP ${res.status}: ${text || "Request failed"}`);
    }
    logHttpApiResponseDebug({
      method,
      url: resolvedBase,
      params,
      status: res.status,
      ok: true,
      data: res.data,
    });
    return res.data as T;
  }

  const resolved = appendQueryParams(resolvedBase, params);
  const headersMap = (options?.headers ?? {}) as Record<string, string>;
  let body: BodyInit | undefined;
  if (options?.body != null && typeof options.body === "object" && !(options.body instanceof FormData) && !(options.body instanceof ArrayBuffer) && !ArrayBuffer.isView(options.body)) {
    body = JSON.stringify(options.body);
    if (!headersMap["Content-Type"]) headersMap["Content-Type"] = "application/json";
  } else if (options?.body !== undefined) {
    body = options.body as BodyInit;
  }
  const init: RequestInit = {
    method: options?.method,
    headers: headersMap,
    signal: options?.signal,
    body,
  };

  const res = await fetch(resolved, init);
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    logHttpApiResponseDebug({
      method,
      url: resolvedBase,
      params,
      status: res.status,
      ok: false,
      data: text,
    });
    throw new Error(`HTTP ${res.status}: ${text || res.statusText}`);
  }
  const contentType = res.headers.get("Content-Type") || "";
  if (contentType.includes("application/json")) {
    const payload = (await res.json()) as T;
    logHttpApiResponseDebug({
      method,
      url: resolvedBase,
      params,
      status: res.status,
      ok: true,
      data: payload,
    });
    return payload;
  }
  const textBody = await res.text();
  logHttpApiResponseDebug({
    method,
    url: resolvedBase,
    params,
    status: res.status,
    ok: true,
    data: textBody,
  });
  return textBody as T;
}

/**
 * 将 CapacitorHttp 返回的 data 转为 ArrayBuffer（原生常见为 base64 字符串）。
 * @param data 插件返回体
 * @returns 二进制缓冲
 */
function capacitorHttpDataToArrayBuffer(data: unknown): ArrayBuffer {
  if (data instanceof ArrayBuffer) return data;
  if (typeof data === "string") {
    const bin = atob(data);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
  }
  if (data != null && typeof data === "object" && "buffer" in data && "byteLength" in data) {
    const view = data as ArrayBufferView;
    return view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength);
  }
  throw new Error("无法解析二进制 HTTP 响应");
}

/** 二进制 GET 选项（与 JSON `request` 类似，不含 body） */
export interface RequestBinaryOptions {
  params?: HttpQueryParams;
  headers?: Record<string, string>;
  /** 覆盖默认 VITE_API_TOKEN */
  token?: string;
  /** 为 true 时不附加 Authorization */
  skipAuth?: boolean;
  signal?: AbortSignal;
  /**
   * 下载进度：Web 端在存在 Content-Length 时 total 为字节总数；无 Content-Length 或原生端 total 为 null（仅 loaded 增长，收尾时 total 可能等于 loaded）。
   * @param loaded 已接收字节数
   * @param total 总字节数，未知时为 null
   */
  onProgress?: (loaded: number, total: number | null) => void;
}

/**
 * 使用 XMLHttpRequest 拉取二进制并上报进度。
 * WebView/Capacitor 下 `fetch`+ReadableStream 常无 body 或整包缓冲，导致 onProgress 一直为 0；XHR 的 `onprogress` 能拿到 Content-Length 与已收字节。
 * @param requestUrl 最终请求 URL（原生 HTTP 资源应先转为 `_capacitor_http_interceptor_` 同源地址）
 * @param headers 请求头
 * @param signal 可选中止信号
 * @param onProgress 进度回调
 * @returns ArrayBuffer
 */
function requestBinaryViaXhr(
  requestUrl: string,
  headers: Record<string, string>,
  signal: AbortSignal | undefined,
  onProgress: (loaded: number, total: number | null) => void,
): Promise<ArrayBuffer> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", requestUrl);
    for (const [key, val] of Object.entries(headers)) {
      if (val !== undefined && val !== "") xhr.setRequestHeader(key, val);
    }
    xhr.responseType = "arraybuffer";

    const onAbort = () => xhr.abort();
    if (signal) {
      if (signal.aborted) {
        reject(new DOMException("Aborted", "AbortError"));
        return;
      }
      signal.addEventListener("abort", onAbort, { once: true });
    }

    xhr.onprogress = (e) => {
      if (e.lengthComputable && e.total > 0) {
        onProgress(e.loaded, e.total);
      } else {
        onProgress(e.loaded, null);
      }
    };

    xhr.onload = () => {
      if (signal) signal.removeEventListener("abort", onAbort);
      if (xhr.status < 200 || xhr.status >= 300) {
        reject(new Error(`HTTP ${xhr.status}: ${xhr.statusText || "Request failed"}`));
        return;
      }
      const buf = xhr.response as ArrayBuffer;
      if (!buf || buf.byteLength === 0) {
        reject(new Error("空响应"));
        return;
      }
      onProgress(buf.byteLength, buf.byteLength);
      resolve(buf);
    };

    xhr.onerror = () => {
      if (signal) signal.removeEventListener("abort", onAbort);
      reject(new Error("网络错误"));
    };

    xhr.onabort = () => {
      if (signal) signal.removeEventListener("abort", onAbort);
      reject(new DOMException("Aborted", "AbortError"));
    };

    onProgress(0, null);
    xhr.send();
  });
}

/**
 * GET 二进制资源：原生走 CapacitorHttp `arraybuffer`，Web 走 fetch。
 * 与 `resolveUrl`、BASE_URL、Bearer 策略与 `apiRequest` 对齐。
 * @param url 相对或绝对 URL
 * @param options 查询参数、头、鉴权
 * @returns 响应体 ArrayBuffer
 */
export async function requestBinary(url: string, options?: RequestBinaryOptions): Promise<ArrayBuffer> {
  const token = options?.token ?? DEFAULT_API_TOKEN;
  const headers: Record<string, string> = { ...(options?.headers as Record<string, string>) };
  if (token && !options?.skipAuth) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  const params = options?.params;
  const resolvedBase = resolveUrl(url);
  const onProgress = options?.onProgress;

  logHttpApiRequestPayload({ method: "GET", url: resolvedBase, params });

  let requestUrl = appendQueryParams(resolvedBase, params);

  /** 需要进度时统一走 XHR（避免 fetch 在 WebView/代理下 body 不可用或整包缓冲导致进度恒为 0） */
  if (onProgress) {
    if (isNative() && /^http:\/\//i.test(requestUrl)) {
      requestUrl = capacitorHttpInterceptorResourceSrc(requestUrl);
    } else if (
      typeof window !== "undefined" &&
      window.location.protocol === "https:" &&
      /^http:\/\//i.test(requestUrl)
    ) {
      requestUrl = resolveFetchUrlForAbsoluteHttp(requestUrl);
    }
    return requestBinaryViaXhr(requestUrl, headers, options?.signal, onProgress);
  }

  if (isNative()) {
    const capOptions: {
      url: string;
      method: string;
      headers: Record<string, string>;
      params?: HttpParams;
      responseType: "arraybuffer";
    } = {
      url: resolvedBase,
      method: "GET",
      headers,
      responseType: "arraybuffer",
    };
    const capParams = toCapacitorParams(params);
    if (capParams) capOptions.params = capParams;
    const res = await CapacitorHttp.request(capOptions);
    if (res.status < 200 || res.status >= 300) {
      logHttpApiResponseDebug({
        method: "GET",
        url: resolvedBase,
        params,
        status: res.status,
        ok: false,
        data: res.data,
      });
      const text = typeof res.data === "string" ? res.data : (res.data ? JSON.stringify(res.data) : "");
      throw new Error(`HTTP ${res.status}: ${text || "Request failed"}`);
    }
    const ab = capacitorHttpDataToArrayBuffer(res.data);
    logHttpApiResponseDebug({
      method: "GET",
      url: resolvedBase,
      params,
      status: res.status,
      ok: true,
      data: ab,
    });
    return ab;
  }

  let fetchUrl = requestUrl;
  if (
    typeof window !== "undefined" &&
    window.location.protocol === "https:" &&
    /^http:\/\//i.test(fetchUrl)
  ) {
    fetchUrl = resolveFetchUrlForAbsoluteHttp(fetchUrl);
  }
  const res = await fetch(fetchUrl, {
    method: "GET",
    headers,
    signal: options?.signal,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    logHttpApiResponseDebug({
      method: "GET",
      url: resolvedBase,
      params,
      status: res.status,
      ok: false,
      data: text,
    });
    throw new Error(`HTTP ${res.status}: ${text || res.statusText}`);
  }
  const ab = await res.arrayBuffer();
  logHttpApiResponseDebug({
    method: "GET",
    url: resolvedBase,
    params,
    status: res.status,
    ok: true,
    data: ab,
  });
  return ab;
}

// ─── 业务信封与 apiRequest ─────────────────────────────────────────

/** 文档约定的同步 JSON 信封 */
export interface ApiEnvelope<T = unknown> {
  status: number;
  message: string;
  data: T;
}

/** 业务层错误：HTTP 已成功但 status 字段非 200 */
export class ApiError extends Error {
  constructor(
    /** 响应体中的业务 status */
    public readonly apiStatus: number,
    message: string,
    /** 原始解析前的对象，便于调试 */
    public readonly raw?: unknown,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/** 将接口响应序列化为单行 JSON，便于 Logcat / 控制台排查（避免循环引用时降级） */
function jsonStringifyForLog(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    try {
      return String(value);
    } catch {
      return "[unstringifiable]";
    }
  }
}

/**
 * 解析同步接口 JSON：若存在标准信封且 status !== 200 则抛 ApiError，否则返回 data。
 * **注意**：部分接口响应**不含**文档「响应规范-同步响应」的 `status`/`message`/`data` 信封，应使用 {@link apiRequestRaw} 或 `uploadMultipart({ unwrapEnvelope: false })`，勿依赖本函数从信封中取 `data`。
 * @param raw request() 解析后的对象
 */
export function unwrapApiData<T>(raw: unknown): T {
  if (raw && typeof raw === "object" && "status" in raw && "data" in raw) {
    const o = raw as ApiEnvelope<unknown>;
    if (typeof o.status === "number" && o.status !== 200) {
      console.error(
        "[ApiEnvelope] 业务 status !== 200，完整响应 JSON:",
        jsonStringifyForLog(raw),
      );
      throw new ApiError(o.status, String(o.message ?? "请求失败"), raw);
    }
    return o.data as T;
  }
  return raw as T;
}

export interface ApiRequestOptions extends RequestInitExt {
  /** 覆盖默认的 VITE_API_TOKEN */
  token?: string;
  /** 为 true 时不添加 Authorization */
  skipAuth?: boolean;
}

/**
 * 带 Bearer 鉴权与业务信封解析的请求（保持 request() 不变供非标准响应使用）。
 * @param url 相对或绝对路径
 * @param options 含 params / body / token 等
 * @returns 解包后的 data 字段类型
 */
export async function apiRequest<T = unknown>(url: string, options?: ApiRequestOptions): Promise<T> {
  const token = options?.token ?? DEFAULT_API_TOKEN;
  const headers: Record<string, string> = { ...(options?.headers as Record<string, string>) };
  if (token && !options?.skipAuth) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  const { token: _t, skipAuth: _s, ...rest } = options ?? {};
  const raw = await request<unknown>(url, { ...rest, headers });
  return unwrapApiData<T>(raw);
}

/**
 * 与 {@link apiRequest} 相同鉴权与 JSON 请求，但**不**经 {@link unwrapApiData} 解包。
 * 用于响应体直接为业务字段、**无**文档「同步响应」信封的接口。
 * @param url 相对或绝对路径
 * @param options 与 apiRequest 一致
 * @returns 解析后的 JSON 根对象
 */
export async function apiRequestRaw<T = unknown>(url: string, options?: ApiRequestOptions): Promise<T> {
  const token = options?.token ?? DEFAULT_API_TOKEN;
  const headers: Record<string, string> = { ...(options?.headers as Record<string, string>) };
  if (token && !options?.skipAuth) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  const { token: _t, skipAuth: _s, ...rest } = options ?? {};
  const raw = await request<unknown>(url, { ...rest, headers });
  return raw as T;
}

// ─── multipart 上传（Web FormData / 原生 formData 数组）──────────────

/** 原生 Capacitor 多段表单条目（与 Android CapacitorHttpUrlConnection 一致） */
export type NativeFormDataEntry =
  | { type: "string"; key: string; value: string }
  | { type: "base64File"; key: string; value: string; fileName: string; contentType: string };

export interface UploadMultipartOptions {
  url: string;
  userId: string;
  file: Blob | File;
  /** 表单中文件字段名，默认 file */
  fileFieldName?: string;
  extraFields?: Record<string, string>;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  token?: string;
  skipAuth?: boolean;
  /**
   * 为 `false` 时不解析「同步响应」信封（`status`/`message`/`data`），直接以 JSON 根对象为 `T`。
   * 无标准信封的上传类接口使用；默认 `true` 与历史行为一致。
   */
  unwrapEnvelope?: boolean;
}

/**
 * 生成 multipart boundary（不含前缀 --）。
 */
export function generateMultipartBoundary(): string {
  return `capboundary${Date.now()}${Math.random().toString(36).slice(2, 9)}`;
}

/**
 * 根据 user_id、文件与其它字段构造原生 formData 条目数组（供测试与原生上传复用）。
 * @param userId 用户 id
 * @param fileBase64 文件内容的 Base64（无 data: 前缀）
 * @param fileName 文件名
 * @param contentType 文件 MIME
 * @param fileFieldName 文件字段名
 * @param extraFields 额外字符串字段
 */
/**
 * Blob/File 转 Base64（无 data: 前缀），供原生 multipart 使用。
 * @param blob 二进制内容
 */
export function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => {
      const s = r.result as string;
      const i = s.indexOf(",");
      resolve(i >= 0 ? s.slice(i + 1) : s);
    };
    r.onerror = () => reject(r.error ?? new Error("read blob failed"));
    r.readAsDataURL(blob);
  });
}

export function buildNativeMultipartEntries(
  userId: string,
  fileBase64: string,
  fileName: string,
  contentType: string,
  fileFieldName: string,
  extraFields?: Record<string, string>,
): NativeFormDataEntry[] {
  const entries: NativeFormDataEntry[] = [{ type: "string", key: "user_id", value: userId }];
  if (extraFields) {
    for (const [k, v] of Object.entries(extraFields)) {
      entries.push({ type: "string", key: k, value: v });
    }
  }
  entries.push({
    type: "base64File",
    key: fileFieldName,
    value: fileBase64,
    fileName,
    contentType,
  });
  return entries;
}

/**
 * POST multipart/form-data：Web 使用 FormData；原生使用 dataType formData + boundary。
 * @param options 上传参数；`unwrapEnvelope: false` 时响应无标准信封
 * @returns 默认解析信封后的 `data`；`unwrapEnvelope: false` 时为 JSON 根对象
 */
export async function uploadMultipart<T = unknown>(options: UploadMultipartOptions): Promise<T> {
  const {
    url,
    userId,
    file,
    fileFieldName = "file",
    extraFields,
    headers: optHeaders,
    signal,
    token = DEFAULT_API_TOKEN,
    skipAuth,
    unwrapEnvelope = true,
  } = options;

  const authHeaders: Record<string, string> = { ...optHeaders };
  if (token && !skipAuth) authHeaders["Authorization"] = `Bearer ${token}`;

  const resolved = resolveUrl(url);
  const fileName = file instanceof File ? file.name : "upload.bin";
  const contentType = file instanceof File && file.type ? file.type : "application/octet-stream";

  if (shouldLogHttpApiRequestPayload()) {
    emitHttpPayloadDebug("API 请求", {
      method: "POST",
      url: resolved,
      body: {
        _type: "multipart/form-data",
        user_id: userId,
        fileFieldName,
        fileName,
        contentType,
        extraFields: extraFields ? { ...extraFields } : undefined,
      },
    });
  }

  if (isNative()) {
    const boundary = generateMultipartBoundary();
    const contentTypeHeader = `multipart/form-data; boundary=${boundary}`;
    const base64 = await blobToBase64(file);
    const data = buildNativeMultipartEntries(userId, base64, fileName, contentType, fileFieldName, extraFields);
    const res = await CapacitorHttp.request({
      url: resolved,
      method: "POST",
      headers: { ...authHeaders, "Content-Type": contentTypeHeader },
      data,
      dataType: "formData",
    });
    if (res.status < 200 || res.status >= 300) {
      logHttpApiResponseDebug({
        method: "POST",
        url: resolved,
        status: res.status,
        ok: false,
        data: res.data,
      });
      const text = typeof res.data === "string" ? res.data : (res.data ? JSON.stringify(res.data) : "");
      throw new Error(`HTTP ${res.status}: ${text || "Upload failed"}`);
    }
    const nativePayload =
      typeof res.data === "string"
        ? (() => {
            try {
              return JSON.parse(res.data) as unknown;
            } catch {
              return res.data;
            }
          })()
        : res.data;
    logHttpApiResponseDebug({
      method: "POST",
      url: resolved,
      status: res.status,
      ok: true,
      data: nativePayload,
    });
    return (unwrapEnvelope ? unwrapApiData<T>(nativePayload) : (nativePayload as T)) as T;
  }

  const form = new FormData();
  form.append("user_id", userId);
  if (extraFields) {
    for (const [k, v] of Object.entries(extraFields)) form.append(k, v);
  }
  form.append(fileFieldName, file, fileName);

  const headers: Record<string, string> = { ...authHeaders };
  const res = await fetch(resolved, { method: "POST", headers, body: form, signal });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    logHttpApiResponseDebug({
      method: "POST",
      url: resolved,
      status: res.status,
      ok: false,
      data: text,
    });
    throw new Error(`HTTP ${res.status}: ${text || res.statusText}`);
  }
  const json = (await res.json()) as unknown;
  logHttpApiResponseDebug({
    method: "POST",
    url: resolved,
    status: res.status,
    ok: true,
    data: json,
  });
  return (unwrapEnvelope ? unwrapApiData<T>(json) : (json as T)) as T;
}

// ─── TTS 流式（二进制）──────────────────────────────────────────────

export interface GetTtsStreamOptions {
  params: HttpQueryParams;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  token?: string;
  skipAuth?: boolean;
}

export interface GetTtsStreamResult {
  /** 音频二进制 */
  blob: Blob;
  /** 从 Content-Disposition 解析的文件名（若有） */
  fileName?: string;
}

/**
 * 从 Content-Disposition 解析 filename。
 * @param header Content-Disposition 头值
 */
export function parseContentDispositionFileName(header: string | null): string | undefined {
  if (!header) return undefined;
  const m = /filename\*?=(?:UTF-8''|")?([^";\n]+)/i.exec(header);
  if (!m) return undefined;
  try {
    return decodeURIComponent(m[1].replace(/"/g, "").trim());
  } catch {
    return m[1].replace(/"/g, "").trim();
  }
}

function base64ToBlob(base64: string, mimeType: string): Blob {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mimeType || "application/octet-stream" });
}

/**
 * GET /v1/tts-stream：拉取语音二进制（Web 为 Blob；原生为 arraybuffer Base64 转 Blob）。
 * @param url 完整或相对路径（如 /v1/tts-stream）
 * @param options 查询参数与鉴权
 */
export async function getTtsStream(url: string, options: GetTtsStreamOptions): Promise<GetTtsStreamResult> {
  const { params, signal, token = DEFAULT_API_TOKEN, skipAuth } = options;
  const headers: Record<string, string> = { ...options.headers };
  if (token && !skipAuth) headers["Authorization"] = `Bearer ${token}`;

  const resolvedBase = resolveUrl(url);

  logHttpApiRequestPayload({ method: "GET", url: resolvedBase, params });

  if (isNative()) {
    const res = await CapacitorHttp.request({
      url: resolvedBase,
      method: "GET",
      headers,
      params: toCapacitorParams(params),
      responseType: "arraybuffer",
    });
    if (res.status < 200 || res.status >= 300) {
      logHttpApiResponseDebug({
        method: "GET",
        url: resolvedBase,
        params,
        status: res.status,
        ok: false,
        data: res.data,
      });
      throw new Error(`HTTP ${res.status}: TTS request failed`);
    }
    const mime = (res.headers?.["Content-Type"] || res.headers?.["content-type"] || "audio/mpeg") as string;
    const cd = (res.headers?.["Content-Disposition"] || res.headers?.["content-disposition"]) as string | undefined;
    const dataStr = typeof res.data === "string" ? res.data : "";
    const blob = base64ToBlob(dataStr, mime.split(";")[0]?.trim() || "application/octet-stream");
    logHttpApiResponseDebug({
      method: "GET",
      url: resolvedBase,
      params,
      status: res.status,
      ok: true,
      data: blob,
    });
    return { blob, fileName: parseContentDispositionFileName(cd ?? null) };
  }

  const resolved = appendQueryParams(resolvedBase, params);
  const res = await fetch(resolved, { method: "GET", headers, signal });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    logHttpApiResponseDebug({
      method: "GET",
      url: resolvedBase,
      params,
      status: res.status,
      ok: false,
      data: text,
    });
    throw new Error(`HTTP ${res.status}: ${text || res.statusText}`);
  }
  const blob = await res.blob();
  const cd = res.headers.get("Content-Disposition");
  logHttpApiResponseDebug({
    method: "GET",
    url: resolvedBase,
    params,
    status: res.status,
    ok: true,
    data: blob,
  });
  return { blob, fileName: parseContentDispositionFileName(cd) };
}

// ─── 分块流式 (chunked) ────────────────────────────────────────────

export interface StreamChunkedOptions {
  url: string;
  method?: string;
  body?: BodyInit | object;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  params?: HttpQueryParams;
  onChunk: (text: string) => void;
  onDone?: () => void;
  onError?: (err: Error) => void;
}

/**
 * 分块流式请求：Web 使用 getReader() 逐块回调；原生使用 CapacitorHttp 一次性返回后回调 onChunk。
 * 返回取消函数。
 */
export function streamChunked(options: StreamChunkedOptions): () => void {
  const { url, method = "GET", body, headers, signal, params, onChunk, onDone, onError } = options;
  const resolvedBase = resolveUrl(url);
  const upperMethod = String(method).toUpperCase();
  logHttpApiRequestPayload({
    method,
    url: resolvedBase,
    params,
    body:
      body != null && upperMethod !== "GET"
        ? typeof body === "object" &&
            !(body instanceof FormData) &&
            !(body instanceof ArrayBuffer) &&
            !ArrayBuffer.isView(body)
          ? body
          : serializeBodyForHttpDebugLog(body as RequestInitExt["body"])
        : undefined,
  });
  const controller = new AbortController();
  let cancelled = false;
  if (signal) {
    signal.addEventListener("abort", () => {
      cancelled = true;
      controller.abort();
    });
  }
  const cancel = () => {
    cancelled = true;
    controller.abort();
  };

  if (isNative()) {
    const capOptions: {
      url: string;
      method: string;
      headers: Record<string, string>;
      data?: object | string;
      params?: HttpParams;
    } = {
      url: resolvedBase,
      method,
      headers: (headers as Record<string, string>) ?? {},
    };
    const capParams = toCapacitorParams(params);
    if (capParams) capOptions.params = capParams;
    if (body != null && typeof body === "object" && !(body instanceof FormData) && !(body instanceof ArrayBuffer) && !ArrayBuffer.isView(body)) {
      capOptions.data = body as object;
      capOptions.headers["Content-Type"] = "application/json";
    }
    (async () => {
      try {
        const res = await CapacitorHttp.request(capOptions);
        if (cancelled) return;
        if (res.status < 200 || res.status >= 300) {
          onError?.(new Error(`HTTP ${res.status}`));
          return;
        }
        const text = typeof res.data === "string" ? res.data : (res.data != null ? JSON.stringify(res.data) : "");
        if (text) onChunk(text);
        onDone?.();
      } catch (e) {
        if (!cancelled) onError?.(e instanceof Error ? e : new Error(String(e)));
      }
    })();
    return cancel;
  }

  const resolved = appendQueryParams(resolvedBase, params);
  const init: RequestInit = {
    method,
    headers: headers as HeadersInit,
    signal: controller.signal,
  };
  if (body != null) {
    if (typeof body === "object" && !(body instanceof FormData) && !(body instanceof ArrayBuffer) && !ArrayBuffer.isView(body)) {
      init.body = JSON.stringify(body);
      (init.headers as Record<string, string>) = { ...(init.headers as Record<string, string>), "Content-Type": "application/json" };
    } else {
      init.body = body as BodyInit;
    }
  }

  (async () => {
    try {
      const res = await fetch(resolved, init);
      if (!res.ok) {
        const text = await res.text().catch(() => "");
        onError?.(new Error(`HTTP ${res.status}: ${text || res.statusText}`));
        return;
      }
      const reader = res.body?.getReader();
      if (!reader) {
        onError?.(new Error("No response body"));
        return;
      }
      const decoder = new TextDecoder("utf-8");
      while (!cancelled) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value?.length) onChunk(decoder.decode(value, { stream: true }));
      }
      if (!cancelled) onDone?.();
    } catch (e) {
      if (cancelled || (e instanceof Error && e.name === "AbortError")) return;
      onError?.(e instanceof Error ? e : new Error(String(e)));
    }
  })();

  return cancel;
}

// ─── SSE 流式 ───────────────────────────────────────────────────────

export interface StreamSSEOptions {
  url: string;
  method?: string;
  /** POST 等请求体（可 JSON 序列化对象） */
  data?: object;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  params?: HttpQueryParams;
  onMessage: (data: string | object) => void;
  onDone?: () => void;
  onError?: (err: Error) => void;
  /** 是否尝试将 data 行解析为 JSON 再传给 onMessage */
  parseJSON?: boolean;
  /** 覆盖默认 VITE_API_TOKEN */
  token?: string;
  /** 为 true 时不添加 Authorization */
  skipAuth?: boolean;
}

/** 判断是否为 SSE 结束行（data:done / data:[DONE]），不触发 onMessage */
function isSseDoneLine(raw: string): boolean {
  const s = raw.trim();
  if (s === "done" || s === "[DONE]") return true;
  return false;
}

/**
 * 使用 fetch 读取 SSE：边收边按行解析 `data:`，供 Web 与原生（开启 CapacitorHttp fetch 补丁后）共用。
 * @param reader 响应体的 ReadableStream 读取器
 * @param cancelled 为 true 时尽快结束循环
 * @param onLineData 解析出的 `data:` 行内容（不含 `data:` 前缀）
 */
async function consumeSseFromReader(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  cancelled: () => boolean,
  onLineData: (raw: string) => void,
): Promise<void> {
  const decoder = new TextDecoder("utf-8");
  let buffer = "";
  while (!cancelled()) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value?.length) buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      if (line.startsWith("data:")) {
        const raw = line.slice(5).trim();
        onLineData(raw);
      }
    }
  }
}

/**
 * SSE 流式请求：Accept: text/event-stream，按行解析 data 行并回调 onMessage。
 * 识别 **data:done**（及 **data:[DONE]**）时触发 onDone。
 * Web 与 Android/iOS 统一走 **fetch + ReadableStream**（需在 `capacitor.config` 中开启 `CapacitorHttp.enabled`，见官方文档）。
 * 原生在 fetch 抛错时降级为 `CapacitorHttp.request` 整包解析（未开补丁或 WebView 直连失败时仍可用）。
 * 返回取消函数。
 */
export function streamSSE(options: StreamSSEOptions): () => void {
  const {
    url,
    method = "GET",
    data,
    headers = {},
    signal,
    params,
    onMessage,
    onDone,
    onError,
    parseJSON = true,
    token = DEFAULT_API_TOKEN,
    skipAuth,
  } = options;
  const resolvedBase = resolveUrl(url);
  const controller = new AbortController();
  let cancelled = false;
  let doneEmitted = false;
  if (signal) {
    signal.addEventListener("abort", () => {
      cancelled = true;
      controller.abort();
    });
  }
  const cancel = () => {
    cancelled = true;
    controller.abort();
  };

  const emitDoneOnce = () => {
    if (doneEmitted) return;
    doneEmitted = true;
    onDone?.();
  };

  const handleDataPayload = (raw: string) => {
    if (isSseDoneLine(raw)) {
      emitDoneOnce();
      return;
    }
    if (raw === "") return;
    try {
      const payload = parseJSON ? (JSON.parse(raw) as object) : raw;
      onMessage(payload);
    } catch {
      onMessage(raw);
    }
  };

  /** 将整段 SSE 文本按行解析（整包响应或无可读流时） */
  const parseSSELines = (text: string) => {
    const lines = text.split(/\r?\n/);
    for (const line of lines) {
      if (line.startsWith("data:")) {
        const raw = line.slice(5).trim();
        handleDataPayload(raw);
      }
    }
  };

  const reqHeaders: Record<string, string> = { Accept: "text/event-stream", ...headers };
  if (token && !skipAuth && !reqHeaders["Authorization"] && !reqHeaders["authorization"]) {
    reqHeaders["Authorization"] = `Bearer ${token}`;
  }
  if (data != null && method !== "GET" && !reqHeaders["Content-Type"]) {
    reqHeaders["Content-Type"] = "application/json";
  }

  const resolved = appendQueryParams(resolvedBase, params);
  const init: RequestInit = {
    method,
    headers: reqHeaders as Record<string, string>,
    signal: controller.signal,
  };
  if (data != null && method !== "GET") (init as RequestInit & { body: string }).body = JSON.stringify(data);

  logHttpApiRequestPayload({
    method,
    url: resolvedBase,
    params,
    body: data != null && String(method).toUpperCase() !== "GET" ? data : undefined,
  });

  /**
   * 原生专用：CapacitorHttp 整包拉取后解析（fetch 不可用时的降级路径）。
   * @returns 是否已处理完成（成功或已回调错误）
   */
  const runNativeCapacitorSseFallback = async (): Promise<void> => {
    const capParams = toCapacitorParams(params);
    const capOpts: {
      url: string;
      method: string;
      headers: Record<string, string>;
      data?: object;
      params?: HttpParams;
    } = {
      url: resolvedBase,
      method,
      headers: reqHeaders as Record<string, string>,
    };
    if (capParams) capOpts.params = capParams;
    if (data != null && method !== "GET") capOpts.data = data;
    const res = await CapacitorHttp.request(capOpts);
    if (cancelled) return;
    if (res.status < 200 || res.status >= 300) {
      onError?.(new Error(`HTTP ${res.status}`));
      return;
    }
    const text = typeof res.data === "string" ? res.data : (res.data != null ? JSON.stringify(res.data) : "");
    parseSSELines(text);
    emitDoneOnce();
  };

  (async () => {
    try {
      const res = await fetch(resolved, init);
      if (cancelled) return;
      if (!res.ok) {
        const text = await res.text().catch(() => "");
        onError?.(new Error(`HTTP ${res.status}: ${text || res.statusText}`));
        return;
      }
      const reader = res.body?.getReader();
      if (reader) {
        await consumeSseFromReader(reader, () => cancelled, handleDataPayload);
        if (!cancelled) emitDoneOnce();
        return;
      }
      // 无 ReadableStream：一次性读完再解析（极少数环境）
      const text = await res.text();
      if (cancelled) return;
      parseSSELines(text);
      emitDoneOnce();
    } catch (e) {
      if (cancelled || (e instanceof Error && e.name === "AbortError")) return;
      if (isNative()) {
        try {
          await runNativeCapacitorSseFallback();
        } catch (e2) {
          if (!cancelled) onError?.(e2 instanceof Error ? e2 : new Error(String(e2)));
        }
        return;
      }
      onError?.(e instanceof Error ? e : new Error(String(e)));
    }
  })();

  return cancel;
}

// ─── 可选：带 baseURL 的 API 客户端 ─────────────────────────────────

export interface ApiClient {
  request: typeof request;
  apiRequest: typeof apiRequest;
  uploadMultipart: typeof uploadMultipart;
  getTtsStream: typeof getTtsStream;
  streamChunked: typeof streamChunked;
  streamSSE: typeof streamSSE;
}

/**
 * 创建固定 baseURL 的客户端，后续 url 为相对路径时与该 base 拼接。
 * 若 url 已是绝对地址则不再拼接。
 */
export function createApiClient(baseURL: string): ApiClient {
  const base = baseURL.replace(/\/$/, "");
  const resolve = (url: string) => (url.startsWith("http") ? url : `${base}${url.startsWith("/") ? url : `/${url}`}`);

  return {
    request<T = unknown>(url: string, options?: RequestInitExt): Promise<T> {
      return request(resolve(url), options);
    },
    apiRequest<T = unknown>(url: string, options?: ApiRequestOptions): Promise<T> {
      return apiRequest(resolve(url), options);
    },
    uploadMultipart<T = unknown>(options: UploadMultipartOptions): Promise<T> {
      return uploadMultipart({ ...options, url: resolve(options.url) });
    },
    getTtsStream(url: string, options: GetTtsStreamOptions): Promise<GetTtsStreamResult> {
      return getTtsStream(resolve(url), options);
    },
    streamChunked(options: StreamChunkedOptions): () => void {
      return streamChunked({ ...options, url: resolve(options.url) });
    },
    streamSSE(options: StreamSSEOptions): () => void {
      return streamSSE({ ...options, url: resolve(options.url) });
    },
  };
}
