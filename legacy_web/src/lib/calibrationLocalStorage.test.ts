import { beforeEach, describe, expect, it } from "vitest";
import { mergeE1PumpGearCalibWireIntoCalibrationLocalStorage } from "./calibrationLocalStorage";

describe("calibrationLocalStorage", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("does not treat device E1 pump gear history as user calibration", () => {
    mergeE1PumpGearCalibWireIntoCalibrationLocalStorage("L", 2, 6);

    expect(localStorage.getItem("calibration")).toBeNull();
  });
});
