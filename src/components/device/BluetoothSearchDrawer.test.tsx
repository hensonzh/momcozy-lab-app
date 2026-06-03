import { act, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import BluetoothSearchDrawer from "./BluetoothSearchDrawer";
import { connect, getConnectedPumpDevices, startLEScan } from "@/lib/ble";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";

vi.mock("framer-motion", async () => {
  const React = await import("react");
  return {
    motion: new Proxy({}, {
      get: (_target, tag: string) => ({ children, ...props }: any) =>
        React.createElement(tag, props, children),
    }),
  };
});

vi.mock("@/lib/ble", () => ({
  isBleSupported: vi.fn(() => true),
  initializeBle: vi.fn(() => Promise.resolve()),
  startLEScan: vi.fn(() => Promise.resolve()),
  stopLEScan: vi.fn(() => Promise.resolve()),
  getConnectedPumpDevices: vi.fn(() => Promise.resolve([])),
  connect: vi.fn(() => Promise.resolve()),
  openBluetoothSettings: vi.fn(() => Promise.resolve()),
  openAppSettings: vi.fn(() => Promise.resolve()),
}));

function storedDevice(patch: Partial<StoredDeviceInfo> = {}): StoredDeviceInfo {
  return {
    deviceId: "connected-device",
    deviceName: "LT_TEST_L",
    connected: true,
    battery: 88,
    rssi: -48,
    flangeSize: 24,
    sealSize: "M",
    model: "LT_TEST_L",
    firmware: "1.0",
    serialNumber: "connected-device",
    ...patch,
  };
}

describe("BluetoothSearchDrawer", () => {
  afterEach(() => {
    deviceStore.setDevice("L", null);
    deviceStore.setDevice("R", null);
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it("shows the connected paired device if scanning times out after another connection completes", async () => {
    vi.useFakeTimers();

    render(
      <BluetoothSearchDrawer
        open
        side="L"
        onClose={vi.fn()}
        onConnect={vi.fn()}
      />,
    );

    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(startLEScan).toHaveBeenCalled();

    deviceStore.setDevice("L", storedDevice());

    await act(async () => {
      vi.advanceTimersByTime(10_000);
      await Promise.resolve();
    });

    expect(screen.getByText("LT_TEST_L")).toBeInTheDocument();
    expect(screen.getByText("已配对")).toBeInTheDocument();
  });

  it("does not restart scanning when open drawer props rerender with new callbacks", async () => {
    const { rerender } = render(
      <BluetoothSearchDrawer
        open
        side="L"
        onClose={vi.fn()}
        onConnect={vi.fn()}
      />,
    );

    await waitFor(() => {
      expect(startLEScan).toHaveBeenCalledTimes(1);
    });

    rerender(
      <BluetoothSearchDrawer
        open
        side="L"
        onClose={vi.fn()}
        onConnect={vi.fn()}
      />,
    );

    await act(async () => {
      await Promise.resolve();
    });

    expect(startLEScan).toHaveBeenCalledTimes(1);
  });

  it("recovers a native connected device when scanning finds no matching devices", async () => {
    vi.useFakeTimers();
    const onConnect = vi.fn();
    const onClose = vi.fn();
    vi.mocked(getConnectedPumpDevices).mockResolvedValueOnce([
      {
        device: { deviceId: "native-connected", name: "LT_TEST_L" },
        localName: "LT_TEST_L",
      },
    ]);

    render(
      <BluetoothSearchDrawer
        open
        side="L"
        onClose={onClose}
        onConnect={onConnect}
      />,
    );

    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
      vi.advanceTimersByTime(10_000);
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(getConnectedPumpDevices).toHaveBeenCalled();
    expect(connect).toHaveBeenCalledWith("native-connected", expect.any(Function));
    expect(onConnect).toHaveBeenCalledWith("native-connected", "LT_TEST_L", -50);
    expect(onClose).toHaveBeenCalled();
  });
});
