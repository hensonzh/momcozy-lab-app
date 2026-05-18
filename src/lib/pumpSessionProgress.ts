/**
 * 全局吸乳 process_all（0–100）快照：供 PumpSessionIsland 与各页展示。
 * 与 pumpSessionLifecycle 一致使用 sessionStorage，刷新保留、杀进程清空。
 */

import { createScopedConsole } from "@/lib/logger";

const STORAGE_KEY = "pump_session_process_all";

const log = createScopedConsole("PumpSessionProgress");

function clampPct(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
}

function readStorage(): number {
  try {
    const s = sessionStorage.getItem(STORAGE_KEY);
    if (s == null) return 0;
    return clampPct(Number(s));
  } catch {
    return 0;
  }
}

let current = typeof window !== "undefined" ? readStorage() : 0;

const listeners = new Set<() => void>();

function persist(v: number) {
  try {
    sessionStorage.setItem(STORAGE_KEY, String(v));
  } catch {
    /* 隐私模式等 */
  }
}

function notify() {
  listeners.forEach((fn) => {
    try {
      fn();
    } catch (e) {
      log.warn("listener-error", e);
    }
  });
}

export function getProcessAll(): number {
  return current;
}

export function setProcessAll(next: number): void {
  const v = clampPct(next);
  if (v === current) return;
  current = v;
  persist(v);
  notify();
}

export function subscribeProcessAll(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
