import { sendB1SetPumpParams } from "@/lib/ble";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";

type CalibrationAutoStartResult = {
  stimGear: number;
  deepGear: number;
};

type CalibrationAutoStartSnapshot = Record<
  DeviceSide,
  { connected?: boolean; deviceId?: string } | null
>;

type SendB1 = (
  deviceId: string,
  startStop: 0 | 1,
  mode: 0 | 1 | 2,
  gear: number,
  scene: 0 | 1,
) => Promise<unknown>;

export function buildCalibrationAutoStartRoute(): string {
  return "/pump?from=calibration&autoStarted=1";
}

export async function startPumpAfterCalibration(
  results: { L?: CalibrationAutoStartResult; R?: CalibrationAutoStartResult },
  snapshot: CalibrationAutoStartSnapshot = deviceStore.get(),
  send: SendB1 = sendB1SetPumpParams,
): Promise<void> {
  const fallback = results.L ?? results.R;
  if (!fallback) return;

  for (const side of ["L", "R"] as const) {
    const device = snapshot[side];
    if (!device?.connected || !device.deviceId) continue;

    const result = results[side] ?? fallback;
    const gear = Math.max(0, result.stimGear - 1);
    try {
      await send(device.deviceId, 1, 0, gear, 1);
    } catch (error) {
      console.error(`[CalibrationAutoStart] start pump failed: side=${side}`, error);
    }
  }
}
