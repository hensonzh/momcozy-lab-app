/* ── Shared Plan Types & Mock Data ── */
import type { ScheduleTask } from "@/data/mockData";

/** Lactation plans (maintain/chase/wean/fertility) are mutually exclusive among themselves.
 *  Work plan can parallel with maintain/chase/wean but is mutually exclusive with fertility. */
export const LACTATION_PLAN_IDS = ["maintain", "chase", "wean", "fertility"] as const;
export const PARALLEL_PLAN_IDS = ["work"] as const;

/** Goal direction → plan ID mapping */
export const goalToPlanMap: Record<string, string> = {
  increase: "chase",
  maintain: "maintain",
  decrease: "wean",
  fertility: "fertility",
};

/** Default active plan IDs */
const DEFAULT_ACTIVE_PLANS = ["maintain", "work"];

/** Get active plan IDs from localStorage */
export const getActivePlanIds = (): string[] => {
  try {
    const stored = localStorage.getItem("activePlanIds");
    return stored ? JSON.parse(stored) : DEFAULT_ACTIVE_PLANS;
  } catch {
    return DEFAULT_ACTIVE_PLANS;
  }
};

/**
 * Set active plan IDs with exclusivity rules:
 * - Lactation plans (maintain/chase/wean/fertility) are mutually exclusive
 * - Work plan can coexist with maintain/chase/wean but NOT with fertility
 */
export const setActivePlanIds = (ids: string[]) => {
  let lactationPlan: string | null = null;
  const parallel: string[] = [];
  for (const id of ids) {
    if ((LACTATION_PLAN_IDS as readonly string[]).includes(id)) {
      lactationPlan = id;
    } else {
      parallel.push(id);
    }
  }
  // fertility and work are mutually exclusive
  const filteredParallel = lactationPlan === "fertility"
    ? parallel.filter((id) => id !== "work")
    : parallel;
  const result = lactationPlan ? [lactationPlan, ...filteredParallel] : filteredParallel;
  const unique = [...new Set(result)];
  localStorage.setItem("activePlanIds", JSON.stringify(unique));
  window.dispatchEvent(new CustomEvent("activePlansUpdated", { detail: unique }));
};

/** Activate a lactation plan (replaces any existing lactation plan, keeps parallel plans; fertility removes work) */
export const activateLactationPlan = (planId: string) => {
  const current = getActivePlanIds();
  let parallelOnly = current.filter((id) => (PARALLEL_PLAN_IDS as readonly string[]).includes(id));
  if (planId === "fertility") {
    parallelOnly = parallelOnly.filter((id) => id !== "work");
  }
  setActivePlanIds([planId, ...parallelOnly]);
};

/** Toggle work plan on/off (cannot coexist with fertility) */
export const toggleWorkPlan = (active: boolean) => {
  const current = getActivePlanIds();
  if (active) {
    // If fertility is active, cannot enable work
    const hasFertility = current.some((id) => id === "fertility");
    if (hasFertility) return; // silently reject
    setActivePlanIds([...current, "work"]);
  } else {
    setActivePlanIds(current.filter((id) => id !== "work"));
  }
};

/** Get current goal info from localStorage */
export const getCurrentGoal = (): { planId: string; label: string; summary: string } => {
  try {
    const stored = localStorage.getItem("currentLactationGoal");
    if (stored) return JSON.parse(stored);
  } catch {
    return { planId: "maintain", label: "维持奶量", summary: "近7天日均580ml，节奏稳定 💪" };
  }
  return { planId: "maintain", label: "维持奶量", summary: "近7天日均580ml，节奏稳定 💪" };
};

/** Set current goal and dispatch event */
export const setCurrentGoal = (goal: { planId: string; label: string; summary: string }) => {
  localStorage.setItem("currentLactationGoal", JSON.stringify(goal));
  window.dispatchEvent(new CustomEvent("goalUpdated", { detail: goal }));
};
export interface MilestoneTask {
  title: string;
  icon: string;
  intervalDays: number;
}

export interface Milestone {
  id: string;
  label: string;
  startDate: string; // "YYYY-MM-DD"
  durationWeeks: number;
  tasks: MilestoneTask[];
}

