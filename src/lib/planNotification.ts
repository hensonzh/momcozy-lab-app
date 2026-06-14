import { useSyncExternalStore } from "react";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";

export type PlanNotificationKind = "birth_journey_plan" | "milk_plan";
export type PlanNotificationTarget = "status" | "schedule";

export interface PlanNotificationPayload {
  kind: PlanNotificationKind;
  target: PlanNotificationTarget;
  label: string;
  planId?: number;
  planType?: string;
  dates?: string[];
}

interface PlanNotificationConfig {
  navKey: string;
  pageKey: string;
}

export const PLAN_NOTIFICATION_CHANGE_EVENT = "mmc-plan-notification-change";

export const birthJourneyPlanNotificationConfig: PlanNotificationConfig = {
  navKey: "mmc_birth_journey_plan_nav_pending",
  pageKey: "mmc_birth_journey_plan_card_pending",
};

export const milkPlanNotificationConfig: PlanNotificationConfig = {
  navKey: "mmc_milk_plan_nav_pending",
  pageKey: "mmc_milk_plan_schedule_pending",
};

function dispatchPlanNotificationChange(): void {
  try {
    window.dispatchEvent(new Event(PLAN_NOTIFICATION_CHANGE_EVENT));
  } catch {
    /* ignore */
  }
}

function subscribe(callback: () => void): () => void {
  window.addEventListener(PLAN_NOTIFICATION_CHANGE_EVENT, callback);
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener(PLAN_NOTIFICATION_CHANGE_EVENT, callback);
    window.removeEventListener("storage", callback);
  };
}

function readRaw(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeRaw(key: string, value: string | null): void {
  try {
    if (value == null) {
      localStorage.removeItem(key);
    } else {
      localStorage.setItem(key, value);
    }
  } catch {
    /* ignore */
  }
}

function encodePayload(payload?: PlanNotificationPayload): string {
  return payload ? JSON.stringify(payload) : "1";
}

function decodePayload(raw: string | null): PlanNotificationPayload | null {
  if (!raw || raw === "1") return null;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    return parsed as PlanNotificationPayload;
  } catch {
    return null;
  }
}

function hasPending(key: string): boolean {
  return readRaw(key) != null;
}

export function markPlanNotification(config: PlanNotificationConfig, payload?: PlanNotificationPayload): void {
  writeRaw(config.navKey, encodePayload(payload));
  writeRaw(config.pageKey, null);
  dispatchPlanNotificationChange();
}

export function transferPlanNotificationToPage(config: PlanNotificationConfig): void {
  const raw = readRaw(config.navKey);
  if (raw == null) return;
  writeRaw(config.navKey, null);
  writeRaw(config.pageKey, raw);
  dispatchPlanNotificationChange();
}

export function clearPlanPageNotification(config: PlanNotificationConfig): void {
  if (!hasPending(config.pageKey)) return;
  writeRaw(config.pageKey, null);
  dispatchPlanNotificationChange();
}

export function clearPlanNotification(config: PlanNotificationConfig): void {
  const hadPending = hasPending(config.navKey) || hasPending(config.pageKey);
  writeRaw(config.navKey, null);
  writeRaw(config.pageKey, null);
  if (hadPending) dispatchPlanNotificationChange();
}

export function consumePlanPageNotification(config: PlanNotificationConfig): PlanNotificationPayload | null {
  const raw = readRaw(config.pageKey);
  if (raw == null) return null;
  writeRaw(config.pageKey, null);
  dispatchPlanNotificationChange();
  return decodePayload(raw);
}

export function usePlanNavNotification(config: PlanNotificationConfig): boolean {
  return useSyncExternalStore(subscribe, () => hasPending(config.navKey), () => false);
}

