import React, { useEffect, useState, useMemo, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useNavigate } from "react-router-dom";
import {
  ArrowRight,
  Bed,
  BookOpen,
  CalendarDays,
  ChevronDown,
  ClipboardList,
  Coffee,
  Droplets,
  Activity,
  Frown,
  HelpCircle,
  HeartPulse,
  Moon,
  PencilLine,
  Ruler,
  Target,
  Timer,
  Trash2,
  Utensils,
  Baby,
  X,
} from "lucide-react";
import {
  Area, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Line, ComposedChart,
} from "recharts";
import { useVolumeUnit, formatVol, unitLabel } from "@/lib/volumeUnit";
import type {
  CarePlanArtifact,
  MomBabyTodayData,
  GrowthQueryData,
  PregnancyDiaryEntry,
  PumpInfoLactationDayItem,
  GrowthRecord,
} from "@/lib/agentApiTypes";
import {
  createPregnancyDiaryEntry,
  deleteCarePlanArtifact,
  queryCarePlanList,
  queryPregnancyDiaryList,
  queryPregnancyDiaryToday,
  updatePregnancyDiaryEntry,
} from "@/lib/agentApi";
import {
  calendarDaysSinceDeliveryLocal,
  pickMomBabyDeliveryDateYmd,
  postpartumWeekFromDay,
} from "@/lib/momBabyDelivery";
import { queryMomBabyInfo, queryMomBabyToday, getPumpInfo, queryPumpMilkRecords } from "@/lib/momPumpTwinAgentApi";
import {
  queryLatestGrowth,
  addGrowthRecord,
  reviseGrowthRecord,
  getGrowthHistory,
  queryFeedingRecords,
} from "@/lib/babyTwinAgentApi";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import {
  consumeStatusGrowthHighlightPending,
  STATUS_GROWTH_HIGHLIGHT_EVENT,
} from "@/lib/statusGrowthHighlight";
import {
  clearBirthJourneyPlanCardNotification,
  subscribeBirthJourneyPlanDeleted,
  useBirthJourneyPlanCardNotification,
} from "@/lib/birthJourneyPlanNotification";
import { subscribePregnancyDiaryChanged } from "@/lib/pregnancyDiaryEvents";

import momAvatar from "@/assets/mom-avatar-felt.png";
import babyAvatar from "@/assets/baby-avatar-felt.png";
import momcozyAgentAvatar from "@/assets/momcozy-agent.png";
import postpartumRecoveryIcon from "@/assets/postpartum-recovery-icon.png";

/** `/v1/mom-baby/*`、`/v1/growth/*`、`/v1/pump/info/get` 已接入部分；乳房健康和睡眠仍为占位模块。 */

/** 母乳趋势 / 成长曲线：压缩左右与底部留白，同时保证刻度文本不被裁切 */
const STATUS_OVERVIEW_CHART_MARGIN = { top: 8, right: 14, left: 0, bottom: 8 } as const;
const LACTATION_TREND_COLORS = {
  actual: "#b9792a",
  estimate: "#8a5f7d",
  band: "#dff4e8",
  grid: "#d8eadf",
  axis: "#8a6742",
};
const GROWTH_CHART_COLORS = {
  actual: "#7d64aa",
  height: "#9479c4",
  band: "#eee6ff",
  grid: "#eadff8",
  axis: "#7560a0",
};

type BabyRecordRow = { date: string; weightKg: number; heightCm: number; headCm: number };
type StatusDigitalTwinTab = "mom" | "baby";
type BabyStatusPanelId = "baby-health" | "growth-milestone" | "baby-sleep";
type MomStatusPanelId =
  | "birth-journey-detail"
  | "pregnancy-diary-detail"
  | "milk-info"
  | "baby-feed-info"
  | "breast-info"
  | "breast-detail"
  | "postpartum-detail"
  | "rest-info"
  | "rest-detail";

const INITIAL_BREAST_HEALTH_SUMMARY = "最近出现涨奶和硬块，伴随按压疼痛";
const INITIAL_REST_SUMMARY = "最近夜间睡眠被照护和吸奶打断，白天容易疲惫";
const POSTPARTUM_RECOVERY_PLAN_TITLE = "盆底肌康复训练";
const POSTPARTUM_RECOVERY_PLAN_STATUS = `正在执行${POSTPARTUM_RECOVERY_PLAN_TITLE}`;

const BREAST_HEALTH_TIMELINE = [
  {
    time: "三天前 晚间",
    title: "轻微涨奶",
    detail: "右侧乳房有胀感，吸奶后明显缓解。",
  },
  {
    time: "昨天 上午",
    title: "发现硬块",
    detail: "左侧外上区域摸到硬块，按压时有疼痛感。",
  },
  {
    time: "今天",
    title: "涨奶硬块",
    detail: INITIAL_BREAST_HEALTH_SUMMARY,
  },
] as const;

const REST_RECOVERY_TIMELINE = [
  {
    time: "三天前 夜间",
    title: "睡眠连续性较差",
    detail: "夜间照护后又进行吸奶，连续睡眠约 2 小时。",
  },
  {
    time: "昨天 午后",
    title: "短时补休",
    detail: "午后补睡约 30 分钟，醒后疲惫感有所缓解。",
  },
  {
    time: "今天 上午",
    title: "白天容易疲惫",
    detail: INITIAL_REST_SUMMARY,
  },
] as const;

const POSTPARTUM_RECOVERY_COURSES = [
  { time: "第 1-2 天", status: "已完成", title: "盆底肌唤醒练习", detail: "呼吸配合轻收缩，建立盆底肌发力感" },
  { time: "第 3-5 天", status: "进行中", title: "骨盆稳定训练", detail: "低强度核心稳定动作，帮助恢复骨盆控制" },
  { time: "第 6-7 天", title: "腰背与肩颈放松", detail: "照护和吸奶后的短时拉伸，缓解腰背疲劳" },
] as const;

const DIARY_MOOD_OPTIONS = ["平稳", "开心", "焦虑", "低落", "容易烦躁"] as const;
const DIARY_ENERGY_OPTIONS = ["不错", "一般", "很累"] as const;
const DIARY_SLEEP_OPTIONS = ["睡得好", "易醒", "失眠", "白天补觉"] as const;
const DIARY_FETAL_MOVEMENT_OPTIONS = ["胎动正常", "比平时少", "比平时频繁", "还没明显感觉"] as const;
const DIARY_SYMPTOM_OPTIONS = ["腰酸", "水肿", "胃口变化", "宫缩感", "胎动变化", "头晕", "腹痛", "出血"] as const;

const BABY_HEALTH_ITEMS = [
  "自闭症风险筛查",
  "生长发育迟缓风险筛查",
  "消化系统风险筛查",
  "皮肤异常风险筛查",
  "认知互动风险筛查",
  "宝宝情绪跟踪",
] as const;

const BABY_GROWTH_MILESTONES = [
  { title: "说出完整主谓短句", date: "2026.05.28", detail: "能说出带主语和动作的短句，语言组织能力继续发展。" },
  { title: "独立上下低矮台阶", date: "2026.05.12", detail: "能自己上下低矮台阶，动作计划能力更成熟。" },
  { title: "双脚离地原地跳跃", date: "2026.04.26", detail: "双脚能同时离地，腿部力量和协调性增强。" },
  { title: "说出首个双字短句", date: "2026.04.08", detail: "能把两个词连在一起表达需求或发现。" },
  { title: "首次双脚小跑", date: "2026.03.21", detail: "能双脚交替快速移动，运动稳定性进一步提升。" },
  { title: "自主站立", date: "2026.03.02", detail: "短时间不用扶站立，平衡能力继续发展。" },
  { title: "四点手足爬行", date: "2026.02.12", detail: "能用手和膝盖协调前进，探索范围变大。" },
  { title: "无支撑独自坐稳", date: "2026.01.25", detail: "不用扶也能坐稳一段时间，核心控制更成熟。" },
  { title: "首次叫爸爸", date: "2026.01.08", detail: "能发出接近“爸爸”的音节，表达欲更明显。" },
  { title: "首次叫妈妈", date: "2025.12.22", detail: "发出接近“妈妈”的音节，开始把声音和人联系起来。" },
  { title: "首次完整自主翻身", date: "2025.12.04", detail: "能从仰卧翻到俯卧，身体协调性继续提升。" },
  { title: "出生后首次自主抬头", date: "2025.11.18", detail: "趴卧时能短暂抬起头，开始建立颈肩控制。" },
] as const;

const BABY_SLEEP_SUMMARY = [
  { title: "总睡眠", value: "4h 57min", tone: "peach", icon: Moon },
  { title: "最长睡眠", value: "3h 08min", tone: "cream", icon: Timer },
  { title: "哭闹", value: "0次", tone: "cream", icon: Frown },
  { title: "活动", value: "26次", tone: "peach", icon: Activity },
] as const;

const BABY_SLEEP_CHART = [
  { period: "00:00", sleepMinutes: 74, activityMinutes: 28, cryMinutes: 0 },
  { period: "02:00", sleepMinutes: 76, activityMinutes: 34, cryMinutes: 0 },
  { period: "04:00", sleepMinutes: 68, activityMinutes: 24, cryMinutes: 0 },
  { period: "06:00", sleepMinutes: 0, activityMinutes: 52, cryMinutes: 8 },
  { period: "08:00", sleepMinutes: 0, activityMinutes: 46, cryMinutes: 0 },
  { period: "10:00", sleepMinutes: 0, activityMinutes: 33, cryMinutes: 0 },
] as const;

const MaiInlineAvatar = () => (
  <img
    src={momcozyAgentAvatar}
    alt=""
    aria-hidden="true"
    className="h-5 w-5 shrink-0 rounded-full object-cover"
  />
);

const PostpartumRecoveryIcon = () => (
  <img
    src={postpartumRecoveryIcon}
    alt=""
    aria-hidden="true"
    className="h-5 w-5 shrink-0 object-contain"
  />
);

type BirthJourneyPhase = {
  id?: string;
  title?: string;
  date_range?: string;
  status?: string;
  goal?: string;
  is_current?: boolean;
  actions?: unknown;
  watchouts?: unknown;
  comate_help?: unknown;
};

type BirthJourneyPayload = {
  subtitle?: string;
  owner?: Record<string, unknown>;
  phases?: BirthJourneyPhase[];
  next_action?: { label?: string; detail?: string; send_text?: string };
  estimated_due_date?: string;
};

function asBirthJourneyPayload(plan: CarePlanArtifact | null): BirthJourneyPayload {
  return (plan?.payload ?? {}) as BirthJourneyPayload;
}

function compactText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function compactTextList(value: unknown, limit = 3): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(compactText).filter(Boolean).slice(0, limit);
}

const BIRTH_JOURNEY_HOSPITAL_BAG_HELP = "制定个性化待产清单";

function birthJourneyPhaseList(plan: CarePlanArtifact | null): BirthJourneyPhase[] {
  const phases = asBirthJourneyPayload(plan).phases;
  return Array.isArray(phases) ? phases : [];
}

function isBirthJourneyCurrentPhase(phase: BirthJourneyPhase | null | undefined): boolean {
  return Boolean(phase?.is_current || phase?.status === "current");
}

function birthJourneyCurrentPhaseIndex(plan: CarePlanArtifact | null): number {
  const phases = birthJourneyPhaseList(plan);
  const index = phases.findIndex(isBirthJourneyCurrentPhase);
  return index >= 0 ? index : 0;
}

function currentBirthJourneyPhase(plan: CarePlanArtifact | null): BirthJourneyPhase | null {
  const phases = birthJourneyPhaseList(plan);
  if (phases.length === 0) return null;
  return phases[birthJourneyCurrentPhaseIndex(plan)] ?? phases[0] ?? null;
}

function birthJourneyNextPrompt(plan: CarePlanArtifact | null): string {
  return compactText(asBirthJourneyPayload(plan).next_action?.send_text) || "我想继续完善生产全过程计划";
}

function birthJourneyPhaseKey(phase: BirthJourneyPhase, index: number): string {
  return compactText(phase.id) || compactText(phase.title) || `phase-${index}`;
}

function isLatePregnancyBirthJourneyPhase(phase: BirthJourneyPhase | null | undefined): boolean {
  return compactText(phase?.id) === "late_pregnancy" || compactText(phase?.title) === "孕晚期";
}

type BirthJourneySuggestion = {
  action: string;
  help?: string;
};

type BirthJourneyPhaseDetail = {
  goal: string;
  watchouts: string[];
  suggestions: BirthJourneySuggestion[];
  helpPrompts: string[];
};

function birthJourneySuggestionPairs(phase: BirthJourneyPhase | null | undefined): BirthJourneySuggestion[] {
  const actions = compactTextList(phase?.actions, 12);
  return actions.map((action) => ({ action, help: "" }));
}

function birthJourneyHelpPrompts(phase: BirthJourneyPhase | null | undefined): string[] {
  const items = compactTextList(phase?.comate_help, 12);
  if (items.includes(BIRTH_JOURNEY_HOSPITAL_BAG_HELP) || isLatePregnancyBirthJourneyPhase(phase)) {
    return [BIRTH_JOURNEY_HOSPITAL_BAG_HELP];
  }
  return [];
}

function birthJourneyPhaseDetailSections(phase: BirthJourneyPhase): BirthJourneyPhaseDetail {
  return {
    goal: compactText(phase.goal),
    watchouts: compactTextList(phase.watchouts, 12),
    suggestions: birthJourneySuggestionPairs(phase),
    helpPrompts: birthJourneyHelpPrompts(phase),
  };
}

function formatDiaryDateLabel(dateKey: string): string {
  const parts = dateKey.split("-");
  if (parts.length >= 3) return `${Number(parts[1])}月${Number(parts[2])}日`;
  return dateKey;
}

function pregnancyDiarySummary(entry: PregnancyDiaryEntry | null): string {
  if (!entry) return "今天还没有记录";
  const parts = [
    entry.mood ? `心情${entry.mood}` : "",
    entry.fetal_movement ? entry.fetal_movement : "",
    entry.sleep_summary ? entry.sleep_summary : "",
  ].filter(Boolean);
  if (parts.length > 0) return `今日已记录：${parts.slice(0, 2).join("，")}`;
  return entry.content ? `今日已记录：${entry.content}` : "今天已有孕期记录";
}

function pregnancyDiarySignalTags(entry: PregnancyDiaryEntry): string[] {
  return [
    entry.mood ? `心情${entry.mood}` : "",
    compactText(entry.fetal_movement),
    compactText(entry.sleep_summary),
    ...entry.symptom_tags,
  ].map(compactText).filter(Boolean).slice(0, 4);
}

function pregnancyDiaryRecentCount(entries: PregnancyDiaryEntry[], days = 7): number {
  const dateKeys = new Set(buildRecentDateKeys(days));
  return entries.filter((entry) => dateKeys.has(entry.entry_date)).length;
}

function pregnancyDiaryQuestionCount(entries: PregnancyDiaryEntry[]): number {
  return entries.reduce((total, entry) => {
    const note = compactText(entry.appointment_note);
    if (!note) return total;
    return total + Math.max(1, note.split(/[？?\n；;]/).map((item) => item.trim()).filter(Boolean).length);
  }, 0);
}

function pregnancyDiaryRecentTags(entries: PregnancyDiaryEntry[], limit = 4): string[] {
  const seen = new Set<string>();
  const tags: string[] = [];
  entries.slice(0, 7).forEach((entry) => {
    entry.symptom_tags.forEach((tag) => {
      const text = compactText(tag);
      if (!text || seen.has(text)) return;
      seen.add(text);
      tags.push(text);
    });
  });
  return tags.slice(0, limit);
}

function pregnancyDiaryReviewSummary(entries: PregnancyDiaryEntry[]): string {
  if (entries.length === 0) return "记录几天后，我可以帮你回顾睡眠、情绪、胎动和身体感受的变化。";
  const recent = entries.slice(0, 7);
  const tags = pregnancyDiaryRecentTags(recent, 3);
  const sleepSignals = recent.map((entry) => compactText(entry.sleep_summary)).filter(Boolean);
  const moodSignals = recent.map((entry) => compactText(entry.mood)).filter(Boolean);
  const parts = [
    tags.length > 0 ? `身体感受集中在${tags.join("、")}` : "",
    sleepSignals.length > 0 ? `睡眠记录 ${sleepSignals[0]}` : "",
    moodSignals.length > 0 ? `最近心情${moodSignals[0]}` : "",
  ].filter(Boolean);
  if (parts.length === 0) return "已经开始沉淀孕期记录，继续记录后可以整理成产检沟通清单。";
  return `${parts.slice(0, 2).join("，")}。`;
}

function pregnancyDiaryAgentPrompts(entries: PregnancyDiaryEntry[]): string[] {
  const prompts = [
    "帮我回顾最近7天的孕期日记",
    "帮我根据孕期日记整理下次产检要问医生的问题",
  ];
  if (pregnancyDiaryQuestionCount(entries) > 0) {
    prompts.unshift("帮我整理孕期日记里的产检问题清单");
  }
  return [...new Set(prompts)].slice(0, 3);
}

