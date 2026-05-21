import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { deviceStore } from "@/lib/deviceStore";

import PumpSession from "./PumpSession";

vi.mock("@/lib/ble", () => ({
  endRunAndUpdateStore: vi.fn(),
  ensureProtocolNotify: vi.fn(() => Promise.resolve()),
  isBleSupported: vi.fn(() => false),
  queryDeviceStatusAndUpdateStore: vi.fn(),
  sendB1SetPumpParams: vi.fn(),
  subscribeProtocolNotifications: vi.fn(() => vi.fn()),
}));

describe("PumpSession", () => {
  beforeEach(() => {
    localStorage.clear();
    deviceStore.setDevice("L", null);
    deviceStore.setDevice("R", null);
  });

  it("renders when calibration exists and only one pump side is connected", () => {
    localStorage.setItem(
      "calibration",
      JSON.stringify({
        L: { stimCozy: 4, deepCozy: 7 },
        R: { stimCozy: 6, deepCozy: 9 },
      }),
    );
    deviceStore.setDevice("L", {
      deviceId: "left-id",
      deviceName: "Left Pump",
      connected: true,
      battery: 80,
      pumpWorkState: 0,
      pumpScene: 1,
      pumpMode: 0,
      gear: 3,
    });

    render(
      <MemoryRouter initialEntries={["/pump"]}>
        <PumpSession />
      </MemoryRouter>,
    );

    expect(screen.getByText("沉浸式吸乳")).toBeTruthy();
  });
});
