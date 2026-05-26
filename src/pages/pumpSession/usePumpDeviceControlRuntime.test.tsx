import { afterEach, describe, expect, it, vi } from "vitest";
import { act, renderHook } from "@testing-library/react";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";
import { powerOffDeviceAndUpdateStore } from "@/lib/ble";
import { usePumpDeviceControlRuntime } from "./usePumpDeviceControlRuntime";
import type { SessionState, SideState } from "./pumpSessionModel";

vi.mock("@/lib/ble", () => ({
  ensureProtocolNotify: vi.fn(),
  isBleSupported: vi.fn(() => true),
  powerOffDeviceAndUpdateStore: vi.fn(),
  queryDeviceStatusAndUpdateStore: vi.fn(),
  sendB1SetPumpParams: vi.fn(),
  subscribeProtocolNotifications: vi.fn(() => vi.fn()),
}));

const sideState: SideState = {
  mode: "stimulate",
  gear: 3,
  flow: 0,
};

function storedDevice(patch: Partial<StoredDeviceInfo>): StoredDeviceInfo {
  return {
    deviceId: "left-device",
    deviceName: "Left",
    connected: true,
    battery: 90,
    flangeSize: 24,
    sealSize: "",
    model: "pump",
    firmware: "1.0",
    serialNumber: "sn",
    pumpMode: 0,
    gear: 3,
    pumpWorkState: 1,
    pumpScene: 1,
    duration: 321,
    milkMl: 12.3,
    moFlag: 1,
    milkFlag: 1,
    ...patch,
  };
}

describe("usePumpDeviceControlRuntime stopPumpWithBle", () => {
  afterEach(() => {
    deviceStore.setDevice("L", null);
    deviceStore.setDevice("R", null);
    vi.clearAllMocks();
  });

  it("sends FE power-off and keeps the last realtime duration after the response", async () => {
    deviceStore.setDevice("L", storedDevice({ duration: 321 }));
    vi.mocked(powerOffDeviceAndUpdateStore).mockImplementation(async () => {
      const current = deviceStore.get().L;
      if (current) deviceStore.setDevice("L", { ...current, finalMilkMl: 12.8 });
    });

    const { result } = renderHook(() =>
      usePumpDeviceControlRuntime({
        left: sideState,
        right: sideState,
        aiMode: true,
        enablePumpSessionMockEffects: false,
        sessionState: "running" as SessionState,
        setSessionState: vi.fn(),
        setLeft: vi.fn(),
        setRight: vi.fn(),
        setElapsed: vi.fn(),
        setAiMode: vi.fn(),
      }),
    );

    await act(async () => {
      await result.current.stopPumpWithBle();
    });

    const stopped = deviceStore.get().L;
    expect(powerOffDeviceAndUpdateStore).toHaveBeenCalledWith("left-device", "L");
    expect(stopped?.pumpWorkState).toBe(0);
    expect(stopped?.duration).toBe(321);
    expect(stopped?.finalMilkMl).toBe(12.8);
  });
});
