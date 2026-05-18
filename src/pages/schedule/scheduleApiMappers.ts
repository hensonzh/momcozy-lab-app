/**
 * 将计划相关接口数据映射为呵护计划页控件所需结构（今日任务、Milestone/月历用的 Plan）。
 */
import type { ScheduleTask } from "@/data/mockData";
import type { Plan } from "@/data/planMockData";
import type { PlanListItem, PlanMilestoneListItem, PlanPumpListEntry, PlanPumpTodayData } from "@/lib/agentApiTypes";

/** 文档约定的 plan_type 集合（与 PlanQueryData.plan_type 一致） */
const API_PLAN_TYPES = new Set(["maintain", "chase", "wean", "fertility", "work"]);

/**
 * 将 plan/query 返回的 plan_type 映射为前端计划 id（与 planMockData、planColors 一致）。
 * @param plan_type 接口 plan_type 原始字符串
 * @returns 合法 id；无法识别时回退 maintain
 */
export function apiPlanTypeToFrontendPlanId(plan_type: string): string {
  const t = (plan_type ?? "").trim().toLowerCase();
  return API_PLAN_TYPES.has(t) ? t : "maintain";
}

/**
 * 根据 plan_type 生成与接口文档一致的中文短名称（目标栏主标题旁展示）。
 * @param plan_type 接口 plan_type
 * @returns 中文计划名
 */
export function apiPlanTypeToShortLabel(plan_type: string): string {
  const t = (plan_type ?? "").trim().toLowerCase();
  const map: Record<string, string> = {
    maintain: "维持奶量",
    chase: "逐步增量",
    wean: "温和离乳",
    fertility: "待产计划",
    work: "返工计划",
  };
  return map[t] ?? "呵护计划";
}

/**
 * 呵护计划页「泌乳/待产/返工」目标栏左上角小标题文案。
 * @param plan_type 接口 plan_type（或与之一致的前端 planId）
 * @returns 栏目标题
 */
export function lactationGoalBarSectionTitle(plan_type: string): string {
  const t = (plan_type ?? "").trim().toLowerCase();
  if (t === "fertility") return "我的待产计划";
  if (t === "work") return "我的返工计划";
  return "我的泌乳目标";
}

/** 接口 plan_type + plan_summary 映射后的目标栏展示模型 */
export interface CarePlanGoalDisplay {
  planId: string;
  label: string;
  summary: string;
  goalBarTitle: string;
}

/**
 * 由 plan/query 的 plan_type、plan_summary 生成目标栏展示数据。
 * @param plan_type 接口 plan_type
 * @param plan_summary 接口 plan_summary
 * @returns planId、主副文案、栏目标题
 */
export function buildCarePlanGoalDisplayFromApi(plan_type: string, plan_summary: string): CarePlanGoalDisplay {
  const summary = (plan_summary ?? "").trim();
  const short = apiPlanTypeToShortLabel(plan_type);
  return {
    planId: apiPlanTypeToFrontendPlanId(plan_type),
    label: short,
    summary: summary || short,
    goalBarTitle: lactationGoalBarSectionTitle(plan_type),
  };
}

/**
 * 将接口时间字段规范为当日展示用的 HH:mm（支持纯时间与 ISO 字符串）。
 * @param time 接口返回的时间字符串
 * @returns HH:mm
 */
export function normalizeTaskTime(time: string): string {
  const t = time.trim();
  const hm = t.match(/^(\d{1,2}):(\d{2})/);
  if (hm) {
    const h = Math.min(23, Math.max(0, parseInt(hm[1], 10)));
    const m = Math.min(59, Math.max(0, parseInt(hm[2], 10)));
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
  }
  const d = Date.parse(t);
  if (!Number.isNaN(d)) {
    const x = new Date(d);
    return `${String(x.getHours()).padStart(2, "0")}:${String(x.getMinutes()).padStart(2, "0")}`;
  }
  return "12:00";
}

const TASK_PLAN_NAME_FALLBACK = "排乳计划";

