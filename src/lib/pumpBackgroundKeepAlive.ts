import { Capacitor, registerPlugin } from "@capacitor/core";
import { createScopedConsole } from "@/lib/logger";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";

const log = createScopedConsole("PumpBackgroundKeepAlive");

export const PUMP_BACKGROUND_WAKE_LOCK_MS = 60_000;

interface PumpSessionKeepAlivePlugin {
  acquire(options: { timeoutMs: number }): Promise<void>;
  release(): Promise<void>;
}

const PumpSessionKeepAlive = registerPlugin<PumpSessionKeepAlivePlugin>("PumpSessionKeepAlive");

export type PumpBackgroundKeepAliveAction =
  | { type: "acquire"; timeoutMs: number }
  | { type: "release" }
  | { type: "none" };

export function resolvePumpBackgroundKeepAliveAction(input: {
  isAndroidNative: boolean;
  appVisible: boolean;
  state: SessionState;
}): PumpBackgroundKeepAliveAction {
  if (!input.isAndroidNative) return { type: "none" };
  if (!input.appVisible && (input.state === "running" || input.state === "paused")) {
    return { type: "acquire", timeoutMs: PUMP_BACKGROUND_WAKE_LOCK_MS };
  }
  return { type: "release" };
}

const isAndroidNative = Capacitor.getPlatform() === "android";
let started = false;
let currentState: SessionState = pumpSessionLifecycle.getSessionState();
let wakeLockHeld = false;

function readAppVisible(): boolean {
  if (typeof document === "undefined") return true;
  return document.visibilityState !== "hidden";
}

function syncKeepAlive(): void {
  const action = resolvePumpBackgroundKeepAliveAction({
    isAndroidNative,
    appVisible: readAppVisible(),
    state: currentState,
  });

  if (action.type === "none") return;

  if (action.type === "acquire") {
    if (wakeLockHeld) return;
    wakeLockHeld = true;
    PumpSessionKeepAlive.acquire({ timeoutMs: action.timeoutMs }).catch((error) => {
      wakeLockHeld = false;
      log.warn("acquire wake lock failed", error);
    });
    return;
  }

  if (!wakeLockHeld) return;
  wakeLockHeld = false;
  PumpSessionKeepAlive.release().catch((error) => {
    log.warn("release wake lock failed", error);
  });
}

export function startPumpBackgroundKeepAliveBridge(): void {
  if (started || !isAndroidNative) return;
  started = true;

  pumpSessionLifecycle.subscribe((next) => {
    currentState = next;
    syncKeepAlive();
  });

  document.addEventListener("visibilitychange", syncKeepAlive);
  window.addEventListener("pagehide", syncKeepAlive);
  window.addEventListener("pageshow", syncKeepAlive);
  syncKeepAlive();
}
