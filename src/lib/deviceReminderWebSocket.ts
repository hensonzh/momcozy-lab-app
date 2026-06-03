import { Capacitor, registerPlugin } from "@capacitor/core";
import type { PluginListenerHandle } from "@capacitor/core";
import { executeDeviceReminderAction, type DeviceReminderActionKey } from "@/lib/deviceReminderActions";
import { recordMilkAnalysisContextEvent } from "@/lib/analysisContextEvents";
import { appendAgentHubAnalysisMessage } from "@/lib/agentHubChatMessages";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { getRuntimeUserId } from "@/lib/debugUserConfig";
import { createScopedConsole } from "@/lib/logger";
import { markStatusGrowthHighlightPending } from "@/lib/statusGrowthHighlight";

export type DeviceReminderWebSocketReminderType =
  | "task_reminder"
  | "lactation_feeding_reminder"
  | "daily_summary_reminder"
  | "milk_analysis_reminder"
  | "baby_growth_update_reminder";

const DEVICE_REMINDER_WS_URL = "ws://192.168.204.127:8767/api/ws?token=websocket-token";
const RECONNECT_DELAYS_MS = [1000, 3000, 5000, 10000, 15000];

const log = createScopedConsole("DeviceReminderWebSocket");

interface DeviceReminderWebSocketPlugin {
  start(options: { wsUrl: string; apiBaseUrl: string; bearerToken: string; userId: string }): Promise<void>;
  stop(): Promise<void>;
  addListener(
    eventName: "deviceReminderHandled",
    listenerFunc: (event: { reminderType?: string; actionKey?: string; notifyJson?: string }) => void,
  ): Promise<PluginListenerHandle>;
}

const NativeDeviceReminderWebSocket =
  registerPlugin<DeviceReminderWebSocketPlugin>("DeviceReminderWebSocket");

const reminderTypeToActionKey: Record<DeviceReminderWebSocketReminderType, DeviceReminderActionKey> = {
  task_reminder: "task_reminder",
  lactation_feeding_reminder: "mom_baby",
  daily_summary_reminder: "daily_summary",
  milk_analysis_reminder: "milk_analysis",
  baby_growth_update_reminder: "growth_update",
};

function envValue(key: keyof ImportMetaEnv): string {
  return (typeof import.meta !== "undefined" && (import.meta.env[key] as string | undefined)?.trim()) || "";
}

function currentRuntimeUserId(): string {
  return getRuntimeUserId(envValue("VITE_DEFAULT_USER_ID"));
}

function appendUserIdToWebSocketUrl(rawUrl: string, userId: string): string {
  const trimmedUrl = rawUrl.trim();
  const trimmedUserId = userId.trim();
  if (!trimmedUrl || !trimmedUserId) return trimmedUrl;
  try {
    const url = new URL(trimmedUrl);
    url.searchParams.set("user_id", trimmedUserId);
    return url.toString();
  } catch {
    const separator = trimmedUrl.includes("?") ? "&" : "?";
    return `${trimmedUrl}${separator}user_id=${encodeURIComponent(trimmedUserId)}`;
  }
}

function handleNativeReminderHandled(event: { notifyJson?: string }): void {
  const raw = typeof event.notifyJson === "string" ? event.notifyJson.trim() : "";
  if (!raw) return;
  try {
    const payload = JSON.parse(raw) as {
      event?: string;
      body?: string;
      chatMessageId?: string;
      analysis_card?: AgentAnalysisCard;
    };
    const analysisKind =
      payload.event === "summary"
        ? "daily_summary"
        : payload.event === "mom_baby"
          ? "mom_baby"
          : payload.event === "milk_analysis"
            ? "milk_analysis"
            : null;
    if (analysisKind && typeof payload.body === "string" && payload.body.trim()) {
      appendAgentHubAnalysisMessage(payload.body, {
        kind: analysisKind,
        id: payload.chatMessageId,
        analysisCard: payload.analysis_card,
      });
      if (analysisKind === "milk_analysis") {
        void recordMilkAnalysisContextEvent({
          message: payload.body,
          analysisCard: payload.analysis_card,
          chatMessageId: payload.chatMessageId,
        });
      }
    } else if (payload.event === "grown") {
      markStatusGrowthHighlightPending();
    }
  } catch (error) {
    log.warn("parse native reminder notifyJson failed", error);
  }
}

