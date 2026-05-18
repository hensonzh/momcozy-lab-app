// Mock data for Mai App（演示/占位数据；对话类型见 @/types/chat）

import type { ChatMessage } from "@/types/chat";

export interface PumpRecord {
  id: string;
  /** 记录标题（任务完成生成记录时优先使用任务标题） */
  recordTitle?: string;
  /** 服务端 `/v1/pump-milk/upload` 返回，用于与云端记录对齐 */
  pumpId?: number;
  /** 服务端 `/v1/feeding/add` 返回，用于与云端喂养记录对齐 */
  feedingId?: number;
  /** 服务端喂养动作 `feed_action` */
  feedAction?: number;
  /** 服务端泌乳 `pump_source`：0 设备 / 1 手动 / 2 计划 */
  pumpSource?: number;
  date: string;
  time: string;
  durationMin: number;
  leftMl: number;
  rightMl: number;
  totalMl: number;
  source: "device" | "manual" | "voice";
  mode: "stimulate" | "deep";
  subLabel?: "补录" | "亲喂" | "配方奶" | "瓶喂";
  /** Record category: inventory (supply) or feeding (consumption) */
  category?: "inventory" | "feeding";
}

export interface BabyData {
  name: string;
  birthDate: string;
  ageWeeks: number;
  records: { date: string; weightKg: number; heightCm: number; headCm: number }[];
}

export interface ScheduleTask {
  id: string;
  /** 服务端任务唯一 id（/v1/plan/*） */
  taskId?: number;
  /** 服务端 task_done 原始值：true/false/jump */
  taskDoneRaw?: string;
  /** 服务端 task_type 原始值：0/1/2 或文案 */
  taskTypeRaw?: string | number;
  /** 服务端 task_source 原始值：Mai/手动等 */
  taskSourceRaw?: string;
  time: string;
  type: "pump" | "feed" | "meeting" | "custom";
  title: string;
  done: boolean;
  doneSource?: "manual" | "system"; // how the task was marked done
  adjusted?: string; // reason for adjustment
  source?: "mai" | "manual" | "device"; // who added this task
  reason?: string; // e.g. 追奶, 减奶
  /** plan-pump plan_list 的 entry_type：avoid 表示服务端下发的避开时段（今日任务行展示删除而非标签） */
  planPumpEntryType?: "plan" | "avoid";
  /** 删除避开时段接口 start_time（与后端字段一致，原样上报） */
  avoidPeriodStart?: string;
  /** 删除避开时段接口 end_time */
  avoidPeriodEnd?: string;
  /** 删除避开时段可选参数 plan_id */
  planPumpPlanId?: number;
}

export interface DeviceInfo {
  id: string;
  side: "L" | "R";
  connected: boolean;
  battery: number;
  flangeSize: number;
  sealSize: string;
  model: string;
  firmware: string;
  serialNumber: string;
}

// 7-day pump records
export const pumpRecords: PumpRecord[] = [
  { id: "p1", date: "2026-03-09", time: "06:30", durationMin: 20, leftMl: 85, rightMl: 90, totalMl: 175, source: "device", mode: "deep" },
  { id: "p2", date: "2026-03-09", time: "10:00", durationMin: 15, leftMl: 70, rightMl: 65, totalMl: 135, source: "device", mode: "deep" },
  { id: "p3", date: "2026-03-09", time: "14:00", durationMin: 0, leftMl: 80, rightMl: 75, totalMl: 155, source: "manual", mode: "deep" },
  { id: "p4", date: "2026-03-08", time: "06:00", durationMin: 22, leftMl: 90, rightMl: 85, totalMl: 175, source: "device", mode: "deep" },
  { id: "p5", date: "2026-03-08", time: "10:30", durationMin: 16, leftMl: 75, rightMl: 70, totalMl: 145, source: "device", mode: "deep" },
  { id: "p6", date: "2026-03-08", time: "14:30", durationMin: 20, leftMl: 80, rightMl: 80, totalMl: 160, source: "voice", mode: "deep" },
  { id: "p7", date: "2026-03-08", time: "21:00", durationMin: 18, leftMl: 70, rightMl: 65, totalMl: 135, source: "device", mode: "deep" },
  { id: "p8", date: "2026-03-07", time: "07:00", durationMin: 20, leftMl: 80, rightMl: 85, totalMl: 165, source: "device", mode: "deep" },
  { id: "p9", date: "2026-03-07", time: "11:00", durationMin: 15, leftMl: 65, rightMl: 70, totalMl: 135, source: "device", mode: "stimulate" },
  { id: "p10", date: "2026-03-07", time: "15:00", durationMin: 17, leftMl: 75, rightMl: 70, totalMl: 145, source: "manual", mode: "deep" },
  { id: "p11", date: "2026-03-06", time: "06:30", durationMin: 20, leftMl: 70, rightMl: 75, totalMl: 145, source: "device", mode: "deep" },
  { id: "p12", date: "2026-03-06", time: "10:00", durationMin: 14, leftMl: 60, rightMl: 65, totalMl: 125, source: "device", mode: "deep" },
  { id: "p13", date: "2026-03-06", time: "22:00", durationMin: 20, leftMl: 80, rightMl: 75, totalMl: 155, source: "device", mode: "deep" },
  { id: "p14", date: "2026-03-05", time: "07:00", durationMin: 18, leftMl: 75, rightMl: 70, totalMl: 145, source: "device", mode: "deep" },
  { id: "p15", date: "2026-03-05", time: "13:00", durationMin: 15, leftMl: 65, rightMl: 60, totalMl: 125, source: "manual", mode: "stimulate" },
  { id: "p16", date: "2026-03-04", time: "06:00", durationMin: 22, leftMl: 70, rightMl: 65, totalMl: 135, source: "device", mode: "deep" },
  { id: "p17", date: "2026-03-04", time: "12:00", durationMin: 16, leftMl: 60, rightMl: 55, totalMl: 115, source: "device", mode: "deep" },
  { id: "p18", date: "2026-03-04", time: "20:00", durationMin: 20, leftMl: 75, rightMl: 70, totalMl: 145, source: "device", mode: "deep" },
  { id: "p19", date: "2026-03-03", time: "07:00", durationMin: 20, leftMl: 65, rightMl: 60, totalMl: 125, source: "device", mode: "deep" },
  { id: "p20", date: "2026-03-03", time: "14:00", durationMin: 15, leftMl: 55, rightMl: 60, totalMl: 115, source: "device", mode: "deep" },
];

