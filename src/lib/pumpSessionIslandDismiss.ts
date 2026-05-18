/**
 * 「已结束」态吸乳岛彻底关闭标记：绑定某次结束的 ended-at，新会话 running 时清除。
 */

const STORAGE_KEY = "pump_session_island_dismiss_ended_at";

function readEndedAt(): number | null {
  try {
    const s = sessionStorage.getItem(STORAGE_KEY);
    if (s == null) return null;
    const n = Number(s);
    return Number.isFinite(n) ? n : null;
  } catch {
    return null;
  }
}

/** 是否与某次结束的 time 对齐且用户已点关岛 */
export function isIslandDismissedForEndedAt(endedAt: number): boolean {
  const d = readEndedAt();
  return d !== null && d === endedAt;
}

export function markIslandDismissedForEnded(endedAt: number): void {
  try {
    sessionStorage.setItem(STORAGE_KEY, String(endedAt));
  } catch {
    /* ignore */
  }
}

export function clearIslandDismissForEnded(): void {
  try {
    sessionStorage.removeItem(STORAGE_KEY);
  } catch {
    /* ignore */
  }
}