export function startDeviceReminderWebSocket(): () => void {
  if (Capacitor.getPlatform() === "android") {
    let disposed = false;
    let listener: PluginListenerHandle | null = null;

    void NativeDeviceReminderWebSocket.addListener("deviceReminderHandled", handleNativeReminderHandled)
      .then((handle) => {
        if (disposed) {
          void handle.remove();
          return;
        }
        listener = handle;
      })
      .catch((error) => log.warn("add native listener failed", error));

    const userId = currentRuntimeUserId();
    void NativeDeviceReminderWebSocket.start({
      wsUrl: appendUserIdToWebSocketUrl(envValue("VITE_DEVICE_REMINDER_WS_URL") || DEVICE_REMINDER_WS_URL, userId),
      apiBaseUrl: envValue("VITE_API_BASE_URL"),
      bearerToken: envValue("VITE_API_TOKEN"),
      userId,
    }).catch((error) => log.warn("start native websocket service failed", error));

    return () => {
      disposed = true;
      void listener?.remove();
    };
  }

  return startWebDeviceReminderWebSocket();
}

function startWebDeviceReminderWebSocket(): () => void {
  if (typeof window === "undefined" || typeof WebSocket === "undefined") return () => {};

  let stopped = false;
  let ws: WebSocket | null = null;
  let reconnectTimer: number | null = null;
  let reconnectAttempt = 0;
  let queue = Promise.resolve();

  const cleanupReconnectTimer = (): void => {
    if (reconnectTimer == null) return;
    window.clearTimeout(reconnectTimer);
    reconnectTimer = null;
  };

  const scheduleReconnect = (): void => {
    if (stopped || reconnectTimer != null) return;
    const delay = RECONNECT_DELAYS_MS[Math.min(reconnectAttempt, RECONNECT_DELAYS_MS.length - 1)];
    reconnectAttempt += 1;
    reconnectTimer = window.setTimeout(() => {
      reconnectTimer = null;
      connect();
    }, delay);
  };

  const handlePayload = (payload: unknown): void => {
    const reminderType = findReminderType(payload);
    if (!reminderType) {
      log.warn("ignore message without supported reminder_type", payload);
      return;
    }

    const actionKey = reminderTypeToActionKey[reminderType];
    queue = queue
      .then(() => executeDeviceReminderAction(actionKey))
      .catch((error) => {
        log.warn("execute reminder action failed", { reminderType, actionKey, error });
      });
  };

  function connect(): void {
    if (stopped) return;
    try {
      ws = new WebSocket(
        appendUserIdToWebSocketUrl(envValue("VITE_DEVICE_REMINDER_WS_URL") || DEVICE_REMINDER_WS_URL, currentRuntimeUserId()),
      );
    } catch (error) {
      log.warn("create websocket failed", error);
      scheduleReconnect();
      return;
    }

    ws.onopen = () => {
      reconnectAttempt = 0;
      log.log("connected");
    };

    ws.onmessage = (event) => {
      if (typeof event.data !== "string") {
        log.warn("ignore non-string websocket message");
        return;
      }
      try {
        handlePayload(parseJsonFrame(event.data));
      } catch (error) {
        log.warn("parse websocket message failed", error);
      }
    };

    ws.onerror = (error) => {
      log.warn("websocket error", error);
    };

    ws.onclose = (event) => {
      if (ws && ws.readyState === WebSocket.CLOSED) ws = null;
      if (!stopped) {
        log.warn("websocket closed", { code: event.code, reason: event.reason });
        scheduleReconnect();
      }
    };
  }

  connect();

  return () => {
    stopped = true;
    cleanupReconnectTimer();
    if (ws && (ws.readyState === WebSocket.CONNECTING || ws.readyState === WebSocket.OPEN)) {
      ws.close(1000, "app teardown");
    }
    ws = null;
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function parseJsonFrame(raw: string): unknown {
  const text = raw.trim();
  if (!text) return null;
  if (!text.startsWith("data:")) return JSON.parse(text);

  const payload = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith("data:"))
    .map((line) => line.slice("data:".length).trim())
    .join("\n")
    .trim();
  if (!payload || payload === "[DONE]") return null;
  return JSON.parse(payload);
}

function findReminderType(payload: unknown): DeviceReminderWebSocketReminderType | null {
  if (Array.isArray(payload)) {
    for (const item of payload) {
      const reminderType = findReminderType(item);
      if (reminderType) return reminderType;
    }
    return null;
  }

  if (!isRecord(payload)) return null;
  const value = payload.reminder_type;
  if (typeof value === "string" && value in reminderTypeToActionKey) {
    return value as DeviceReminderWebSocketReminderType;
  }

  for (const key of ["data", "payload", "message", "body"]) {
    const reminderType = findReminderType(payload[key]);
    if (reminderType) return reminderType;
  }
  return null;
}
