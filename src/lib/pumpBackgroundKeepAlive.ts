import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";

export const PUMP_BACKGROUND_WAKE_LOCK_MS = 60_000;

export type PumpBackgroundKeepAliveAction =
  | { type: "acquire"; timeoutMs: number }
  | { type: "release" }
  | { type: "none" };

export function resolvePumpBackgroundKeepAliveAction(input: {
  isAndroidNative: boolean;
  appVisible: boolean;
  state: SessionState;
}): PumpBackgroundKeepAliveAction {
  if (!input.isAndroidNative) return { type: "none" };
  if (!input.appVisible && (input.state === "running" || input.state === "paused")) {
    return { type: "acquire", timeoutMs: PUMP_BACKGROUND_WAKE_LOCK_MS };
  }
  return { type: "release" };
}

