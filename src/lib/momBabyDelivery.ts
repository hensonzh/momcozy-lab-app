import type { MomBabyInfoData } from "./agentApiTypes";

const DAY_MS = 24 * 60 * 60 * 1000;

/** 接口文档 `delivery_date`（及兼容别名 deliveryDate / deliverydate）中取 yyyy-MM-dd */
export function pickMomBabyDeliveryDateYmd(data: Partial<MomBabyInfoData>): string | null {
  const raw =
    typeof data.delivery_date === "string"
      ? data.delivery_date
      : typeof data.deliveryDate === "string"
        ? data.deliveryDate
        : typeof data.deliverydate === "string"
          ? data.deliverydate
          : "";
  const m = raw.trim().match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : raw.trim().length ? raw.trim() : null;
}

function parseYmdStartLocal(ymd: string): Date | null {
  const canon = ymd.trim().match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!canon) return null;
  const y = Number(canon[1]);
  const mo = Number(canon[2]) - 1;
  const da = Number(canon[3]);
  const date = new Date(y, mo, da);
  return Number.isNaN(date.getTime()) ? null : date;
}

function localDateStart(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/**
 * 分娩日至目标日期（本地日历日）的整天数差；分娩日与目标日期同一天为 0。
 */
export function calendarDaysSinceDeliveryOnLocal(deliveryYmd: string, targetDate: Date = new Date()): number | null {
  const delivery = parseYmdStartLocal(deliveryYmd);
  if (!delivery) return null;
  return Math.floor((localDateStart(targetDate).getTime() - delivery.getTime()) / DAY_MS);
}

/**
 * 分娩日至今日（本地日历日）的整天数差；分娩日与今天同一天为 0。
 */
export function calendarDaysSinceDeliveryLocal(deliveryYmd: string): number | null {
  return calendarDaysSinceDeliveryOnLocal(deliveryYmd);
}

/**
 * 产后第 N 周展示口径：分娩当天属于第 1 周。
 */
export function postpartumWeekFromDay(daysSinceDelivery: number): number {
  return Math.floor(Math.max(0, daysSinceDelivery) / 7) + 1;
}

export function postpartumWeekFromDeliveryYmd(deliveryYmd: string, targetDate: Date = new Date()): number | null {
  const days = calendarDaysSinceDeliveryOnLocal(deliveryYmd, targetDate);
  return typeof days === "number" ? postpartumWeekFromDay(days) : null;
}

export function formatPostpartumWeekFromDay(daysSinceDelivery: number): string {
  return `产后第 ${postpartumWeekFromDay(daysSinceDelivery)} 周`;
}
