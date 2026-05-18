const STATUS_GROWTH_HIGHLIGHT_PENDING_KEY = "mmc_status_growth_highlight_pending";

export const STATUS_GROWTH_HIGHLIGHT_EVENT = "mmc-status-growth-highlight";

export function markStatusGrowthHighlightPending(): void {
  try {
    sessionStorage.setItem(STATUS_GROWTH_HIGHLIGHT_PENDING_KEY, "1");
  } catch {
    /* ignore */
  }
}

export function consumeStatusGrowthHighlightPending(): boolean {
  try {
    const value = sessionStorage.getItem(STATUS_GROWTH_HIGHLIGHT_PENDING_KEY);
    if (value !== "1") return false;
    sessionStorage.removeItem(STATUS_GROWTH_HIGHLIGHT_PENDING_KEY);
    return true;
  } catch {
    return false;
  }
}
