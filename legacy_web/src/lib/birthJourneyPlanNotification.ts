import {
  birthJourneyPlanNotificationConfig,
  clearPlanNotification,
  clearPlanPageNotification,
  markPlanNotification,
  richTextPayloadHasBirthJourneyPlanCard,
  transferPlanNotificationToPage,
  usePlanNavNotification,
  usePlanPageNotification,
} from "@/lib/planNotification";

export { richTextPayloadHasBirthJourneyPlanCard };

export const BIRTH_JOURNEY_PLAN_DELETED_EVENT = "mmc-birth-journey-plan-deleted";
export const BIRTH_JOURNEY_PLAN_UPDATED_EVENT = "mmc-birth-journey-plan-updated";

export function markBirthJourneyPlanGeneratedNotification(): void {
  markPlanNotification(birthJourneyPlanNotificationConfig);
}

export function markBirthJourneyPlanUpdatedNotification(): void {
  markPlanNotification(birthJourneyPlanNotificationConfig, {
    kind: "birth_journey_plan",
    target: "status",
    reason: "updated",
    label: "孕期计划已同步",
  });
}

export function transferBirthJourneyPlanNotificationToStatusCard(): void {
  transferPlanNotificationToPage(birthJourneyPlanNotificationConfig);
}

export function clearBirthJourneyPlanCardNotification(): void {
  clearPlanPageNotification(birthJourneyPlanNotificationConfig);
}

export function clearBirthJourneyPlanGeneratedNotification(): void {
  clearPlanNotification(birthJourneyPlanNotificationConfig);
}

export function notifyBirthJourneyPlanDeleted(): void {
  clearBirthJourneyPlanGeneratedNotification();
  try {
    window.dispatchEvent(new Event(BIRTH_JOURNEY_PLAN_DELETED_EVENT));
  } catch {
    /* ignore */
  }
}

export function notifyBirthJourneyPlanUpdated(): void {
  try {
    window.dispatchEvent(new Event(BIRTH_JOURNEY_PLAN_UPDATED_EVENT));
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

export function subscribeBirthJourneyPlanUpdated(callback: () => void): () => void {
  window.addEventListener(BIRTH_JOURNEY_PLAN_UPDATED_EVENT, callback);
  return () => {
    window.removeEventListener(BIRTH_JOURNEY_PLAN_UPDATED_EVENT, callback);
  };
}

export function useBirthJourneyPlanNavNotification(): boolean {
  return usePlanNavNotification(birthJourneyPlanNotificationConfig);
}

export function useBirthJourneyPlanCardNotification(): boolean {
  return usePlanPageNotification(birthJourneyPlanNotificationConfig);
}
