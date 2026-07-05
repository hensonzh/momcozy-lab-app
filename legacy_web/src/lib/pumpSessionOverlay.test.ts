import { describe, expect, test } from "vitest";
import { buildPumpOverlaySyncAction } from "@/lib/pumpSessionOverlay";

describe("buildPumpOverlaySyncAction", () => {
  test("updates the overlay only for active Android sessions with overlay permission", () => {
    expect(buildPumpOverlaySyncAction({
      platform: "android",
      permissionGranted: true,
      state: "running",
      processAll: 64.4,
      routePath: "/",
      appVisible: true,
    })).toEqual({ type: "update", state: "running", processAll: 64 });

    expect(buildPumpOverlaySyncAction({
      platform: "android",
      permissionGranted: true,
      state: "paused",
      processAll: 101,
      routePath: "/records",
      appVisible: true,
    })).toEqual({ type: "update", state: "paused", processAll: 100 });
  });

  test("hides the native overlay while the pump page is already visible", () => {
    expect(buildPumpOverlaySyncAction({
      platform: "android",
      permissionGranted: true,
      state: "running",
      processAll: 64,
      routePath: "/pump",
      appVisible: true,
    })).toEqual({ type: "hide" });
  });

  test("updates the overlay from the pump page after the app moves to background", () => {
    expect(buildPumpOverlaySyncAction({
      platform: "android",
      permissionGranted: true,
      state: "running",
      processAll: 64,
      routePath: "/pump",
      appVisible: false,
    })).toEqual({ type: "update", state: "running", processAll: 64 });
  });

  test("hides the overlay when the active pump session ends", () => {
    expect(buildPumpOverlaySyncAction({
      platform: "android",
      permissionGranted: true,
      state: "ended",
      processAll: 80,
      routePath: "/",
      appVisible: true,
    })).toEqual({ type: "hide" });
  });

  test("skips overlay work off Android or without overlay permission", () => {
    expect(buildPumpOverlaySyncAction({
      platform: "web",
      permissionGranted: true,
      state: "running",
      processAll: 50,
      routePath: "/",
      appVisible: true,
    })).toEqual({ type: "skip" });

    expect(buildPumpOverlaySyncAction({
      platform: "android",
      permissionGranted: false,
      state: "running",
      processAll: 50,
      routePath: "/",
      appVisible: true,
    })).toEqual({ type: "skip" });
  });
});
