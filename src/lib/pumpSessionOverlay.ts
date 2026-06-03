import React from "react";
import { Capacitor } from "@capacitor/core";
import { ToastAction } from "@/components/ui/toast";
import { toast } from "@/components/ui/use-toast";
import { createScopedConsole } from "@/lib/logger";
import { getProcessAll, subscribeProcessAll } from "@/lib/pumpSessionProgress";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";
import { getNativeAndroidPumpSessionBridge } from "@/lib/nativeAndroidPumpSession";

const log = createScopedConsole("PumpSessionOverlay");

type OverlayPlatform = "android" | "ios" | "web" | string;

export type PumpOverlaySyncAction =
  | { type: "update"; state: "running" | "paused"; processAll: number }
  | { type: "hide" }
  | { type: "skip" };

export function clampPumpOverlayProgress(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

export function buildPumpOverlaySyncAction(input: {
  platform: OverlayPlatform;
  permissionGranted: boolean;
  state: SessionState;
  processAll: number;
  routePath: string;
  appVisible: boolean;
}): PumpOverlaySyncAction {
  if (input.platform !== "android") return { type: "skip" };
  if (!input.permissionGranted) return { type: "skip" };
  if (input.routePath === "/pump" && input.appVisible) return { type: "hide" };
  if (input.state === "running" || input.state === "paused") {
    return {
      type: "update",
      state: input.state,
      processAll: clampPumpOverlayProgress(input.processAll),
    };
  }
  return { type: "hide" };
}

const isAndroidNative = Capacitor.getPlatform() === "android";

let started = false;
let currentState: SessionState = pumpSessionLifecycle.getSessionState();
let currentProcessAll = clampPumpOverlayProgress(getProcessAll());
let currentRoutePath = typeof window !== "undefined" ? window.location.pathname : "/";
let currentAppVisible = typeof document !== "undefined" ? document.visibilityState !== "hidden" : true;
let permissionGranted = false;
let permissionChecked = false;
let permissionToastShown = false;
let lastNativeSnapshotKey = "";

function refreshCurrentRoutePath(): void {
  currentRoutePath = window.location.pathname;
}

function refreshCurrentAppVisibility(): void {
  currentAppVisible = document.visibilityState !== "hidden";
}

async function refreshOverlayPermission(): Promise<boolean> {
  if (!isAndroidNative) return false;
  try {
    permissionGranted = !!getNativeAndroidPumpSessionBridge()?.canDrawOverlays?.();
    permissionChecked = true;
    return permissionGranted;
  } catch (error) {
    log.warn("canDrawOverlays failed", error);
    permissionChecked = true;
    permissionGranted = false;
    return false;
  }
}

function showPermissionToastOnce(): void {
  if (permissionToastShown) return;
  permissionToastShown = true;
  toast({
    title: "开启吸乳悬浮进度条",
    description: "授权“显示在其他应用上层”后，吸乳进度可在其他 App 上方显示。",
    action: React.createElement(
      ToastAction,
      {
        altText: "去开启",
        onClick: () => {
            try {
              getNativeAndroidPumpSessionBridge()?.openOverlaySettings?.();
            } catch (error) {
              log.warn("openOverlaySettings failed", error);
            }
        },
      },
      "去开启",
    ),
  });
}

async function syncNativeOverlaySnapshot(): Promise<void> {
  if (!isAndroidNative) return;
  const snapshotKey = `${currentState}|${currentProcessAll}`;
  if (snapshotKey === lastNativeSnapshotKey) return;
  lastNativeSnapshotKey = snapshotKey;
  try {
    getNativeAndroidPumpSessionBridge()?.updateSession?.(currentState, currentProcessAll);
  } catch (error) {
    lastNativeSnapshotKey = "";
    log.warn("snapshot overlay state failed", error);
  }
}

async function syncOverlay(): Promise<void> {
  if (!isAndroidNative) return;

  await syncNativeOverlaySnapshot();

  if (!permissionChecked) {
    await refreshOverlayPermission();
  }

  if (!permissionGranted) {
    if (currentState === "running" || currentState === "paused") {
      showPermissionToastOnce();
    }
    return;
  }

  const action = buildPumpOverlaySyncAction({
    platform: "android",
    permissionGranted,
    state: currentState,
    processAll: currentProcessAll,
    routePath: currentRoutePath,
    appVisible: currentAppVisible,
  });

  try {
    if (action.type === "update") {
      getNativeAndroidPumpSessionBridge()?.updateSession?.(action.state, action.processAll);
    } else if (action.type === "hide") {
      if (currentState === "running" || currentState === "paused") {
        getNativeAndroidPumpSessionBridge()?.updateSession?.(currentState, currentProcessAll);
      } else {
        getNativeAndroidPumpSessionBridge()?.stopSession?.();
      }
    }
  } catch (error) {
    log.warn("sync overlay failed", error);
  }
}

export function startPumpSessionOverlayBridge(): void {
  if (started || !isAndroidNative) return;
  started = true;

  const refreshOnFocus = () => {
    refreshCurrentRoutePath();
    refreshCurrentAppVisibility();
    permissionChecked = false;
    void syncOverlay();
  };

  const syncAppVisibilityChange = () => {
    refreshCurrentRoutePath();
    refreshCurrentAppVisibility();
    void syncOverlay();
  };

  const syncRouteChange = () => {
    refreshCurrentRoutePath();
    refreshCurrentAppVisibility();
    void syncOverlay();
  };

  window.addEventListener("focus", refreshOnFocus);
  document.addEventListener("visibilitychange", syncAppVisibilityChange);
  window.addEventListener("pagehide", syncAppVisibilityChange);
  window.addEventListener("pageshow", refreshOnFocus);
  window.addEventListener("popstate", syncRouteChange);
  window.addEventListener("hashchange", syncRouteChange);

  const originalPushState = window.history.pushState.bind(window.history);
  const originalReplaceState = window.history.replaceState.bind(window.history);
  window.history.pushState = (...args) => {
    const result = originalPushState(...args);
    window.setTimeout(syncRouteChange, 0);
    return result;
  };
  window.history.replaceState = (...args) => {
    const result = originalReplaceState(...args);
    window.setTimeout(syncRouteChange, 0);
    return result;
  };

  void syncOverlay();
  pumpSessionLifecycle.subscribe((next) => {
    currentState = next;
    void syncOverlay();
  });
  subscribeProcessAll(() => {
    currentProcessAll = clampPumpOverlayProgress(getProcessAll());
    if (currentState !== "running" && currentState !== "paused") return;
    void syncOverlay();
  });
}
