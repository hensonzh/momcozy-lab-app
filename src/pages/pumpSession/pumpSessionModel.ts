import { deviceStore } from "@/lib/deviceStore";

export type PumpMode = "stimulate" | "deep" | "mixed";
export type SessionState = "idle" | "running" | "paused" | "ended";

export interface SideState {
  gear: number;
  mode: PumpMode;
  flow: number;
}

export interface DeviceRuntimeInfo {
  pumping?: boolean;
  sessionState?: SessionState;
}

export interface MaiBubbleAction {
  label: string;
  action: () => void;
}

export interface MaiSessionBubble {
  text: string;
  actions?: MaiBubbleAction[];
}

export const MAX_GEAR = 15;
export const MIN_GEAR = 1;

export const toProtocolGear = (gear: number): number => Math.max(0, Math.min(14, gear - 1));
export const fromProtocolGear = (gear: number): number => Math.max(MIN_GEAR, Math.min(MAX_GEAR, gear + 1));
/** 协议 0 刺激 / 1 吸乳 / 2 混合 — 与 PumpSession_last fromProtocolMode / toProtocolMode 一致 */
export function fromProtocolPumpMode(b: number): PumpMode {
  if (b === 1) return "deep";
  if (b === 2) return "mixed";
  return "stimulate";
}

export const toProtocolMode = (mode: PumpMode): 0 | 1 | 2 =>
  mode === "deep" ? 1 : mode === "mixed" ? 2 : 0;

/**
 * 双侧 SYNC 模式按钮高亮 — 与 PumpSession_last currentMode useMemo（L1779-1824）一致。
 * 返回 null 时刺激/吸乳均不高亮（例如双侧刺激/深度不一致且无助记规则时）。
 */
export function syncModeButtonHighlight(params: {
  leftOnline: boolean;
  rightOnline: boolean;
  leftMode: PumpMode;
  rightMode: PumpMode;
}): PumpMode | null {
  const { leftOnline, rightOnline, leftMode, rightMode } = params;
  if (leftOnline && rightOnline) {
    if (leftMode === rightMode) return leftMode;
    const lm = leftMode;
    const rm = rightMode;
    if (lm === "mixed" && rm !== "mixed") return rm;
    if (rm === "mixed" && lm !== "mixed") return lm;
    if (
      (lm === "stimulate" || lm === "deep") &&
      (rm === "stimulate" || rm === "deep") &&
      lm !== rm
    ) {
      return "deep";
    }
    return null;
  }
  if (leftOnline) return leftMode;
  if (rightOnline) return rightMode;
  return null;
}

export function initialAiModeFromStore(): boolean {
  const { L, R } = deviceStore.get();
  const leftOnline = !!L?.connected;
  const rightOnline = !!R?.connected;

  if (leftOnline && rightOnline && L?.pumpScene != null && R?.pumpScene != null) {
    return L.pumpScene === R.pumpScene ? L.pumpScene === 1 : false;
  }
  if (leftOnline && L?.pumpScene != null) return L.pumpScene === 1;
  if (rightOnline && R?.pumpScene != null) return R.pumpScene === 1;
  return true;
}

// 与 last L928-968 对齐：进入页面以 deviceStore 持久化 duration 初始化 elapsed。
export function initialElapsedFromStore(): number {
  const { L, R } = deviceStore.get();
  const leftOnline = !!L?.connected;
  const rightOnline = !!R?.connected;
  const leftRunning = L?.pumpWorkState === 0x01;
  const rightRunning = R?.pumpWorkState === 0x01;
  if (!leftOnline && !rightOnline) return 0;
  if (leftOnline && !rightOnline) return typeof L?.duration === "number" ? L.duration : 0;
  if (!leftOnline && rightOnline) return typeof R?.duration === "number" ? R.duration : 0;
  if (leftRunning && !rightRunning) return typeof L?.duration === "number" ? L.duration : 0;
  if (!leftRunning && rightRunning) return typeof R?.duration === "number" ? R.duration : 0;
  if (typeof L?.duration === "number" && typeof R?.duration === "number") {
    return Math.max(L.duration, R.duration);
  }
  return 0;
}
