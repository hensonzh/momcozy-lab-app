/**
 * 全局吸奶会话生命周期单例。
 *
 * 状态枚举（与 pumpSessionModel.SessionState 一致）：
 *   - "idle"    未开始（默认；不写入持久化）
 *   - "running" 进行中（任意一侧在线设备 pumpWorkState === 0x01）
 *   - "paused"  暂停中（先前 running，且所有在线侧 pumpWorkState !== 0x01）
 *   - "ended"   已结束（用户在 PumpSession 弹窗确认结束，预留其他结束条件）
 *
 * 持久化策略：
 *   - 使用 sessionStorage（杀进程 → 清空 → 冷启动默认 idle）；
 *   - SPA 路由跳转、F5 刷新均保持；
 *   - 模块加载时一次性清理旧版 localStorage["pump_session_state"] 残留。
 *
 * 状态机由 deviceStore 订阅驱动（边缘触发）：
 *   - 任意在线侧从 not-running → running 边缘 ⇒ running
 *   - 任意在线侧存在的前提下，所有在线侧由 running → not-running 边缘 ⇒ 当前为 running 时转 paused
 *   - markSessionEnded() 立即写 ended，并启动短冷却忽略设备态反弹
 */

import { deviceStore } from "@/lib/deviceStore";
import { createScopedConsole } from "@/lib/logger";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";

export const PUMP_SESSION_STATE_KEY = "pump_session_state";
const PUMP_SESSION_LETDOWN_COUNTS_KEY = "pump_session_letdown_counts";

const LEGACY_LOCAL_STORAGE_KEY = "pump_session_state";

/** ended 后忽略设备态反弹的冷却时长，避免 BLE 停泵指令未完成时短暂 running 引起回滚 */
const ENDED_COOLDOWN_MS = 2000;
/** 所有在线侧都处于暂停时，达到阈值自动结束（自然时间） */
const PAUSE_TIMEOUT_MS = 10 * 60 * 1000;
/** 定时重算步长：用于暂停超时判定，不依赖设备上报频率 */
const RECONCILE_TICK_MS = 1000;

export type PumpSessionEndReason =
  | "user-confirm"
  | "device-offline-ended-single"
  | "device-offline-ended-both"
  | "pause-timeout-ended"
  | (string & {});

type Listener = (state: SessionState) => void;
type EndedListener = (event: PumpSessionEndedEvent) => void;

export interface PumpSessionEndedEvent {
  reason: PumpSessionEndReason;
  at: number;
  prevState: SessionState;
}

const VALID_STATES: ReadonlySet<string> = new Set<SessionState>(["running", "paused", "ended"]);

const lifecycleLogger = createScopedConsole("PumpSessionLifecycle");

let currentState: SessionState = "idle";
let prevAnyOnlineRunning = false;
let prevAnyOnline = false;
let endedCooldownUntil = 0;
let lastDeviceFingerprint = "";
let pausedAllOnlineSinceMs: number | null = null;
/** 上一帧 reconcile 结束时各侧是否 BLE 连接，用于「全离线」时区分单侧曾在线 vs 双侧曾在线 */
let lastReconcileLeftConn = false;
let lastReconcileRightConn = false;
let prevLetdownL = false;
let prevLetdownR = false;
let letdownCountL = 0;
let letdownCountR = 0;
const listeners = new Set<Listener>();
const endedListeners = new Set<EndedListener>();
let lastEndedEvent: PumpSessionEndedEvent | null = null;

function isSessionStateValue(v: unknown): v is SessionState {
  return typeof v === "string" && VALID_STATES.has(v);
}

/** 设备快照"诊断指纹"：仅包含影响状态机的字段，变化时才输出 reconcile 日志，控制噪声 */
function buildDeviceFingerprint(): string {
  const { L, R } = deviceStore.get();
  const part = (d: typeof L) =>
    d
      ? `${d.connected ? 1 : 0}|${d.pumpWorkState ?? "_"}|${d.lastDeviceWorkstateTs ? "T" : "_"}`
      : "null";
  return `L:${part(L)};R:${part(R)}`;
}

