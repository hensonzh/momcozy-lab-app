/**
 * 吸乳会话自动结束（全离线 / 暂停超时）：非吸乳页系统通知、回智能体主页后的收尾（小结 + BLE），
 * 以及停止吸乳摘要写入对话（供非 PumpSession 挂载时调用）。
 *
 * 小结只应生成一次：registerPumpAutoEndOffPumpPending 在自动结束且非吸乳页时写入；
 * tryRunPumpAutoEndOffPumpTeardownOnce 在「已在智能体主页 / 之后进入主页 / 点击通知」三条路径上竞争 claim，先到先得。
 */

import { Capacitor } from "@capacitor/core";
import {
  postAgUiWebSocketStream,
  postPumpSessionSummaryWebSocket,
  parseChatRichTextFromSseData,
} from "@/lib/agentApi";
import {
  mergePendingRichTextPayload,
  resolveAgUiEventType,
  richTextFromToolResultPayload,
} from "@/lib/agUiStreamSideEffects";
import {
  getAgentConversationIdForRequest,
  getAgUiThreadIdForRequest,
  persistAgentConversationIdFromSse,
  persistAgUiThreadId,
} from "@/lib/agentConversationSession";
import { extractChatAnswerChunk, mergeStreamingAnswerDelta } from "@/lib/chatStreaming";
import { chatStore } from "@/lib/chatStore";
import { savePersistedChatMessages } from "@/lib/chatMessagesLocalPersistence";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";
import { endRunAndUpdateStore, isBleSupported } from "@/lib/ble";
import {
  getPumpAgentUploadProcessProgress,
  markPumpAgentUploadProcessStepStop,
  setPumpAgentUploadOperationSource,
} from "@/lib/pumpAgentUpload";
import { createScopedConsole } from "@/lib/logger";
import {
  pumpSessionLifecycle,
  type PumpSessionEndedEvent,
  type PumpSessionEndReason,
} from "@/lib/pumpSessionLifecycle";
import { showPumpAutoEndLocalNotice } from "@/lib/pumpSessionNotification";
import { toast } from "@/components/ui/use-toast";
import type { ChatMessage } from "@/types/chat";
import type { ChatRichTextPayload, PumpSessionSummaryBody, PumpSessionSummarySide } from "@/lib/agentApiTypes";
import { getRuntimeUserId } from "@/lib/debugUserConfig";

// ─── 吸乳小结写入对话 ─────────────────────────────────────────────
const CHAT_USER_ID = getRuntimeUserId(import.meta.env.VITE_DEFAULT_USER_ID as string | undefined);
const MAI_CHAT_QUERY_STOP_PUMP = "停止吸乳-开始吸乳APP";
const STOP_SUMMARY_TIMEOUT_MS = 12000;
const PUMP_SESSION_SUMMARY_WS_TIMEOUT_MS = 15000;

/** AgentHub 监听：外部写入 chatStore 后合并进 Hub 的 messages（与通知收尾一致） */
export const AGENT_HUB_SYNC_CHAT_EVENT = "mmc-agent-hub-sync-chat";
/** 吸奶结束卡片里「本次收集 / 奶量」等行的填充程度，用于多段 rich_text 时保留更完整的一条 */
function pumpStopRichTextCompleteness(r: ChatRichTextPayload): number {
  let score = 0;
  for (const c of r.card ?? []) {
    if (String(c.type ?? "").trim() !== "吸奶结束") continue;
    for (const row of c.content ?? []) {
      const t = row.title ?? "";
      const v = row.content?.trim() ?? "";
      if (!v) continue;
      if (t.includes("收集") || t.includes("奶量")) score += 10 + v.length;
      else score += 1 + v.length;
    }
  }
  return score;
}