/**
 * 今日任务行「计划」小标签用：将接口 plan_name 等缩为最多 maxChars 个字符，避免行尾被挤出。
 * 用 Array.from 按 Unicode 标码位截取，避免拆坏 emoji/代理对。
 * @param name 计划名（如 plan_name）
 * @param maxChars 最多字符数，默认 5
 */
export function abbreviatePlanNameForTaskBadge(name: string, maxChars = 5): string {
  const t = (name ?? "").trim();
  if (!t) return TASK_PLAN_NAME_FALLBACK;
  const chars = Array.from(t);
  if (chars.length <= maxChars) return t;
  return chars.slice(0, maxChars).join("");
}

/**
 * 根据后台计划名称映射到前端计划 id（与 planMockData、planColors 对齐；无法识别时生成稳定 api 前缀 id）。
 * @param planName 接口 plan_name
 * @param index 同名多条时的序号，保证 id 唯一
 * @returns 前端 plan id
 */
export function planNameToStableId(planName: string, index: number): string {
  const n = planName.trim();
  let base: string;
  if (n.includes("待产")) base = "fertility";
  else if (n.includes("返工")) base = "work";
  else if (n.includes("维持")) base = "maintain";
  else if (n.includes("增量") || n.includes("追奶")) base = "chase";
  else if (n.includes("离乳") || n.includes("减奶")) base = "wean";
  else {
    const slug = n
      .slice(0, 24)
      .replace(/\s+/g, "-")
      .replace(/[^\w\u4e00-\u9fa5-]/g, "");
    base = `api-${slug || "plan"}`;
  }
  return index === 0 ? base : `${base}-${index}`;
}

function planIdToEmoji(planId: string): string {
  if (planId.startsWith("maintain")) return "🥛";
  if (planId.startsWith("chase")) return "🚀";
  if (planId.startsWith("wean")) return "🌿";
  if (planId.startsWith("fertility")) return "🤰";
  if (planId.startsWith("work")) return "💼";
  return "📋";
}

function parseDateOnly(s: string): Date {
  const t = s.trim();
  const m = t.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  const d = new Date(t);
  return Number.isNaN(d.getTime()) ? new Date() : d;
}

/**
 * 计算两个日期之间的周数（至少 1 周），用于 Milestone 展示。
 * @param start 开始日
 * @param end 结束日
 * @returns 周数
 */
export function weeksBetween(start: Date, end: Date): number {
  const ms = end.getTime() - start.getTime();
  return Math.max(1, Math.ceil(ms / (7 * 24 * 3600 * 1000)));
}

function inferIconFromLabel(label?: string): string {
  const s = label?.trim() ?? "";
  if (s.includes("喂") || s.includes("亲喂")) return "🍼";
  return "🤱";
}

/**
 * 从接口 milestone 项取阶段标题（兼容文档 titile 与常见 title）。
 * @param m milestones_list 单项
 * @returns 非空标题，缺省时为「阶段」
 */
export function milestonePhaseTitleFromApi(m: PlanMilestoneListItem): string {
  const raw = (m.titile ?? m.title ?? "").trim();
  return raw || "阶段";
}

/**
 * 将日期字符串规范为 Milestone.startDate 用的 YYYY-MM-DD。
 * @param s 接口 date
 * @returns YYYY-MM-DD
 */