export const dailySummary = [
  { date: "02/07", total: 250, sessions: 2 },
  { date: "02/08", total: 275, sessions: 3 },
  { date: "02/09", total: 260, sessions: 2 },
  { date: "02/10", total: 290, sessions: 3 },
  { date: "02/11", total: 305, sessions: 3 },
  { date: "02/12", total: 270, sessions: 2 },
  { date: "02/13", total: 295, sessions: 3 },
  { date: "02/14", total: 310, sessions: 3 },
  { date: "02/15", total: 285, sessions: 3 },
  { date: "02/16", total: 280, sessions: 3 },
  { date: "02/17", total: 310, sessions: 3 },
  { date: "02/18", total: 265, sessions: 2 },
  { date: "02/19", total: 330, sessions: 3 },
  { date: "02/20", total: 290, sessions: 3 },
  { date: "02/21", total: 345, sessions: 3 },
  { date: "02/22", total: 310, sessions: 3 },
  { date: "02/23", total: 355, sessions: 3 },
  { date: "02/24", total: 320, sessions: 3 },
  { date: "02/25", total: 370, sessions: 3 },
  { date: "02/26", total: 300, sessions: 2 },
  { date: "02/27", total: 385, sessions: 3 },
  { date: "02/28", total: 340, sessions: 3 },
  { date: "03/01", total: 360, sessions: 3 },
  { date: "03/02", total: 310, sessions: 3 },
  { date: "03/03", total: 240, sessions: 2 },
  { date: "03/04", total: 395, sessions: 3 },
  { date: "03/05", total: 270, sessions: 2 },
  { date: "03/06", total: 425, sessions: 3 },
  { date: "03/07", total: 445, sessions: 3 },
  { date: "03/08", total: 615, sessions: 4 },
];

export const babyData: BabyData = {
  name: "小豆豆",
  birthDate: "2025-12-15",
  ageWeeks: 12,
  records: [
    { date: "2025-12-15", weightKg: 3.2, heightCm: 49, headCm: 34 },
    { date: "2026-01-15", weightKg: 4.1, heightCm: 52, headCm: 36 },
    { date: "2026-02-15", weightKg: 5.0, heightCm: 55, headCm: 38 },
    { date: "2026-03-09", weightKg: 5.8, heightCm: 58, headCm: 39.5 },
  ],
};