function mergePumpStopRichText(
  prev: ChatRichTextPayload | null,
  next: ChatRichTextPayload,
): ChatRichTextPayload {
  if (!prev) return next;
  if (pumpStopRichTextCompleteness(next) > pumpStopRichTextCompleteness(prev)) {
    return mergePendingRichTextPayload(null, next);
  }
  if (pumpStopRichTextCompleteness(prev) > pumpStopRichTextCompleteness(next)) {
    return prev;
  }
  return mergePendingRichTextPayload(prev, next);
}

/** ag-ui：仅 TEXT_MESSAGE_CONTENT / 旧 message 事件取正文增量 */
function extractPumpStopAnswerChunk(data: string | object): string {
  const tag = resolveAgUiEventType(data);
  if (tag) {
    if (tag === "reasoning") return extractChatAnswerChunk(data);
    if (tag === "message") return extractChatAnswerChunk(data);
    if (tag !== "TEXT_MESSAGE_CONTENT") return "";
    if (typeof data === "object" && data != null) {
      const delta = (data as { delta?: unknown }).delta;
      if (typeof delta === "string" && delta) return delta;
    }
    return "";
  }
  return extractChatAnswerChunk(data);
}

function parseToolResultContent(content: unknown): Record<string, unknown> | null {
  if (content == null) return null;
  if (typeof content === "object" && !Array.isArray(content)) {
    return content as Record<string, unknown>;
  }
  if (typeof content === "string" && content.trim()) {
    try {
      const o = JSON.parse(content) as unknown;
      if (typeof o === "object" && o != null && !Array.isArray(o)) return o as Record<string, unknown>;
    } catch {
      return null;
    }
  }
  return null;
}

function handlePumpStopStreamMessage(
  data: string | object,
  merged: { current: string },
  richHolder: { current: ChatRichTextPayload | null },
): void {
  persistAgentConversationIdFromSse(data);
  if (typeof data === "object" && data != null) {
    persistAgUiThreadId((data as { thread_id?: unknown }).thread_id);
  }
  const rich = parseChatRichTextFromSseData(data);
  if (rich) {
    richHolder.current = mergePumpStopRichText(richHolder.current, rich);
  }
  const eventType = resolveAgUiEventType(data);
  if (eventType === "TOOL_CALL_RESULT" && typeof data === "object" && data != null) {
    const parsed = parseToolResultContent((data as Record<string, unknown>).content);
    if (parsed) {
      const built = richTextFromToolResultPayload(parsed);
      if (built) {
        richHolder.current = mergePumpStopRichText(richHolder.current, built);
      }
    }
  }
  const chunk = extractPumpStopAnswerChunk(data);
  if (!chunk) return;
  const next = mergeStreamingAnswerDelta(merged.current, chunk);
  merged.current = next.merged;
}
function commitPumpStopSummaryToChat(mergedText: string, rich: ChatRichTextPayload | undefined): void {
  const ts = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
  const fallbackText = mergedText.trim() || rich?.content || "已停止吸乳";
  const msg: ChatMessage = {
    id: `stop-report-${Date.now()}`,
    role: "mai",
    content: fallbackText,
    timestamp: ts,
    cardType: "report",
    ...(rich ? { richText: rich } : {}),
  };
  const currentMsgs = chatStore.get().messages;
  const nextMsgs = [...currentMsgs, msg];
  chatStore.setMessages(nextMsgs);
  void savePersistedChatMessages(nextMsgs);
  if (typeof window !== "undefined") {
    window.setTimeout(() => {
      window.dispatchEvent(new CustomEvent(AGENT_HUB_SYNC_CHAT_EVENT));
    }, 0);
  }
}

function nowChatTimestamp(): string {
  return new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
}

function numberOrUndefined(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  return value;
}

function modeName(mode: unknown): string | undefined {
  if (typeof mode !== "number") return undefined;
  if (mode === 0) return "stimulate";
  if (mode === 1) return "expression";
  if (mode === 2) return "mix";
  return String(mode);
}

