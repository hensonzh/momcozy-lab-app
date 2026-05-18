import { apiRequestRaw } from "@/lib/http";
import { resolveChatAssetUrl } from "@/lib/chatAssetUrl";

export const IBCLC_CONSULT_COMPLETED_KEY = "momcozy_ibclc_consult_completed";
export const IBCLC_CLIENT_USER_ID_KEY = "momcozy_user_id";

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
    if (!parsed || typeof parsed !== "object") return null;
    const payload = parsed as IbclcConsultCompletedPayload;
    return payload.type === "momcozy.ibclc_consult_completed" ? payload : null;
  } catch {
    return null;
  }
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

export function buildIbclcChatUrl(url: string, consultId: string, threadId: string, returnTo?: string): string {
  const raw = resolveChatAssetUrl(url.trim() || "/ibclc-chat.html", { allowBaseFallback: false });
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
  threadId: string,
  consultId: string,
): boolean {
  if (!payload || payload.type !== "momcozy.ibclc_consult_completed") return false;
  const eventThreadId = String(payload.conversation_id || payload.thread_id || payload.threadId || "").trim();
  if (eventThreadId && threadId.trim() && eventThreadId !== threadId.trim()) return false;
  const eventConsultId = String(payload.consult_id || payload.consultId || "").trim();
  return Boolean(eventConsultId && eventConsultId === consultId.trim());
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
