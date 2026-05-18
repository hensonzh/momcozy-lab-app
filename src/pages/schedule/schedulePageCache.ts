/**
 * 呵护计划页：上次成功拉取的接口快照（localStorage），首屏先展示缓存，网络返回后按差异更新并回写。
 */
import type { MilkPeriodInfo, PlanListItem, PlanPumpTodayData } from "@/lib/agentApiTypes";

/** plan/query 结构升级（milestones_list 等）后递增，避免旧缓存反序列化误判 */
const SNAPSHOT_VERSION = 2 as const;

/** 可 JSON 序列化的计划页快照（version 便于以后迁移） */
export interface SchedulePageSnapshotV1 {
  version: typeof SNAPSHOT_VERSION;
  userId: string;
  /** GET /v1/plan/query 成功时的 plan_list */
  planList: PlanListItem[];
  /** GET /v1/plan/query 成功时的 plan_type / plan_summary（目标栏首屏与接口对齐） */
  carePlanMeta?: { plan_type: string; plan_summary: string };
  /** GET /v1/plan-pump/today 成功时的 plan_data；无追奶/减奶日程时可能为空列表 */
  planPumpData: PlanPumpTodayData["plan_data"] | null;
  /** 可选：上次成功的泌乳周期（用于 Milky.Way 首屏预热） */
  milkPeriod?: MilkPeriodInfo | null;
}

/** 写入快照时与 `version` 字段保持一致（避免手写数字漂移） */
export const SCHEDULE_PAGE_SNAPSHOT_VERSION = SNAPSHOT_VERSION;

/**
 * 生成 localStorage 键（按用户区分）。
 * @param userId 用户 id
 * @returns 存储键名
 */
function storageKey(userId: string): string {
  return `maiSchedulePageV${SNAPSHOT_VERSION}:${userId}`;
}

/**
 * 判断两段可 JSON 化的数据是否一致（避免无意义的 setState）。
 * @param a 左值
 * @param b 右值
 * @returns 序列化后是否相同
 */
export function scheduleJsonEqual(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

function isRecord(x: unknown): x is Record<string, unknown> {
  return typeof x === "object" && x !== null && !Array.isArray(x);
}

function isValidDurationWeeks(x: unknown): boolean {
  if (typeof x === "number" && Number.isFinite(x)) return true;
  if (typeof x === "string" && x.trim() !== "" && Number.isFinite(Number(x))) return true;
  return false;
}

function isPlanMilestoneListItem(x: unknown): boolean {
  if (!isRecord(x)) return false;
  if (typeof x.date !== "string") return false;
  if (!isValidDurationWeeks(x.duration_weeks)) return false;
  if (typeof x.content !== "string") return false;
  const tit = x.titile;
  const ttl = x.title;
  if (tit != null && typeof tit !== "string") return false;
  if (ttl != null && typeof ttl !== "string") return false;
  return true;
}

function isPlanListItem(x: unknown): x is PlanListItem {
  if (!isRecord(x)) return false;
  if (typeof x.plan_name !== "string") return false;
  if (typeof x.milestones_summary !== "string") return false;
  if (!Array.isArray(x.milestones_list) || !x.milestones_list.every(isPlanMilestoneListItem)) return false;
  return true;
}

function isPlanPumpData(x: unknown): x is PlanPumpTodayData["plan_data"] {
  if (!isRecord(x)) return false;
  if (typeof x.plan_id !== "number" || !Number.isFinite(x.plan_id)) return false;
  if (!Array.isArray(x.plan_list)) return false;
  return true;
}

function isMilkPeriodInfo(x: unknown): x is MilkPeriodInfo {
  if (!isRecord(x)) return false;
  return (
    typeof x.colostrum_period === "string" &&
    typeof x.establishment_period === "string" &&
    typeof x.stable_delivery_period === "string" &&
    typeof x.weaning_period === "string"
  );
}

/**
 * 解析并校验 localStorage 中的快照；userId 必须与当前页一致。
 * @param raw JSON 字符串
 * @param userId 期望用户 id
 * @returns 合法快照或 null
 */
function parseSnapshot(raw: string, userId: string): SchedulePageSnapshotV1 | null {
  let o: unknown;
  try {
    o = JSON.parse(raw) as unknown;
  } catch {
    return null;
  }
  if (!isRecord(o)) return null;
  if (o.version !== SNAPSHOT_VERSION) return null;
  if (typeof o.userId !== "string" || o.userId !== userId) return null;
  if (!Array.isArray(o.planList) || !o.planList.every(isPlanListItem)) return null;
  if (o.planPumpData != null && !isPlanPumpData(o.planPumpData)) return null;
  if (o.milkPeriod !== undefined && o.milkPeriod !== null && !isMilkPeriodInfo(o.milkPeriod)) return null;
  if (o.carePlanMeta !== undefined && o.carePlanMeta !== null) {
    if (!isRecord(o.carePlanMeta)) return null;
    const cm = o.carePlanMeta as Record<string, unknown>;
    if (typeof cm.plan_type !== "string" || typeof cm.plan_summary !== "string") return null;
  }
  return o as unknown as SchedulePageSnapshotV1;
}

/**
 * 读取当前用户下的计划页缓存（不存在或校验失败返回 null）。
 * @param userId 用户 id
 * @returns 快照或 null
 */
export function readSchedulePageCache(userId: string): SchedulePageSnapshotV1 | null {
  if (typeof localStorage === "undefined") return null;
  try {
    const raw = localStorage.getItem(storageKey(userId));
    if (!raw) return null;
    return parseSnapshot(raw, userId);
  } catch {
    return null;
  }
}

/**
 * 写入快照（失败静默，避免打断 UI）。
 * @param snapshot 完整快照（须含 version/userId）
 */
export function writeSchedulePageCache(snapshot: SchedulePageSnapshotV1): void {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(storageKey(snapshot.userId), JSON.stringify(snapshot));
  } catch {
    /* 配额满或隐私模式等 */
  }
}
