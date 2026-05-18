import { apiRequestRaw } from "@/lib/http";

export const IBCLC_CONSULT_COMPLETED_KEY = "momcozy_ibclc_consult_completed";
export const IBCLC_CONSULT_COMPLETIONS_KEY = "momcozy_ibclc_consult_completions";
export const IBCLC_CLIENT_USER_ID_KEY = "momcozy_user_id";
export const IBCLC_RETURN_TO_KEY = "momcozy_ibclc_return_to";
export const IBCLC_RETURN_VIEWPORT_KEY = "momcozy_ibclc_return_viewport";
const MAX_STORED_IBCLC_COMPLETIONS = 50;
const MAX_IBCLC_RETURN_VIEWPORT_AGE_MS = 10 * 60 * 1000;

export type IbclcConsultCompletedPayload = {
  type: "momcozy.ibclc_consult_completed";
  conversation_id?: string;
  thread_id?: string;
  threadId?: string;
  consult_id?: string;
  consultId?: string;
  event_type?: string;
  completed_at?: string;
  event?: string;
  session_state?: unknown;
};

export type IbclcClientEventResult = {
  status?: string;
  conversation_id?: string;
  consult_id?: string;
  event?: string;
  session_state?: unknown;
  event_type?: string;
};

export type IbclcReturnViewportSnapshot = {
  return_to: string;
  consult_id?: string;
  scroll_top: number;
  scroll_height?: number;
  saved_at: number;
};

function parseIbclcConsultCompletion(value: unknown): IbclcConsultCompletedPayload | null {
  if (!value || typeof value !== "object") return null;
  const payload = value as IbclcConsultCompletedPayload;
  return payload.type === "momcozy.ibclc_consult_completed" ? payload : null;
}

function ibclcCompletionStorageKey(payload: IbclcConsultCompletedPayload): string {
  const consultId = String(payload.consult_id || payload.consultId || "").trim();
  if (consultId) return `consult:${consultId}`;
  const threadId = String(payload.conversation_id || payload.thread_id || payload.threadId || "").trim();
  return threadId ? `thread:${threadId}` : "";
}

export function clientMessageSentAt(date = new Date()): string {
  const pad = (value: number, length = 2): string => String(Math.trunc(Math.abs(value))).padStart(length, "0");
  const offsetMinutes = -date.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? "+" : "-";
  const offsetHours = Math.floor(Math.abs(offsetMinutes) / 60);
  const offsetRemainder = Math.abs(offsetMinutes) % 60;
  return [
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`,
    "T",
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`,
    ".",
    pad(date.getMilliseconds(), 3),
    `${sign}${pad(offsetHours)}:${pad(offsetRemainder)}`,
  ].join("");
}

export function readStoredIbclcConsultCompletion(): IbclcConsultCompletedPayload | null {
  try {
    const raw = localStorage.getItem(IBCLC_CONSULT_COMPLETED_KEY);
    if (!raw?.trim()) return null;
    const parsed = JSON.parse(raw) as unknown;
    return parseIbclcConsultCompletion(parsed);
  } catch {
    return null;
  }
}

export function readStoredIbclcConsultCompletions(): IbclcConsultCompletedPayload[] {
  const result: IbclcConsultCompletedPayload[] = [];
  const seenKeys = new Set<string>();
  const addCompletion = (payload: IbclcConsultCompletedPayload | null) => {
    if (!payload) return;
    const key = ibclcCompletionStorageKey(payload);
    if (key && seenKeys.has(key)) return;
    if (key) seenKeys.add(key);
    result.push(payload);
  };

  try {
    const raw = localStorage.getItem(IBCLC_CONSULT_COMPLETIONS_KEY);
    if (raw?.trim()) {
      const parsed = JSON.parse(raw) as unknown;
      if (Array.isArray(parsed)) {
        for (const item of parsed) addCompletion(parseIbclcConsultCompletion(item));
      } else {
        addCompletion(parseIbclcConsultCompletion(parsed));
      }
    }
  } catch {
    /* Ignore malformed historical cache. */
  }

  addCompletion(readStoredIbclcConsultCompletion());
  return result;
}

export function readOrCreateIbclcClientUserId(fallbackUserId: string): string {
  try {
    const existing = localStorage.getItem(IBCLC_CLIENT_USER_ID_KEY)?.trim();
    if (existing) return existing;
    const next = fallbackUserId.trim() || `user_${crypto.randomUUID()}`;
    localStorage.setItem(IBCLC_CLIENT_USER_ID_KEY, next);
    return next;
  } catch {
    return fallbackUserId.trim() || "app-user";
  }
}

export function rememberIbclcReturnTo(returnTo: string): void {
  const value = returnTo.trim();
  if (!value) return;
  try {
    localStorage.setItem(IBCLC_RETURN_TO_KEY, value);
  } catch {
    /* Best-effort route recovery only. */
  }
}

export function readStoredIbclcReturnTo(): string {
  try {
    return localStorage.getItem(IBCLC_RETURN_TO_KEY)?.trim() || "";
  } catch {
    return "";
  }
}

export function rememberIbclcReturnViewport(input: {
  returnTo: string;
  consultId: string;
  scrollTop: number;
  scrollHeight?: number;
}): void {
  const returnTo = input.returnTo.trim();
  if (!returnTo) return;
  const payload: IbclcReturnViewportSnapshot = {
    return_to: returnTo,
    consult_id: input.consultId.trim() || undefined,
    scroll_top: Math.max(0, Math.round(input.scrollTop)),
    scroll_height: typeof input.scrollHeight === "number" ? Math.max(0, Math.round(input.scrollHeight)) : undefined,
    saved_at: Date.now(),
  };
  try {
    localStorage.setItem(IBCLC_RETURN_VIEWPORT_KEY, JSON.stringify(payload));
  } catch {
    /* Best-effort route recovery only. */
  }
}

