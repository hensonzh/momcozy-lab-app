import { afterEach, describe, expect, it, vi } from "vitest";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";
import {
  setBleAutoReconnectPaused,
  tryReconnectOfflineDevices,
} from "@/lib/reconnectOfflineDevices";
import { startLEScan } from "@/lib/ble";

vi.mock("@/lib/ble", () => ({
  initializeBle: vi.fn(() => Promise.resolve()),
  connect: vi.fn(() => Promise.resolve()),
  resetBleProtocolStateForDevice: vi.fn(),
  configurePumpAfterBleConnect: vi.fn(() => Promise.resolve()),
  startLEScan: vi.fn(() => Promise.resolve()),
  stopLEScan: vi.fn(() => Promise.resolve()),
}));

vi.mock("@/lib/deviceInfoReport", () => ({
  reportDeviceInfoAfterProtocolConfigured: vi.fn(),
}));

function storedDevice(patch: Partial<StoredDeviceInfo> = {}): StoredDeviceInfo {
  return {
    deviceId: "bound-device",
    deviceName: "LT_TEST_L",
    connected: false,
    battery: 0,
    flangeSize: 24,
    sealSize: "M",
    model: "LT_TEST_L",
    firmware: "-",
    serialNumber: "bound-device",
    ...patch,
  };
}

describe("tryReconnectOfflineDevices", () => {
  afterEach(() => {
    setBleAutoReconnectPaused(false);
    deviceStore.setDevice("L", null);
    deviceStore.setDevice("R", null);
    vi.clearAllMocks();
  });

  it("does not start automatic reconnect scanning while reconnect is paused", () => {
    deviceStore.setDevice("L", storedDevice());
    setBleAutoReconnectPaused(true);

    tryReconnectOfflineDevices({ onlyOffline: true });

    expect(startLEScan).not.toHaveBeenCalled();
  });
});
