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

export function canStartPumpSession(snapshot: PumpDeviceConnectionSnapshot): boolean {
  return Boolean((snapshot.L?.connected && snapshot.L?.deviceId) || (snapshot.R?.connected && snapshot.R?.deviceId));
}

export type PumpStartGate = "pump" | "calibration" | "device";

export type CalibrationPromptConfirmGate = "calibration" | "device";

export type PumpGateDialogKind = "calibration" | "device";

export type CalibrationPromptConfirmAction =
  | { type: "navigate"; route: "/calibration" | "/device" }
  | { type: "showDevicePrompt" };

export function resolveCalibrationPromptConfirmGate(
  snapshot: PumpDeviceConnectionSnapshot,
): CalibrationPromptConfirmGate {
  return snapshot.L?.connected && snapshot.R?.connected ? "calibration" : "device";
}

export function resolveCalibrationPromptConfirmAction(
  dialog: PumpGateDialogKind,
  snapshot: PumpDeviceConnectionSnapshot,
): CalibrationPromptConfirmAction {
  if (dialog === "device") {
    return { type: "navigate", route: "/device" };
  }

  return resolveCalibrationPromptConfirmGate(snapshot) === "calibration"
    ? { type: "navigate", route: "/calibration" }
    : { type: "showDevicePrompt" };
}

export function resolvePumpStartGate(
  hasCalibration: boolean,
  snapshot: PumpDeviceConnectionSnapshot,
): PumpStartGate {
  if (!hasCalibration) {
    return "calibration";
  }
  return canStartPumpSession(snapshot) ? "pump" : "device";
}
