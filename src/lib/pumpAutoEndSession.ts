/**
 * 吸乳会话自动结束（全离线 / 暂停超时）：非吸乳页系统通知、回智能体主页后的收尾（小结 + BLE），
 * 以及停止吸乳摘要写入对话（供非 PumpSession 挂载时调用）。
 *
 * 小结只应生成一次：registerPumpAutoEndOffPumpPending 在自动结束且非吸乳页时写入；
 * tryRunPumpAutoEndOffPumpTeardownOnce 在「已在智能体主页 / 之后进入主页 / 点击通知」三条路径上竞争 claim，先到先得。
 */

import { Capacitor, registerPlugin } from "@capacitor/core";
import { postPumpSessionSummaryWebSocket } from "@/lib/agentApi";
import {
  getAgentConversationIdForRequest,
  getAgUiThreadIdForRequest,
} from "@/lib/agentConversationSession";
import { chatStore } from "@/lib/chatStore";
import { savePersistedChatMessages } from "@/lib/chatMessagesLocalPersistence";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";
import { isBleSupported, powerOffDeviceAndUpdateStore } from "@/lib/ble";
import {
  getPumpAgentUploadProcessProgress,
  markPumpAgentUploadProcessStepStop,
  resetPumpAgentUploadProcessProgress,
  setPumpAgentUploadOperationSource,
} from "@/lib/pumpAgentUpload";
import { createScopedConsole, stringifyLogArg } from "@/lib/logger";
import {
  pumpSessionLifecycle,
  type PumpSessionEndedEvent,
  type PumpSessionEndReason,
} from "@/lib/pumpSessionLifecycle";
import { showPumpAutoEndLocalNotice } from "@/lib/pumpSessionNotification";
import { toast } from "@/components/ui/use-toast";
import type { ChatMessage } from "@/types/chat";
import type { PumpMilkUploadBody, PumpSessionSummaryBody, PumpSessionSummarySide } from "@/lib/agentApiTypes";
import { getRuntimeUserId } from "@/lib/debugUserConfig";
import { uploadPumpMilkRecord } from "@/lib/momPumpTwinAgentApi";

// ─── 吸乳小结写入对话 ─────────────────────────────────────────────
const CHAT_USER_ID = getRuntimeUserId(import.meta.env.VITE_DEFAULT_USER_ID as string | undefined);
const PUMP_SESSION_SUMMARY_WS_TIMEOUT_MS = 15000;

interface NativePumpAgentUploadPlugin {
  setConfig(options: { apiBaseUrl: string; bearerToken: string; userId: string }): Promise<void>;
  uploadMilkRecord(options: { userId: string; endedAtMs: number }): Promise<{ response?: { error?: number } }>;
}

const NativePumpAgentUpload = registerPlugin<NativePumpAgentUploadPlugin>("PumpAgentUpload");

function viteApiBaseUrl(): string {
  return (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim()) || "";
}

function viteApiToken(): string {
  return (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_TOKEN as string | undefined)?.trim()) || "";
}

export interface PumpStopSummaryOptions {
  displayedDurationSeconds?: number;
}

/** AgentHub 监听：外部写入 chatStore 后合并进 Hub 的 messages（与通知收尾一致） */
export const AGENT_HUB_SYNC_CHAT_EVENT = "mmc-agent-hub-sync-chat";

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

function displayedMilkMl(device: ReturnType<typeof deviceStore.get>["L"]): number {
  if (!device?.connected || typeof device.milkMl !== "number" || !Number.isFinite(device.milkMl)) return 0;
  return Math.max(0, Math.round(device.milkMl));
}

function displayedDurationSeconds(options?: PumpStopSummaryOptions | null): number | undefined {
  const n = options?.displayedDurationSeconds;
  if (typeof n !== "number" || !Number.isFinite(n)) return undefined;
  return Math.max(0, Math.round(n));
}

function buildPumpSessionSummarySide(
  side: DeviceSide,
  device: ReturnType<typeof deviceStore.get>["L"],
  process: number,
  options?: PumpStopSummaryOptions | null,
): PumpSessionSummarySide {
  const milk = displayedMilkMl(device);
  const duration = displayedDurationSeconds(options) ?? numberOrUndefined(device?.duration);
  const letdownCounts = pumpSessionLifecycle.getLetdownCounts();
  const letdownCount = side === "R" ? letdownCounts.R : letdownCounts.L;
  return {
    connected: Boolean(device?.connected),
    milk_ml: milk,
    process: Number.isFinite(process) ? Math.max(0, Math.min(100, Math.round(process))) : undefined,
    mode: modeName(device?.pumpMode),
    level: numberOrUndefined(device?.gear),
    duration_seconds: duration,
    has_milk: typeof device?.milkFlag === "number" ? Boolean(device.milkFlag & 0x01) : undefined,
    has_letdown: typeof device?.moFlag === "number" ? Boolean(device.moFlag & 0x01) : undefined,
    letdown_count: letdownCount,
  };
}

function buildPumpSessionSummaryBody(event?: PumpSessionEndedEvent | null, options?: PumpStopSummaryOptions | null): PumpSessionSummaryBody {
  const snap = deviceStore.get();
  const progress = getPumpAgentUploadProcessProgress();
  const endedAtMs = event?.at ?? Date.now();
  const left = buildPumpSessionSummarySide("L", snap.L, progress.processL, options);
  const right = buildPumpSessionSummarySide("R", snap.R, progress.processR, options);
  const leftMilk = left.milk_ml ?? 0;
  const rightMilk = right.milk_ml ?? 0;
  const leftDuration = left.duration_seconds ?? 0;
  const rightDuration = right.duration_seconds ?? 0;
  const displayedDuration = displayedDurationSeconds(options);
  const conversationId = getAgentConversationIdForRequest() || getAgUiThreadIdForRequest();

  return {
    user_id: CHAT_USER_ID,
    conversation_id: conversationId,
    ended_at: new Date(endedAtMs).toISOString(),
    end_reason: event?.reason ?? "unknown",
    process_all: Math.max(0, Math.min(100, Math.round(progress.processAll))),
    total_milk_ml: Math.max(0, Math.round((leftMilk + rightMilk) * 10) / 10),
    duration_seconds: displayedDuration ?? (Math.max(leftDuration, rightDuration) || undefined),
    event_id: `pump-summary-${endedAtMs}`,
    left,
    right,
  };
}