export interface Plan {
  id: string;
  name: string;
  emoji: string;
  currentMilestoneIndex: number;
  maiSummary: string;
  milestones: Milestone[];
}

/** Color config per plan — used for calendar + timeline */
export const planColors: Record<string, { bg: string; border: string; text: string; milestoneBg: string }> = {
  maintain: { bg: "bg-teal-200 dark:bg-teal-900/40", border: "border-teal-400 dark:border-teal-600", text: "text-teal-800 dark:text-teal-200", milestoneBg: "bg-teal-400 dark:bg-teal-600" },
  chase:    { bg: "bg-amber-100 dark:bg-amber-900/30", border: "border-amber-300 dark:border-amber-700", text: "text-amber-700 dark:text-amber-300", milestoneBg: "bg-amber-300 dark:bg-amber-700" },
  wean:     { bg: "bg-emerald-100 dark:bg-emerald-900/30", border: "border-emerald-300 dark:border-emerald-700", text: "text-emerald-700 dark:text-emerald-300", milestoneBg: "bg-emerald-300 dark:bg-emerald-700" },
  fertility:{ bg: "bg-pink-100 dark:bg-pink-900/30", border: "border-pink-300 dark:border-pink-700", text: "text-pink-700 dark:text-pink-300", milestoneBg: "bg-pink-300 dark:bg-pink-700" },
  work:     { bg: "bg-violet-100 dark:bg-violet-900/30", border: "border-violet-300 dark:border-violet-700", text: "text-violet-700 dark:text-violet-300", milestoneBg: "bg-violet-300 dark:bg-violet-700" },
};

