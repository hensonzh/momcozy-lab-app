import { useSyncExternalStore } from "react";

export const PREGNANCY_DIARY_CHANGED_EVENT = "momcozy-pregnancy-diary-changed";
const PREGNANCY_DIARY_NOTIFICATION_EVENT = "momcozy-pregnancy-diary-notification-change";
const NAV_PENDING_KEY = "mmc_pregnancy_diary_nav_pending";
const CARD_PENDING_KEY = "mmc_pregnancy_diary_card_pending";
const LEGACY_CARD_LABEL_KEY = "mmc_pregnancy_diary_card_label";

export type PregnancyDiaryChangedAction = "created" | "updated" | "deleted" | "changed";

function dispatchNotificationChange(): void {
  try {
    window.dispatchEvent(new Event(PREGNANCY_DIARY_NOTIFICATION_EVENT));
  } catch {
    /* ignore */
  }
}

function readFlag(key: string): boolean {
  try {
    return localStorage.getItem(key) === "1";
  } catch {
    return false;
  }
}

function writeFlag(key: string, value: boolean): void {
  try {
    if (value) localStorage.setItem(key, "1");
    else localStorage.removeItem(key);
  } catch {
    /* ignore */
  }
}

function clearLegacyCardLabel(): void {
  try {
    localStorage.removeItem(LEGACY_CARD_LABEL_KEY);
  } catch {
    /* ignore */
  }
}

function subscribeNotification(callback: () => void): () => void {
  window.addEventListener(PREGNANCY_DIARY_NOTIFICATION_EVENT, callback);
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener(PREGNANCY_DIARY_NOTIFICATION_EVENT, callback);
    window.removeEventListener("storage", callback);
  };
}

export function markPregnancyDiaryChangedNotification(action: PregnancyDiaryChangedAction = "changed"): void {
  if (action === "deleted") {
    clearPregnancyDiaryChangedNotification();
    return;
  }
  writeFlag(NAV_PENDING_KEY, true);
  writeFlag(CARD_PENDING_KEY, false);
  clearLegacyCardLabel();
  dispatchNotificationChange();
}

export function transferPregnancyDiaryNotificationToStatusCard(): void {
  if (!readFlag(NAV_PENDING_KEY)) return;
  writeFlag(NAV_PENDING_KEY, false);
  writeFlag(CARD_PENDING_KEY, true);
  dispatchNotificationChange();
}

export function clearPregnancyDiaryChangedNotification(): void {
  const hadPending = readFlag(NAV_PENDING_KEY) || readFlag(CARD_PENDING_KEY);
  writeFlag(NAV_PENDING_KEY, false);
  writeFlag(CARD_PENDING_KEY, false);
  clearLegacyCardLabel();
  if (hadPending) dispatchNotificationChange();
}

export function clearPregnancyDiaryCardNotification(): void {
  if (!readFlag(CARD_PENDING_KEY)) return;
  writeFlag(CARD_PENDING_KEY, false);
  clearLegacyCardLabel();
  dispatchNotificationChange();
}

export function notifyPregnancyDiaryChanged(action: PregnancyDiaryChangedAction = "changed"): void {
  if (typeof window === "undefined") return;
  markPregnancyDiaryChangedNotification(action);
  window.dispatchEvent(new CustomEvent(PREGNANCY_DIARY_CHANGED_EVENT, { detail: { action } }));
}

export function subscribePregnancyDiaryChanged(callback: () => void): () => void {
  if (typeof window === "undefined") return () => {};
  window.addEventListener(PREGNANCY_DIARY_CHANGED_EVENT, callback);
  return () => window.removeEventListener(PREGNANCY_DIARY_CHANGED_EVENT, callback);
}

export function usePregnancyDiaryNavNotification(): boolean {
  return useSyncExternalStore(subscribeNotification, () => readFlag(NAV_PENDING_KEY), () => false);
}

export function usePregnancyDiaryCardNotification(): boolean {
  return useSyncExternalStore(subscribeNotification, () => readFlag(CARD_PENDING_KEY), () => false);
}