function buildPumpSessionSummarySide(device: ReturnType<typeof deviceStore.get>["L"], process: number): PumpSessionSummarySide {
  const milk = numberOrUndefined(device?.finalMilkMl) ?? numberOrUndefined(device?.milkMl);
  return {
    connected: Boolean(device?.connected),
    milk_ml: milk,
    process: Number.isFinite(process) ? Math.max(0, Math.min(100, Math.round(process))) : undefined,
    mode: modeName(device?.pumpMode),
    level: numberOrUndefined(device?.gear),
    duration_seconds: numberOrUndefined(device?.duration),
    has_milk: typeof device?.milkFlag === "number" ? Boolean(device.milkFlag & 0x01) : undefined,
    has_letdown: typeof device?.moFlag === "number" ? Boolean(device.moFlag & 0x01) : undefined,
  };
}

function buildPumpSessionSummaryBody(event?: PumpSessionEndedEvent | null): PumpSessionSummaryBody {
  const snap = deviceStore.get();
  const progress = getPumpAgentUploadProcessProgress();
  const endedAtMs = event?.at ?? Date.now();
  const left = buildPumpSessionSummarySide(snap.L, progress.processL);
  const right = buildPumpSessionSummarySide(snap.R, progress.processR);
  const leftMilk = left.milk_ml ?? 0;
  const rightMilk = right.milk_ml ?? 0;
  const leftDuration = left.duration_seconds ?? 0;
  const rightDuration = right.duration_seconds ?? 0;
  const conversationId = getAgentConversationIdForRequest() || getAgUiThreadIdForRequest();

  return {
    user_id: CHAT_USER_ID,
    conversation_id: conversationId,
    ended_at: new Date(endedAtMs).toISOString(),
    end_reason: event?.reason ?? "unknown",
    process_all: Math.max(0, Math.min(100, Math.round(progress.processAll))),
    total_milk_ml: Math.max(0, Math.round((leftMilk + rightMilk) * 10) / 10),
    duration_seconds: Math.max(leftDuration, rightDuration) || undefined,
    event_id: `pump-summary-${endedAtMs}`,
    left,
    right,
  };
}

function commitPumpSessionSummaryResponseToChat(
  response: Awaited<ReturnType<typeof postPumpSessionSummaryWebSocket>>,
  fallbackEventId: string | undefined,
): boolean {
  const chatMessage = response.data?.chat_message;
  const content = typeof chatMessage?.content === "string" ? chatMessage.content.trim() : "";
  if (!content) return false;
  const id = chatMessage?.id?.trim() || fallbackEventId || `pump-summary-${Date.now()}`;
  const msg: ChatMessage = {
    id,
    role: "mai",
    content,
    timestamp: chatMessage?.timestamp?.trim() || nowChatTimestamp(),
    cardType: chatMessage?.cardType === "report" ? "report" : "report",
    cardData: chatMessage?.cardData ?? { kind: "pump-session-summary", event_id: id },
  };
  const currentMsgs = chatStore.get().messages;
  if (currentMsgs.some((m) => m.id === msg.id)) return true;
  const nextMsgs = [...currentMsgs, msg];
  chatStore.setMessages(nextMsgs);
  void savePersistedChatMessages(nextMsgs);
  if (typeof window !== "undefined") {
    window.setTimeout(() => {
      window.dispatchEvent(new CustomEvent(AGENT_HUB_SYNC_CHAT_EVENT));
    }, 0);
  }
  return true;
}

async function pushPumpSessionSummaryWebSocketToChat(event?: PumpSessionEndedEvent | null): Promise<boolean> {
  const body = buildPumpSessionSummaryBody(event ?? pumpSessionLifecycle.getLastEndedEvent());
  const response = await postPumpSessionSummaryWebSocket(body, { timeoutMs: PUMP_SESSION_SUMMARY_WS_TIMEOUT_MS });
  if (typeof response.status === "number" && response.status !== 200) {
    throw new Error(response.message || `pump session summary status=${response.status}`);
  }
  if (typeof response.data?.error === "number" && response.data.error !== 0) {
    throw new Error(response.data.message || `pump session summary error=${response.data.error}`);
  }
  return commitPumpSessionSummaryResponseToChat(response, body.event_id);
}

