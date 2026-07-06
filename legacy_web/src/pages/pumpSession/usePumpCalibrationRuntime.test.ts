import { describe, expect, it } from "vitest";
import {
  shouldSkipCalibrationInitialGearSetup,
  canStartPumpCalibration,
  readPumpCalibrationSessionConfig,
  shouldPromptForPumpCalibration,
} from "./usePumpCalibrationRuntime";

describe("shouldPromptForPumpCalibration", () => {
  it("requires a strictly valid calibration payload before suppressing the pump prompt", () => {
    localStorage.setItem(
      "calibration",
      JSON.stringify({
        L: { stimCozy: 255, deepCozy: 255 },
        R: { stimCozy: 255, deepCozy: 255 },
      }),
    );

    expect(shouldPromptForPumpCalibration()).toBe(true);
  });

  it("does not prompt when a strict calibration payload exists", () => {
    localStorage.setItem(
      "calibration",
      JSON.stringify({
        L: { stimCozy: 3, deepCozy: 7 },
        R: { stimCozy: 4, deepCozy: 8 },
      }),
    );

    expect(shouldPromptForPumpCalibration()).toBe(false);
  });
});

describe("canStartPumpCalibration", () => {
  it("requires both left and right pumps to be connected", () => {
    expect(canStartPumpCalibration({ L: null, R: null })).toBe(false);
    expect(canStartPumpCalibration({ L: { connected: true }, R: null })).toBe(false);
    expect(canStartPumpCalibration({ L: null, R: { connected: true } })).toBe(false);
    expect(canStartPumpCalibration({ L: { connected: true }, R: { connected: true } })).toBe(true);
  });
});

describe("readPumpCalibrationSessionConfig", () => {
  it("ignores invalid calibration payloads when deriving pump gears", () => {
    localStorage.setItem(
      "calibration",
      JSON.stringify({
        L: { stimCozy: 255, deepCozy: 255 },
        R: { stimCozy: 255, deepCozy: 255 },
      }),
    );

    expect(readPumpCalibrationSessionConfig(false)).toEqual({
      hasCalibration: false,
      initGearL: 5,
      initGearR: 5,
      targetGearL: 5,
      targetGearR: 5,
    });
  });

  it("uses strict calibration payloads for ramp-up gears", () => {
    localStorage.setItem(
      "calibration",
      JSON.stringify({
        L: { stimCozy: 4, deepCozy: 7 },
        R: { stimCozy: 6, deepCozy: 9 },
      }),
    );

    expect(readPumpCalibrationSessionConfig(false)).toEqual({
      hasCalibration: true,
      initGearL: 2,
      initGearR: 4,
      targetGearL: 4,
      targetGearR: 6,
    });
  });

  it("does not apply calibration-derived initial gears when calibration auto-started the pump", () => {
    localStorage.setItem(
      "calibration",
      JSON.stringify({
        L: { stimCozy: 4, deepCozy: 7 },
        R: { stimCozy: 6, deepCozy: 9 },
      }),
    );

    expect(readPumpCalibrationSessionConfig(true, true)).toEqual({
      hasCalibration: true,
      initGearL: 5,
      initGearR: 5,
      targetGearL: 4,
      targetGearR: 6,
    });
  });
});

describe("shouldSkipCalibrationInitialGearSetup", () => {
  it("only skips initial gear setup for calibration routes that already auto-started the pump", () => {
    expect(shouldSkipCalibrationInitialGearSetup(true, "1")).toBe(true);
    expect(shouldSkipCalibrationInitialGearSetup(true, null)).toBe(false);
    expect(shouldSkipCalibrationInitialGearSetup(false, "1")).toBe(false);
  });
});