function snapshotForLog() {
  const { L, R } = deviceStore.get();
  const sideForLog = (d: typeof L) =>
    d
      ? {
          connected: !!d.connected,
          pumpWorkState: d.pumpWorkState ?? null,
          hasWorkstateTs: !!d.lastDeviceWorkstateTs,
        }
      : null;
  return { L: sideForLog(L), R: sideForLog(R) };
}

/**
 * 派生当前设备快照中的"在线"与"在线侧运行中"标志。
 *
 * 注意：`pumpWorkState` 字段在 deviceStore 启动恢复时不会被清零，可能残留上一次会话的 `0x01`；
 * 而 `lastDeviceWorkstateTs` 在恢复时被复位为 ""，仅当 BLE 真实收到状态包后才会被刷新。
 * 因此这里要求 `lastDeviceWorkstateTs` 非空才信任 `pumpWorkState === 0x01`，
 * 避免「连接设备但 BLE 尚未上报」的窗口期误判为运行中。
 */
function readDeviceSnapshotDerived(): { anyOnline: boolean; anyOnlineRunning: boolean } {
  const { L, R } = deviceStore.get();
  const leftOnline = !!L?.connected;
  const rightOnline = !!R?.connected;
  const leftRunning = leftOnline && L?.pumpWorkState === 0x01 && !!L?.lastDeviceWorkstateTs;
  const rightRunning = rightOnline && R?.pumpWorkState === 0x01 && !!R?.lastDeviceWorkstateTs;
  return {
    anyOnline: leftOnline || rightOnline,
    anyOnlineRunning: leftRunning || rightRunning,
  };
}

/** 与 reconcile 相同的派生标志；供 PumpSession 等判断「自动结束提示是否已过时」。 */
export function getPumpSessionDeviceDerived(): {
  anyOnline: boolean;
  anyOnlineRunning: boolean;
} {
  return readDeviceSnapshotDerived();
}

function persist(): void {
  try {
    if (currentState === "idle") {
      sessionStorage.removeItem(PUMP_SESSION_STATE_KEY);
    } else {
      sessionStorage.setItem(PUMP_SESSION_STATE_KEY, currentState);
    }
  } catch {
    // 隐私模式 / 容量满，忽略
  }
}

function notify(): void {
  listeners.forEach((cb) => cb(currentState));
}

function notifyEnded(event: PumpSessionEndedEvent): void {
  endedListeners.forEach((cb) => cb(event));
}

function transition(next: SessionState): void {
  if (next === currentState) return;
  const prev = currentState;
  currentState = next;
  if (next === "running" && (prev === "idle" || prev === "ended")) {
    resetLetdownCounters();
  }
  // 离开 ended 表示新一轮会话已开启，旧的结束事件对新会话不再适用，
  // 必须清空，否则消费者（PumpSession 挂载时读取 getLastEndedEvent）会跨会话误触发结束弹窗
  if (prev === "ended" && next !== "ended" && lastEndedEvent !== null) {
    lifecycleLogger.log("clear-stale-ended-event", {
      from: prev,
      to: next,
      clearedEvent: lastEndedEvent,
    });
    lastEndedEvent = null;
  }
  persist();
  lifecycleLogger.log("transition", { from: prev, to: next, snapshot: snapshotForLog() });
  notify();
}

function persistLetdownCounters(): void {
  try {
    sessionStorage.setItem(PUMP_SESSION_LETDOWN_COUNTS_KEY, JSON.stringify({ L: letdownCountL, R: letdownCountR }));
  } catch {
    // 隐私模式 / 容量满，忽略
  }
}

function resetLetdownCounters(): void {
  prevLetdownL = false;
  prevLetdownR = false;
  letdownCountL = 0;
  letdownCountR = 0;
  persistLetdownCounters();
}

