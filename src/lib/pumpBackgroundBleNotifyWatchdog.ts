import { Capacitor } from "@capacitor/core";
import {
  queryDeviceStatusAndUpdateStore,
  resetBleProtocolStateForDevice,
  subscribeProtocolNotifications,
} from "@/lib/ble";
import { deviceStore, type DeviceSide, type StoredDeviceInfo } from "@/lib/deviceStore";
import { createScopedConsole } from "@/lib/logger";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";

const log = createScopedConsole("PumpBackgroundBleNotifyWatchdog");

export const BACKGROUND_BLE_NOTIFY_STALE_MS = 8_000;
export const BACKGROUND_BLE_NOTIFY_WATCHDOG_INTERVAL_MS = 5_000;
const BACKGROUND_BLE_NOTIFY_RECOVERY_COOLDOWN_MS = 10_000;

type RecoverInput = {
  appVisible: boolean;
  connected: boolean;
  deviceId?: string | null;
  sessionActive: boolean;
  lastProcessTs?: string | null;
  nowMs: number;
  staleMs?: number;
};

export function shouldRecoverPumpBleNotify(input: RecoverInput): boolean {
  if (input.appVisible) return false;
  if (!input.sessionActive) return false;
  if (!input.connected || !input.deviceId) return false;

  const staleMs = input.staleMs ?? BACKGROUND_BLE_NOTIFY_STALE_MS;
  const parsed = input.lastProcessTs ? Date.parse(input.lastProcessTs) : NaN;
  if (!Number.isFinite(parsed)) return true;
  return input.nowMs - parsed >= staleMs;
}

const isAndroidNative = Capacitor.getPlatform() === "android";
let started = false;
let currentState: SessionState = pumpSessionLifecycle.getSessionState();
let appVisible = typeof document !== "undefined" ? document.visibilityState !== "hidden" : true;
const lastRecoveryAtByDevice = new Map<string, number>();
const recoveryInFlight = new Set<string>();
const watchdogUnsubBySide = new Map<DeviceSide, () => void>();

function isSessionActive(): boolean {
  return currentState === "running" || currentState === "paused";
}

function refreshAppVisibility(): void {
  appVisible = document.visibilityState !== "hidden";
}

function recoverSideNotify(side: DeviceSide, device: StoredDeviceInfo, nowMs: number): void {
  const deviceId = device.deviceId;
  if (!deviceId) return;
  if (recoveryInFlight.has(deviceId)) return;

  const lastRecoveryAt = lastRecoveryAtByDevice.get(deviceId) ?? 0;
  if (nowMs - lastRecoveryAt < BACKGROUND_BLE_NOTIFY_RECOVERY_COOLDOWN_MS) return;

  recoveryInFlight.add(deviceId);
  lastRecoveryAtByDevice.set(deviceId, nowMs);

  void (async () => {
    log.warn("recover stale background notify", {
      side,
      deviceId,
      lastDeviceProcessTs: device.lastDeviceProcessTs ?? null,
    });

    try {
      watchdogUnsubBySide.get(side)?.();
      watchdogUnsubBySide.delete(side);
    } catch {
      // Best effort cleanup before resetting protocol state.
    }

    try {
      resetBleProtocolStateForDevice(deviceId);
      const unsubscribe = subscribeProtocolNotifications(deviceId, () => {});
      watchdogUnsubBySide.set(side, unsubscribe);
      await queryDeviceStatusAndUpdateStore(deviceId, side).catch(() => {});
    } catch (error) {
      log.warn("recover stale background notify failed", { side, deviceId, error });
    } finally {
      recoveryInFlight.delete(deviceId);
    }
  })();
}

function checkOnce(): void {
  if (!isAndroidNative) return;
  refreshAppVisibility();
  const sessionActive = isSessionActive();
  const nowMs = Date.now();
  const snap = deviceStore.get();

  (["L", "R"] as const).forEach((side) => {
    const device = snap[side];
    if (!device) return;
    if (!shouldRecoverPumpBleNotify({
      appVisible,
      connected: !!device.connected,
      deviceId: device.deviceId,
      sessionActive,
      lastProcessTs: device.lastDeviceProcessTs,
      nowMs,
    })) {
      return;
    }
    recoverSideNotify(side, device, nowMs);
  });
}

export function startPumpBackgroundBleNotifyWatchdog(): void {
  if (started || !isAndroidNative) return;
  started = true;

  pumpSessionLifecycle.subscribe((next) => {
    currentState = next;
    checkOnce();
  });

  document.addEventListener("visibilitychange", checkOnce);
  window.addEventListener("pagehide", checkOnce);
  window.addEventListener("pageshow", checkOnce);

  window.setInterval(checkOnce, BACKGROUND_BLE_NOTIFY_WATCHDOG_INTERVAL_MS);
  checkOnce();
}
