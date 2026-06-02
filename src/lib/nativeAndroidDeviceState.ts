import { Capacitor, registerPlugin, type PluginListenerHandle } from "@capacitor/core";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";
import { createScopedConsole } from "@/lib/logger";

declare global {
  interface Window {
    MmcNativeDeviceState?: {
      updateSnapshotJson?: (snapshotJson: string) => void;
      getSnapshotJson?: () => string;
      clearSnapshot?: () => void;
    };
  }
}

interface NativeDeviceSnapshot {
  L: StoredDeviceInfo | null;
  R: StoredDeviceInfo | null;
}

interface NativeDeviceStatePlugin {
  addListener(
    eventName: "nativeDeviceStateChanged",
    listenerFunc: (event: { snapshotJson?: string }) => void,
  ): Promise<PluginListenerHandle>;
}

const log = createScopedConsole("NativeDeviceState");
const MmcBleState = registerPlugin<NativeDeviceStatePlugin>("MmcBle");
let started = false;
let lastSnapshotJson = "";

function getBridge() {
  return typeof window !== "undefined" ? window.MmcNativeDeviceState : undefined;
}

function readNativeSnapshot(): NativeDeviceSnapshot | null {
  const raw = getBridge()?.getSnapshotJson?.();
  return parseSnapshotJson(raw);
}

function parseSnapshotJson(raw: string | undefined): NativeDeviceSnapshot | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<NativeDeviceSnapshot>;
    return {
      L: parsed.L ?? null,
      R: parsed.R ?? null,
    };
  } catch (error) {
    log.warn("read native snapshot failed", error);
    return null;
  }
}

function writeNativeSnapshot(): void {
  const bridge = getBridge();
  if (!bridge?.updateSnapshotJson) return;
  const snapshotJson = JSON.stringify(deviceStore.get());
  if (snapshotJson === lastSnapshotJson) return;
  lastSnapshotJson = snapshotJson;
  bridge.updateSnapshotJson(snapshotJson);
}

export function startNativeAndroidDeviceStateBridge(): void {
  if (started) return;
  if (Capacitor.getPlatform() !== "android") return;
  started = true;

  const nativeSnapshot = readNativeSnapshot();
  if (nativeSnapshot && (nativeSnapshot.L || nativeSnapshot.R)) {
    deviceStore.replaceSnapshot(nativeSnapshot);
  }

  writeNativeSnapshot();
  deviceStore.subscribe(writeNativeSnapshot);
  void MmcBleState.addListener("nativeDeviceStateChanged", (event) => {
    const nativeSnapshot = parseSnapshotJson(event.snapshotJson);
    if (!nativeSnapshot) return;
    lastSnapshotJson = event.snapshotJson ?? "";
    deviceStore.replaceSnapshot(nativeSnapshot);
  }).catch((error) => {
    log.warn("subscribe native state failed", error);
  });
}

export function clearNativeAndroidDeviceStateSnapshot(): void {
  getBridge()?.clearSnapshot?.();
  lastSnapshotJson = "";
}

export {};
