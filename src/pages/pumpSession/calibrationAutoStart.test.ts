import { describe, expect, it, vi } from "vitest";
import {
  buildCalibrationAutoStartRoute,
  startPumpAfterCalibration,
} from "./calibrationAutoStart";

describe("buildCalibrationAutoStartRoute", () => {
  it("marks calibration pump navigation as already auto-started", () => {
    expect(buildCalibrationAutoStartRoute()).toBe("/pump?from=calibration&autoStarted=1");
  });
});

describe("startPumpAfterCalibration", () => {
  it("starts connected pumps with stimulate comfort gears in auto scene", async () => {
    const send = vi.fn().mockResolvedValue(undefined);

    await startPumpAfterCalibration(
      {
        L: { stimGear: 4, deepGear: 7 },
        R: { stimGear: 6, deepGear: 9 },
      },
      {
        L: { connected: true, deviceId: "left-id" },
        R: { connected: true, deviceId: "right-id" },
      },
      send,
    );

    expect(send).toHaveBeenCalledWith("left-id", 1, 0, 3, 1);
    expect(send).toHaveBeenCalledWith("right-id", 1, 0, 5, 1);
  });

  it("skips offline sides and continues when a send fails", async () => {
    const send = vi.fn().mockRejectedValueOnce(new Error("fail"));
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      await startPumpAfterCalibration(
        {
          L: { stimGear: 4, deepGear: 7 },
          R: { stimGear: 6, deepGear: 9 },
        },
        {
          L: { connected: true, deviceId: "left-id" },
          R: { connected: false, deviceId: "right-id" },
        },
        send,
      );
    } finally {
      consoleError.mockRestore();
    }

    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenCalledWith("left-id", 1, 0, 3, 1);
  });
});