function updateLetdownCounters(): void {
  if (currentState !== "running" && currentState !== "paused") return;
  const { L, R } = deviceStore.get();
  const leftRunning = !!L?.connected && L?.pumpWorkState === 0x01 && !!L?.lastDeviceWorkstateTs;
  const rightRunning = !!R?.connected && R?.pumpWorkState === 0x01 && !!R?.lastDeviceWorkstateTs;
  const nextLetdownL = leftRunning && typeof L?.moFlag === "number" && (L.moFlag & 0x01) !== 0;
  const nextLetdownR = rightRunning && typeof R?.moFlag === "number" && (R.moFlag & 0x01) !== 0;

  const beforeL = letdownCountL;
  const beforeR = letdownCountR;
  if (nextLetdownL && !prevLetdownL) letdownCountL += 1;
  if (nextLetdownR && !prevLetdownR) letdownCountR += 1;

  prevLetdownL = nextLetdownL;
  prevLetdownR = nextLetdownR;
  if (letdownCountL !== beforeL || letdownCountR !== beforeR) persistLetdownCounters();
}

function markEndedInternal(reason: PumpSessionEndReason): void {
  // 幂等：防止同一结束事件重复触发
  if (currentState === "ended") return;
  const prev = currentState;
  endedCooldownUntil = Date.now() + ENDED_COOLDOWN_MS;
  pausedAllOnlineSinceMs = null;
  transition("ended");
  const event: PumpSessionEndedEvent = {
    reason,
    at: Date.now(),
    prevState: prev,
  };
  lastEndedEvent = event;
  lifecycleLogger.log("ended-event", event);
  notifyEnded(event);
}

/**
 * 根据 deviceStore 当前快照重算并按规则推进状态。
 * 由 deviceStore.subscribe 订阅器触发，每次外部 setDevice/setConnected 后被调用。
 */
function reconcileFromDevice(): void {
  const fingerprint = buildDeviceFingerprint();
  const fingerprintChanged = fingerprint !== lastDeviceFingerprint;
  const { anyOnline, anyOnlineRunning } = readDeviceSnapshotDerived();

  // 自动结束后若仍有 BLE 在线侧，旧的 lastEndedEvent 不应再驱动吸乳页弹窗（含离线结束与暂停超时结束；
  // 暂停超时结束时本就 anyOnline，下一帧即清；全离线结束则重连后才清）
  if (currentState === "ended" && anyOnline && lastEndedEvent !== null) {
    lifecycleLogger.log("clear-stale-ended-on-device-online-while-ended", {
      clearedReason: lastEndedEvent.reason,
      inCooldown: Date.now() < endedCooldownUntil,
      snapshot: snapshotForLog(),
    });
    lastEndedEvent = null;
  }

  if (Date.now() < endedCooldownUntil) {
    if (fingerprintChanged) {
      lifecycleLogger.log("reconcile (cooldown)", {
        currentState,
        anyOnline,
        anyOnlineRunning,
        prevAnyOnlineRunning,
        cooldownRemainMs: endedCooldownUntil - Date.now(),
        snapshot: snapshotForLog(),
      });
      lastDeviceFingerprint = fingerprint;
    }
    prevAnyOnlineRunning = anyOnlineRunning;
    prevAnyOnline = anyOnline;
    return;
  }

  if (fingerprintChanged) {
    lifecycleLogger.log("reconcile", {
      currentState,
      anyOnline,
      anyOnlineRunning,
      prevAnyOnlineRunning,
      snapshot: snapshotForLog(),
    });
    lastDeviceFingerprint = fingerprint;
  }

  if (!prevAnyOnlineRunning && anyOnlineRunning) {
    transition("running");
  } else if (
    prevAnyOnlineRunning &&
    !anyOnlineRunning &&
    anyOnline &&
    currentState === "running"
  ) {
    transition("paused");
  }

  updateLetdownCounters();

  // 自动结束 1：从「有在线侧」到「全离线」，仅在 running/paused 生效
  if (
    prevAnyOnline &&
    !anyOnline &&
    (currentState === "running" || currentState === "paused")
  ) {
    const bothWereConnectedLastTick = lastReconcileLeftConn && lastReconcileRightConn;
    markEndedInternal(
      bothWereConnectedLastTick ? "device-offline-ended-both" : "device-offline-ended-single",
    );
  }

  // 自动结束 2：所有在线侧都暂停，连续 10 分钟（自然时间）
  if (anyOnline && !anyOnlineRunning && (currentState === "running" || currentState === "paused")) {
    if (pausedAllOnlineSinceMs == null) {
      pausedAllOnlineSinceMs = Date.now();
    } else if (Date.now() - pausedAllOnlineSinceMs >= PAUSE_TIMEOUT_MS) {
      markEndedInternal("pause-timeout-ended");
    }
  } else {
    pausedAllOnlineSinceMs = null;
  }

  prevAnyOnlineRunning = anyOnlineRunning;
  prevAnyOnline = anyOnline;

  const snap = deviceStore.get();
  lastReconcileLeftConn = !!snap.L?.connected;
  lastReconcileRightConn = !!snap.R?.connected;
}

