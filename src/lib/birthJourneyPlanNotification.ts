import { useSyncExternalStore } from "react";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";

const NAV_PENDING_KEY = "mmc_birth_journey_plan_nav_pending";
const CARD_PENDING_KEY = "mmc_birth_journey_plan_card_pending";
const CHANGE_EVENT = "mmc-birth-journey-plan-notification-change";
export const BIRTH_JOURNEY_PLAN_DELETED_EVENT = "mmc-birth-journey-plan-deleted";

function dispatchChange(): void {
  try {
    window.dispatchEvent(new Event(CHANGE_EVENT));
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
    if (value) {
      localStorage.setItem(key, "1");
    } else {
      localStorage.removeItem(key);
    }
  } catch {
    /* ignore */
  }
}

function subscribe(callback: () => void): () => void {
  window.addEventListener(CHANGE_EVENT, callback);
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener(CHANGE_EVENT, callback);
    window.removeEventListener("storage", callback);
  };
}

export function markBirthJourneyPlanGeneratedNotification(): void {
  writeFlag(NAV_PENDING_KEY, true);
  writeFlag(CARD_PENDING_KEY, false);
  dispatchChange();
}

export function transferBirthJourneyPlanNotificationToStatusCard(): void {
  if (!readFlag(NAV_PENDING_KEY)) return;
  writeFlag(NAV_PENDING_KEY, false);
  writeFlag(CARD_PENDING_KEY, true);
  dispatchChange();
}

export function clearBirthJourneyPlanCardNotification(): void {
  if (!readFlag(CARD_PENDING_KEY)) return;
  writeFlag(CARD_PENDING_KEY, false);
  dispatchChange();
}

export function clearBirthJourneyPlanGeneratedNotification(): void {
  const hadPending = readFlag(NAV_PENDING_KEY) || readFlag(CARD_PENDING_KEY);
  writeFlag(NAV_PENDING_KEY, false);
  writeFlag(CARD_PENDING_KEY, false);
  if (hadPending) dispatchChange();
}

export function notifyBirthJourneyPlanDeleted(): void {
  clearBirthJourneyPlanGeneratedNotification();
  try {
    window.dispatchEvent(new Event(BIRTH_JOURNEY_PLAN_DELETED_EVENT));
  } catch {
    /* ignore */
  }
}

export function subscribeBirthJourneyPlanDeleted(callback: () => void): () => void {
  window.addEventListener(BIRTH_JOURNEY_PLAN_DELETED_EVENT, callback);
  return () => {
    window.removeEventListener(BIRTH_JOURNEY_PLAN_DELETED_EVENT, callback);
  };
}

export function useBirthJourneyPlanNavNotification(): boolean {
  return useSyncExternalStore(subscribe, () => readFlag(NAV_PENDING_KEY), () => false);
}

export function useBirthJourneyPlanCardNotification(): boolean {
  return useSyncExternalStore(subscribe, () => readFlag(CARD_PENDING_KEY), () => false);
}

export function richTextPayloadHasBirthJourneyPlanCard(payload?: ChatRichTextPayload | null): boolean {
  if (!payload || !Array.isArray(payload.action)) return false;
  return payload.action.some((action) => {
    if (!action || typeof action !== "object" || Array.isArray(action)) return false;
    const record = action as Record<string, unknown>;
    if (record.kind !== "ag_ui_artifact") return false;
    const card = record.card;
    if (!card || typeof card !== "object" || Array.isArray(card)) return false;
    const cardRecord = card as Record<string, unknown>;
    const cardType = String(cardRecord.card_type ?? "").trim();
    const nestedCardJson = cardRecord.card_json;
    const nestedCardType =
      nestedCardJson && typeof nestedCardJson === "object" && !Array.isArray(nestedCardJson)
        ? String((nestedCardJson as Record<string, unknown>).card_type ?? "").trim()
        : "";
    return cardType === "birth_journey_plan_card" || nestedCardType === "birth_journey_plan_card";
  });
}