export const mockPlans: Plan[] = [
  {
    id: "maintain",
    name: "维持奶量",
    emoji: "🥛",
    currentMilestoneIndex: 2,
    maiSummary: "你的泌乳节奏很稳定，日均580ml已保持3周，继续保持这个频率就好，不用焦虑哦 💪",
    milestones: [
      {
        id: "m-maintain-1", label: "建立基础", startDate: "2026-01-03", durationWeeks: 4,
        tasks: [
          { title: "双侧吸奶 20min", icon: "🤱", intervalDays: 1 },
          { title: "亲喂练习", icon: "🍼", intervalDays: 1 },
          { title: "记录奶量", icon: "📝", intervalDays: 1 },
        ],
      },
      {
        id: "m-maintain-2", label: "稳定产量", startDate: "2026-01-31", durationWeeks: 6,
        tasks: [
          { title: "规律吸奶 5次/天", icon: "🤱", intervalDays: 1 },
          { title: "夜间吸奶 1次", icon: "🌙", intervalDays: 1 },
          { title: "称量检查", icon: "⚖️", intervalDays: 3 },
        ],
      },
      {
        id: "m-maintain-3", label: "自如维持", startDate: "2026-03-10", durationWeeks: 8,
        tasks: [
          { title: "弹性吸奶 4–5次/天", icon: "🤱", intervalDays: 1 },
          { title: "宝宝体重监测", icon: "👶", intervalDays: 7 },
          { title: "营养补充提醒", icon: "💊", intervalDays: 2 },
        ],
      },
      {
        id: "m-maintain-4", label: "长期平稳", startDate: "2026-05-09", durationWeeks: 12,
        tasks: [
          { title: "按需吸奶", icon: "🤱", intervalDays: 1 },
          { title: "月度产量回顾", icon: "📊", intervalDays: 30 },
        ],
      },
    ],
  },
  {
    id: "chase",
    name: "安心追奶",
    emoji: "🚀",
    currentMilestoneIndex: 1,
    maiSummary: "追奶第2周啦，产量比上周提升了12%，身体也在积极响应，我们按节奏来 🌱",
    milestones: [
      {
        id: "m-chase-1", label: "频率提升", startDate: "2026-03-01", durationWeeks: 2,
        tasks: [
          { title: "增加吸奶至 7次/天", icon: "🤱", intervalDays: 1 },
          { title: "Power Pumping", icon: "⚡", intervalDays: 2 },
          { title: "充分饮水 2L+", icon: "💧", intervalDays: 1 },
        ],
      },
      {
        id: "m-chase-2", label: "巩固增量", startDate: "2026-03-15", durationWeeks: 3,
        tasks: [
          { title: "保持 6–7次/天", icon: "🤱", intervalDays: 1 },
          { title: "夜间加吸 1次", icon: "🌙", intervalDays: 1 },
          { title: "产量趋势分析", icon: "📈", intervalDays: 3 },
        ],
      },
      {
        id: "m-chase-3", label: "达标评估", startDate: "2026-04-05", durationWeeks: 2,
        tasks: [
          { title: "逐步回调至 5次/天", icon: "🤱", intervalDays: 1 },
          { title: "目标达成检查", icon: "🎯", intervalDays: 7 },
        ],
      },
    ],
  },
  {
    id: "wean",
    name: "稳步减奶",
    emoji: "🌿",
    currentMilestoneIndex: 0,
    maiSummary: "减奶计划刚启动，我们慢慢来，每周减少一次吸奶，让身体自然适应 🍃",
    milestones: [
      {
        id: "m-wean-1", label: "缓慢起步", startDate: "2026-03-20", durationWeeks: 2,
        tasks: [
          { title: "减至 4次/天", icon: "🤱", intervalDays: 1 },
          { title: "缩短单次时长 5min", icon: "⏱️", intervalDays: 2 },
          { title: "乳房舒适度检查", icon: "🩺", intervalDays: 1 },
        ],
      },
      {
        id: "m-wean-2", label: "持续递减", startDate: "2026-04-03", durationWeeks: 3,
        tasks: [
          { title: "减至 3次/天", icon: "🤱", intervalDays: 1 },
          { title: "监测乳腺状态", icon: "🩺", intervalDays: 3 },
        ],
      },
      {
        id: "m-wean-3", label: "安全离乳", startDate: "2026-04-24", durationWeeks: 2,
        tasks: [
          { title: "减至 1–2次/天", icon: "🤱", intervalDays: 1 },
          { title: "完全停止评估", icon: "✅", intervalDays: 7 },
        ],
      },
    ],
  },
  {
    id: "fertility",
    name: "待产计划",
    emoji: "🤰",
    currentMilestoneIndex: 0,
    maiSummary: "待产期间的泌乳管理很重要，我会帮你做好身体和营养的准备，一起加油 🌷",
    milestones: [
      {
        id: "m-fertility-1", label: "营养储备", startDate: "2026-04-01", durationWeeks: 4,
        tasks: [
          { title: "叶酸补充", icon: "💊", intervalDays: 1 },
          { title: "铁/钙检测", icon: "🩸", intervalDays: 14 },
          { title: "逐步调整吸奶频率", icon: "🤱", intervalDays: 1 },
        ],
      },
      {
        id: "m-fertility-2", label: "身体调适", startDate: "2026-04-29", durationWeeks: 4,
        tasks: [
          { title: "产检记录", icon: "📅", intervalDays: 1 },
          { title: "基础体温监测", icon: "🌡️", intervalDays: 1 },
          { title: "泌乳量渐减跟踪", icon: "📉", intervalDays: 3 },
        ],
      },
      {
        id: "m-fertility-3", label: "待产就绪", startDate: "2026-05-27", durationWeeks: 4,
        tasks: [
          { title: "产前检查提醒", icon: "🏥", intervalDays: 30 },
          { title: "运动与休息平衡", icon: "🧘", intervalDays: 2 },
        ],
      },
    ],
  },
  {
    id: "work",
    name: "返工计划",
    emoji: "💼",
    currentMilestoneIndex: 1,
    maiSummary: "返工第2周适应得不错！午休吸奶的节奏已经稳定，记得带好储奶袋哦 👜",
    milestones: [
      {
        id: "m-work-1", label: "返工准备", startDate: "2026-02-15", durationWeeks: 2,
        tasks: [
          { title: "储奶练习", icon: "🧊", intervalDays: 1 },
          { title: "背奶包准备", icon: "🎒", intervalDays: 7 },
          { title: "模拟工作日排程", icon: "📋", intervalDays: 2 },
        ],
      },
      {
        id: "m-work-2", label: "适应期", startDate: "2026-03-01", durationWeeks: 3,
        tasks: [
          { title: "工位吸奶 2–3次", icon: "🤱", intervalDays: 1 },
          { title: "午休吸奶提醒", icon: "⏰", intervalDays: 1 },
          { title: "储奶量记录", icon: "📝", intervalDays: 1 },
        ],
      },
      {
        id: "m-work-3", label: "游刃有余", startDate: "2026-03-22", durationWeeks: 4,
        tasks: [
          { title: "弹性吸奶节奏", icon: "🤱", intervalDays: 1 },
          { title: "周末亲喂补充", icon: "🍼", intervalDays: 7 },
          { title: "月度回顾", icon: "📊", intervalDays: 30 },
        ],
      },
    ],
  },
];