const BabyStatusPanelSheet: React.FC<{
  panel: BabyStatusPanelId;
  onClose: () => void;
}> = ({ panel, onClose }) => {
  const isMilestone = panel === "growth-milestone";
  const isSleepReport = panel === "baby-sleep";
  const title = isMilestone ? "成长 milestone" : isSleepReport ? "宝宝睡眠报告" : "宝宝健康";

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[60] bg-black/35 backdrop-blur-sm"
        onClick={onClose}
      />
      <motion.section
        role="dialog"
        aria-modal="true"
        aria-label={title}
        initial={{ y: "100%", opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        exit={{ y: "100%", opacity: 0 }}
        transition={{ type: "spring", damping: 28, stiffness: 300 }}
        className="fixed inset-x-0 bottom-0 z-[61] mx-auto w-full max-w-lg rounded-t-3xl border-t border-border/40 bg-card px-5 pt-4 shadow-2xl"
        style={{ paddingBottom: "max(1.75rem, env(safe-area-inset-bottom))" }}
      >
        <div className="mb-4 flex items-center justify-between gap-3">
          <h3 className="text-base font-extrabold text-foreground">{title}</h3>
          <button type="button" onClick={onClose} className="rounded-full p-2 text-muted-foreground active:bg-muted">
            <X className="h-4 w-4" />
          </button>
        </div>

        {panel === "baby-health" ? (
          <div className="space-y-2">
            {BABY_HEALTH_ITEMS.map((item) => (
              <article key={item} className="flex items-center justify-between gap-3 rounded-2xl border border-[#dcefea] bg-[#fbfffd] px-4 py-3">
                <span className="text-sm font-bold text-foreground">{item}</span>
                <span className="shrink-0 rounded-full bg-[#e5f7f0] px-2.5 py-1 text-[11px] font-extrabold text-[#2f8a72]">
                  待开通
                </span>
              </article>
            ))}
          </div>
        ) : null}

        {isMilestone ? (
          <div className="max-h-[72vh] overflow-y-auto pr-1">
            <div className="relative flex flex-col gap-3 pb-1">
              <span aria-hidden="true" className="absolute bottom-4 left-[13px] top-4 w-px bg-gradient-to-t from-[#dcf7ed] via-[#cceee1] to-[#76c7ad]" />
              {BABY_GROWTH_MILESTONES.map((record, index) => {
                const total = Math.max(1, BABY_GROWTH_MILESTONES.length - 1);
                const recency = 1 - index / total;
                const hue = 146 + recency * 18;
                const dotSize = 10 + recency * 8;
                const borderColor = `hsl(${hue}, 42%, ${64 - recency * 10}%)`;
                const softColor = `hsl(${hue}, 70%, ${97 - recency * 3}%)`;
                const cardBorderColor = `hsl(${hue}, 58%, ${89 - recency * 5}%)`;

                return (
                  <article key={`${record.title}-${index}`} className="relative flex gap-3">
                    <span
                      aria-hidden="true"
                      className="mt-4 flex h-7 w-7 shrink-0 items-center justify-center"
                    >
                      <span
                        className="rounded-full border-2"
                        style={{
                          width: dotSize,
                          height: dotSize,
                          borderColor,
                          backgroundColor: softColor,
                          boxShadow: `0 0 0 ${1 + recency * 1.5}px hsla(${hue}, 62%, 92%, 0.72)`,
                        }}
                      />
                    </span>
                    <div
                      className="min-w-0 flex-1 rounded-2xl border px-3 py-3"
                      style={{
                        borderColor: cardBorderColor,
                        background: `linear-gradient(135deg, #fff 0%, ${softColor} 100%)`,
                      }}
                    >
                      <div className="flex gap-3">
                        <img
                          src={babyAvatar}
                          alt=""
                          aria-hidden="true"
                          className="h-12 w-12 shrink-0 rounded-2xl object-cover"
                        />
                        <div className="min-w-0 flex-1">
                          <div className="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-0.5">
                            <p className="truncate text-sm font-extrabold text-foreground">{record.title}</p>
                            <time className="shrink-0 text-[10px] font-normal text-[#9a8fa5]">{record.date}</time>
                          </div>
                          <p className="mt-1 text-xs font-medium leading-relaxed text-[#6f617a]">{record.detail}</p>
                        </div>
                      </div>
                    </div>
                  </article>
                );
              })}
            </div>
          </div>
        ) : null}

        {isSleepReport ? (
          <div className="max-h-[76vh] overflow-y-auto rounded-[28px] bg-[#fffdf8] px-4 pb-5 pt-3">
            <div className="mb-5 flex items-center justify-between">
              <button type="button" className="rounded-2xl bg-[#fff1c9] px-2.5 py-2 text-[10px] font-extrabold text-[#c68b36] active:scale-95">
                前一天
              </button>
              <p className="text-base font-black text-foreground">11-16</p>
              <button type="button" className="rounded-2xl bg-[#fff1c9] px-2.5 py-2 text-[10px] font-extrabold text-[#c68b36] active:scale-95">
                后一天
              </button>
            </div>

            <div className="grid grid-cols-2 gap-x-4 gap-y-5">
              {BABY_SLEEP_SUMMARY.map((item) => (
                <article
                  key={item.title}
                  className={`relative min-h-[110px] rounded-2xl px-3 pb-3 pt-9 text-center shadow-sm ${
                    item.tone === "peach" ? "bg-[#ffdccc]" : "bg-[#fff4e8]"
                  }`}
                >
                  <div className="absolute -top-7 left-1/2 flex h-14 w-14 -translate-x-1/2 items-center justify-center rounded-full bg-[#ffe8df] text-[#ff9677] shadow-sm">
                    <item.icon className="h-6 w-6" strokeWidth={2.3} />
                  </div>
                  <p className="text-[12px] font-black text-[#ff9677]">{item.title}</p>
                  <p className="mt-3 text-[15px] font-black text-foreground">{item.value}</p>
                </article>
              ))}
            </div>

            <div className="mt-7 text-center">
              <h4 className="text-[15px] font-black text-foreground">宝宝睡眠记录</h4>
              <p className="mt-1 text-[10px] font-bold text-[#8a767f]">按时段看睡眠、活动和哭闹时长</p>
              <div className="mt-3 flex justify-center gap-4 text-[10px] font-bold text-muted-foreground">
                <span className="inline-flex items-center gap-1.5"><i className="h-2 w-3 rounded-sm bg-[#25d6a3]" />睡眠</span>
                <span className="inline-flex items-center gap-1.5"><i className="h-2 w-3 rounded-sm bg-[#e6b65c]" />活动</span>
                <span className="inline-flex items-center gap-1.5"><i className="h-2 w-3 rounded-sm bg-[#8c78c8]" />哭闹</span>
              </div>

              <div className="mt-5 rounded-[24px] bg-[#fffaf2] px-3 pb-3 pt-4">
                <div className="flex h-[142px] gap-2">
                  <div className="flex w-7 flex-col justify-between pb-6 pt-1 text-right text-[9px] font-bold text-[#b99f86]">
                    <span>90m</span>
                    <span>60m</span>
                    <span>30m</span>
                    <span>0</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="relative h-[112px]">
                      <span aria-hidden="true" className="absolute inset-x-0 top-0 border-t border-dashed border-[#efdccc]" />
                      <span aria-hidden="true" className="absolute inset-x-0 top-1/3 border-t border-dashed border-[#efdccc]" />
                      <span aria-hidden="true" className="absolute inset-x-0 top-2/3 border-t border-dashed border-[#efdccc]" />
                      <span aria-hidden="true" className="absolute inset-x-0 bottom-0 border-t border-[#ead5c2]" />
                      <div className="relative z-10 flex h-full items-end justify-between gap-1.5">
                        {BABY_SLEEP_CHART.map((row) => (
                          <div key={row.period} className="flex h-full min-w-0 flex-1 items-end justify-center gap-0.5">
                            <span className="w-2 rounded-t-full bg-[#25d6a3]" style={{ height: `${Math.max(4, (row.sleepMinutes / 90) * 100)}%`, opacity: row.sleepMinutes > 0 ? 1 : 0.16 }} />
                            <span className="w-2 rounded-t-full bg-[#e6b65c]" style={{ height: `${Math.max(4, (row.activityMinutes / 90) * 100)}%`, opacity: row.activityMinutes > 0 ? 1 : 0.16 }} />
                            <span className="w-2 rounded-t-full bg-[#8c78c8]" style={{ height: `${Math.max(4, (row.cryMinutes / 90) * 100)}%`, opacity: row.cryMinutes > 0 ? 1 : 0.16 }} />
                          </div>
                        ))}
                      </div>
                    </div>
                    <div className="mt-2 flex justify-between gap-1 text-[9px] font-bold text-[#9a8170]">
                      {BABY_SLEEP_CHART.map((row) => (
                        <span key={row.period} className="min-w-0 flex-1 text-center">{row.period}</span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </motion.section>
    </>
  );
};

const MomStatusPanelSheet: React.FC<{
  panel: MomStatusPanelId;
  onClose: () => void;
  onAgentPrefill: (prompt: string) => void;
  birthJourneyPlan: CarePlanArtifact | null;
  birthJourneyLoading: boolean;
  birthJourneyDeleting: boolean;
  birthJourneyDeleteErr: string | null;
  onDeleteBirthJourneyPlan: () => void;
  pregnancyDiaryEntries: PregnancyDiaryEntry[];
  pregnancyDiaryLoading: boolean;
  pregnancyDiaryJustSaved: boolean;
  onOpenDiaryEditor: () => void;
}> = ({
  panel,
  onClose,
  onAgentPrefill,
  birthJourneyPlan,
  birthJourneyLoading,
  birthJourneyDeleting,
  birthJourneyDeleteErr,
  onDeleteBirthJourneyPlan,
  pregnancyDiaryEntries,
  pregnancyDiaryLoading,
  pregnancyDiaryJustSaved,
  onOpenDiaryEditor,
}) => {
  const [postpartumTrainingHintVisible, setPostpartumTrainingHintVisible] = useState(false);
  const [birthJourneyDeleteConfirmVisible, setBirthJourneyDeleteConfirmVisible] = useState(false);
  const [expandedBirthJourneyPhaseKeys, setExpandedBirthJourneyPhaseKeys] = useState<Record<string, boolean>>({});
  const postpartumTrainingHintTimerRef = useRef<number | null>(null);
  const isInfo = panel.endsWith("-info");
  const isCenteredInfo =
    panel === "milk-info" || panel === "baby-feed-info" || panel === "breast-info" || panel === "rest-info";
  const titleMap: Record<MomStatusPanelId, string> = {
    "birth-journey-detail": "生产全过程计划",
    "pregnancy-diary-detail": "孕期日记",
    "milk-info": "今日产出说明",
    "baby-feed-info": "今日摄入说明",
    "breast-info": "乳房健康说明",
    "breast-detail": "乳房健康日记",
    "postpartum-detail": POSTPARTUM_RECOVERY_PLAN_TITLE,
    "rest-info": "补能与休息说明",
    "rest-detail": "补能与休息",
  };
  const infoTextMap: Partial<Record<MomStatusPanelId, string>> = {
    "milk-info": "使用吸奶器产出的奶量，不含亲喂",
    "baby-feed-info": "妈妈实际记录的喂养数据，不包含亲喂",
    "breast-info": "通过您和智能体的日常对话采集的乳房健康记录",
    "rest-info": "所有信息来自智能体的收集。",
  };
  const infoText = infoTextMap[panel] ?? "所有信息来自智能体的收集。";

  useEffect(() => {
    if (panel !== "birth-journey-detail") {
      setBirthJourneyDeleteConfirmVisible(false);
      setExpandedBirthJourneyPhaseKeys({});
    }
  }, [panel]);

  useEffect(() => {
    return () => {
      if (postpartumTrainingHintTimerRef.current !== null) {
        window.clearTimeout(postpartumTrainingHintTimerRef.current);
      }
    };
  }, []);

  const showPostpartumTrainingHint = () => {
    setPostpartumTrainingHintVisible(true);

    if (postpartumTrainingHintTimerRef.current !== null) {
      window.clearTimeout(postpartumTrainingHintTimerRef.current);
    }

    postpartumTrainingHintTimerRef.current = window.setTimeout(() => {
      setPostpartumTrainingHintVisible(false);
      postpartumTrainingHintTimerRef.current = null;
    }, 1500);
  };

  const birthJourneyPhases = birthJourneyPhaseList(birthJourneyPlan);
  const birthJourneyCurrentIndex = birthJourneyCurrentPhaseIndex(birthJourneyPlan);
  const birthJourneyCurrentPhase = currentBirthJourneyPhase(birthJourneyPlan);
  const birthJourneyCurrentGoal = compactText(birthJourneyCurrentPhase?.goal);
  const birthJourneyCurrentDateRange = compactText(birthJourneyCurrentPhase?.date_range);
  const birthJourneyCurrentWatchouts = compactTextList(birthJourneyCurrentPhase?.watchouts, 12);
  const birthJourneyCurrentSuggestions = birthJourneySuggestionPairs(birthJourneyCurrentPhase);
  const birthJourneyCurrentHelpPrompts = birthJourneyHelpPrompts(birthJourneyCurrentPhase);
  const birthJourneyUpcomingPhases = birthJourneyPhases
    .map((phase, index) => ({ phase, index }))
    .filter((item) => item.index > birthJourneyCurrentIndex);
  const pregnancyDiaryRecentCount7 = pregnancyDiaryRecentCount(pregnancyDiaryEntries, 7);
  const pregnancyDiaryQuestions = pregnancyDiaryQuestionCount(pregnancyDiaryEntries);
  const pregnancyDiaryReview = pregnancyDiaryReviewSummary(pregnancyDiaryEntries);
  const pregnancyDiaryPrompts = pregnancyDiaryAgentPrompts(pregnancyDiaryEntries);
  const pregnancyDiaryPrimaryPrompt = pregnancyDiaryPrompts[0] ?? "帮我回顾最近7天的孕期日记";
  const pregnancyDiaryPrimaryAction = pregnancyDiaryQuestions > 0 ? "整理产检问题" : "回顾最近记录";

  if (isCenteredInfo) {
    return (
      <>
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-50 bg-black/35 backdrop-blur-sm"
          onClick={onClose}
        />
        <motion.section
          role="dialog"
          aria-modal="true"
          aria-label={titleMap[panel]}
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.96 }}
          transition={{ duration: 0.18, ease: "easeOut" }}
          className="pointer-events-none fixed inset-0 z-[51] flex items-center justify-center px-6"
        >
          <div className="pointer-events-auto w-full max-w-[360px] rounded-3xl border border-white/70 bg-card px-5 py-4 shadow-2xl">
            <div className="mb-3 flex items-center justify-between gap-3">
              <h3 className="text-base font-extrabold text-foreground">{titleMap[panel]}</h3>
              <button type="button" onClick={onClose} className="rounded-full p-2 text-muted-foreground active:bg-muted">
                <X className="h-4 w-4" />
              </button>
            </div>
            <p className="rounded-2xl bg-muted/45 px-4 py-3 text-sm font-medium leading-relaxed text-foreground">
              {infoText}
            </p>
          </div>
        </motion.section>
      </>
    );
  }

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 bg-black/35 backdrop-blur-sm"
        onClick={onClose}
      />
      <motion.section
        initial={{ y: "100%", opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        exit={{ y: "100%", opacity: 0 }}
        transition={{ type: "spring", damping: 28, stiffness: 300 }}
        className="fixed inset-x-0 bottom-0 z-50 mx-auto w-full max-w-lg rounded-t-3xl border-t border-border/40 bg-card px-5 pt-4 shadow-2xl"
        style={{ paddingBottom: "max(1.75rem, env(safe-area-inset-bottom))" }}
      >
        <div className="mb-4 flex items-center justify-between gap-3">
          <h3 className="text-base font-extrabold text-foreground">{titleMap[panel]}</h3>
          <button type="button" onClick={onClose} className="rounded-full p-2 text-muted-foreground active:bg-muted">
            <X className="h-4 w-4" />
          </button>
        </div>

        {isInfo ? (
          <div className="rounded-2xl bg-muted/45 px-4 py-3 text-sm font-medium leading-relaxed text-foreground">
            {infoText}
          </div>
        ) : null}

        {panel === "birth-journey-detail" ? (
          <div className="max-h-[76vh] space-y-3 overflow-y-auto pr-1">
            {birthJourneyLoading ? (
              <div className="rounded-2xl bg-muted/45 px-4 py-5 text-center text-sm font-semibold text-muted-foreground">
                正在加载生产全过程计划…
              </div>
            ) : birthJourneyPlan ? (
              <>
                <div className="space-y-3 rounded-2xl border border-[#edb586] bg-[#fff7ee] px-4 py-3">
                  <div className="flex items-start gap-3">
                    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#f2a36e] text-white">
                      <ClipboardList className="h-4 w-4" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="text-[11px] font-bold text-[#b65c28]">当前阶段</p>
                      <div className="mt-0.5 flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-0.5">
                        <p className="text-base font-extrabold leading-tight text-foreground">
                          {birthJourneyCurrentPhase?.title ?? "待完善"}
                        </p>
                        {birthJourneyCurrentDateRange ? (
                          <p className="text-[11px] font-bold leading-tight text-[#a8653a]">
                            {birthJourneyCurrentDateRange}
                          </p>
                        ) : null}
                      </div>
                    </div>
                  </div>

                  {birthJourneyCurrentGoal ? (
                    <section className="rounded-xl border border-[#f5d4bc] bg-white px-3 py-2.5">
                      <p className="text-[11px] font-extrabold text-[#b65c28]">阶段目标</p>
                      <p className="mt-1 text-xs font-semibold leading-relaxed text-[#5f5368]">{birthJourneyCurrentGoal}</p>
                    </section>
                  ) : null}

                  {birthJourneyCurrentWatchouts.length > 0 ? (
                    <section className="rounded-xl border border-[#f6ddb2] bg-[#fffaf2] px-3 py-2.5">
                      <p className="text-[11px] font-extrabold text-[#805d22]">温馨提醒</p>
                      <div className="mt-1.5 space-y-1.5">
                        {birthJourneyCurrentWatchouts.map((item) => (
                          <p key={item} className="text-[11px] font-semibold leading-relaxed text-[#6d5530]">{item}</p>
                        ))}
                      </div>
                    </section>
                  ) : null}

                  <section>
                    <p className="text-sm font-extrabold text-foreground">本阶段建议做</p>
                    {birthJourneyCurrentSuggestions.length > 0 ? (
                      <div className="mt-2 space-y-2">
                        {birthJourneyCurrentSuggestions.map((suggestion, suggestionIndex) => (
                          <div key={suggestion.action} className="rounded-xl bg-white px-3 py-2">
                            <div className="flex gap-2">
                              <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[#fff0e4] text-[11px] font-extrabold leading-none text-[#b65c28]">
                                {suggestionIndex + 1}
                              </span>
                              <p className="text-xs font-extrabold leading-relaxed text-[#5f5368]">{suggestion.action}</p>
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="mt-2 rounded-xl bg-muted/30 px-3 py-2 text-xs font-semibold text-muted-foreground">
                        暂无本阶段建议，建议继续补充计划。
                      </p>
                    )}
                    {birthJourneyCurrentHelpPrompts.length > 0 ? (
                      <div className="mt-3">
                        <p className="text-[11px] font-extrabold text-[#b65c28]">我能帮你做</p>
                        <div className="mt-1.5 flex flex-wrap gap-1.5">
                          {birthJourneyCurrentHelpPrompts.map((prompt) => (
                            <button
                              key={prompt}
                              type="button"
                              onClick={() => onAgentPrefill(prompt)}
                              className="inline-flex items-center gap-1.5 rounded-xl border border-[#b65c28] bg-[#b65c28] px-3 py-2 text-[11px] font-extrabold leading-relaxed text-white transition-colors hover:bg-[#a94f22] active:scale-[0.98]"
                            >
                              <span>{prompt}</span>
                              <ArrowRight className="h-3 w-3 shrink-0" />
                            </button>
                          ))}
                        </div>
                      </div>
                    ) : null}
                  </section>
                </div>

                <div className="rounded-2xl border border-[#eadfd8] bg-[#fffdfb] px-4 py-3">
                  <div className="mb-2 flex items-center gap-2">
                    <p className="text-sm font-extrabold text-[#4a3f3a]">未来计划</p>
                  </div>
                  {birthJourneyUpcomingPhases.length > 0 ? (
                    <div className="space-y-2">
                          {birthJourneyUpcomingPhases.map(({ phase, index }) => {
                            const phaseKey = birthJourneyPhaseKey(phase, index);
                            const expanded = Boolean(expandedBirthJourneyPhaseKeys[phaseKey]);
                            const detailSections = birthJourneyPhaseDetailSections(phase);
                            return (
                          <article key={phaseKey} className="rounded-xl bg-[#f8f5f2] px-3 py-2">
                            <button
                              type="button"
                              onClick={() =>
                                setExpandedBirthJourneyPhaseKeys((prev) => ({
                                  ...prev,
                                  [phaseKey]: !prev[phaseKey],
                                }))
                              }
                              aria-expanded={expanded}
                              className="block w-full text-left"
                            >
                              <div className="min-w-0 flex-1">
                                <div className="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-0.5">
                                  <p className="shrink-0 text-sm font-extrabold text-foreground">{phase.title ?? "阶段"}</p>
                                  {phase.date_range ? (
                                    <span className="min-w-0 text-[11px] font-bold text-muted-foreground">{phase.date_range}</span>
                                  ) : null}
                                </div>
                              </div>
                            </button>
                                {expanded && (
                                  detailSections.goal ||
                                  detailSections.watchouts.length > 0 ||
                                  detailSections.suggestions.length > 0 ||
                                  detailSections.helpPrompts.length > 0
                                ) ? (
                                  <div className="mt-3 space-y-3 border-t border-[#e5ded9] pt-3">
                                    {detailSections.goal ? (
                                      <section>
                                        <p className="text-[11px] font-extrabold text-[#4a4542]">阶段目标</p>
                                        <p className="mt-1 text-[11px] font-normal leading-relaxed text-[#5b5450]">
                                          {detailSections.goal}
                                        </p>
                                      </section>
                                    ) : null}
                                    {detailSections.watchouts.length > 0 ? (
                                      <section>
                                        <p className="text-[11px] font-extrabold text-[#4a4542]">温馨提醒</p>
                                        <div className="mt-1 space-y-1">
                                          {detailSections.watchouts.map((item) => (
                                            <p key={item} className="text-[11px] font-normal leading-relaxed text-[#5b5450]">{item}</p>
                                          ))}
                                        </div>
                                      </section>
                                    ) : null}
                                    {detailSections.suggestions.length > 0 ? (
                                      <section>
                                        <p className="text-[11px] font-extrabold text-[#4a4542]">本阶段建议做</p>
                                        <div className="mt-1.5 space-y-1.5">
                                          {detailSections.suggestions.map((suggestion, suggestionIndex) => (
                                            <div key={suggestion.action} className="rounded-xl bg-white/70 px-3 py-2">
                                              <div className="flex gap-1.5 text-[11px] font-normal leading-relaxed text-[#5b5450]">
                                                <span className="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-[#ece8e4] text-[10px] font-extrabold leading-none text-[#4a4542]">
                                                  {suggestionIndex + 1}
                                                </span>
                                                <span>{suggestion.action}</span>
                                              </div>
                                            </div>
                                          ))}
                                        </div>
                                      </section>
                                    ) : null}
                                    {detailSections.helpPrompts.length > 0 ? (
                                      <section>
                                        <p className="text-[11px] font-extrabold text-[#4a4542]">我能帮你做</p>
                                        <div className="mt-1.5 flex flex-wrap gap-1.5">
                                          {detailSections.helpPrompts.map((prompt) => (
                                            <button
                                              key={prompt}
                                              type="button"
                                              onClick={() => onAgentPrefill(prompt)}
                                              className="inline-flex items-center gap-1.5 rounded-xl border border-[#c9beb7] bg-white px-3 py-2 text-[11px] font-extrabold leading-relaxed text-[#4a4542] transition-colors hover:border-[#9d8f86] hover:bg-[#f8f5f2] active:scale-[0.98]"
                                            >
                                              <span>{prompt}</span>
                                              <ArrowRight className="h-3 w-3 shrink-0" />
                                            </button>
                                          ))}
                                        </div>
                                      </section>
                                    ) : null}
                                  </div>
                                ) : null}
                          </article>
                        );
                      })}
                    </div>
                  ) : (
                    <p className="rounded-xl bg-muted/30 px-3 py-3 text-xs font-semibold text-muted-foreground">
                      当前已经是计划中的最后阶段。
                    </p>
                  )}
                </div>

                {birthJourneyDeleteErr ? (
                  <p className="rounded-2xl bg-destructive/10 px-4 py-2 text-xs font-bold text-destructive">
                    {birthJourneyDeleteErr}
                  </p>
                ) : null}

                {birthJourneyDeleteConfirmVisible ? (
                  <div className="rounded-2xl border border-destructive/20 bg-destructive/5 px-4 py-3">
                    <p className="text-sm font-extrabold text-foreground">确认删除生产全过程计划？</p>
                    <p className="mt-1 text-xs font-semibold leading-relaxed text-muted-foreground">
                      删除后，状态页不再展示这份计划。需要时可以重新生成。
                    </p>
                    <div className="mt-3 grid grid-cols-2 gap-2">
                      <button
                        type="button"
                        onClick={() => setBirthJourneyDeleteConfirmVisible(false)}
                        disabled={birthJourneyDeleting}
                        className="inline-flex items-center justify-center rounded-2xl border border-border bg-card px-4 py-3 text-sm font-extrabold text-foreground active:scale-[0.99] disabled:opacity-60"
                      >
                        取消
                      </button>
                      <button
                        type="button"
                        onClick={onDeleteBirthJourneyPlan}
                        disabled={birthJourneyDeleting}
                        className="inline-flex items-center justify-center gap-2 rounded-2xl bg-destructive px-4 py-3 text-sm font-extrabold text-destructive-foreground active:scale-[0.99] disabled:opacity-60"
                      >
                        <Trash2 className="h-4 w-4" />
                        {birthJourneyDeleting ? "删除中" : "确认删除"}
                      </button>
                    </div>
                  </div>
                    ) : (
                      <div className="flex justify-end">
                        <button
                          type="button"
                          onClick={() => setBirthJourneyDeleteConfirmVisible(true)}
                          disabled={birthJourneyDeleting}
                          className="inline-flex items-center justify-center gap-1.5 px-3 py-2 text-xs font-bold text-muted-foreground active:text-destructive disabled:opacity-60"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                          删除计划
                        </button>
                      </div>
                    )}
              </>
            ) : (
              <div className="space-y-3">
                <div className="rounded-2xl border border-[#e6d9fb] bg-[#fbf7ff] px-4 py-5 text-center">
                  <ClipboardList className="mx-auto h-7 w-7 text-[#7d64aa]" />
                  <p className="mt-2 text-sm font-extrabold text-foreground">还没有生产全过程计划</p>
                  <p className="mt-1 text-xs font-semibold leading-relaxed text-[#6f617a]">
                    生成后会在这里展示当前阶段、下一步行动和完整生产时间线。
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => onAgentPrefill("帮我制定生产全过程计划")}
                  className="inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-primary px-4 py-3 text-sm font-extrabold text-primary-foreground active:scale-[0.99]"
                >
                  <MaiInlineAvatar />
                  制定生产全过程计划
                </button>
              </div>
            )}
          </div>
        ) : null}

        {panel === "pregnancy-diary-detail" ? (
          <div className="max-h-[76vh] space-y-4 overflow-y-auto pr-1">
            <section className="rounded-[20px] border border-[#eadfd8] bg-[#fff9f2] px-5 py-5">
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <p className="text-[11px] font-extrabold text-[#b66335]">最近一周</p>
                  <p className="mt-2 text-[18px] font-extrabold leading-relaxed text-[#36272f]">
                    记录了 {pregnancyDiaryRecentCount7}/7 天
                  </p>
                  <p className="mt-2 text-xs font-semibold leading-relaxed text-[#7f6b70]">
                    {pregnancyDiaryReview}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={onOpenDiaryEditor}
                  className="inline-flex shrink-0 items-center gap-1.5 rounded-full bg-[#b66335] px-4 py-2.5 text-xs font-extrabold text-white shadow-[0_8px_18px_rgba(182,99,53,0.22)] active:scale-[0.98]"
                >
                  <PencilLine className="h-3.5 w-3.5" />
                  记录今天
                </button>
              </div>
            </section>

            {pregnancyDiaryJustSaved ? (
              <p className="rounded-2xl border border-[#bfe3d8] bg-[#f2fbf7] px-4 py-3 text-xs font-bold leading-relaxed text-[#3f7162]">
                今天的记录已保存，我可以继续帮你整理产检问题或回顾最近几天的状态变化。
              </p>
            ) : null}

            {pregnancyDiaryEntries.length > 0 ? (
              <section className="rounded-[20px] border border-[#eadfd8] bg-white px-4 py-3">
                <button
                  type="button"
                  onClick={() => onAgentPrefill(pregnancyDiaryPrimaryPrompt)}
                  className="flex w-full items-center justify-between gap-3 text-left active:scale-[0.99]"
                >
                  <div className="flex min-w-0 items-center gap-3">
                    <MaiInlineAvatar />
                    <div className="min-w-0">
                      <p className="text-sm font-extrabold text-foreground">{pregnancyDiaryPrimaryAction}</p>
                      <p className="mt-0.5 text-[11px] font-semibold leading-relaxed text-[#8a757b]">
                        {pregnancyDiaryQuestions > 0
                          ? `从日记里整理 ${pregnancyDiaryQuestions} 个问题`
                          : "把最近记录整理成一段状态回顾"}
                      </p>
                    </div>
                  </div>
                  <span className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[#f5eee9] text-[#9b552f]">
                    <ArrowRight className="h-4 w-4" />
                  </span>
                </button>
              </section>
            ) : null}

            {pregnancyDiaryLoading ? (
              <div className="rounded-2xl bg-muted/45 px-4 py-5 text-center text-sm font-semibold text-muted-foreground">
                正在加载孕期日记…
              </div>
            ) : pregnancyDiaryEntries.length > 0 ? (
              <section className="space-y-3">
                <div className="flex items-baseline justify-between gap-3 px-1">
                  <p className="text-base font-extrabold text-foreground">最近记录</p>
                  <p className="text-[10px] font-bold text-muted-foreground">{pregnancyDiaryEntries.length} 篇</p>
                </div>
                <div className="space-y-3">
                  {pregnancyDiaryEntries.map((entry, index) => (
                    <article
                      key={entry.entry_id}
                      className={`rounded-[18px] border px-4 py-4 ${
                        index === 0
                          ? "border-[#efc8ac] bg-[#fff7ee]"
                          : "border-[#eadfd8] bg-[#fffdfb]"
                      }`}
                    >
                      <div className="flex min-w-0 items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="text-sm font-extrabold text-foreground">{formatDiaryDateLabel(entry.entry_date)}</p>
                          {entry.gestational_week ? (
                            <p className="mt-0.5 text-[10px] font-bold text-[#8a757b]">{entry.gestational_week}</p>
                          ) : null}
                        </div>
                        {index === 0 ? (
                          <span className="shrink-0 rounded-full bg-[#f4e3d5] px-2.5 py-1 text-[10px] font-extrabold text-[#9b552f]">
                            今天
                          </span>
                        ) : null}
                      </div>
                      {entry.content ? (
                        <p className="mt-3 line-clamp-2 text-xs font-semibold leading-relaxed text-[#5f5357]">{entry.content}</p>
                      ) : (
                        <p className="mt-3 text-xs font-semibold leading-relaxed text-[#5f5357]">
                          {pregnancyDiarySummary(entry)}
                        </p>
                      )}
                      <div className="mt-3 flex flex-wrap gap-1.5">
                        {pregnancyDiarySignalTags(entry).map((tag) => (
                          <span key={tag} className="rounded-full bg-[#f5eee9] px-2.5 py-1 text-[10px] font-bold text-[#75666b]">
                            {tag}
                          </span>
                        ))}
                        {entry.appointment_note ? (
                          <span className="rounded-full bg-[#f5eee9] px-2.5 py-1 text-[10px] font-bold text-[#9b552f]">
                            有产检问题
                          </span>
                        ) : null}
                      </div>
                    </article>
                  ))}
                </div>
              </section>
            ) : (
              <div className="rounded-[24px] border border-[#eadfd8] bg-[#fffdfb] px-4 py-5 text-center">
                <BookOpen className="mx-auto h-7 w-7 text-[#b66335]" />
                <p className="mt-2 text-sm font-extrabold text-foreground">还没有孕期日记</p>
                <p className="mt-1 text-xs font-semibold leading-relaxed text-[#7f6b70]">
                  从今天开始记录心情、身体感受、胎动和产检点滴。
                </p>
              </div>
            )}
          </div>
        ) : null}

        {panel === "breast-detail" ? (
          <div className="space-y-3">
            <div className="relative flex flex-col-reverse gap-3">
              <span aria-hidden="true" className="absolute bottom-3 left-[9px] top-3 w-px bg-[#ffd9c8]" />
              {BREAST_HEALTH_TIMELINE.map((record, index) => {
                const isCurrent = index === BREAST_HEALTH_TIMELINE.length - 1;
                return (
                  <article key={record.time} className="relative flex gap-3">
                    <span
                      aria-hidden="true"
                      className={`mt-1 h-5 w-5 shrink-0 rounded-full border-2 ${
                        isCurrent
                          ? "border-[#b96f55] bg-[#ffd9c8] shadow-[0_0_0_4px_rgba(255,217,200,0.45)]"
                          : "border-[#ffd9c8] bg-card"
                      }`}
                    />
                    <div className="min-w-0 flex-1 rounded-2xl border border-[#ffd9c8] bg-[#fff8f1] px-4 py-3">
                      <div className="flex min-w-0 items-center justify-between gap-2">
                        <p className="truncate text-sm font-extrabold text-foreground">{record.title}</p>
                        <span className="shrink-0 text-[11px] font-bold text-[#b6674b]">{record.time}</span>
                      </div>
                      <p className="mt-1 text-xs font-semibold leading-relaxed text-[#6f5560]">{record.detail}</p>
                    </div>
                  </article>
                );
              })}
            </div>
            <button
              type="button"
              onClick={() => onAgentPrefill("我想了解乳房健康情况，最近有涨奶和硬块，按压会疼")}
              className="inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-primary px-4 py-3 text-sm font-extrabold text-primary-foreground active:scale-[0.99]"
            >
              <MaiInlineAvatar />
              让我了解更多
            </button>
          </div>
        ) : null}

        {panel === "postpartum-detail" ? (
          <div className="space-y-3">
            <div className="space-y-2">
              {POSTPARTUM_RECOVERY_COURSES.map((course) => (
                <article key={course.title} className="rounded-2xl border border-border/50 bg-background px-4 py-3">
                  <div className="flex items-center gap-1.5">
                    <p className="text-[11px] font-bold text-[#2f8a72]">{course.time}</p>
                    {"status" in course ? (
                      <span className="rounded-full bg-[#dcf7ed] px-2 py-0.5 text-[10px] font-extrabold text-[#2f8a72]">
                        {course.status}
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1 text-sm font-bold text-foreground">{course.title}</p>
                  <p className="mt-1 text-xs font-medium leading-snug text-muted-foreground">{course.detail}</p>
                </article>
              ))}
            </div>
            <div className="relative">
              <AnimatePresence>
                {postpartumTrainingHintVisible ? (
                  <motion.div
                    initial={{ opacity: 0, y: 6, scale: 0.98 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 4, scale: 0.98 }}
                    transition={{ duration: 0.18, ease: "easeOut" }}
                    className="pointer-events-none absolute -top-10 right-0 z-10 whitespace-nowrap rounded-full bg-[#35212c]/90 px-3 py-1.5 text-[12px] font-bold text-white shadow-lg"
                  >
                    暂未开通此功能
                  </motion.div>
                ) : null}
              </AnimatePresence>
              <button
                type="button"
                onClick={showPostpartumTrainingHint}
                className="inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-primary px-4 py-3 text-sm font-extrabold text-primary-foreground active:scale-[0.99]"
              >
                <MaiInlineAvatar />
                继续训练
              </button>
            </div>
          </div>
        ) : null}

        {panel === "rest-detail" ? (
          <div className="space-y-3">
            <div className="relative flex flex-col-reverse gap-3">
              <span aria-hidden="true" className="absolute bottom-3 left-[9px] top-3 w-px bg-[#ffe4b8]" />
              {REST_RECOVERY_TIMELINE.map((record, index) => {
                const isCurrent = index === REST_RECOVERY_TIMELINE.length - 1;
                return (
                  <article key={record.time} className="relative flex gap-3">
                    <span
                      aria-hidden="true"
                      className={`mt-1 h-5 w-5 shrink-0 rounded-full border-2 ${
                        isCurrent
                          ? "border-[#b36d20] bg-[#ffe4b8] shadow-[0_0_0_4px_rgba(255,228,184,0.5)]"
                          : "border-[#ffe4b8] bg-card"
                      }`}
                    />
                    <div className="min-w-0 flex-1 rounded-2xl border border-[#ffe4b8] bg-[#fffaf0] px-4 py-3">
                      <div className="flex min-w-0 items-center justify-between gap-2">
                        <p className="truncate text-sm font-extrabold text-foreground">{record.title}</p>
                        <span className="shrink-0 text-[11px] font-bold text-[#b36d20]">{record.time}</span>
                      </div>
                      <p className="mt-1 text-xs font-semibold leading-relaxed text-[#6d5530]">{record.detail}</p>
                    </div>
                  </article>
                );
              })}
            </div>
            <button
              type="button"
              onClick={() => onAgentPrefill("我想了解最近的睡眠和休息情况，夜间照护后白天很疲惫")}
              className="w-full rounded-2xl bg-primary px-4 py-3 text-sm font-extrabold text-primary-foreground active:scale-[0.99]"
            >
              让我了解更多
            </button>
          </div>
        ) : null}
      </motion.section>
    </>
  );
};

/* ── Expandable Section Component ── */
const Expandable: React.FC<{
  title: string;
  icon: React.ReactNode;
  badge?: React.ReactNode;
  summary?: React.ReactNode;
  children: React.ReactNode;
  defaultOpen?: boolean;
  className?: string;
  id?: string;
}> = ({ title, icon, badge, summary, children, defaultOpen = false, className = "", id }) => {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <motion.div
      id={id}
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={`mx-4 mb-3 rounded-[16px] bg-card border border-border/55 shadow-none overflow-hidden ${className}`}
    >
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="w-full flex items-center gap-2 p-3.5 text-left"
      >
        <div className="w-6 h-6 shrink-0 flex items-center justify-center">
          {icon}
        </div>
        <span className="text-sm font-semibold text-foreground flex-1">{title}</span>
        {badge}
        <motion.div animate={{ rotate: open ? 180 : 0 }} transition={{ duration: 0.2 }}>
          <ChevronDown className="w-4 h-4 text-muted-foreground" />
        </motion.div>
      </button>
      {!open && summary && (
        <div className="px-4 pb-3 -mt-1">{summary}</div>
      )}
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25, ease: "easeInOut" }}
          >
            <div className="px-4 pb-4 min-w-0">{children}</div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

type StatusModuleTone = "rose" | "amber" | "mint" | "sky" | "violet" | "peach" | "aqua" | "pink";

const STATUS_MODULE_TONE_CLASSES: Record<
  StatusModuleTone,
  { card: string; icon: string; cta: string; glow: string }
> = {
  rose: {
    card: "from-[#fff7f9] via-[#fffafb] to-[#fff0f5]",
    icon: "bg-[#f4dbe4] text-[#a96a80]",
    cta: "bg-white/80 text-[#a35f76]",
    glow: "bg-[#f2bfd0]",
  },
  amber: {
    card: "from-[#fffaf0] via-[#fffdf8] to-[#fff1d6]",
    icon: "bg-[#ffe4b8] text-[#b9792a]",
    cta: "bg-white/80 text-[#b36d20]",
    glow: "bg-[#ffd287]",
  },
  mint: {
    card: "from-[#f2fffb] via-[#fbfffd] to-[#dcf7ed]",
    icon: "bg-[#cceee1] text-[#388b72]",
    cta: "bg-white/80 text-[#2f8a72]",
    glow: "bg-[#ace4d1]",
  },
  sky: {
    card: "from-[#f4fbff] via-[#fbfdff] to-[#e1f1ff]",
    icon: "bg-[#d5eafa] text-[#4f84a6]",
    cta: "bg-white/80 text-[#477f9f]",
    glow: "bg-[#b9dff4]",
  },
  violet: {
    card: "from-[#fbf7ff] via-[#fffafd] to-[#eee6ff]",
    icon: "bg-[#e6d9fb] text-[#7d64aa]",
    cta: "bg-white/80 text-[#7560a0]",
    glow: "bg-[#d8c7f4]",
  },
  peach: {
    card: "from-[#fff8f1] via-[#fffdf9] to-[#ffe7dc]",
    icon: "bg-[#ffd9c8] text-[#b96f55]",
    cta: "bg-white/80 text-[#b6674b]",
    glow: "bg-[#ffc6ad]",
  },
  aqua: {
    card: "from-[#f1fffe] via-[#fbffff] to-[#d8f4f5]",
    icon: "bg-[#c8ecee] text-[#3b8a90]",
    cta: "bg-white/80 text-[#31828b]",
    glow: "bg-[#aee0e5]",
  },
  pink: {
    card: "from-[#fff6fb] via-[#fffafd] to-[#ffe5f0]",
    icon: "bg-[#f6d6e5] text-[#b75d82]",
    cta: "bg-white/80 text-[#ad5579]",
    glow: "bg-[#f0b6cf]",
  },
};

type StatusModuleCardProps = {
  title: string;
  subtitle?: string;
  bodyText?: React.ReactNode;
  value?: string;
  supportingText?: string;
  metrics?: readonly {
    label: string;
    value: string;
    onInfoClick?: () => void;
    ariaLabel?: string;
  }[];
  action?: string;
  secondaryAction?: string;
  notificationLabel?: string;
  icon: React.ReactNode;
  tone: StatusModuleTone;
  onClick?: () => void;
  onSecondaryClick?: () => void;
  onInfoClick?: () => void;
  infoPlacement?: "title" | "subtitle";
  alignActionTextWithTitle?: boolean;
};

function StatusModuleCard({
  title,
  subtitle,
  bodyText,
  value,
  supportingText,
  metrics,
  action,
  secondaryAction,
  notificationLabel,
  icon,
  tone,
  onClick,
  onSecondaryClick,
  onInfoClick,
  infoPlacement = "title",
  alignActionTextWithTitle = false,
}: StatusModuleCardProps) {
  const toneClasses = STATUS_MODULE_TONE_CLASSES[tone];
  const hasMetrics = Boolean(metrics?.length);
  const hasBodyText = Boolean(bodyText);
  const infoButton = onInfoClick ? (
    <button
      type="button"
      aria-label={`${title}说明`}
      onClick={onInfoClick}
      className="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-white/65 text-[#8d6f7d] shadow-[0_4px_12px_-9px_rgba(83,47,64,0.35)] active:scale-95"
    >
      <HelpCircle className="h-3.5 w-3.5" />
    </button>
  ) : null;
  const content = (
    <>
      {notificationLabel ? (
        <span className="absolute right-12 top-3 z-20 rounded-full bg-[#d85f8c] px-2 py-0.5 text-[10px] font-extrabold leading-tight text-white shadow-sm">
          {notificationLabel}
        </span>
      ) : null}
      <div className="relative z-10 flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="flex min-w-0 items-center gap-1">
            <h3 className="truncate text-[14px] font-bold leading-tight text-[#35212c]">{title}</h3>
            {infoPlacement === "title" ? infoButton : null}
          </div>
          {subtitle ? (
            <div className="mt-1 flex min-w-0 items-start gap-1">
              <p className="line-clamp-2 text-[11px] font-medium leading-snug text-[#7a6870]">{subtitle}</p>
              {infoPlacement === "subtitle" ? infoButton : null}
            </div>
          ) : null}
        </div>
        <span className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-xl ${toneClasses.icon}`}>
          {icon}
        </span>
      </div>
      <div className={`relative z-10 ${hasMetrics ? "mt-5" : hasBodyText ? "mt-2 flex flex-1 flex-col" : "mt-auto"}`}>
        {bodyText ? (
          <p className="my-auto line-clamp-2 text-[11px] font-medium leading-snug text-[#7a6870]">{bodyText}</p>
        ) : null}
        {metrics?.length ? (
          <div className={`grid ${metrics.length >= 3 ? "grid-cols-3 gap-1.5" : metrics.length > 1 ? "grid-cols-2 gap-2" : "grid-cols-1 gap-2"}`}>
            {metrics.map((metric) => (
              <div key={metric.label} className="min-w-0">
                <div className="flex min-w-0 items-center gap-1">
                  <span className="truncate text-[11px] font-semibold leading-tight text-[#7a5b68]">{metric.label}</span>
                  {metric.onInfoClick ? (
                    <button
                      type="button"
                      aria-label={metric.ariaLabel ?? `${metric.label}说明`}
                      onClick={metric.onInfoClick}
                      className="inline-flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-white/65 text-[#8d6f7d] shadow-[0_4px_12px_-9px_rgba(83,47,64,0.35)] active:scale-95"
                    >
                      <HelpCircle className="h-3 w-3" />
                    </button>
                  ) : null}
                </div>
                <p className={`mt-1 min-h-[22px] truncate font-bold leading-tight text-[#35212c] ${metrics.length >= 3 ? "text-[14px]" : "text-[16px]"}`}>{metric.value}</p>
              </div>
            ))}
          </div>
        ) : null}
        {value ? <p className="min-h-[22px] text-[16px] font-bold leading-tight text-[#35212c]">{value}</p> : null}
        {supportingText ? <p className="mt-1 text-[11px] font-medium leading-snug text-[#7a5b68]">{supportingText}</p> : null}
        {action || secondaryAction ? (
          <div className={`mt-2 flex flex-wrap gap-1.5 ${alignActionTextWithTitle ? "-ml-2.5" : ""}`}>
            {action ? (
              onClick ? (
                <button type="button" onClick={onClick} className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${toneClasses.cta}`}>
                  {action}
                </button>
              ) : (
                <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${toneClasses.cta}`}>
                  {action}
                </span>
              )
            ) : null}
            {secondaryAction ? (
              onSecondaryClick ? (
                <button type="button" onClick={onSecondaryClick} className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${toneClasses.cta}`}>
                  {secondaryAction}
                </button>
              ) : (
                <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${toneClasses.cta}`}>
                  {secondaryAction}
                </span>
              )
            ) : null}
          </div>
        ) : null}
      </div>
      <span
        aria-hidden="true"
        className={`absolute -bottom-8 -right-6 h-24 w-24 rounded-full opacity-25 blur-lg ${toneClasses.glow}`}
      />
    </>
  );

  const className = `relative flex min-h-[132px] flex-col overflow-hidden rounded-[16px] border border-white/80 bg-gradient-to-br p-3.5 text-left shadow-none ring-1 ring-border/20 ${toneClasses.card}`;

  return <article className={className}>{content}</article>;
}

function scrollStatusSection(id: string): void {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
}


type VolumeUnit = Parameters<typeof formatVol>[1];

type LactationTrendPoint = {
  dateKey: string;
  actual: number;
  estimated: number;
  refPad: number;
  refSpan: number;
  actualMl: number;
  estimatedMl: number;
  refLowMl: number;
  refHighMl: number;
};

const LactationTrendTooltip = ({
  active,
  label,
  payload,
  unit,
}: {
  active?: boolean;
  label?: string;
  payload?: readonly { payload?: LactationTrendPoint }[];
  unit: VolumeUnit;
}) => {
  const row = payload?.[0]?.payload;
  if (!active || !row) return null;
  const uLabel = unitLabel(unit);
  const line = (ml: number, name: string, color: string) => (
    <p key={name} style={{ color }}>
      {name}：{formatVol(ml, unit)}
      {uLabel}
    </p>
  );
  return (
    <div className="rounded-lg bg-card border border-border/50 px-3 py-2 text-xs shadow-lg max-w-[220px]">
      <p className="font-semibold text-foreground mb-1">{label}</p>
      {line(row.actualMl, "吸乳总量", LACTATION_TREND_COLORS.actual)}
      {line(row.estimatedMl, "含亲喂估算", LACTATION_TREND_COLORS.estimate)}
      <p className="text-muted-foreground mt-0.5 border-t border-border/40 pt-1">
        参考区间：{formatVol(row.refLowMl, unit)}
        {uLabel} – {formatVol(row.refHighMl, unit)}
        {uLabel}
      </p>
    </div>
  );
};

function lactationEstimateMl(item: PumpInfoLactationDayItem): number {
  const raw = item.total_milk_estimate ?? item.totol_milk_estimate;
  const n = typeof raw === "number" ? raw : Number(raw);
  return Number.isFinite(n) ? Math.max(0, n) : 0;
}

function parseLactationDateKey(raw: string): string {
  const t = raw.trim();
  const iso = t.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`;
  const slash = t.match(/^(\d{4})[/-](\d{1,2})[/-](\d{1,2})/);
  if (slash) {
    return `${slash[1]}-${slash[2].padStart(2, "0")}-${slash[3].padStart(2, "0")}`;
  }
  const monthDay = t.match(/^(\d{1,2})[/-](\d{1,2})$/);
  if (monthDay) {
    const year = new Date().getFullYear();
    return `${year}-${monthDay[1].padStart(2, "0")}-${monthDay[2].padStart(2, "0")}`;
  }
  return t;
}

function shortLactationDateLabel(dateKey: string): string {
  const p = dateKey.split("-");
  if (p.length >= 3) return `${p[1]}/${p[2]}`;
  return dateKey;
}

function toLocalDateKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function shiftLocalDate(base: Date, offsetDays: number): Date {
  return new Date(base.getFullYear(), base.getMonth(), base.getDate() + offsetDays);
}

function buildRecentDateKeys(windowSize: number, baseNow = new Date()): string[] {
  const out: string[] = [];
  const baseDate = new Date(baseNow.getFullYear(), baseNow.getMonth(), baseNow.getDate());
  for (let i = windowSize - 1; i >= 0; i--) {
    out.push(toLocalDateKey(shiftLocalDate(baseDate, -i)));
  }
  return out;
}

function pickLactationTrendDateTicks(dateKeys: readonly string[], windowSize: 7 | 30): string[] {
  const n = dateKeys.length;
  if (n === 0) return [];
  if (windowSize === 7 || n <= 8) return [...dateKeys];
  const tickCount = Math.min(7, n);
  const idxSet = new Set<number>();
  for (let i = 0; i < tickCount; i++) {
    const idx = tickCount === 1 ? 0 : Math.round((i / (tickCount - 1)) * (n - 1));
    idxSet.add(idx);
  }
  return [...idxSet].sort((a, b) => a - b).map((idx) => dateKeys[idx]!);
}

function formatLactationTrendDateTick(dateKey: string): string {
  return shortLactationDateLabel(dateKey);
}

function formatLactationTrendTooltipDate(dateKey: string): string {
  const [y, m, d] = dateKey.split("-");
  if (!y || !m || !d) return dateKey;
  return `${y}/${m}/${d}`;
}

type LactationTrendRowMl = {
  dateKey: string;
  date: string;
  actualMl: number;
  estimatedMl: number;
  refLowMl: number;
  refHighMl: number;
};

function buildLactationTrendRowsMl(list: PumpInfoLactationDayItem[]): LactationTrendRowMl[] {
  const byKey = new Map<string, PumpInfoLactationDayItem>();
  for (const item of list) {
    const key = parseLactationDateKey(item.delivery_date);
    byKey.set(key, item);
  }
  const keys = [...byKey.keys()].sort((a, b) => a.localeCompare(b));
  return keys.map((dateKey) => {
    const item = byKey.get(dateKey)!;
    let refLo = typeof item.reference_lower === "number" ? item.reference_lower : Number(item.reference_lower);
    let refHi = typeof item.reference_upper === "number" ? item.reference_upper : Number(item.reference_upper);
    if (!Number.isFinite(refLo)) refLo = 0;
    if (!Number.isFinite(refHi)) refHi = 0;
    refHi = Math.max(refHi, refLo);
    const rawAct = typeof item.total_milk === "number" ? item.total_milk : Number(item.total_milk);
    const actualMl = Number.isFinite(rawAct) ? Math.max(0, rawAct) : 0;
    const estimatedMl = lactationEstimateMl(item);
    return {
      dateKey,
      date: shortLactationDateLabel(dateKey),
      actualMl,
      estimatedMl,
      refLowMl: refLo,
      refHighMl: refHi,
    };
  });
}

const whoWeightP25 = (week: number) => +(3.0 + week * 0.17).toFixed(2);
const whoWeightP75 = (week: number) => +(3.8 + week * 0.22).toFixed(2);
const whoHeightP25 = (week: number) => +(48.0 + week * 0.7).toFixed(1);
const whoHeightP75 = (week: number) => +(50.5 + week * 0.85).toFixed(1);

type GrowthChartPoint = {
  week: string;
  weight: number;
  wP25: number;
  wP75: number;
  height: number;
  hP25: number;
  hP75: number;
};

/**
 * 成长曲线横轴刻度：点数 ≤11 全部展示；点数更多时在 5～11 个刻度间按索引均匀取点。
 * 仅影响 XAxis 标签，`data` 仍完整传入图表。
 */
function pickGrowthChartWeekTicks(weekLabels: readonly string[]): string[] {
  const n = weekLabels.length;
  if (n === 0) return [];
  if (n <= 11) return [...weekLabels];
  const target = Math.min(11, Math.max(7, Math.ceil(n / 6)));
  const k = Math.min(target, n);
  const idxSet = new Set<number>();
  for (let i = 0; i < k; i++) {
    const idx = k === 1 ? 0 : Math.round((i / (k - 1)) * (n - 1));
    idxSet.add(idx);
  }
  return [...idxSet].sort((a, b) => a - b).map((j) => weekLabels[j]!);
}

/** 纵轴刻度：至多一位小数（整数不写小数后缀） */
function formatGrowthChartYTick(v: unknown, unit: "kg" | "cm"): string {
  if (typeof v !== "number" || Number.isNaN(v)) return "";
  return `${Number(v.toFixed(1))} ${unit}`;
}

const buildGrowthChartData = (
  records: BabyRecordRow[],
  birthDateStr: string | null,
): GrowthChartPoint[] => {
  if (!birthDateStr || records.length === 0) return [];
  const birth = new Date(birthDateStr);
  const latest = new Date(records[records.length - 1].date);
  const totalWeeks = Math.ceil((latest.getTime() - birth.getTime()) / (7 * 24 * 60 * 60 * 1000));

  const points: GrowthChartPoint[] = [];
  for (let w = 0; w <= totalWeeks; w++) {
    const dayOffset = w * 7;
    const targetDate = new Date(birth.getTime() + dayOffset * 24 * 60 * 60 * 1000);

    let before = records[0];
    let after = records[records.length - 1];
    for (let i = 0; i < records.length - 1; i++) {
      const d = new Date(records[i].date);
      const dNext = new Date(records[i + 1].date);
      if (targetDate >= d && targetDate <= dNext) {
        before = records[i];
        after = records[i + 1];
        break;
      }
    }

    const bDate = new Date(before.date);
    const aDate = new Date(after.date);
    const span = aDate.getTime() - bDate.getTime();
    const ratio = span > 0 ? (targetDate.getTime() - bDate.getTime()) / span : 0;
    const r = Math.max(0, Math.min(1, ratio));
    const weight = +(before.weightKg + (after.weightKg - before.weightKg) * r).toFixed(2);
    const height = +(before.heightCm + (after.heightCm - before.heightCm) * r).toFixed(1);

    points.push({
      week: `W${w}`,
      weight, wP25: whoWeightP25(w), wP75: whoWeightP75(w),
      height, hP25: whoHeightP25(w), hP75: whoHeightP75(w),
    });
  }
  return points;
};

/** 兼容 YYYY-MM-DD、YY-MM-DD 及 slash 分隔 */
function normalizeGrowthHistoryDate(raw: string): string {
  const s = raw.trim();
  const iso = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`;
  const yy = s.match(/^(\d{2})-(\d{2})-(\d{2})$/);
  if (yy) {
    const y = Number(yy[1]);
    const fullYear = y >= 70 ? 1900 + y : 2000 + y;
    return `${fullYear}-${yy[2]}-${yy[3]}`;
  }
  return parseLactationDateKey(s);
}

/** GET /v1/growth/history → 成长曲线 interpolate 用记录 */
function mapGrowthHistoryToBabyRows(data: GrowthRecord[]): BabyRecordRow[] {
  const byDay = new Map<string, { row: BabyRecordRow; growthId: number }>();
  for (const r of data) {
    const date = normalizeGrowthHistoryDate(r.date);
    const weightKg =
      typeof r.weight_kg === "number" ? r.weight_kg : Number(r.weight_kg);
    const heightCm =
      typeof r.height_cm === "number" ? r.height_cm : Number(r.height_cm);
    const headCm = typeof r.head_cm === "number" ? r.head_cm : Number(r.head_cm);
    if (!Number.isFinite(weightKg) || !Number.isFinite(heightCm)) continue;
    const growthIdRaw =
      typeof r.growth_id === "number" ? r.growth_id : Number(r.growth_id);
    const growthId = Number.isFinite(growthIdRaw) ? growthIdRaw : -1;
    const row: BabyRecordRow = {
      date,
      weightKg,
      heightCm,
      headCm: Number.isFinite(headCm) ? headCm : 0,
    };
    const prev = byDay.get(date);
    if (!prev || growthId >= prev.growthId) byDay.set(date, { row, growthId });
  }
  return [...byDay.keys()]
    .sort((a, b) => a.localeCompare(b))
    .map((k) => byDay.get(k)!.row);
}

/** 接口可能返回 number 或数字字符串 */
function mlFromApi(v: unknown): number | null {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : null;
}

/** 三条测量时间中可解析的最新时间戳（ms）；均不可解析时返回 null */
function latestGrowthMesTimestampMs(g: GrowthQueryData): number | null {
  const times = [g.weight_mes_time, g.height_mes_time, g.head_mes_time].filter(
    (t): t is string => typeof t === "string" && t.trim().length > 0,
  );
  if (!times.length) return null;
  let best = NaN;
  for (const t of times) {
    const n = Date.parse(t);
    if (!Number.isNaN(n) && (Number.isNaN(best) || n > best)) best = n;
  }
  return Number.isNaN(best) ? null : best;
}

/** 比较两个时间戳是否为同一本地日历日 */
function sameLocalCalendarDayMs(aMs: number, bMs: number): boolean {
  const a = new Date(aMs);
  const b = new Date(bMs);
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/** 与「当前此刻」同一天则视为可走 revise（需配合 growth_id） */
function growthLastRecordedSameLocalDayAsNow(g: GrowthQueryData): boolean {
  const lastMs = latestGrowthMesTimestampMs(g);
  return lastMs !== null && sameLocalCalendarDayMs(lastMs, Date.now());
}

const EmptyChartHint = ({ children }: { children: React.ReactNode }) => (
  <div className="flex items-center justify-center py-14 text-[11px] text-muted-foreground text-center px-4">
    {children}
  </div>
);

/**
 * 状态页「信息显示区」：所有可滚动内容（不含顶栏安全区与底部导航）。
 */
const StatusOverviewBody: React.FC = () => {
  const navigate = useNavigate();
  const [unit] = useVolumeUnit();
  const birthJourneyPlanCardNotification = useBirthJourneyPlanCardNotification();
  const isOz = unit === "oz";
  const conv = useCallback((ml: number) => (isOz ? +(ml * 0.033814).toFixed(1) : ml), [isOz]);

  const [deliveryYmd, setDeliveryYmd] = useState<string | null>(null);
  const [momBabyToday, setMomBabyToday] = useState<MomBabyTodayData | null>(null);
  const [momBabyLoading, setMomBabyLoading] = useState(true);
  const [todayQueryLoading, setTodayQueryLoading] = useState(true);
  const [momBabyErr, setMomBabyErr] = useState<string | null>(null);

  const [lactationInfoList, setLactationInfoList] = useState<PumpInfoLactationDayItem[]>([]);
  const [pumpInfoLoading, setPumpInfoLoading] = useState(true);

  const [growthLoading, setGrowthLoading] = useState(true);
  const [latestGrowth, setLatestGrowth] = useState<GrowthQueryData | null>(null);
  const [growthHistoryRows, setGrowthHistoryRows] = useState<BabyRecordRow[]>([]);
  const [growthHistoryLoading, setGrowthHistoryLoading] = useState(true);

  const [babyMetrics, setBabyMetrics] = useState<{
    weightKg: number | null;
    heightCm: number | null;
    headCm: number | null;
  }>({ weightKg: null, heightCm: null, headCm: null });

  const [isGrowthDrawerOpen, setIsGrowthDrawerOpen] = useState(false);
  const [editWeight, setEditWeight] = useState("");
  const [editHeight, setEditHeight] = useState("");
  const [editHead, setEditHead] = useState("");
  const [growthSubmitting, setGrowthSubmitting] = useState(false);
  const [growthSaveErr, setGrowthSaveErr] = useState<string | null>(null);
  const [growthMetricsBlinkOn, setGrowthMetricsBlinkOn] = useState(false);
  const [activeDigitalTwin, setActiveDigitalTwin] = useState<StatusDigitalTwinTab>("mom");
  const [activeMomPanel, setActiveMomPanel] = useState<MomStatusPanelId | null>(null);
  const [activeBabyPanel, setActiveBabyPanel] = useState<BabyStatusPanelId | null>(null);
  const [todayDevicePumpCount, setTodayDevicePumpCount] = useState<number | null>(null);
  const [todayPumpRecordsLoading, setTodayPumpRecordsLoading] = useState(true);
  const [todayFeedingCount, setTodayFeedingCount] = useState<number | null>(null);
  const [todayFeedingRecordsLoading, setTodayFeedingRecordsLoading] = useState(true);
  const [birthJourneyPlan, setBirthJourneyPlan] = useState<CarePlanArtifact | null>(null);
  const [birthJourneyLoading, setBirthJourneyLoading] = useState(true);
  const [birthJourneyDeleting, setBirthJourneyDeleting] = useState(false);
  const [birthJourneyDeleteErr, setBirthJourneyDeleteErr] = useState<string | null>(null);
  const [pregnancyDiaryEntries, setPregnancyDiaryEntries] = useState<PregnancyDiaryEntry[]>([]);
  const [pregnancyDiaryToday, setPregnancyDiaryToday] = useState<PregnancyDiaryEntry | null>(null);
  const [pregnancyDiaryLoading, setPregnancyDiaryLoading] = useState(true);
  const [isPregnancyDiaryEditorOpen, setIsPregnancyDiaryEditorOpen] = useState(false);
  const [diaryGestationalWeek, setDiaryGestationalWeek] = useState("");
  const [diaryMood, setDiaryMood] = useState("");
  const [diaryEnergy, setDiaryEnergy] = useState("");
  const [diarySleep, setDiarySleep] = useState("");
  const [diaryFetalMovement, setDiaryFetalMovement] = useState("");
  const [diarySymptomTags, setDiarySymptomTags] = useState("");
  const [diaryAppointmentNote, setDiaryAppointmentNote] = useState("");
  const [diaryContent, setDiaryContent] = useState("");
  const [diarySaving, setDiarySaving] = useState(false);
  const [diarySaveErr, setDiarySaveErr] = useState<string | null>(null);
  const [pregnancyDiaryJustSaved, setPregnancyDiaryJustSaved] = useState(false);
  const growthMetricsRef = useRef<HTMLDivElement | null>(null);
  const growthBlinkTimerRef = useRef<number | null>(null);

  const prefillAgentHub = useCallback((prompt: string) => {
    setActiveMomPanel(null);
    navigate("/", { state: { agentPrefill: prompt } });
  }, [navigate]);

  const handleDeleteBirthJourneyPlan = useCallback(async () => {
    const plan = birthJourneyPlan;
    if (!plan || birthJourneyDeleting) return;
    setBirthJourneyDeleting(true);
    setBirthJourneyDeleteErr(null);
    try {
      const result = await deleteCarePlanArtifact({
        user_id: DEFAULT_CHAT_USER_ID,
        plan_id: plan.plan_id,
      });
      if (result.error !== 0) {
        throw new Error("删除生产全过程计划失败");
      }
      setBirthJourneyPlan(null);
      clearBirthJourneyPlanCardNotification();
      setActiveMomPanel(null);
    } catch (e: unknown) {
      setBirthJourneyDeleteErr(e instanceof Error ? e.message : "删除生产全过程计划失败");
    } finally {
      setBirthJourneyDeleting(false);
    }
  }, [birthJourneyDeleting, birthJourneyPlan]);

  useEffect(() => subscribeBirthJourneyPlanDeleted(() => {
    setBirthJourneyPlan(null);
    clearBirthJourneyPlanCardNotification();
    setActiveMomPanel((panel) => (panel === "birth-journey-detail" ? null : panel));
  }), []);

  const reloadPregnancyDiary = useCallback(async (signal?: AbortSignal) => {
    const todayDateKey = toLocalDateKey(new Date());
    const [today, list] = await Promise.all([
      queryPregnancyDiaryToday({ user_id: DEFAULT_CHAT_USER_ID, timestamp: todayDateKey }, { signal }),
      queryPregnancyDiaryList({ user_id: DEFAULT_CHAT_USER_ID, limit: 12 }, { signal }),
    ]);
    const realEntries = list.error === 0 && Array.isArray(list.diary_list) ? list.diary_list : [];
    setPregnancyDiaryToday(today.error === 0 ? today.diary ?? null : null);
    setPregnancyDiaryEntries(realEntries);
  }, []);

  const reloadPumpInfo = useCallback(async (signal?: AbortSignal) => {
    const data = await getPumpInfo(DEFAULT_CHAT_USER_ID, { signal });
    if (data.error !== 0 || !Array.isArray(data.lactation_info_list)) {
      setLactationInfoList([]);
      return;
    }
    setLactationInfoList(data.lactation_info_list);
  }, []);

  useEffect(() => subscribePregnancyDiaryChanged(() => {
    setPregnancyDiaryLoading(true);
    void reloadPregnancyDiary().finally(() => setPregnancyDiaryLoading(false));
  }), [reloadPregnancyDiary]);

  useEffect(() => {
    let ac: AbortController | null = null;
    const refreshPumpInfo = () => {
      if (document.visibilityState !== "visible") return;
      ac?.abort();
      ac = new AbortController();
      void reloadPumpInfo(ac.signal).catch((e: unknown) => {
        if ((e as { name?: string })?.name === "AbortError") return;
      });
    };
    const onVisibilityChange = () => {
      if (document.visibilityState === "visible") refreshPumpInfo();
    };
    window.addEventListener("focus", refreshPumpInfo);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      ac?.abort();
      window.removeEventListener("focus", refreshPumpInfo);
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, [reloadPumpInfo]);

  const openPregnancyDiaryEditor = useCallback(() => {
    setActiveMomPanel(null);
    setDiarySaveErr(null);
    setPregnancyDiaryJustSaved(false);
    const entry = pregnancyDiaryToday;
    setDiaryGestationalWeek(entry?.gestational_week ?? "");
    setDiaryMood(entry?.mood ?? "");
    setDiaryEnergy(entry?.energy_level ?? "");
    setDiarySleep(entry?.sleep_summary ?? "");
    setDiaryFetalMovement(entry?.fetal_movement ?? "");
    setDiarySymptomTags(entry?.symptom_tags?.join("、") ?? "");
    setDiaryAppointmentNote(entry?.appointment_note ?? "");
    setDiaryContent(entry?.content ?? "");
    setIsPregnancyDiaryEditorOpen(true);
  }, [pregnancyDiaryToday]);

  const toggleDiarySymptomTag = useCallback((tag: string) => {
    setDiarySymptomTags((current) => {
      const parts = current
        .split(/[、,，\s]+/)
        .map((item) => item.trim())
        .filter(Boolean);
      if (parts.includes(tag)) return parts.filter((item) => item !== tag).join("、");
      return [...parts, tag].join("、");
    });
  }, []);

  useEffect(() => {
    let cancelled = false;
    const ac = new AbortController();
    const todayDateKey = toLocalDateKey(new Date());

    setMomBabyLoading(true);
    setMomBabyErr(null);
    void (async () => {
      try {
        const data = await queryMomBabyInfo(DEFAULT_CHAT_USER_ID, { signal: ac.signal });
        if (cancelled) return;
        if (data.error !== 0) {
          setDeliveryYmd(null);
          setMomBabyErr("未取得有效的妈妈宝宝档案信息");
          return;
        }
        setDeliveryYmd(pickMomBabyDeliveryDateYmd(data));
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setDeliveryYmd(null);
        setMomBabyErr(e instanceof Error ? e.message : "加载妈妈和宝宝信息失败");
      } finally {
        if (!cancelled) setMomBabyLoading(false);
      }
    })();

    setTodayQueryLoading(true);
    setMomBabyToday(null);
    void (async () => {
      try {
        const data = await queryMomBabyToday(DEFAULT_CHAT_USER_ID, { signal: ac.signal });
        if (cancelled) return;
        if (data.error !== 0) {
          setMomBabyToday(null);
          return;
        }
        setMomBabyToday(data);
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setMomBabyToday(null);
      } finally {
        if (!cancelled) setTodayQueryLoading(false);
      }
    })();

    setGrowthLoading(true);
    setLatestGrowth(null);
    void (async () => {
      try {
        const data = await queryLatestGrowth({ user_id: DEFAULT_CHAT_USER_ID }, { signal: ac.signal });
        if (cancelled) return;
        if (data.error !== 0) {
          setLatestGrowth(null);
          return;
        }
        setLatestGrowth(data);
        setBabyMetrics({
          weightKg: mlFromApi(data.weight_kg),
          heightCm: mlFromApi(data.height_cm),
          headCm: mlFromApi(data.head_cm),
        });
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setLatestGrowth(null);
      } finally {
        if (!cancelled) setGrowthLoading(false);
      }
    })();

    setGrowthHistoryLoading(true);
    setGrowthHistoryRows([]);
    void (async () => {
      try {
        const hist = await getGrowthHistory({ user_id: DEFAULT_CHAT_USER_ID }, { signal: ac.signal });
        if (cancelled) return;
        if (hist.error !== 0 || !Array.isArray(hist.growth_data)) {
          setGrowthHistoryRows([]);
          return;
        }
        setGrowthHistoryRows(mapGrowthHistoryToBabyRows(hist.growth_data));
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setGrowthHistoryRows([]);
      } finally {
        if (!cancelled) setGrowthHistoryLoading(false);
      }
    })();

    setPumpInfoLoading(true);
    setLactationInfoList([]);
    void reloadPumpInfo(ac.signal)
      .catch((e: unknown) => {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setLactationInfoList([]);
      })
      .finally(() => {
        if (!cancelled) setPumpInfoLoading(false);
      });

    setTodayPumpRecordsLoading(true);
    setTodayDevicePumpCount(null);
    void (async () => {
      try {
        const data = await queryPumpMilkRecords(
          { user_id: DEFAULT_CHAT_USER_ID, timestamp: todayDateKey },
          { signal: ac.signal },
        );
        if (cancelled) return;
        if (data.error !== 0 || !Array.isArray(data.pump_milk_list)) {
          setTodayDevicePumpCount(null);
          return;
        }
        setTodayDevicePumpCount(
          data.pump_milk_list.filter((item) => item.pump_type === 0 && item.pump_source === 0).length,
        );
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setTodayDevicePumpCount(null);
      } finally {
        if (!cancelled) setTodayPumpRecordsLoading(false);
      }
    })();

    setTodayFeedingRecordsLoading(true);
    setTodayFeedingCount(null);
    void (async () => {
      try {
        const data = await queryFeedingRecords(
          { user_id: DEFAULT_CHAT_USER_ID, timestamp: todayDateKey },
          { signal: ac.signal },
        );
        if (cancelled) return;
        if (data.error !== 0 || !Array.isArray(data.feed_list)) {
          setTodayFeedingCount(null);
          return;
        }
        const totalFeed = typeof data.total_feed === "number" ? data.total_feed : Number(data.total_feed);
        setTodayFeedingCount(Number.isFinite(totalFeed) ? Math.max(0, totalFeed) : data.feed_list.length);
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setTodayFeedingCount(null);
      } finally {
        if (!cancelled) setTodayFeedingRecordsLoading(false);
      }
    })();

    setBirthJourneyLoading(true);
    setBirthJourneyPlan(null);
    void (async () => {
      try {
        const data = await queryCarePlanList(
          { user_id: DEFAULT_CHAT_USER_ID, status: "active" },
          { signal: ac.signal },
        );
        if (cancelled) return;
        if (data.error !== 0 || !Array.isArray(data.plan_list)) {
          setBirthJourneyPlan(null);
          return;
        }
        setBirthJourneyPlan(data.plan_list.find((plan) => plan.plan_type === "birth_journey") ?? null);
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setBirthJourneyPlan(null);
      } finally {
        if (!cancelled) setBirthJourneyLoading(false);
      }
    })();

    setPregnancyDiaryLoading(true);
    setPregnancyDiaryToday(null);
    setPregnancyDiaryEntries([]);
    void (async () => {
      try {
        await reloadPregnancyDiary(ac.signal);
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setPregnancyDiaryToday(null);
        setPregnancyDiaryEntries([]);
      } finally {
        if (!cancelled) setPregnancyDiaryLoading(false);
      }
    })();

    return () => {
      cancelled = true;
      ac.abort();
    };
  }, [reloadPregnancyDiary, reloadPumpInfo]);

  const babyDaysSinceBirth = deliveryYmd ? calendarDaysSinceDeliveryLocal(deliveryYmd) : null;
  const babyAgeDays =
    typeof babyDaysSinceBirth === "number" ? Math.max(0, babyDaysSinceBirth) : null;
  const postpartumWeeks =
    typeof babyAgeDays === "number" ? postpartumWeekFromDay(babyAgeDays) : null;

  /** WHO 适龄带需分娩日为周锚点；仅在无档案时用首条测量日兜底周序 */
  const growthChartBirthAnchor = deliveryYmd ?? growthHistoryRows[0]?.date ?? null;

  const todayPumpMl = useMemo(
    () => (momBabyToday ? mlFromApi(momBabyToday.pump_milk_volum) : null),
    [momBabyToday],
  );
  const todayFeedMl = useMemo(
    () => (momBabyToday ? mlFromApi(momBabyToday.feeding_volum) : null),
    [momBabyToday],
  );
  const [windowSize, setWindowSize] = useState<7 | 30>(7);
  const [growthCurveType, setGrowthCurveType] = useState<"weight" | "height">("weight");

  const lactationRowsMl = useMemo(
    () => buildLactationTrendRowsMl(lactationInfoList),
    [lactationInfoList],
  );

  const trendData = useMemo((): LactationTrendPoint[] => {
    const now = new Date();
    const todayKey = toLocalDateKey(now);
    const dateKeys = buildRecentDateKeys(windowSize, shiftLocalDate(now, -1));
    const rowsByDateKey = new Map(
      lactationRowsMl
        .filter((row) => row.dateKey.localeCompare(todayKey) < 0)
        .map((row) => [row.dateKey, row]),
    );
    return dateKeys.map((dateKey) => {
      const row = rowsByDateKey.get(dateKey) ?? null;
      const actualMl = row?.actualMl ?? 0;
      const estimatedMl = row?.estimatedMl ?? 0;
      const refLowMl = row?.refLowMl ?? 0;
      const refHighMl = row?.refHighMl ?? 0;
      const refPadMl = refLowMl;
      const refSpanMl = Math.max(0, refHighMl - refLowMl);
      return {
        dateKey,
        actual: conv(actualMl),
        estimated: conv(estimatedMl),
        refPad: conv(refPadMl),
        refSpan: conv(refSpanMl),
        actualMl,
        estimatedMl,
        refLowMl,
        refHighMl,
      };
    });
  }, [lactationRowsMl, windowSize, conv]);

  const lactationTrendDateTicks = useMemo(
    () => pickLactationTrendDateTicks(trendData.map((d) => d.dateKey), windowSize),
    [trendData, windowSize],
  );

  const growthChartData = useMemo(
    () => buildGrowthChartData(growthHistoryRows, growthChartBirthAnchor),
    [growthHistoryRows, growthChartBirthAnchor],
  );

  const growthChartWeekTicks = useMemo(
    () => pickGrowthChartWeekTicks(growthChartData.map((d) => d.week)),
    [growthChartData],
  );

  const growthYAxisDomains = useMemo(() => {
    if (!growthChartData.length) return null;
    let wMin = Infinity;
    let wMax = -Infinity;
    let hMin = Infinity;
    let hMax = -Infinity;
    for (const p of growthChartData) {
      wMin = Math.min(wMin, p.weight, p.wP25, p.wP75);
      wMax = Math.max(wMax, p.weight, p.wP25, p.wP75);
      hMin = Math.min(hMin, p.height, p.hP25, p.hP75);
      hMax = Math.max(hMax, p.height, p.hP25, p.hP75);
    }
    const padW = Math.max(0.15, (wMax - wMin) * 0.12);
    const padH = Math.max(1, (hMax - hMin) * 0.12);
    return {
      weight: [Math.max(1.5, wMin - padW), wMax + padW] as [number, number],
      height: [Math.max(40, hMin - padH), hMax + padH] as [number, number],
    };
  }, [growthChartData]);

  const todayPumpLabel = todayQueryLoading
    ? "加载中"
    : todayPumpMl !== null
      ? `${formatVol(todayPumpMl, unit)}${unitLabel(unit)}`
      : "待记录";
  const todayFeedLabel = todayQueryLoading
    ? "加载中"
    : todayFeedMl !== null
      ? `${formatVol(todayFeedMl, unit)}${unitLabel(unit)}`
      : "待记录";
  const todayPumpCountLabel = todayPumpRecordsLoading
    ? "加载中"
    : todayDevicePumpCount !== null
      ? `${todayDevicePumpCount}次`
      : "待同步";
  const todayFeedingCountLabel = todayFeedingRecordsLoading
    ? "加载中"
    : todayFeedingCount !== null
      ? `${todayFeedingCount}次`
      : "待同步";
  const babyWeightLabel =
    growthLoading
      ? "加载中"
      : typeof babyMetrics.weightKg === "number"
        ? `${babyMetrics.weightKg}kg`
        : "待记录";
  const babyHeightLabel =
    growthLoading
      ? "加载中"
      : typeof babyMetrics.heightCm === "number"
        ? `${babyMetrics.heightCm}cm`
        : "待记录";
  const babyHeadLabel =
    growthLoading
      ? "加载中"
      : typeof babyMetrics.headCm === "number"
        ? `${babyMetrics.headCm}cm`
        : "待记录";
  const momStatusSubtitle = momBabyLoading
    ? "正在加载妈妈信息…"
    : momBabyErr
      ? "妈妈档案待绑定"
      : typeof postpartumWeeks === "number"
        ? `产后第 ${postpartumWeeks} 周`
        : "暂无有效分娩日期";
  const babyStatusSubtitle = momBabyLoading
    ? "正在加载宝宝信息…"
    : momBabyErr
      ? "宝宝档案待绑定"
      : typeof babyAgeDays === "number"
        ? `宝宝已出生 ${babyAgeDays} 天`
        : "暂无有效分娩日期";
  const birthJourneyCardPhase = currentBirthJourneyPhase(birthJourneyPlan);
  const birthJourneyPhaseTitle = birthJourneyCardPhase?.title ?? "";
  const birthJourneyCardFocus = compactText(birthJourneyCardPhase?.goal);
  const birthJourneyCardText = birthJourneyLoading
    ? "正在加载生产全过程计划"
    : birthJourneyPlan
      ? `当前阶段：${birthJourneyPhaseTitle || "待完善"}`
      : "还没有计划哦";
  const birthJourneyCardAction = birthJourneyPlan ? "查看计划" : "制定计划";
  const pregnancyDiaryCardText = pregnancyDiaryLoading
    ? "正在加载孕期日记"
    : pregnancyDiarySummary(pregnancyDiaryToday ?? pregnancyDiaryEntries[0] ?? null);
  const pregnancyDiaryCardSupport = pregnancyDiaryLoading
    ? undefined
    : pregnancyDiaryEntries.length > 0
      ? `最近7天记录 ${pregnancyDiaryRecentCount(pregnancyDiaryEntries, 7)} 天`
      : "记录后可整理产检问题和最近状态";
  const pregnancyDiaryAction = pregnancyDiaryToday ? "编辑今天" : "记录今天";

  const runGrowthMetricsHighlight = useCallback(() => {
    if (growthBlinkTimerRef.current !== null) {
      window.clearInterval(growthBlinkTimerRef.current);
      growthBlinkTimerRef.current = null;
    }
    growthMetricsRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    setGrowthMetricsBlinkOn(true);
    let toggleCount = 0;
    growthBlinkTimerRef.current = window.setInterval(() => {
      toggleCount += 1;
      setGrowthMetricsBlinkOn((prev) => !prev);
      if (toggleCount >= 5) {
        if (growthBlinkTimerRef.current !== null) {
          window.clearInterval(growthBlinkTimerRef.current);
          growthBlinkTimerRef.current = null;
        }
        setGrowthMetricsBlinkOn(false);
      }
    }, 500);
  }, []);

  useEffect(() => {
    if (consumeStatusGrowthHighlightPending()) {
      runGrowthMetricsHighlight();
    }
    const onStatusGrowthHighlight = () => runGrowthMetricsHighlight();
    window.addEventListener(STATUS_GROWTH_HIGHLIGHT_EVENT, onStatusGrowthHighlight);
    return () => {
      window.removeEventListener(STATUS_GROWTH_HIGHLIGHT_EVENT, onStatusGrowthHighlight);
      if (growthBlinkTimerRef.current !== null) {
        window.clearInterval(growthBlinkTimerRef.current);
        growthBlinkTimerRef.current = null;
      }
    };
  }, [runGrowthMetricsHighlight]);

  const openGrowthEditor = useCallback(() => {
    setGrowthSaveErr(null);
    setEditWeight(
      typeof babyMetrics.weightKg === "number" ? babyMetrics.weightKg.toString() : "",
    );
    setEditHeight(
      typeof babyMetrics.heightCm === "number" ? babyMetrics.heightCm.toString() : "",
    );
    setEditHead(
      typeof babyMetrics.headCm === "number" ? babyMetrics.headCm.toString() : "",
    );
    setIsGrowthDrawerOpen(true);
  }, [babyMetrics]);

  return (
    <>
      <div className="flex flex-col pb-3">
        <div
          id="status-digital-twin-tabs"
          className="sticky top-0 z-20 mx-0 mt-2 mb-4 grid w-full grid-cols-2 gap-2 bg-background/90 px-4 py-2 backdrop-blur"
          role="tablist"
          aria-label="妈妈宝宝切换"
        >
          {[
            {
              tab: "mom" as const,
              title: "妈妈",
              subtitle: momStatusSubtitle,
              avatar: momAvatar,
              alt: "Mom",
            },
            {
              tab: "baby" as const,
              title: "宝宝",
              subtitle: babyStatusSubtitle,
              avatar: babyAvatar,
              alt: "Baby",
            },
          ].map(({ tab, title, subtitle, avatar, alt }) => {
            const selected = activeDigitalTwin === tab;
            return (
                  <button
                    key={tab}
                    type="button"
                    role="tab"
                    aria-selected={selected}
                    onClick={() => setActiveDigitalTwin(tab)}
                    className={`relative flex min-h-[68px] w-full min-w-0 items-center gap-2 overflow-hidden rounded-[16px] px-2.5 py-2 text-left transition-all ${
                      selected
                        ? "bg-[#fff7fb] text-[#35212c] shadow-none ring-2 ring-[#d8adc2]"
                        : "bg-white/45 text-muted-foreground opacity-72 shadow-none ring-1 ring-white/70 active:bg-white/70"
                    }`}
                  >
                    <span
                      aria-hidden="true"
                      className={`absolute inset-y-3 left-0 w-1 rounded-r-full bg-[#b46f91] transition-opacity ${
                        selected ? "opacity-100" : "opacity-0"
                      }`}
                    />
                    <img
                      src={avatar}
                      alt={alt}
                      className={`h-10 w-10 shrink-0 rounded-full border-2 object-cover ${
                        selected ? "border-[#b46f91]/45" : "border-border/50 opacity-75"
                      }`}
                    />
                    <span className="min-w-0">
                      <span className="block truncate text-[15px] font-bold leading-tight">{title}</span>
                      <span
                        className={`mt-1 block truncate text-[10px] font-semibold leading-tight ${
                          selected ? "text-[#806171]" : "text-muted-foreground"
                        }`}
                      >
                        {subtitle}
                      </span>
                    </span>
              </button>
            );
          })}
        </div>

        {activeDigitalTwin === "mom" ? (
          <>
            <div className="order-2 mx-4 mb-4 grid grid-cols-2 gap-3">
              <StatusModuleCard
                title="母乳产出"
                metrics={[
                  {
                    label: "今日产出",
                    value: todayPumpLabel,
                    onInfoClick: () => setActiveMomPanel("milk-info"),
                    ariaLabel: "今日产出说明",
                  },
                  { label: "今日吸奶", value: todayPumpCountLabel },
                ]}
                tone="rose"
                icon={<Droplets className="h-4 w-4" />}
              />
              <StatusModuleCard
                title="乳房健康"
                bodyText={INITIAL_BREAST_HEALTH_SUMMARY}
                action="查看《乳房健康日记》"
                tone="peach"
                icon={<HeartPulse className="h-4 w-4" />}
                onInfoClick={() => setActiveMomPanel("breast-info")}
                onClick={() => setActiveMomPanel("breast-detail")}
                alignActionTextWithTitle
              />
              <StatusModuleCard
                title="产后恢复"
                bodyText={POSTPARTUM_RECOVERY_PLAN_STATUS}
                action="查看计划"
                tone="mint"
                icon={<PostpartumRecoveryIcon />}
                onClick={() => setActiveMomPanel("postpartum-detail")}
                alignActionTextWithTitle
              />
              <StatusModuleCard
                title="补能与休息"
                bodyText={
                  <span className="font-medium">
                    待开通 <strong className="font-bold">睡眠</strong> 与 <strong className="font-bold">营养</strong> 功能
                  </span>
                }
                tone="amber"
                icon={<Coffee className="h-4 w-4" />}
                onInfoClick={() => setActiveMomPanel("rest-info")}
                alignActionTextWithTitle
              />
              <StatusModuleCard
                title="生产全过程计划"
                bodyText={birthJourneyCardText}
                supportingText={
                  birthJourneyPlan && !birthJourneyLoading && birthJourneyCardFocus
                    ? birthJourneyCardFocus
                    : undefined
                }
                action={birthJourneyCardAction}
                notificationLabel={birthJourneyPlanCardNotification ? "计划已生成" : undefined}
                tone="violet"
                icon={<ClipboardList className="h-4 w-4" />}
                onClick={() => {
                  if (birthJourneyPlan) {
                    clearBirthJourneyPlanCardNotification();
                    setActiveMomPanel("birth-journey-detail");
                  } else {
                    prefillAgentHub("帮我制定生产全过程计划");
                  }
                }}
                alignActionTextWithTitle
              />
              <StatusModuleCard
                title="孕期日记"
                bodyText={pregnancyDiaryCardText}
                supportingText={pregnancyDiaryCardSupport}
                action={pregnancyDiaryAction}
                secondaryAction="查看日记"
                tone="aqua"
                icon={<BookOpen className="h-4 w-4" />}
                onClick={openPregnancyDiaryEditor}
                onSecondaryClick={() => setActiveMomPanel("pregnancy-diary-detail")}
                alignActionTextWithTitle
              />
            </div>

            <Expandable
              id="status-milk-trend"
              title="母乳趋势"
              className="order-3 border-[#f0dfc4] bg-gradient-to-br from-[#fffaf0] via-white to-[#fff1d6]"
              defaultOpen
              icon={<div className="w-6 h-6 rounded-full bg-[#ffe4b8] flex items-center justify-center"><Target className="w-3.5 h-3.5 text-[#b9792a]" /></div>}
            >
              <div className="flex justify-between items-center mb-2">
                <div className="flex items-center gap-2 text-[9px] text-[#8a6742]">
                  <div className="flex items-center gap-1">
                    <div className="w-3 h-[2px]" style={{ backgroundColor: LACTATION_TREND_COLORS.actual }}></div>
                    <span>吸乳总量</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <div className="w-3 h-[2px] border-b border-dashed opacity-80" style={{ borderColor: LACTATION_TREND_COLORS.estimate }}></div>
                    <span>含亲喂估算</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <div className="w-3 h-2 opacity-80" style={{ backgroundColor: LACTATION_TREND_COLORS.band }}></div>
                    <span>目标参考区间</span>
                  </div>
                </div>
                <div className="flex rounded-full bg-[#fff1d6] p-0.5 text-[10px] font-medium">
                  <button type="button" onClick={() => setWindowSize(7)} className={`px-2 py-0.5 rounded-full ${windowSize === 7 ? "bg-[#b9792a] text-white" : "text-[#8a6742]"}`}>周</button>
                  <button type="button" onClick={() => setWindowSize(30)} className={`px-2 py-0.5 rounded-full ${windowSize === 30 ? "bg-[#b9792a] text-white" : "text-[#8a6742]"}`}>月</button>
                </div>
              </div>
              {pumpInfoLoading ? (
                <EmptyChartHint>正在加载最近一个月泌乳数据…</EmptyChartHint>
              ) : trendData.length === 0 ? (
                <EmptyChartHint>暂无母乳趋势数据，可多日记录产量后在本页查看。</EmptyChartHint>
              ) : (
                <div className="h-[188px] w-full min-w-0 max-w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <ComposedChart data={trendData} margin={STATUS_OVERVIEW_CHART_MARGIN}>
                      <CartesianGrid strokeDasharray="3 3" stroke={LACTATION_TREND_COLORS.grid} />
                      <XAxis
                        dataKey="dateKey"
                        ticks={lactationTrendDateTicks}
                        tickFormatter={formatLactationTrendDateTick}
                        tick={{ fontSize: 9, fill: LACTATION_TREND_COLORS.axis }}
                        stroke={LACTATION_TREND_COLORS.axis}
                        interval={0}
                        minTickGap={8}
                        tickMargin={6}
                        padding={{ left: 0, right: 8 }}
                      />
                      <YAxis
                        tick={{ fontSize: 9, fill: LACTATION_TREND_COLORS.axis }}
                        stroke={LACTATION_TREND_COLORS.axis}
                        width={unit === "oz" ? 48 : 42}
                        domain={[0, "auto"]}
                        tickFormatter={(v) =>
                          typeof v !== "number" || Number.isNaN(v)
                            ? ""
                            : unit === "oz"
                              ? `${v.toFixed(1)} oz`
                              : `${Math.round(v)} mL`}
                      />
                      <Tooltip
                        labelFormatter={(value) =>
                          formatLactationTrendTooltipDate(
                            typeof value === "string" ? value : String(value ?? ""),
                          )}
                        content={<LactationTrendTooltip unit={unit} />}
                      />
                      <Area
                        type="monotone"
                        dataKey="refPad"
                        stackId="refBand"
                        stroke="none"
                        fill="transparent"
                        legendType="none"
                        fillOpacity={0}
                        dot={false}
                        activeDot={false}
                        isAnimationActive={false}
                      />
                      <Area
                        type="monotone"
                        dataKey="refSpan"
                        stackId="refBand"
                        stroke="none"
                        fill={LACTATION_TREND_COLORS.band}
                        fillOpacity={0.75}
                        dot={false}
                        activeDot={false}
                        isAnimationActive={false}
                      />
                      <Line
                        type="monotone"
                        dataKey="estimated"
                        stroke={LACTATION_TREND_COLORS.estimate}
                        strokeDasharray="4 3"
                        strokeWidth={2.4}
                        strokeOpacity={1}
                        dot={windowSize === 7 ? { r: 2.5, strokeWidth: 1.5, fill: "#fff", stroke: LACTATION_TREND_COLORS.estimate } : false}
                      />
                      <Line
                        type="monotone"
                        dataKey="actual"
                        stroke={LACTATION_TREND_COLORS.actual}
                        strokeWidth={2.5}
                        dot={
                              windowSize === 7
                                ? { r: 3, strokeWidth: 2, fill: "#fffaf0", stroke: LACTATION_TREND_COLORS.actual }
                                : false
                        }
                        activeDot={{ r: 5 }}
                      />
                    </ComposedChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Expandable>

          </>
        ) : (
          <>
            <div className="order-6 mx-4 mb-4 grid grid-cols-2 gap-3">
              <StatusModuleCard
                title="奶量摄入"
                metrics={[
                  {
                    label: "今日摄入",
                    value: todayFeedLabel,
                    onInfoClick: () => setActiveMomPanel("baby-feed-info"),
                    ariaLabel: "今日摄入说明",
                  },
                  { label: "今日喂奶", value: todayFeedingCountLabel },
                ]}
                tone="sky"
                icon={<Utensils className="h-4 w-4" />}
              />
              <StatusModuleCard
                title="成长发育"
                metrics={[
                  { label: "体重", value: babyWeightLabel },
                  { label: "身高", value: babyHeightLabel },
                  { label: "头围", value: babyHeadLabel },
                ]}
                action="修改指标"
                secondaryAction="成长milestone"
                tone="mint"
                icon={<Ruler className="h-4 w-4" />}
                onClick={openGrowthEditor}
                onSecondaryClick={() => setActiveBabyPanel("growth-milestone")}
                alignActionTextWithTitle
              />
              <StatusModuleCard
                title="宝宝健康"
                action="查看健康信息"
                tone="aqua"
                icon={<HeartPulse className="h-4 w-4" />}
                onClick={() => setActiveBabyPanel("baby-health")}
                alignActionTextWithTitle
              />
              <StatusModuleCard
                title="宝宝睡眠"
                metrics={[
                  { label: "今日睡眠", value: "4h 57min" },
                ]}
                action="查看报告"
                tone="violet"
                icon={<Bed className="h-4 w-4" />}
                onClick={() => setActiveBabyPanel("baby-sleep")}
                alignActionTextWithTitle
              />
            </div>

            <div
              ref={growthMetricsRef}
              className={`order-8 transition-all duration-200 ${
                growthMetricsBlinkOn
                  ? "rounded-[24px] ring-2 ring-emerald-300/80 shadow-[0_0_0_4px_rgba(110,231,183,0.22)]"
                  : ""
              }`}
            >
              <Expandable
                id="status-baby-growth-curve"
                title="宝宝成长曲线"
                className="border-[#e6d9fb] bg-gradient-to-br from-[#fbf7ff] via-white to-[#eee6ff]"
                defaultOpen
                icon={<div className="w-6 h-6 rounded-full bg-[#e6d9fb] flex items-center justify-center"><Baby className="w-3.5 h-3.5 text-[#7d64aa]" /></div>}
              >
        <div className="flex justify-between items-center mb-2">
          <div className="flex items-center gap-2 text-[9px] text-[#7560a0]">
            <div className="flex items-center gap-1">
              <div className="w-3 h-[2px]" style={{ backgroundColor: GROWTH_CHART_COLORS.actual }}></div>
              <span>实际测量</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-2 opacity-80" style={{ backgroundColor: GROWTH_CHART_COLORS.band }}></div>
              <span>同龄参考区间</span>
            </div>
          </div>
          <div className="flex rounded-full bg-[#f2ecff] p-0.5 text-[9px] font-medium">
            <button type="button" onClick={() => setGrowthCurveType("weight")} className={`px-2 py-0.5 rounded-full ${growthCurveType === "weight" ? "bg-[#7d64aa] text-white" : "text-[#7560a0]"}`}>体重</button>
            <button type="button" onClick={() => setGrowthCurveType("height")} className={`px-2 py-0.5 rounded-full ${growthCurveType === "height" ? "bg-[#7d64aa] text-white" : "text-[#7560a0]"}`}>身高</button>
          </div>
        </div>
        {growthHistoryLoading ? (
          <EmptyChartHint>正在加载生长发育历史…</EmptyChartHint>
        ) : growthChartData.length === 0 ? (
          <EmptyChartHint>暂无成长曲线数据，录入多项测量后与同龄参考一同展示。</EmptyChartHint>
        ) : growthCurveType === "weight" ? (
          <div className="h-[188px] w-full min-w-0 max-w-full">
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={growthChartData} margin={STATUS_OVERVIEW_CHART_MARGIN}>
                    <defs>
                      <linearGradient id="growthBandPrimary" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={GROWTH_CHART_COLORS.band} stopOpacity={0.85} />
                        <stop offset="100%" stopColor={GROWTH_CHART_COLORS.band} stopOpacity={0.5} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke={GROWTH_CHART_COLORS.grid} opacity={0.75} vertical={false} />
                    <XAxis
                      dataKey="week"
                      ticks={growthChartWeekTicks}
                      tick={{ fontSize: 9, fill: GROWTH_CHART_COLORS.axis }}
                      stroke={GROWTH_CHART_COLORS.axis}
                      interval={0}
                      tickMargin={6}
                      padding={{ left: 0, right: 8 }}
                    />
                    <YAxis
                      tick={{ fontSize: 9, fill: GROWTH_CHART_COLORS.axis }}
                      stroke={GROWTH_CHART_COLORS.axis}
                      width={42}
                      domain={growthYAxisDomains?.weight ?? [2.5, 7]}
                      allowDecimals
                      tickFormatter={(v) => formatGrowthChartYTick(v, "kg")}
                    />
                    <Tooltip contentStyle={{ fontSize: 11 }} />
                    <Area type="monotone" dataKey="wP75" stroke="none" fill="url(#growthBandPrimary)" name="P75参考" fillOpacity={1} />
                    <Area type="monotone" dataKey="wP25" stroke="none" fill="hsl(var(--card))" name="P25参考" fillOpacity={1} />
                    <Line type="monotone" dataKey="weight" name="体重" stroke={GROWTH_CHART_COLORS.actual} strokeWidth={3} dot={{ r: 4, strokeWidth: 1.5, fill: "#f7fffc", stroke: GROWTH_CHART_COLORS.actual }} />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="h-[188px] w-full min-w-0 max-w-full">
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={growthChartData} margin={STATUS_OVERVIEW_CHART_MARGIN}>
                    <defs>
                      <linearGradient id="growthBandSecondary" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={GROWTH_CHART_COLORS.band} stopOpacity={0.85} />
                        <stop offset="100%" stopColor={GROWTH_CHART_COLORS.band} stopOpacity={0.5} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke={GROWTH_CHART_COLORS.grid} opacity={0.75} vertical={false} />
                    <XAxis
                      dataKey="week"
                      ticks={growthChartWeekTicks}
                      tick={{ fontSize: 9, fill: GROWTH_CHART_COLORS.axis }}
                      stroke={GROWTH_CHART_COLORS.axis}
                      interval={0}
                      tickMargin={6}
                      padding={{ left: 0, right: 8 }}
                    />
                    <YAxis
                      tick={{ fontSize: 9, fill: GROWTH_CHART_COLORS.axis }}
                      stroke={GROWTH_CHART_COLORS.axis}
                      width={42}
                      domain={growthYAxisDomains?.height ?? [46, 64]}
                      allowDecimals
                      tickFormatter={(v) => formatGrowthChartYTick(v, "cm")}
                    />
                    <Tooltip contentStyle={{ fontSize: 11 }} />
                    <Area type="monotone" dataKey="hP75" stroke="none" fill="url(#growthBandSecondary)" name="P75参考" fillOpacity={1} />
                    <Area type="monotone" dataKey="hP25" stroke="none" fill="hsl(var(--card))" name="P25参考" fillOpacity={1} />
                    <Line type="monotone" dataKey="height" name="身高" stroke={GROWTH_CHART_COLORS.height} strokeWidth={3} dot={{ r: 4, strokeWidth: 1.5, fill: "#f7fffc", stroke: GROWTH_CHART_COLORS.height }} />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        )}
              </Expandable>
            </div>

          </>
        )}
      </div>

      <AnimatePresence>
        {activeMomPanel ? (
          <MomStatusPanelSheet
            panel={activeMomPanel}
            onClose={() => setActiveMomPanel(null)}
            onAgentPrefill={prefillAgentHub}
            birthJourneyPlan={birthJourneyPlan}
            birthJourneyLoading={birthJourneyLoading}
            birthJourneyDeleting={birthJourneyDeleting}
            birthJourneyDeleteErr={birthJourneyDeleteErr}
            onDeleteBirthJourneyPlan={handleDeleteBirthJourneyPlan}
            pregnancyDiaryEntries={pregnancyDiaryEntries}
            pregnancyDiaryLoading={pregnancyDiaryLoading}
            pregnancyDiaryJustSaved={pregnancyDiaryJustSaved}
            onOpenDiaryEditor={openPregnancyDiaryEditor}
          />
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {activeBabyPanel ? (
          <BabyStatusPanelSheet
            panel={activeBabyPanel}
            onClose={() => setActiveBabyPanel(null)}
          />
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {isPregnancyDiaryEditorOpen ? (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm"
              onClick={() => {
                if (!diarySaving) setIsPregnancyDiaryEditorOpen(false);
              }}
            />
            <motion.div
              initial={{ y: "100%", opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: "100%", opacity: 0 }}
              transition={{ type: "spring", damping: 28, stiffness: 300 }}
              className="fixed inset-x-0 bottom-0 z-50 mx-auto w-full max-w-lg rounded-t-3xl border-t border-border/40 bg-card px-5 pt-4 shadow-2xl"
              style={{ paddingBottom: "max(2rem, env(safe-area-inset-bottom))" }}
            >
              <div className="mb-4 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="text-base font-extrabold text-foreground">记录今天的孕期日记</h3>
                  <p className="mt-1 flex items-center gap-1 text-[11px] font-semibold text-muted-foreground">
                    <CalendarDays className="h-3.5 w-3.5" />
                    {formatDiaryDateLabel(toLocalDateKey(new Date()))}
                  </p>
                </div>
                <button
                  type="button"
                  disabled={diarySaving}
                  onClick={() => {
                    if (!diarySaving) setIsPregnancyDiaryEditorOpen(false);
                  }}
                  className="flex h-8 w-8 items-center justify-center rounded-full bg-secondary/80 transition-colors active:scale-95 disabled:opacity-50"
                >
                  <X className="h-4 w-4 text-muted-foreground" />
                </button>
              </div>

              <div className="max-h-[68vh] space-y-3 overflow-y-auto pr-1">
                <div className="grid grid-cols-2 gap-3">
                  <label className="min-w-0 rounded-2xl border border-border/50 bg-secondary/20 p-3">
                    <span className="mb-1.5 block text-xs font-semibold text-muted-foreground">孕周</span>
                    <input
                      value={diaryGestationalWeek}
                      onChange={(event) => setDiaryGestationalWeek(event.target.value)}
                      placeholder="如 孕 32 周"
                      className="h-10 w-full rounded-xl border border-border/50 bg-background px-3 text-sm font-bold outline-none transition-all focus:border-primary focus:ring-1 focus:ring-primary/20"
                    />
                  </label>
                  <div className="min-w-0 rounded-2xl border border-border/50 bg-secondary/20 p-3">
                    <span className="mb-2 block text-xs font-semibold text-muted-foreground">心情</span>
                    <div className="flex flex-wrap gap-1.5">
                      {DIARY_MOOD_OPTIONS.map((option) => (
                        <button
                          key={option}
                          type="button"
                          onClick={() => setDiaryMood(option)}
                          className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${
                            diaryMood === option ? "bg-[#2f8a91] text-white" : "bg-white text-[#5c6870]"
                          }`}
                        >
                          {option}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="min-w-0 rounded-2xl border border-border/50 bg-secondary/20 p-3">
                    <span className="mb-2 block text-xs font-semibold text-muted-foreground">精力</span>
                    <div className="flex flex-wrap gap-1.5">
                      {DIARY_ENERGY_OPTIONS.map((option) => (
                        <button
                          key={option}
                          type="button"
                          onClick={() => setDiaryEnergy(option)}
                          className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${
                            diaryEnergy === option ? "bg-[#2f8a91] text-white" : "bg-white text-[#5c6870]"
                          }`}
                        >
                          {option}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="min-w-0 rounded-2xl border border-border/50 bg-secondary/20 p-3">
                    <span className="mb-2 block text-xs font-semibold text-muted-foreground">睡眠</span>
                    <div className="flex flex-wrap gap-1.5">
                      {DIARY_SLEEP_OPTIONS.map((option) => (
                        <button
                          key={option}
                          type="button"
                          onClick={() => setDiarySleep(option)}
                          className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${
                            diarySleep === option ? "bg-[#2f8a91] text-white" : "bg-white text-[#5c6870]"
                          }`}
                        >
                          {option}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
                <div className="rounded-2xl border border-border/50 bg-secondary/20 p-3">
                  <span className="mb-2 block text-xs font-semibold text-muted-foreground">胎动</span>
                  <div className="flex flex-wrap gap-1.5">
                    {DIARY_FETAL_MOVEMENT_OPTIONS.map((option) => (
                      <button
                        key={option}
                        type="button"
                        onClick={() => setDiaryFetalMovement(option)}
                        className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${
                          diaryFetalMovement === option ? "bg-[#2f8a91] text-white" : "bg-white text-[#5c6870]"
                        }`}
                      >
                        {option}
                      </button>
                    ))}
                  </div>
                </div>
                <div className="rounded-2xl border border-border/50 bg-secondary/20 p-3">
                  <span className="mb-2 block text-xs font-semibold text-muted-foreground">身体感受</span>
                  <div className="flex flex-wrap gap-1.5">
                    {DIARY_SYMPTOM_OPTIONS.map((option) => {
                      const selected = diarySymptomTags
                        .split(/[、,，\s]+/)
                        .map((tag) => tag.trim())
                        .filter(Boolean)
                        .includes(option);
                      return (
                        <button
                          key={option}
                          type="button"
                          onClick={() => toggleDiarySymptomTag(option)}
                          className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${
                            selected ? "bg-[#2f8a91] text-white" : "bg-white text-[#5c6870]"
                          }`}
                        >
                          {option}
                        </button>
                      );
                    })}
                  </div>
                  <input
                    value={diarySymptomTags}
                    onChange={(event) => setDiarySymptomTags(event.target.value)}
                    placeholder="也可以补充其它感受"
                    className="mt-2 h-9 w-full rounded-xl border border-border/50 bg-background px-3 text-xs font-semibold outline-none transition-all focus:border-primary focus:ring-1 focus:ring-primary/20"
                  />
                </div>
                <label className="block rounded-2xl border border-border/50 bg-secondary/20 p-3">
                  <span className="mb-1.5 block text-xs font-semibold text-muted-foreground">想问医生的问题</span>
                  <textarea
                    value={diaryAppointmentNote}
                    onChange={(event) => setDiaryAppointmentNote(event.target.value)}
                    placeholder="比如下次产检想确认的身体变化、检查结果或用药问题"
                    rows={2}
                    className="w-full resize-none rounded-xl border border-border/50 bg-background px-3 py-2 text-sm font-semibold leading-relaxed outline-none transition-all focus:border-primary focus:ring-1 focus:ring-primary/20"
                  />
                </label>
                <label className="block rounded-2xl border border-border/50 bg-secondary/20 p-3">
                  <span className="mb-1.5 block text-xs font-semibold text-muted-foreground">今天想记录的事</span>
                  <textarea
                    value={diaryContent}
                    onChange={(event) => setDiaryContent(event.target.value)}
                    placeholder="生活片段、产检点滴、情绪变化，或想留给自己的话"
                    rows={4}
                    className="w-full resize-none rounded-xl border border-border/50 bg-background px-3 py-2 text-sm font-semibold leading-relaxed outline-none transition-all focus:border-primary focus:ring-1 focus:ring-primary/20"
                  />
                </label>
                <div className="rounded-2xl bg-[#fffaf0] px-4 py-3 text-[11px] font-semibold leading-relaxed text-[#6d5530]">
                  如果有明显胎动异常、出血、剧烈腹痛或其它担心的情况，请及时联系医生。
                </div>
              </div>

              {diarySaveErr ? (
                <p className="mt-3 px-0.5 text-[11px] leading-relaxed text-destructive">{diarySaveErr}</p>
              ) : null}

              <motion.button
                type="button"
                disabled={diarySaving}
                whileTap={{ scale: diarySaving ? 1 : 0.97 }}
                onClick={async () => {
                  setDiarySaveErr(null);
                  const todayDateKey = toLocalDateKey(new Date());
                  const symptomTags = diarySymptomTags
                    .split(/[、,，\s]+/)
                    .map((tag) => tag.trim())
                    .filter(Boolean);
                  if (
                    !diaryGestationalWeek.trim() &&
                    !diaryMood.trim() &&
                    !diaryEnergy.trim() &&
                    !diarySleep.trim() &&
                    !diaryFetalMovement.trim() &&
                    symptomTags.length === 0 &&
                    !diaryAppointmentNote.trim() &&
                    !diaryContent.trim()
                  ) {
                    setDiarySaveErr("至少写下一项今天的状态或记录");
                    return;
                  }
                  setDiarySaving(true);
                  try {
                    const baseBody = {
                      user_id: DEFAULT_CHAT_USER_ID,
                      entry_date: todayDateKey,
                      gestational_week: diaryGestationalWeek,
                      mood: diaryMood,
                      energy_level: diaryEnergy,
                      sleep_summary: diarySleep,
                      fetal_movement: diaryFetalMovement,
                      symptom_tags: symptomTags,
                      appointment_note: diaryAppointmentNote,
                      content: diaryContent,
                    };
                    const result = pregnancyDiaryToday
                      ? await updatePregnancyDiaryEntry({ ...baseBody, entry_id: pregnancyDiaryToday.entry_id })
                      : await createPregnancyDiaryEntry(baseBody);
                    if (result.error !== 0) throw new Error("保存孕期日记失败");
                    await reloadPregnancyDiary();
                    setPregnancyDiaryLoading(false);
                    setIsPregnancyDiaryEditorOpen(false);
                    setPregnancyDiaryJustSaved(true);
                    setActiveMomPanel("pregnancy-diary-detail");
                  } catch (e: unknown) {
                    setDiarySaveErr(e instanceof Error ? e.message : "保存失败，请稍后重试");
                  } finally {
                    setDiarySaving(false);
                  }
                }}
                className="mt-4 w-full rounded-2xl bg-foreground py-3.5 text-[15px] font-bold text-background shadow-md disabled:pointer-events-none disabled:opacity-50"
              >
                {diarySaving ? "保存中…" : pregnancyDiaryToday ? "保存今天的修改" : "保存今天的日记"}
              </motion.button>
            </motion.div>
          </>
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {isGrowthDrawerOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm"
              onClick={() => {
                if (!growthSubmitting) setIsGrowthDrawerOpen(false);
              }}
            />
            <motion.div
              initial={{ y: "100%", opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: "100%", opacity: 0 }}
              transition={{ type: "spring", damping: 28, stiffness: 300 }}
              className="fixed inset-x-0 bottom-0 z-50 w-full max-w-lg mx-auto rounded-t-3xl bg-card border-t border-border/40 shadow-2xl px-5 pt-4"
              style={{ paddingBottom: "max(2rem, env(safe-area-inset-bottom))" }}
            >
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-base font-extrabold text-foreground">修改生长指标</h3>
                <button
                  type="button"
                  disabled={growthSubmitting}
                  onClick={() => {
                    if (!growthSubmitting) setIsGrowthDrawerOpen(false);
                  }}
                  className="w-8 h-8 rounded-full bg-secondary/80 hover:bg-secondary flex items-center justify-center transition-colors active:scale-95 disabled:opacity-50"
                >
                  <X className="w-4 h-4 text-muted-foreground" />
                </button>
              </div>

              <div className="space-y-4 mb-6">
                <div className="bg-secondary/20 p-3 rounded-2xl border border-border/50">
                  <label className="text-xs font-semibold text-muted-foreground mb-1.5 block ml-1">体重 (kg)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={editWeight}
                    onChange={(e) => setEditWeight(e.target.value)}
                    className="w-full h-11 rounded-xl bg-background border border-border/50 px-3 text-sm font-bold outline-none focus:border-primary focus:ring-1 focus:ring-primary/20 transition-all"
                  />
                </div>
                <div className="bg-secondary/20 p-3 rounded-2xl border border-border/50">
                  <label className="text-xs font-semibold text-muted-foreground mb-1.5 block ml-1">身高 (cm)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={editHeight}
                    onChange={(e) => setEditHeight(e.target.value)}
                    className="w-full h-11 rounded-xl bg-background border border-border/50 px-3 text-sm font-bold outline-none focus:border-primary focus:ring-1 focus:ring-primary/20 transition-all"
                  />
                </div>
                <div className="bg-secondary/20 p-3 rounded-2xl border border-border/50">
                  <label className="text-xs font-semibold text-muted-foreground mb-1.5 block ml-1">头围 (cm)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={editHead}
                    onChange={(e) => setEditHead(e.target.value)}
                    className="w-full h-11 rounded-xl bg-background border border-border/50 px-3 text-sm font-bold outline-none focus:border-primary focus:ring-1 focus:ring-primary/20 transition-all"
                  />
                </div>
              </div>

              {growthSaveErr ? (
                <p className="text-[11px] text-destructive mb-4 px-0.5 leading-relaxed">{growthSaveErr}</p>
              ) : null}

              <motion.button
                type="button"
                disabled={growthSubmitting}
                whileTap={{ scale: growthSubmitting ? 1 : 0.97 }}
                onClick={async () => {
                  setGrowthSaveErr(null);

                  const w = parseFloat(editWeight);
                  const h = parseFloat(editHeight);
                  const hd = parseFloat(editHead);
                  const weightKg = Number.isFinite(w) ? w : babyMetrics.weightKg;
                  const heightCm = Number.isFinite(h) ? h : babyMetrics.heightCm;
                  const headCmVal = Number.isFinite(hd) ? hd : babyMetrics.headCm;

                  if (
                    typeof weightKg !== "number" ||
                    typeof heightCm !== "number" ||
                    typeof headCmVal !== "number"
                  ) {
                    setGrowthSaveErr("请填写完整的体重、身高与头围");
                    return;
                  }

                  const bodyBase = {
                    user_id: DEFAULT_CHAT_USER_ID,
                    weight_kg: weightKg,
                    height_cm: Math.round(heightCm),
                    head_cm: Math.round(headCmVal),
                  } as const;

                  const tryRevise =
                    latestGrowth != null &&
                    latestGrowth.error === 0 &&
                    Number.isFinite(latestGrowth.growth_id) &&
                    growthLastRecordedSameLocalDayAsNow(latestGrowth);

                  setGrowthSubmitting(true);
                  try {
                    if (tryRevise) {
                      const rev = await reviseGrowthRecord({
                        user_id: bodyBase.user_id,
                        growth_id: latestGrowth.growth_id,
                        weight_kg: bodyBase.weight_kg,
                        height_cm: bodyBase.height_cm,
                        head_cm: bodyBase.head_cm,
                      });
                      if (rev.error !== 0) throw new Error("修改生长发育记录失败");
                    } else {
                      const added = await addGrowthRecord(bodyBase);
                      if (added.error !== 0) throw new Error("上报生长发育记录失败");
                    }

                    const data = await queryLatestGrowth({
                      user_id: DEFAULT_CHAT_USER_ID,
                    });
                    if (data.error === 0) {
                      setLatestGrowth(data);
                      setBabyMetrics({
                        weightKg: mlFromApi(data.weight_kg),
                        heightCm: mlFromApi(data.height_cm),
                        headCm: mlFromApi(data.head_cm),
                      });
                    }

                    const histReload = await getGrowthHistory({
                      user_id: DEFAULT_CHAT_USER_ID,
                    });
                    if (
                      histReload.error === 0 &&
                      Array.isArray(histReload.growth_data)
                    ) {
                      setGrowthHistoryRows(mapGrowthHistoryToBabyRows(histReload.growth_data));
                    }

                    setIsGrowthDrawerOpen(false);
                  } catch (e: unknown) {
                    setGrowthSaveErr(e instanceof Error ? e.message : "保存失败，请稍后重试");
                  } finally {
                    setGrowthSubmitting(false);
                  }
                }}
                className="w-full py-3.5 rounded-2xl bg-foreground text-background text-[15px] font-bold shadow-md disabled:opacity-50 disabled:pointer-events-none"
              >
                {growthSubmitting ? "保存中…" : "保存修改"}
              </motion.button>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
};

export default StatusOverviewBody;