export function usePlanPageNotification(config: PlanNotificationConfig): boolean {
  return useSyncExternalStore(subscribe, () => hasPending(config.pageKey), () => false);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function parseRecordPayload(value: unknown): Record<string, unknown> | null {
  const direct = asRecord(value);
  if (direct) return direct;
  if (typeof value !== "string" || !value.trim()) return null;
  try {
    return asRecord(JSON.parse(value));
  } catch {
    return null;
  }
}

function normalizeToolName(value: unknown): string {
  return asString(value).replace(/-/g, "_");
}

function uniqueDates(values: unknown[]): string[] {
  const dates: string[] = [];
  const seen = new Set<string>();
  for (const value of values) {
    const text = asString(value);
    const date = text.match(/^\d{4}-\d{2}-\d{2}/)?.[0] ?? "";
    if (!date || seen.has(date)) continue;
    seen.add(date);
    dates.push(date);
  }
  return dates;
}

function datesFromCalendarItems(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return uniqueDates(
    value.flatMap((item) => {
      const rec = asRecord(item);
      if (!rec) return [];
      return [rec.date, rec.start_time, rec.task_time];
    }),
  );
}

function datesFromDateList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return uniqueDates(value);
}

function milkPlanCardPayloadFromCard(card: Record<string, unknown>): PlanNotificationPayload | null {
  if (asString(card.card_type) !== "milk_plan_card") return null;
  const cardJson = asRecord(card.card_json);
  const status = asString(cardJson?.status);
  const statusLabel = asString(cardJson?.status_label);
  if (status !== "confirmed" && statusLabel !== "已确认") return null;
  return {
    kind: "milk_plan",
    target: "schedule",
    label: asString(cardJson?.title) || "奶量计划",
    planType: asString(cardJson?.plan_type) || undefined,
  };
}

export function richTextPayloadHasBirthJourneyPlanCard(payload?: ChatRichTextPayload | null): boolean {
  if (!payload || !Array.isArray(payload.action)) return false;
  return payload.action.some((action) => {
    const record = asRecord(action);
    if (!record || record.kind !== "ag_ui_artifact") return false;
    const card = asRecord(record.card);
    if (!card) return false;
    const cardType = asString(card.card_type);
    const nestedCardJson = asRecord(card.card_json);
    const nestedCardType = asString(nestedCardJson?.card_type);
    return cardType === "birth_journey_plan_card" || nestedCardType === "birth_journey_plan_card";
  });
}

export function milkPlanNotificationFromRichText(payload?: ChatRichTextPayload | null): PlanNotificationPayload | null {
  if (!payload || !Array.isArray(payload.action)) return null;
  for (const action of payload.action) {
    const record = asRecord(action);
    if (!record || record.kind !== "ag_ui_artifact") continue;
    const card = asRecord(record.card);
    if (!card) continue;
    const notification = milkPlanCardPayloadFromCard(card);
    if (notification) return notification;
  }
  return null;
}

export function milkPlanNotificationFromAgUiData(data: unknown): PlanNotificationPayload | null {
  const event = parseRecordPayload(data);
  if (!event) return null;
  const payload = parseRecordPayload(event.content) ?? event;
  if (normalizeToolName(payload.tool_name ?? payload.toolName) !== "milk_plan_mutate") return null;
  if (payload.ok !== true) return null;
  const card = asRecord(payload.card);
  if (!card || asString(card.card_type) !== "milk_plan_card") return null;
  const cardJson = asRecord(card.card_json);
  const resultData = asRecord(payload.data);
  const calendarDates = datesFromDateList(payload.calendar_dates);
  return {
    kind: "milk_plan",
    target: "schedule",
    label: asString(cardJson?.title) || "奶量计划",
    planId: asNumber(resultData?.plan_id),
    planType: asString(resultData?.plan_type) || undefined,
    dates: calendarDates.length > 0 ? calendarDates : datesFromCalendarItems(resultData?.calendar_items),
  };
}

export function markMilkPlanSyncedNotification(payload: PlanNotificationPayload): void {
  markPlanNotification(milkPlanNotificationConfig, payload);
}