/* ── Generate today's tasks from active plans ── */

/** Time slot templates per task type icon */
const timeSlotsByType: Record<string, string[]> = {
  "🤱": ["06:30", "10:00", "14:00", "18:00", "21:00"],
  "🍼": ["08:00", "11:30", "17:00"],
  "⚡": ["09:00", "15:00"],
  "🌙": ["03:00"],
  "💧": ["07:00", "12:00", "19:00"],
  "💊": ["08:30"],
  "🩸": ["09:30"],
  "📝": ["20:00"],
  "⚖️": ["10:30"],
  "👶": ["16:00"],
  "📈": ["20:30"],
  "🎯": ["19:00"],
  "⏱️": ["13:00"],
  "🩺": ["11:00"],
  "✅": ["18:00"],
  "📉": ["17:00"],
  "🌡️": ["07:30"],
  "📅": ["09:00"],
  "🏥": ["10:00"],
  "🧘": ["07:00", "18:30"],
  "🧊": ["16:00"],
  "🎒": ["09:00"],
  "📋": ["08:00"],
  "⏰": ["12:00"],
  "📊": ["21:00"],
};

/** Map icon to ScheduleTask type */
const iconToTaskType = (icon: string): "pump" | "feed" | "meeting" => {
  if (["🤱", "⚡", "🌙", "🧊"].includes(icon)) return "pump";
  if (["🍼"].includes(icon)) return "feed";
  return "pump"; // default
};

/**
 * Generate today's ScheduleTask[] from all active plans' current milestones.
 * Each plan's current milestone tasks are expanded into concrete time-slotted tasks.
 */
export const generateTodayTasks = (): ScheduleTask[] => {
  const activeIds = getActivePlanIds();
  const today = new Date();
  const tasks: ScheduleTask[] = [];
  const usedTimeSlots = new Set<string>();

  for (const planId of activeIds) {
    const plan = mockPlans.find((p) => p.id === planId);
    if (!plan) continue;

    // Find the milestone that covers today
    const currentMs = plan.milestones.find((ms) => {
      const start = new Date(ms.startDate);
      const end = new Date(start);
      end.setDate(end.getDate() + ms.durationWeeks * 7);
      return today >= start && today < end;
    });
    if (!currentMs) continue;

    // Compute day-in-milestone for interval filtering
    const msStart = new Date(currentMs.startDate);
    const dayInMs = Math.floor((today.getTime() - msStart.getTime()) / (1000 * 60 * 60 * 24));

    for (const task of currentMs.tasks) {
      // Only include tasks whose interval matches today
      if (task.intervalDays > 1 && dayInMs % task.intervalDays !== 0) continue;

      const slots = timeSlotsByType[task.icon] || ["12:00"];

      // For daily tasks with multiple slots (e.g. pumping 5x/day), use all slots
      // For others, use first available slot
      const slotsToUse = task.intervalDays === 1 ? slots : [slots[0]];

      for (const time of slotsToUse) {
        // Avoid duplicate time slots
        const slotKey = `${time}-${task.title}`;
        if (usedTimeSlots.has(slotKey)) continue;
        usedTimeSlots.add(slotKey);

        tasks.push({
          id: `plan-${planId}-${currentMs.id}-${task.icon}-${time}`,
          time,
          type: iconToTaskType(task.icon),
          title: task.title,
          done: false,
          source: "mai",
          reason: plan.name,
        });
      }
    }
  }

  // Sort by time
  tasks.sort((a, b) => a.time.localeCompare(b.time));
  return tasks;
};

/** Dispatch event to refresh today tasks across the app */
export const refreshTodayTasks = () => {
  window.dispatchEvent(new Event("todayTasksRefresh"));
};
