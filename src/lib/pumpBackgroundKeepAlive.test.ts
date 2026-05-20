import { describe, expect, test } from "vitest";
import {
  PUMP_BACKGROUND_WAKE_LOCK_MS,
  resolvePumpBackgroundKeepAliveAction,
} from "@/lib/pumpBackgroundKeepAlive";

describe("resolvePumpBackgroundKeepAliveAction", () => {
  test("acquires a 60s wake lock when an active pump session moves to background on Android", () => {
    expect(resolvePumpBackgroundKeepAliveAction({
      isAndroidNative: true,
      appVisible: false,
      state: "running",
    })).toEqual({ type: "acquire", timeoutMs: PUMP_BACKGROUND_WAKE_LOCK_MS });

    expect(resolvePumpBackgroundKeepAliveAction({
      isAndroidNative: true,
      appVisible: false,
      state: "paused",
    })).toEqual({ type: "acquire", timeoutMs: PUMP_BACKGROUND_WAKE_LOCK_MS });
  });

  test("releases the wake lock when the app is visible or the pump session is inactive", () => {
    expect(resolvePumpBackgroundKeepAliveAction({
      isAndroidNative: true,
      appVisible: true,
      state: "running",
    })).toEqual({ type: "release" });

    expect(resolvePumpBackgroundKeepAliveAction({
      isAndroidNative: true,
      appVisible: false,
      state: "ended",
    })).toEqual({ type: "release" });
  });

  test("does nothing outside Android native runtime", () => {
    expect(resolvePumpBackgroundKeepAliveAction({
      isAndroidNative: false,
      appVisible: false,
      state: "running",
    })).toEqual({ type: "none" });
  });
});
