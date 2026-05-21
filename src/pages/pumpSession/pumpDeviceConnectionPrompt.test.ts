import { describe, expect, test } from "vitest";
import {
  canStartPumpSession,
  resolveCalibrationPromptConfirmAction,
  resolveCalibrationPromptConfirmGate,
  resolvePumpStartGate,
  shouldShowPumpDeviceNotConnectedPrompt,
} from "@/pages/pumpSession/pumpDeviceConnectionPrompt";

describe("shouldShowPumpDeviceNotConnectedPrompt", () => {
  test("shows the prompt only when no bound device exists and no side is connected", () => {
    expect(shouldShowPumpDeviceNotConnectedPrompt({ L: null, R: null })).toBe(true);
  });

  test("does not show the prompt while a bound device is being reconnected", () => {
    expect(
      shouldShowPumpDeviceNotConnectedPrompt({
        L: {
          deviceId: "left-id",
          deviceName: "Left Pump",
          connected: false,
        },
        R: null,
      }),
    ).toBe(false);
  });

  test("does not show the prompt when any side is connected", () => {
    expect(
      shouldShowPumpDeviceNotConnectedPrompt({
        L: null,
        R: {
          deviceId: "right-id",
          deviceName: "Right Pump",
          connected: true,
        },
      }),
    ).toBe(false);
  });
});

describe("canStartPumpSession", () => {
  test("allows pump session when any side is connected", () => {
    expect(canStartPumpSession({ L: null, R: null })).toBe(false);
    expect(canStartPumpSession({ L: { connected: true, deviceId: "left-id" }, R: null })).toBe(true);
    expect(canStartPumpSession({ L: null, R: { connected: true, deviceId: "right-id" } })).toBe(true);
    expect(
      canStartPumpSession({
        L: { connected: true, deviceId: "left-id" },
        R: { connected: true, deviceId: "right-id" },
      }),
    ).toBe(true);
  });
});

describe("resolvePumpStartGate", () => {
  test("checks calibration before device connection", () => {
    expect(resolvePumpStartGate(false, { L: null, R: null })).toBe("calibration");
    expect(resolvePumpStartGate(false, { L: { connected: true, deviceId: "left-id" }, R: null })).toBe("calibration");
    expect(
      resolvePumpStartGate(false, {
        L: { connected: true, deviceId: "left-id" },
        R: { connected: true, deviceId: "right-id" },
      }),
    ).toBe("calibration");
  });

  test("when calibrated, allows entering pump with one connected side", () => {
    expect(resolvePumpStartGate(true, { L: null, R: null })).toBe("device");
    expect(resolvePumpStartGate(true, { L: { connected: true, deviceId: "left-id" }, R: null })).toBe("pump");
    expect(resolvePumpStartGate(true, { L: null, R: { connected: true, deviceId: "right-id" } })).toBe("pump");
  });
});

describe("resolveCalibrationPromptConfirmGate", () => {
  test("requires both left and right pumps to be connected before entering calibration", () => {
    expect(resolveCalibrationPromptConfirmGate({ L: null, R: null })).toBe("device");
    expect(resolveCalibrationPromptConfirmGate({ L: { connected: true, deviceId: "left-id" }, R: null })).toBe("device");
    expect(resolveCalibrationPromptConfirmGate({ L: null, R: { connected: true, deviceId: "right-id" } })).toBe("device");
    expect(
      resolveCalibrationPromptConfirmGate({
        L: { connected: true, deviceId: "left-id" },
        R: { connected: true, deviceId: "right-id" },
      }),
    ).toBe("calibration");
  });
});

describe("resolveCalibrationPromptConfirmAction", () => {
  test("keeps the dialog open as device prompt when calibration is requested without both pumps connected", () => {
    expect(resolveCalibrationPromptConfirmAction("calibration", { L: null, R: null })).toEqual({
      type: "showDevicePrompt",
    });
  });

  test("navigates to calibration only when both pumps are connected", () => {
    expect(
      resolveCalibrationPromptConfirmAction("calibration", {
        L: { connected: true, deviceId: "left-id" },
        R: { connected: true, deviceId: "right-id" },
      }),
    ).toEqual({ type: "navigate", route: "/calibration" });
  });

  test("navigates to device page from the device prompt action", () => {
    expect(resolveCalibrationPromptConfirmAction("device", { L: null, R: null })).toEqual({
      type: "navigate",
      route: "/device",
    });
  });
});
