type PumpDeviceConnectionSnapshot = {
  L: { connected?: boolean; deviceId?: string | null } | null;
  R: { connected?: boolean; deviceId?: string | null } | null;
};

export function shouldShowPumpDeviceNotConnectedPrompt(
  snapshot: PumpDeviceConnectionSnapshot,
): boolean {
  const hasConnectedDevice = Boolean(snapshot.L?.connected || snapshot.R?.connected);
  if (hasConnectedDevice) return false;

  const hasBoundDevice = Boolean(snapshot.L?.deviceId || snapshot.R?.deviceId);
  return !hasBoundDevice;
}