export function clearStoredIbclcReturnViewport(): void {
  try {
    localStorage.removeItem(IBCLC_RETURN_VIEWPORT_KEY);
  } catch {
    /* Best-effort route recovery only. */
  }
}

export function readStoredIbclcReturnViewport(returnTo: string): IbclcReturnViewportSnapshot | null {
  try {
    const raw = localStorage.getItem(IBCLC_RETURN_VIEWPORT_KEY);
    if (!raw?.trim()) return null;
    const parsed = JSON.parse(raw) as Partial<IbclcReturnViewportSnapshot>;
    const expectedReturnTo = returnTo.trim();
    const storedReturnTo = String(parsed.return_to || "").trim();
    const savedAt = Number(parsed.saved_at);
    if (!storedReturnTo || storedReturnTo !== expectedReturnTo) return null;
    if (!Number.isFinite(savedAt) || Date.now() - savedAt > MAX_IBCLC_RETURN_VIEWPORT_AGE_MS) {
      clearStoredIbclcReturnViewport();
      return null;
    }
    const scrollTop = Number(parsed.scroll_top);
    if (!Number.isFinite(scrollTop)) return null;
    return {
      return_to: storedReturnTo,
      consult_id: String(parsed.consult_id || "").trim() || undefined,
      scroll_top: Math.max(0, Math.round(scrollTop)),
      scroll_height: Number.isFinite(Number(parsed.scroll_height)) ? Math.max(0, Math.round(Number(parsed.scroll_height))) : undefined,
      saved_at: savedAt,
    };
  } catch {
    return null;
  }
}

export function buildIbclcChatUrl(url: string, consultId: string, threadId: string, returnTo?: string): string {
  const raw = url.trim() || "/ibclc-chat.html";
  try {
    const nextUrl = new URL(raw, window.location.origin);
    if (threadId.trim()) nextUrl.searchParams.set("thread_id", threadId.trim());
    if (consultId.trim()) nextUrl.searchParams.set("consult_id", consultId.trim());
    if (returnTo?.trim()) nextUrl.searchParams.set("return_to", returnTo.trim());
    return nextUrl.origin === window.location.origin
      ? `${nextUrl.pathname}${nextUrl.search}${nextUrl.hash}`
      : nextUrl.toString();
  } catch {
    return raw;
  }
}

export function isIbclcCompletionForCard(
  payload: IbclcConsultCompletedPayload | null,
  _threadId: string,
  consultId: string,
): boolean {
  if (!payload || payload.type !== "momcozy.ibclc_consult_completed") return false;
  const expectedConsultId = consultId.trim();
  if (!expectedConsultId) return false;
  const eventConsultId = String(payload.consult_id || payload.consultId || "").trim();
  return Boolean(eventConsultId && eventConsultId === expectedConsultId);
}

export function publishIbclcConsultCompleted(
  result: IbclcClientEventResult | null | undefined,
  fallback: { conversationId: string; consultId: string },
): IbclcConsultCompletedPayload {
  const payload: IbclcConsultCompletedPayload = {
    type: "momcozy.ibclc_consult_completed",
    conversation_id: result?.conversation_id || fallback.conversationId,
    consult_id: result?.consult_id || fallback.consultId,
    event_type: "ibclc_consult_completed",
    completed_at: clientMessageSentAt(),
    event: result?.event || "",
    session_state: result?.session_state ?? null,
  };
  try {
    localStorage.setItem(IBCLC_CONSULT_COMPLETED_KEY, JSON.stringify(payload));
    const key = ibclcCompletionStorageKey(payload);
    const previous = readStoredIbclcConsultCompletions();
    const next = key ? previous.filter((item) => ibclcCompletionStorageKey(item) !== key) : previous;
    next.push(payload);
    localStorage.setItem(IBCLC_CONSULT_COMPLETIONS_KEY, JSON.stringify(next.slice(-MAX_STORED_IBCLC_COMPLETIONS)));
  } catch {
    /* Cross-page notification is best-effort. */
  }
  if (window.opener && !window.opener.closed) {
    window.opener.postMessage(payload, window.location.origin);
  }
  window.dispatchEvent(new CustomEvent("momcozy-ibclc-consult-completed", { detail: payload }));
  return payload;
}

export async function recordIbclcConsultCompleted(input: {
  conversationId: string;
  clientUserId: string;
  consultId: string;
  locale: string;
  timezone: string;
}): Promise<IbclcClientEventResult> {
  const fallback: IbclcClientEventResult = {
    status: input.conversationId ? "local_completed" : "missing_conversation_id",
    conversation_id: input.conversationId,
    consult_id: input.consultId,
    event_type: "ibclc_consult_completed",
  };
  if (!input.conversationId.trim()) return fallback;

  try {
    return await apiRequestRaw<IbclcClientEventResult>("/api/client-event", {
      method: "POST",
      body: {
        thread_id: input.conversationId,
        user_id: input.clientUserId,
        event_type: "ibclc_consult_completed",
        label: "用户已完成一次 IBCLC 在线咨询",
        occurred_at: clientMessageSentAt(),
        locale: input.locale || "zh-CN",
        timezone: input.timezone || "Asia/Shanghai",
        metadata: {
          user_id: input.clientUserId,
          consultant_name: "Emily Chen",
          consultant_credentials: "IBCLC",
          source: "ibclc-chat",
          consult_id: input.consultId,
        },
      },
    });
  } catch {
    return fallback;
  }
}

export function stableIbclcConsultId(seed: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < seed.length; i += 1) {
    hash ^= seed.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return `ibclc_${(hash >>> 0).toString(16).padStart(8, "0")}`;
}
