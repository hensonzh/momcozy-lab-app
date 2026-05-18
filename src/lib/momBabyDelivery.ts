import type { MomBabyInfoData } from "./agentApiTypes";

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

/**
 * 分娩日至今日（本地日历日）的整天数差；分娩日与今天同一天为 0。
 */
export function calendarDaysSinceDeliveryLocal(deliveryYmd: string): number | null {
  const canon = deliveryYmd.trim().match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!canon) return null;
  const y = Number(canon[1]);
  const mo = Number(canon[2]) - 1;
  const da = Number(canon[3]);
  const delivery = new Date(y, mo, da);
  if (Number.isNaN(delivery.getTime())) return null;
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.floor((todayStart.getTime() - delivery.getTime()) / (24 * 60 * 60 * 1000));
}