function runPumpStopSummaryStream(
  startStream: (handlers: {
    onMessage: (data: string | object) => void;
    onDone: () => void;
    onError: (err: Error) => void;
  }) => () => void,
): Promise<void> {
  const merged = { current: "" };
  const richHolder: { current: ChatRichTextPayload | null } = { current: null };
  return new Promise<void>((resolve) => {
    let resolved = false;
    const finish = () => {
      if (resolved) return;
      resolved = true;
      resolve();
    };
    const cancel = startStream({
      onMessage: (data) => handlePumpStopStreamMessage(data, merged, richHolder),
      onDone: () => {
        commitPumpStopSummaryToChat(merged.current, richHolder.current ?? undefined);
        finish();
      },
      onError: (err: Error) => {
        console.error("[pushPumpStopAgentSummaryToChat] failed:", err);
        finish();
      },
    });
    window.setTimeout(() => {
      cancel();
      finish();
    }, STOP_SUMMARY_TIMEOUT_MS);
  });
}
export async function pushPumpStopAgentSummaryToChat(event?: PumpSessionEndedEvent | null): Promise<void> {
  try {
    const committed = await pushPumpSessionSummaryWebSocketToChat(event);
    if (committed) return;
    console.warn("[pushPumpStopAgentSummaryToChat] summary ws returned empty content, fallback to agent stream");
  } catch (err) {
    console.error("[pushPumpStopAgentSummaryToChat] summary ws failed, fallback to agent stream:", err);
  }

  await runPumpStopSummaryStream(({ onMessage, onDone, onError }) =>
    postAgUiWebSocketStream({
      text: MAI_CHAT_QUERY_STOP_PUMP,
      threadId: getAgUiThreadIdForRequest(),
      locale: (typeof navigator !== "undefined" && navigator.language) || "zh-CN",
      images: [],
      forwardedProps: {},
      parseJSON: true,
      onMessage,
      onDone,
      onError,
    }),
  );
}
// ─── BLE 停泵（不依赖 PumpSession）────────────────────────────────
export async function endPumpBleForBothConnectedSides(): Promise<void> {
  if (!isBleSupported()) return;
  const { L, R } = deviceStore.get();
  const items: Array<{ side: DeviceSide; deviceId: string }> = [];
  if (L?.connected && L.deviceId) items.push({ side: "L", deviceId: L.deviceId });
  if (R?.connected && R.deviceId) items.push({ side: "R", deviceId: R.deviceId });
  if (items.length === 0) return;
  setPumpAgentUploadOperationSource("both", "app");
  markPumpAgentUploadProcessStepStop("both");
  for (const it of items) {
    try {
      await endRunAndUpdateStore(it.deviceId, it.side);
      const cur = deviceStore.get()[it.side];
      if (cur) {
        deviceStore.setDevice(it.side, { ...cur, pumpWorkState: 0x00, duration: 0 });
      }
    } catch (error) {
      console.error(`[endPumpBleForBothConnectedSides] BF failed side=${it.side}:`, error);
    }
  }
}
// ─── 通知点击后进首页的收尾 ───────────────────────────────────────
export async function runPumpAutoEndTeardownFromNotification(): Promise<void> {
  try {
    await pushPumpStopAgentSummaryToChat();
  } catch (e) {
    console.error("[runPumpAutoEndTeardownFromNotification] summary failed", e);
  }
  try {
    await endPumpBleForBothConnectedSides();
  } catch (e) {
    console.error("[runPumpAutoEndTeardownFromNotification] ble stop failed", e);
  }
  if (typeof window === "undefined") return;
  // 推迟到下一 macrotask，确保 navigate("/") 后 AgentHub 已挂载并注册监听。
  window.setTimeout(() => {
    window.dispatchEvent(new CustomEvent(AGENT_HUB_SYNC_CHAT_EVENT));
  }, 0);
}
// ─── 非吸乳页自动结束：小结 + BLE 仅执行一次（智能体主页即时 / 稍后进入 / 通知点击）────────
const PUMP_AUTO_END_OFF_PUMP_PENDING_KEY = "mmc_pump_auto_end_off_pump_pending";
/** 非吸乳页发生自动结束时调用：写入待收尾标记，供后续任一路径 claim 后执行 teardown。 */
export function registerPumpAutoEndOffPumpPending(): void {
  if (typeof window === "undefined") return;
  try {
    sessionStorage.setItem(PUMP_AUTO_END_OFF_PUMP_PENDING_KEY, "1");
  } catch {
    /* ignore */
  }
}
function claimPumpAutoEndOffPumpPending(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const v = sessionStorage.getItem(PUMP_AUTO_END_OFF_PUMP_PENDING_KEY);
    if (v !== "1") return false;
    sessionStorage.removeItem(PUMP_AUTO_END_OFF_PUMP_PENDING_KEY);
    return true;
  } catch {
    return false;
  }
}
/**
 * 若存在待收尾标记则消费并执行小结 + BLE + Hub 同步；否则 no-op。
 * @returns 是否实际执行了 teardown
 */
