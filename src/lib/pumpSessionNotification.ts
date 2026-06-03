import { Capacitor } from "@capacitor/core";
import { createScopedConsole } from "@/lib/logger";
import { getProcessAll, subscribeProcessAll } from "@/lib/pumpSessionProgress";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";
import { getNativeAndroidPumpSessionBridge } from "@/lib/nativeAndroidPumpSession";

const log = createScopedConsole("PumpSessionNotification");

const isAndroidNative = Capacitor.getPlatform() === "android";

let started = false;
let currentState: SessionState = pumpSessionLifecycle.getSessionState();
let lastProcessAll = clampPct(getProcessAll());
let permissionChecked = false;

function clampPct(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
}

function canNotifyState(state: SessionState): state is "running" | "paused" {
  return state === "running" || state === "paused";
}

async function ensurePermissionIfNeeded(): Promise<boolean> {
  if (permissionChecked) return true;
  permissionChecked = true;
  try {
    const granted = getNativeAndroidPumpSessionBridge()?.hasPostNotificationsPermission?.() ?? false;
    if (!granted) {
      log.warn("notification permission denied, skip foreground notification");
      return false;
    }
  } catch (error) {
    log.warn("request notification permission failed", error);
    return false;
  }
  return true;
}

async function syncNotification(): Promise<void> {
  if (!isAndroidNative) return;
  if (!canNotifyState(currentState)) {
    try {
      getNativeAndroidPumpSessionBridge()?.stopSession?.();
    } catch (error) {
      log.warn("stop notification failed", error);
    }
    return;
  }

  const allowed = await ensurePermissionIfNeeded();
  if (!allowed) return;
  try {
    getNativeAndroidPumpSessionBridge()?.updateSession?.(currentState, lastProcessAll);
  } catch (error) {
    log.warn("start/update notification failed", error);
  }
}

/** 吸乳进度 100% 完成提醒：独立可清除通知（与前台进度通知分离）。 */
export async function showPumpCompletionLocalNotice(): Promise<void> {
  if (!isAndroidNative) return;
  try {
    getNativeAndroidPumpSessionBridge()?.showCompletionNotice?.();
  } catch (error) {
    log.warn("showCompletionNotice failed", error);
    throw error;
  }
}

export type PumpNotificationPending = {
  path: string | null;
  autoEndTeardown: boolean;
  /** 原生后台提醒带给 Web 的 JSON（如每日奶量总结）。 */
  notifyJson: string | null;
};

/** 从通知 Intent 带来的一次性 Web 路由与是否需在进首页后执行自动结束收尾（仅 Android）。 */
export async function consumePumpNotificationPending(): Promise<PumpNotificationPending> {
  if (!isAndroidNative) return { path: null, autoEndTeardown: false, notifyJson: null };
  try {
    const raw = getNativeAndroidPumpSessionBridge()?.consumePendingNavigateJson?.() ?? "{}";
    const r = JSON.parse(raw) as { path?: string; autoEndTeardown?: boolean; notifyJson?: string };
    const p = typeof r.path === "string" ? r.path.trim() : "";
    const nj = typeof r.notifyJson === "string" ? r.notifyJson.trim() : "";
    return {
      path: p.length > 0 ? p : null,
      autoEndTeardown: !!r.autoEndTeardown,
      notifyJson: nj.length > 0 ? nj : null,
    };
  } catch (error) {
    log.warn("consumePendingNavigate failed", error);
    return { path: null, autoEndTeardown: false, notifyJson: null };
  }
}

/** @deprecated 请使用 consumePumpNotificationPending；保留供仅需 path 的调用方。 */
export async function consumePumpNotificationNavigatePath(): Promise<string | null> {
  const r = await consumePumpNotificationPending();
  return r.path;
}

/** 申请 Android 13+ 通知权限（与吸乳前台通知共用）。 */
export async function requestAndroidPostNotificationsPermission(): Promise<boolean> {
  if (!isAndroidNative) return true;
  try {
    return !!getNativeAndroidPumpSessionBridge()?.hasPostNotificationsPermission?.();
  } catch (error) {
    log.warn("requestPermission failed", error);
    return false;
  }
}

/** 自动结束吸乳：可清除本地消息，点击进 path（默认 /）并可触发 Web 收尾。 */
export async function showPumpAutoEndLocalNotice(options: {
  title: string;
  body: string;
  path?: string;
  autoEndTeardown?: boolean;
}): Promise<void> {
  if (!isAndroidNative) return;
  const allowed = await ensurePermissionIfNeeded();
  if (!allowed) {
    log.warn("skip auto-end notice: notification permission not granted");
    throw new Error("PumpAutoEndNotice: notification permission denied");
  }
  try {
    getNativeAndroidPumpSessionBridge()?.showAutoEndNotice?.(
      options.title,
      options.body,
      options.path ?? "/",
      options.autoEndTeardown !== false,
    );
  } catch (error) {
    log.warn("showAutoEndNotice failed", error);
    throw error;
  }
}

export function startPumpSessionNotificationBridge(): void {
  if (started || !isAndroidNative) return;
  started = true;

  void syncNotification();
  pumpSessionLifecycle.subscribe((next) => {
    currentState = next;
    void syncNotification();
  });

  subscribeProcessAll(() => {
    lastProcessAll = clampPct(getProcessAll());
    if (!canNotifyState(currentState)) return;
    try {
      getNativeAndroidPumpSessionBridge()?.updateSession?.(currentState, lastProcessAll);
    } catch (error) {
      log.warn("notification progress update failed", error);
    }
  });
}