export const todaySchedule: ScheduleTask[] = [
  { id: "s-mai-1", time: "05:00", type: "pump", title: "凌晨追奶", done: false, source: "mai", reason: "追奶" },
  { id: "s1", time: "06:30", type: "pump", title: "晨间吸乳", done: true },
  { id: "s2", time: "08:00", type: "feed", title: "喂奶 + 拍嗝", done: true },
  { id: "s-mai-2", time: "08:30", type: "pump", title: "追奶补充", done: false, source: "mai", reason: "追奶" },
  { id: "s3", time: "10:00", type: "pump", title: "上午吸乳", done: true },
  { id: "s4", time: "11:30", type: "feed", title: "喂奶", done: false },
  { id: "s5", time: "14:00", type: "meeting", title: "团队周会 (钉钉)", done: false, adjusted: "因会议，吸乳顺延至15:00" },
  { id: "s6", time: "15:00", type: "pump", title: "午后吸乳（顺延）", done: false },
  { id: "s-mai-3", time: "16:00", type: "pump", title: "下午加排", done: false, source: "mai", reason: "追奶" },
  { id: "s7", time: "17:00", type: "feed", title: "傍晚喂奶", done: false },
  { id: "s8", time: "21:00", type: "pump", title: "睡前吸乳", done: false },
];

// Empty by default to show unpaired state; add devices to test paired UI
export const devices: DeviceInfo[] = [
  // { id: "d1", side: "L", connected: true, battery: 78, flangeSize: 24, sealSize: "M", model: "Momcozy M.ai Pro", firmware: "v2.1.4", serialNumber: "MP-2026-L-0831" },
  // { id: "d2", side: "R", connected: true, battery: 65, flangeSize: 24, sealSize: "M", model: "Momcozy M.ai Pro", firmware: "v2.1.4", serialNumber: "MP-2026-R-0832" },
];

/** 兼容旧路径：从类型模块再导出 */
export type { ChatMessage, ChatMessageLink } from "@/types/chat";

export const initialMessages: ChatMessage[] = [
  {
    id: "m1",
    role: "mai",
    content: "早上好呀~ ☀️ 今天是产后第12周，你和小豆豆都在稳步成长呢！今天已经完成了3次吸乳，总共465ml，比昨天同时段多了30ml哦，太棒了！",
    timestamp: "08:00",
    cardType: "encourage",
  },
  {
    id: "m2",
    role: "mai",
    content: "温馨提醒：下午2点有一场团队周会，我已经帮你把原定的午后吸乳顺延到了3点。记得会议结束后及时吸乳哦~ 💪",
    timestamp: "08:01",
    cardType: "plan",
  },
];

// Simulated responses for scene buttons
export const sceneResponses: Record<string, ChatMessage> = {
  plan: {
    id: "",
    role: "mai",
    content: "来聊聊你的泌乳计划吧！🌟\n\n我可以帮你完成以下管理：\n• 🌌 了解你当前的泌乳周期阶段\n• 🎯 调整泌乳目标（追奶/维持/减奶）\n• 📊 查看近期奶量趋势\n\n选择你想了解的功能吧～",
    timestamp: "",
    cardType: "tutorial",
    links: [
      { label: "🌌 泌乳周期→", action: "lactation-phase" },
      { label: "🎯 目标调整→", action: "lactation-goal" },
      { label: "📊 奶量趋势→", action: "lactation-trend" },
    ],
  },
  life: {
    id: "",
    role: "mai",
    content: "好的，让我来帮你规划日程～ 📅\n\n我可以帮你完成以下日程管理：\n• 📋 查看/调整今日任务\n• ⛔ 添加避开时段（会议/外出等）\n• 📸 截图识别日程冲突\n• 📊 查看日结报告\n\n点击下方按钮选择你需要的功能吧～",
    timestamp: "",
    cardType: "tutorial",
    links: [
      { label: "📋 查看今日安排→", action: "schedule-view-tasks" },
      { label: "⛔ 添加避开时段→", action: "schedule-add-avoidance" },
      { label: "📸 截图识别日程→", action: "schedule-screenshot" },
      { label: "📊 查看日结报告→", action: "schedule-day-summary" },
    ],
  },
  care: {
    id: "",
    role: "mai",
    content: "来看看你的围产期全程方案吧 🌿\n\n📌 围产期关键阶段轴线：\n\n🟢 孕前准备期\n· 叶酸补充 & 营养储备\n· 基础体检 & 疫苗接种\n· 心理准备 & 生活方式调整\n\n🟡 孕中期（13~28周）\n· 产检计划 & 胎儿发育监测\n· 营养摄入调整 & 体重管理\n· 孕期运动 & 不适缓解\n\n🔴 孕晚期（28周~分娩）\n· 分娩准备 & 待产包清单\n· 产后哺乳知识储备\n· 心理建设 & 家庭支持规划\n\n🟣 产后恢复期\n· 产后42天检查 & 子宫恢复\n· 母乳喂养指导 & 泌乳管理\n· 盆底康复 & 体态修复\n· 产后情绪关怀 & 心理支持\n· 新生儿护理 & 疫苗计划\n\n你目前处于哪个阶段呢？告诉我你的孕产周期和分娩方式，我来为你匹配更精准的方案 💕",
    timestamp: "",
    cardType: "plan",
  },
};