export async function tryRunPumpAutoEndOffPumpTeardownOnce(): Promise<boolean> {
  if (!claimPumpAutoEndOffPumpPending()) return false;
  await runPumpAutoEndTeardownFromNotification();
  return true;
}
// ─── 非吸乳页：自动结束时的系统消息 / toast ─────────────────────────
const log = createScopedConsole("PumpAutoEndSession");
const isAndroidNative = Capacitor.getPlatform() === "android";
function isAutoEndReason(reason: PumpSessionEndReason): boolean {
  return (
    reason === "device-offline-ended-single" ||
    reason === "device-offline-ended-both" ||
    reason === "pause-timeout-ended"
  );
}
function copyFor(reason: PumpSessionEndReason): { title: string; body: string } {
  if (reason === "device-offline-ended-single") {
    return {
      title: "检测到设备已离线，本次吸奶结束",
      body: "检测到设备已离线，本次吸奶结束",
    };
  }
  if (reason === "device-offline-ended-both") {
    return {
      title: "两侧设备均已离线，本次吸奶自动结束",
      body: "两侧设备均已离线，本次吸奶自动结束",
    };
  }
  if (reason === "pause-timeout-ended") {
    return {
      title: "检测到设备长时间暂停",
      body: "所有在线设备已暂停超过10分钟，本次吸奶已自动结束。",
    };
  }
  return { title: "吸乳会话已结束", body: "本次吸乳已结束。" };
}

export function shouldShowPumpAutoEndReminder(input: {
  routePath: string;
  appVisible: boolean;
}): boolean {
  return !(input.routePath === "/pump" && input.appVisible);
}

function isAppVisible(): boolean {
  return document.visibilityState !== "hidden";
}

export function startPumpAutoEndOffPumpReminder(): void {
  if (typeof window === "undefined") return;
  pumpSessionLifecycle.subscribeEnded((evt: PumpSessionEndedEvent) => {
    if (!isAutoEndReason(evt.reason)) return;
    if (!shouldShowPumpAutoEndReminder({
      routePath: window.location.pathname,
      appVisible: isAppVisible(),
    })) return;
    registerPumpAutoEndOffPumpPending();
    if (window.location.pathname === "/") {
      void tryRunPumpAutoEndOffPumpTeardownOnce();
    }
    const { title, body } = copyFor(evt.reason);
    if (isAndroidNative) {
      void showPumpAutoEndLocalNotice({
        title,
        body,
        path: "/",
        autoEndTeardown: true,
      }).catch((error) => {
        log.warn("showPumpAutoEndLocalNotice failed", error);
        toast({ title, description: body });
      });
      return;
    }
    toast({ title, description: body });
  });
}
