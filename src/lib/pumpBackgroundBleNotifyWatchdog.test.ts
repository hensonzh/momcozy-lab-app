import { describe, expect, test } from "vitest";
import { shouldRecoverPumpBleNotify } from "@/lib/pumpBackgroundBleNotifyWatchdog";

describe("shouldRecoverPumpBleNotify", () => {
  test("recovers only active connected devices while the app is backgrounded", () => {
    expect(shouldRecoverPumpBleNotify({
      appVisible: false,
      connected: true,
      deviceId: "device-1",
      sessionActive: true,
      lastProcessTs: new Date(10_000).toISOString(),
      nowMs: 20_000,
      staleMs: 8_000,
    })).toBe(true);

    expect(shouldRecoverPumpBleNotify({
      appVisible: true,
      connected: true,
      deviceId: "device-1",
      sessionActive: true,
      lastProcessTs: new Date(10_000).toISOString(),
      nowMs: 20_000,
      staleMs: 8_000,
    })).toBe(false);
  });

  test("does not recover fresh or disconnected devices", () => {
    expect(shouldRecoverPumpBleNotify({
      appVisible: false,
      connected: true,
      deviceId: "device-1",
      sessionActive: true,
      lastProcessTs: new Date(15_000).toISOString(),
      nowMs: 20_000,
      staleMs: 8_000,
    })).toBe(false);

    expect(shouldRecoverPumpBleNotify({
      appVisible: false,
      connected: false,
      deviceId: "device-1",
      sessionActive: true,
      lastProcessTs: new Date(10_000).toISOString(),
      nowMs: 20_000,
      staleMs: 8_000,
    })).toBe(false);
  });

  test("treats a missing process timestamp as stale once background active", () => {
    expect(shouldRecoverPumpBleNotify({
      appVisible: false,
      connected: true,
      deviceId: "device-1",
      sessionActive: true,
      lastProcessTs: "",
      nowMs: 20_000,
      staleMs: 8_000,
    })).toBe(true);
  });
});
