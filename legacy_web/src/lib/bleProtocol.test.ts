import { describe, expect, it } from "vitest";
import { buildFEPowerOff } from "@/lib/bleProtocol";

describe("bleProtocol FE power-off", () => {
  it("builds the FE power-off request without reboot", () => {
    expect(Array.from(buildFEPowerOff(0))).toEqual([
      0xaa,
      0x55,
      0x00,
      0xfe,
      0x01,
      0x00,
      0x01,
    ]);
  });

  it("builds the FE power-off request with reboot", () => {
    expect(Array.from(buildFEPowerOff(1))).toEqual([
      0xaa,
      0x55,
      0x00,
      0xfe,
      0x01,
      0x01,
      0x00,
    ]);
  });
});