function bootstrap(): void {
  let legacyCleared = false;
  try {
    legacyCleared = localStorage.getItem(LEGACY_LOCAL_STORAGE_KEY) !== null;
    localStorage.removeItem(LEGACY_LOCAL_STORAGE_KEY);
  } catch {
    // 忽略
  }

  let restored: string | null = null;
  try {
    restored = sessionStorage.getItem(PUMP_SESSION_STATE_KEY);
    if (isSessionStateValue(restored)) {
      currentState = restored;
    }
  } catch {
    // 忽略
  }
  try {
    const rawCounts = sessionStorage.getItem(PUMP_SESSION_LETDOWN_COUNTS_KEY);
    const parsed = rawCounts ? JSON.parse(rawCounts) as { L?: unknown; R?: unknown } : null;
    if (parsed) {
      if (typeof parsed.L === "number" && Number.isFinite(parsed.L)) letdownCountL = Math.max(0, Math.round(parsed.L));
      if (typeof parsed.R === "number" && Number.isFinite(parsed.R)) letdownCountR = Math.max(0, Math.round(parsed.R));
    }
  } catch {
    // 忽略
  }

  prevAnyOnlineRunning = readDeviceSnapshotDerived().anyOnlineRunning;
  prevAnyOnline = readDeviceSnapshotDerived().anyOnline;
  {
    const { L, R } = deviceStore.get();
    lastReconcileLeftConn = !!L?.connected;
    lastReconcileRightConn = !!R?.connected;
  }
  lastDeviceFingerprint = buildDeviceFingerprint();
  deviceStore.subscribe(reconcileFromDevice);
  window.setInterval(reconcileFromDevice, RECONCILE_TICK_MS);

  lifecycleLogger.log("bootstrap", {
    initialState: currentState,
    restoredFromSessionStorage: restored,
    legacyLocalStorageCleared: legacyCleared,
    prevAnyOnlineRunning,
    prevAnyOnline,
    snapshot: snapshotForLog(),
  });
}

bootstrap();

export interface PumpSessionLifecycle {
  getSessionState(): SessionState;
  subscribe(listener: Listener): () => void;
  subscribeEnded(listener: EndedListener): () => void;
  markSessionEnded(reason: PumpSessionEndReason): void;
  isActive(): boolean;
  getLastEndedEvent(): PumpSessionEndedEvent | null;
  getLetdownCounts(): { L: number; R: number };
}

export const pumpSessionLifecycle: PumpSessionLifecycle = {
  getSessionState() {
    return currentState;
  },
  subscribe(listener) {
    listeners.add(listener);
    // 挂载晚于上一轮 transition 的订阅者仍可拿到当前状态（进度岛 / 前台通知等均依赖此前提）
    try {
      listener(currentState);
    } catch {
      /* 消费者异常不拖垮 lifecycle */
    }
    return () => {
      listeners.delete(listener);
    };
  },
  subscribeEnded(listener) {
    endedListeners.add(listener);
    return () => {
      endedListeners.delete(listener);
    };
  },
  markSessionEnded(reason) {
    lifecycleLogger.log("markSessionEnded", {
      reason,
      cooldownMs: ENDED_COOLDOWN_MS,
      previousState: currentState,
    });
    markEndedInternal(reason);
  },
  isActive() {
    return currentState === "running" || currentState === "paused";
  },
  getLastEndedEvent() {
    return lastEndedEvent;
  },
  getLetdownCounts() {
    return { L: letdownCountL, R: letdownCountR };
  },
};
