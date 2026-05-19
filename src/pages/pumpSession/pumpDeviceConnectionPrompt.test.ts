import { describe, expect, test } from "vitest";
import { shouldShowPumpDeviceNotConnectedPrompt } from "@/pages/pumpSession/pumpDeviceConnectionPrompt";

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
