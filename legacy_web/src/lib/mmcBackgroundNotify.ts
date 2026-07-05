import { Capacitor, registerPlugin } from "@capacitor/core";
import { createScopedConsole } from "@/lib/logger";

const log = createScopedConsole("BackgroundNotify");

interface BackgroundNotifyPlugin {
  setConfig(options: { apiBaseUrl: string; bearerToken: string; userId: string }): Promise<void>;
  setEnabled(options: { enabled: boolean }): Promise<void>;
  isEnabled(): Promise<{ enabled: boolean }>;
  syncNow(): Promise<void>;
  showReminder(options: {
    title: string;
    body: string;
    path: string;
    notifyJson?: string;
  }): Promise<void>;
  openExactAlarmSettings(): Promise<void>;
  openOverlaySettings(): Promise<void>;
  openBatteryOptimizationSettings(): Promise<void>;
  openAppNotificationSettings(): Promise<void>;
  isIgnoringBatteryOptimizations(): Promise<{ ignoring: boolean }>;
  canDrawOverlays(): Promise<{ granted: boolean }>;
  canScheduleExactAlarms(): Promise<{ granted: boolean }>;
}

const BackgroundNotify = registerPlugin<BackgroundNotifyPlugin>("BackgroundNotify");

const isAndroid = () => Capacitor.getPlatform() === "android";

function viteApiBaseUrl(): string {
  return (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim()) || "";
}

function viteApiToken(): string {
  return (typeof import.meta !== "undefined" && (import.meta.env.VITE_API_TOKEN as string | undefined)?.trim()) || "";
}

/** 将原生 WorkManager 使用的 API 根地址与鉴权与 Web 层对齐。 */
export async function syncNativeBackgroundNotifyConfig(userId: string): Promise<void> {
  if (!isAndroid()) return;
  const uid = String(userId ?? "").trim();
  if (!uid) return;
  try {
    await BackgroundNotify.setConfig({
      apiBaseUrl: viteApiBaseUrl(),
      bearerToken: viteApiToken(),
      userId: uid,
    });
  } catch (e) {
    log.warn("setConfig failed", e);
  }
}

export async function setNativeBackgroundNotifyEnabled(userId: string, enabled: boolean): Promise<void> {
  if (!isAndroid()) return;
  try {
    await syncNativeBackgroundNotifyConfig(userId);
    await BackgroundNotify.setEnabled({ enabled });
  } catch (e) {
    log.warn("setEnabled failed", e);
  }
}

export async function getNativeBackgroundNotifyEnabled(): Promise<boolean> {
  if (!isAndroid()) return false;
  try {
    const r = await BackgroundNotify.isEnabled();
    return !!r.enabled;
  } catch {
    return false;
  }
}

export async function requestNativeNotifySyncNow(): Promise<void> {
  if (!isAndroid()) return;
  try {
    await BackgroundNotify.syncNow();
  } catch (e) {
    log.warn("syncNow failed", e);
  }
}

export async function showNativeReminder(options: {
  title: string;
  body: string;
  path?: string;
  notifyJson?: string;
}): Promise<void> {
  if (!isAndroid()) return;
  try {
    await BackgroundNotify.showReminder({
      title: options.title,
      body: options.body,
      path: options.path ?? "/",
      notifyJson: options.notifyJson,
    });
  } catch (e) {
    log.warn("showReminder failed", e);
    throw e;
  }
}

export async function openNativeExactAlarmSettings(): Promise<void> {
  if (!isAndroid()) return;
  try {
    await BackgroundNotify.openExactAlarmSettings();
  } catch (e) {
    log.warn("openExactAlarmSettings failed", e);
  }
}

export async function openNativeOverlaySettings(): Promise<void> {
  if (!isAndroid()) return;
  try {
    await BackgroundNotify.openOverlaySettings();
  } catch (e) {
    log.warn("openOverlaySettings failed", e);
  }
}

export async function openNativeBatteryOptimizationSettings(): Promise<void> {
  if (!isAndroid()) return;
  try {
    await BackgroundNotify.openBatteryOptimizationSettings();
  } catch (e) {
    log.warn("openBatteryOptimizationSettings failed", e);
  }
}

export async function openNativeAppNotificationSettings(): Promise<void> {
  if (!isAndroid()) return;
  try {
    await BackgroundNotify.openAppNotificationSettings();
  } catch (e) {
    log.warn("openAppNotificationSettings failed", e);
  }
}

export async function getNativeCanScheduleExactAlarms(): Promise<boolean> {
  if (!isAndroid()) return true;
  try {
    const r = await BackgroundNotify.canScheduleExactAlarms();
    return !!r.granted;
  } catch {
    return true;
  }
}

export async function getNativeCanDrawOverlays(): Promise<boolean> {
  if (!isAndroid()) return true;
  try {
    const r = await BackgroundNotify.canDrawOverlays();
    return !!r.granted;
  } catch {
    return true;
  }
}

export async function getNativeIgnoringBatteryOptimizations(): Promise<boolean> {
  if (!isAndroid()) return true;
  try {
    const r = await BackgroundNotify.isIgnoringBatteryOptimizations();
    return !!r.ignoring;
  } catch {
    return true;
  }
}