function formatPumpMilkTime(ms: number): string {
  const d = new Date(ms);
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

function buildPumpMilkUploadBody(event?: PumpSessionEndedEvent | null): PumpMilkUploadBody {
  const snap = deviceStore.get();
  const endedAtMs = event?.at ?? Date.now();
  const leftMilk = displayedMilkMl(snap.L);
  const rightMilk = displayedMilkMl(snap.R);
  return {
    user_id: CHAT_USER_ID,
    pump_type: 0,
    pump_source: 0,
    pump_time: formatPumpMilkTime(endedAtMs),
    pump_milk_volum: Math.max(0, Math.round((leftMilk + rightMilk) * 10) / 10),
  };
}

export async function pushPumpMilkUploadForPumpSessionEnd(event?: PumpSessionEndedEvent | null): Promise<void> {
  if (isAndroidNative) {
    const evt = event ?? pumpSessionLifecycle.getLastEndedEvent();
    await NativePumpAgentUpload.setConfig({
      apiBaseUrl: viteApiBaseUrl(),
      bearerToken: viteApiToken(),
      userId: CHAT_USER_ID,
    });
    const native = await NativePumpAgentUpload.uploadMilkRecord({
      userId: CHAT_USER_ID,
      endedAtMs: evt?.at ?? Date.now(),
    });
    const error = native.response?.error;
    if (typeof error === "number" && error !== 0) {
      throw new Error(`native pump milk upload error=${error}`);
    }
    return;
  }
  const body = buildPumpMilkUploadBody(event ?? pumpSessionLifecycle.getLastEndedEvent());
  log.log("[PUMP_MILK_UPLOAD] upload body", body);
  const response = await uploadPumpMilkRecord(body);
  if (typeof response?.error === "number" && response.error !== 0) {
    throw new Error(`pump milk upload error=${response.error}`);
  }
}

function logPumpSessionSummaryUploadBody(body: PumpSessionSummaryBody): void {
  if (Capacitor.isNativePlatform()) {
    globalThis.console?.warn?.("[PUMP_SESSION_SUMMARY] upload body", stringifyLogArg(body));
    return;
  }
  log.log("[PUMP_SESSION_SUMMARY] upload body", body);
}

function commitPumpSessionSummaryResponseToChat(
  response: Awaited<ReturnType<typeof postPumpSessionSummaryWebSocket>>,
  fallbackEventId: string | undefined,
): ChatMessage | null {
  const chatMessage = response.data?.chat_message;
  const content = typeof chatMessage?.content === "string" ? chatMessage.content.trim() : "";
  if (!content) return null;
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
  const existing = currentMsgs.find((m) => m.id === msg.id);
  if (existing) return existing;
  const nextMsgs = [...currentMsgs, msg];
  chatStore.setMessages(nextMsgs);
  void savePersistedChatMessages(nextMsgs);
  if (typeof window !== "undefined") {
    window.setTimeout(() => {
      window.dispatchEvent(new CustomEvent(AGENT_HUB_SYNC_CHAT_EVENT));
    }, 0);
  }
  return msg;
}

async function pushPumpSessionSummaryWebSocketToChat(
  event?: PumpSessionEndedEvent | null,
  options?: PumpStopSummaryOptions | null,
): Promise<ChatMessage | null> {
  const body = buildPumpSessionSummaryBody(event ?? pumpSessionLifecycle.getLastEndedEvent(), options);
  logPumpSessionSummaryUploadBody(body);
  const response = await postPumpSessionSummaryWebSocket(body, { timeoutMs: PUMP_SESSION_SUMMARY_WS_TIMEOUT_MS });
  if (typeof response.status === "number" && response.status !== 200) {
    throw new Error(response.message || `pump session summary status=${response.status}`);
  }
  if (typeof response.data?.error === "number" && response.data.error !== 0) {
    throw new Error(response.data.message || `pump session summary error=${response.data.error}`);
  }
  return commitPumpSessionSummaryResponseToChat(response, body.event_id);
}

export async function pushPumpStopAgentSummaryToChat(
  event?: PumpSessionEndedEvent | null,
  options?: PumpStopSummaryOptions | null,
): Promise<ChatMessage | null> {
  try {
    const summaryMessage = await pushPumpSessionSummaryWebSocketToChat(event, options);
    if (summaryMessage) return summaryMessage;
    console.warn("[pushPumpStopAgentSummaryToChat] summary ws returned empty content");
    toast({
      title: "吸奶小结生成失败",
      description: "本次吸奶已结束，但暂时没有生成小结内容。",
    });
  } catch (err) {
    console.error("[pushPumpStopAgentSummaryToChat] summary ws failed:", err);
    toast({
      title: "吸奶小结生成失败",
      description: "本次吸奶已结束，但小结服务暂时异常。",
    });
  }
  return null;
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
      await powerOffDeviceAndUpdateStore(it.deviceId, it.side);
    } catch (error) {
      console.error(`[endPumpBleForBothConnectedSides] FE failed side=${it.side}:`, error);
    }
  }
  resetPumpAgentUploadProcessProgress();
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