export function milestoneStartDateFromApi(s: string): string {
  const d = parseDateOnly(s);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/**
 * 将 plan/query 的 plan_list 转为月历/Milestone 使用的 Plan[]（里程碑来自 milestones_list）。
 * @param items 接口 plan_list
 * @returns 与 mockPlans 同结构的展示数据
 */
export function planQueryListToDisplayPlans(items: PlanListItem[]): Plan[] {
  const seen = new Map<string, number>();
  return items.map((item, idx) => {
    const dup = seen.get(item.plan_name) ?? 0;
    seen.set(item.plan_name, dup + 1);
    const id = planNameToStableId(item.plan_name, dup);
    const summary = (item.milestones_summary ?? "").trim();
    const maiSummary = summary ? `${item.plan_name} · ${summary} 💕` : `${item.plan_name} 进行中 💕`;
    const phases = item.milestones_list ?? [];
    const planTitle = item.plan_name.trim() || "计划";
    // milestones_list 为空时仍生成一条占位里程碑，避免月历/时间轴无数据
    const milestones =
      phases.length > 0
        ? phases.map((m, mIdx) => ({
            id: `api-ms-${idx}-${mIdx}`,
            label: milestonePhaseTitleFromApi(m),
            startDate: milestoneStartDateFromApi(m.date),
            durationWeeks: Math.max(1, Math.floor(Number(m.duration_weeks)) || 1),
            tasks: [
              {
                title: (m.content ?? "").trim() || milestonePhaseTitleFromApi(m),
                icon: inferIconFromLabel(milestonePhaseTitleFromApi(m)),
                intervalDays: 1,
              },
            ],
          }))
        : [
            {
              id: `api-ms-${idx}-0`,
              label: planTitle,
              startDate: milestoneStartDateFromApi(new Date().toISOString()),
              durationWeeks: 1,
              tasks: [{ title: summary || planTitle, icon: "📋", intervalDays: 1 }],
            },
          ];
    return {
      id,
      name: planTitle,
      emoji: planIdToEmoji(id),
      currentMilestoneIndex: 0,
      maiSummary,
      milestones,
    };
  });
}

/**
 * 根据 entry_type 决定任务类型：plan 按 label 区分亲喂/吸乳；avoid 为避开时段（meeting）。
 * @param e 接口单项
 * @returns ScheduleTask.type
 */
function planPumpEntryType(e: PlanPumpListEntry): "pump" | "feed" | "meeting" {
  const kind = (e.entry_type ?? "plan").trim().toLowerCase();
  if (kind === "avoid") return "meeting";
  return inferIconFromLabel(e.label) === "🍼" ? "feed" : "pump";
}

/**
 * 将 plan-pump/today 的条目转为今日任务列表（稳定 id 便于与本地合并、去重）。
 * 仅使用 plan_list；忽略 avoid_periods（已由服务端合并进 plan_list）。
 * @param planId 计划 id
 * @param entries 接口 plan_list
 * @param planTitle 展示用计划标题（如 plan_name）
 * @returns ScheduleTask 数组
 */
export function planPumpEntriesToScheduleTasks(
  planId: number,
  entries: PlanPumpListEntry[],
  planTitle: string,
): ScheduleTask[] {
  return entries.map((e, i) => {
    const isAvoid = (e.entry_type ?? "").trim().toLowerCase() === "avoid";
    const rawTime = isAvoid ? (e.start_time ?? e.time) : e.time;
    const time = normalizeTaskTime(rawTime);
    const type = planPumpEntryType(e);
    const base: ScheduleTask = {
      id: `srv-pump-${planId}-${i}-${time}`,
      time,
      type,
      title: e.content,
      done: Boolean(e.finish),
      doneSource: e.finish ? ("system" as const) : undefined,
      source: "mai" as const,
    };
    // 避开时段：不附带 reason/M.ai 侧标签数据，由页面改为展示删除按钮并上报 delete-period
    if (isAvoid) {
      const startRaw = (e.start_time ?? e.time ?? "").trim();
      const endRaw = (e.end_time ?? "").trim();
      return {
        ...base,
        planPumpEntryType: "avoid",
        avoidPeriodStart: startRaw,
        avoidPeriodEnd: endRaw,
        planPumpPlanId: e.plan_id ?? planId,
      };
    }
    return {
      ...base,
      planPumpEntryType: "plan",
      reason: abbreviatePlanNameForTaskBadge(planTitle || TASK_PLAN_NAME_FALLBACK, 5),
    };
  });
}

/**
 * 从 plan-pump/today 的 data 生成今日任务（plan_list 为空时返回空数组，由页面回退 mock 生成）。
 * @param planData 接口 plan_data
 * @returns ScheduleTask 数组
 */
export function planPumpDataToScheduleTasks(planData: PlanPumpTodayData["plan_data"]): ScheduleTask[] {
  const title =
    planData.plan_name != null && String(planData.plan_name).trim() !== ""
      ? String(planData.plan_name)
      : "今日排乳";
  return planPumpEntriesToScheduleTasks(planData.plan_id, planData.plan_list ?? [], title);
}
