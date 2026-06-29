import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Bell, BellOff, CheckCircle2, ChevronLeft, ChevronRight, Clock, HelpCircle, ImageIcon, Loader2, MessageCircle, Plus, Trash2, X } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { format, addDays, isSameDay } from "date-fns";
import { useLocation, useNavigate } from "react-router-dom";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { babyData, type PumpRecord, type ScheduleTask } from "@/data/mockData";
import ReminderAlert from "@/components/schedule/ReminderAlert";
import ManualEntryDialog from "@/components/records/ManualEntryDialog";
import FeedingEntryDialog from "@/components/baby/FeedingEntryDialog";
import AddTaskDialog, { type AddTaskDialogHandle } from "@/components/schedule/AddTaskDialog";
import TimeWheelPickerSheet from "@/components/schedule/TimeWheelPickerSheet";
import { useVolumeUnit, formatVol, unitLabel } from "@/lib/volumeUnit";
import { uploadPumpMilkRecord, queryPumpMilkRecords, deletePumpMilkRecord } from "@/lib/momPumpTwinAgentApi";
import { queryMomBabyInfo } from "@/lib/momPumpTwinAgentApi";
import { addFeedingRecord, deleteFeedingRecord, queryFeedingRecords } from "@/lib/babyTwinAgentApi";
import { addPlanTasks, deletePlanTask, queryCarePlan, revisePlanTask } from "@/lib/agentApi";
import type { FeedingAddBody, FeedingListItem, PlanTaskItem, PumpMilkListItem } from "@/lib/agentApiTypes";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import {
  calendarDaysSinceDeliveryOnLocal,
  postpartumWeekFromDay,
  pickMomBabyDeliveryDateYmd,
} from "@/lib/momBabyDelivery";
import { Capacitor } from "@capacitor/core";
import { Preferences } from "@capacitor/preferences";
import {
  requestNativeNotifySyncNow,
  setNativeBackgroundNotifyEnabled,
} from "@/lib/mmcBackgroundNotify";
import momcozyAgentAvatar from "@/assets/momcozy-agent.png";
import {
  consumePlanPageNotification,
  milkPlanNotificationConfig,
  usePlanPageNotification,
} from "@/lib/planNotification";

const skippedMarker = "已跳过";

const REMINDER_PREF_KEY = "mmc_schedule_reminder_on";

const nextDateKeys = (base: Date, count: number): string[] =>
  Array.from({ length: count }, (_, i) => format(addDays(base, i + 1), "yyyy-MM-dd"));

const lactationPhases = [
  { key: "colostrum", label: "初乳期", range: "0-3天", endDay: 3 },
  { key: "establish", label: "建立期", range: "4天-4周", endDay: 28 },
  { key: "stable", label: "稳产期", range: "1-6个月", endDay: 180 },
  { key: "weaning", label: "离乳期", range: "6个月+", endDay: Infinity },
] as const;

const taskIcon: Record<ScheduleTask["type"], string> = {
  pump: "🤱",
  feed: "🍼",
  meeting: "📅",
  custom: "⭐",
};

const timeDiffInMinutes = (time1: string, time2: string) => {
  const [h1, m1] = time1.split(":").map(Number);
  const [h2, m2] = time2.split(":").map(Number);
  let diff = (h1 * 60 + m1) - (h2 * 60 + m2);
  if (diff < -12 * 60) diff += 24 * 60;
  if (diff > 12 * 60) diff -= 24 * 60;
  return diff; // positive if time1 is later than time2
};

const addMinutes = (time: string, mins: number): string => {
  const [h, m] = time.split(":").map(Number);
  const total = Math.max(0, h * 60 + m + mins);
  return `${String(Math.floor(total / 60) % 24).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
};

const formatClockTime = (d: Date): string => {
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
};

const taskTimeOnDate = (date: Date, time: string): Date | null => {
  const [h, m] = time.split(":").map(Number);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  const target = new Date(date);
  target.setHours(h, m, 0, 0);
  return target;
};

const formatCountdownDuration = (durationMs: number): string => {
  const totalSeconds = Math.max(0, Math.floor(durationMs / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
};

const isActionTask = (task: ScheduleTask) => !task.id.startsWith("blocked-");
const isSkipped = (task: ScheduleTask) => task.adjusted === skippedMarker;
const isFeedingRecord = (record: PumpRecord) => record.category === "feeding" || record.subLabel === "亲喂" || record.subLabel === "瓶喂";
const generatedRecordId = (taskId: string) => `task-record-${taskId}`;
const taskCompletionRecordKey = (date: string, taskId: string) => `${date}::${taskId}`;

const getLactationPhase = (postpartumDay: number) =>
  lactationPhases.find((phase) => postpartumDay <= phase.endDay) || lactationPhases[lactationPhases.length - 1];

const formatTimestampDate = (d: Date) => format(d, "yyyy-MM-dd");

const normalizeApiPlanType = (planType: string) => {
  const t = (planType || "").trim().toLowerCase();
  return t === "none" ? "none" : t;
};

const mapPlanTypeToLabel = (planType: string) => {
  const t = normalizeApiPlanType(planType);
  if (t === "none") return "稳奶";
  const map: Record<string, string> = {
    maintain: "维持奶量",
    chase: "追奶",
    wean: "温和离乳",
    fertility: "待产计划",
    work: "返工计划",
  };
  return map[t] ?? "呵护计划";
};

const mapTodayPlanTypeToHeaderLabel = (planType: string) => {
  const label = mapPlanTypeToLabel(planType);
  return label === "稳奶" ? "稳奶计划执行中" : label;
};

const normalizeTaskPlanBadgeLabel = (label: string) => {
  const t = (label || "").trim();
  if (!t) return "";
  if (t.includes("追奶")) return "追奶计划";
  if (t.includes("减奶") || t.includes("离乳")) return "减奶计划";
  if (t.includes("稳奶") || t.includes("维持")) return "稳奶计划";
  if (t.includes("待产")) return "待产计划";
  if (t.includes("返工")) return "返工计划";
  return t.endsWith("计划") ? t : `${t}计划`;
};

const mapPlanTypeToTaskBadgeLabel = (planType: string) => {
  const t = normalizeApiPlanType(planType);
  const map: Record<string, string> = {
    none: "稳奶计划",
    maintain: "稳奶计划",
    chase: "追奶计划",
    wean: "减奶计划",
    fertility: "待产计划",
    work: "返工计划",
  };
  return map[t] ?? normalizeTaskPlanBadgeLabel(mapPlanTypeToLabel(t));
};

const resolveSmartTaskPlanBadgeLabel = (task: ScheduleTask, planType: string) => {
  if (task.source !== "mai") return null;
  const fromTask = normalizeTaskPlanBadgeLabel(task.reason ?? "");
  return fromTask || mapPlanTypeToTaskBadgeLabel(planType);
};

const formatPostpartumPhaseLabel = (postpartumDay: number, phaseLabel: string) =>
  `产后第${postpartumWeekFromDay(postpartumDay)}周（${phaseLabel}）`;

const buildTodayTaskPlanMethodSentence = (planType: string, planLabel: string): string => {
  const t = normalizeApiPlanType(planType);
  if (t === "chase") {
    return "追奶重点是增加有效移出机会，放在更容易坚持的时段。";
  }
  if (t === "wean") {
    return "减奶重点是循序减少频次或时长，避免突然停吸带来胀痛。";
  }
  if (t === "none" || t === "maintain") {
    return "稳奶重点是稳定关键排乳窗口，避免过度加任务或过早减少。";
  }
  if (t === "work") {
    return "返工重点是保留关键排乳窗口，并适配通勤和工作空档。";
  }
  if (t === "fertility") {
    return "待产重点是按阶段排优先级，先处理必须确认的事项。";
  }
  return `${planLabel}重点是结合阶段、记录和执行负担，保证任务能执行。`;
};

const buildTodayTaskPlanExplanation = ({
  planType,
  actionTaskCount,
  completedTaskCount,
  skippedTaskCount,
  pumpRecordCount,
  feedingRecordCount,
  loading,
}: {
  postpartumDay: number;
  phaseLabel: string;
  planType: string;
  actionTaskCount: number;
  completedTaskCount: number;
  skippedTaskCount: number;
  pumpRecordCount: number;
  feedingRecordCount: number;
  inventoryTotal: number;
  feedingTotal: number;
  volUnit: "mL" | "oz";
  loading: boolean;
}) => {
  const rawPlanLabel = mapTodayPlanTypeToHeaderLabel(planType).replace(/执行中$/, "");
  const planLabel = rawPlanLabel.endsWith("计划") ? rawPlanLabel : `${rawPlanLabel}计划`;
  const taskProgress =
    actionTaskCount > 0
      ? `完成${completedTaskCount}/${actionTaskCount}项${skippedTaskCount > 0 ? `，跳过${skippedTaskCount}项` : ""}`
      : "暂无任务进度";
  const recordFeedback = pumpRecordCount + feedingRecordCount > 0 ? "新增记录只用于看执行反馈" : "暂无新增记录反馈";
  const syncPrefix = loading ? "今天记录还在同步。" : "";
  const methodSentence = buildTodayTaskPlanMethodSentence(planType, planLabel);

  return `${syncPrefix}${planLabel}依据上次制定前读取到的产后阶段、奶量/喂养记录和原有任务节奏。今天${taskProgress}，${recordFeedback}；${methodSentence}`;
};

const smartSourceCardClass = "bg-white border-border/60";
const smartNextCardClass = "bg-white border-primary/35 shadow-md shadow-primary/10";
const manualSourceCardClass = "bg-white border-border/60";
const manualNextCardClass = "bg-white border-primary/35 shadow-md shadow-primary/10";
const completedSourceCardClass = "bg-[hsl(118_22%_94%)] border-[hsl(118_18%_82%)]";
const skippedSourceCardClass = "bg-[hsl(30_6%_92%)] border-0";
const recordValueBadgeClass = "inline-flex h-5 max-w-[5.5rem] items-center rounded-md border border-border/40 bg-background px-1.5 py-0 text-[10px] font-semibold leading-none text-foreground/80 whitespace-nowrap tabular-nums";
const recordCompletionTimeBadgeClass = "inline-flex h-5 max-w-[5.75rem] items-center rounded-md border border-[hsl(118_18%_78%)] bg-[hsl(118_22%_97%)] px-1.5 py-0 text-[10px] font-semibold leading-none text-[hsl(118_24%_34%)] whitespace-nowrap truncate";
const completedTaskBadgeClass = "inline-flex h-5 items-center rounded-md border border-[hsl(118_18%_78%)] bg-[hsl(118_22%_97%)] px-1.5 py-0 text-[10px] font-normal leading-none text-[hsl(118_24%_34%)] whitespace-nowrap";
const skippedTaskBadgeClass = "inline-flex h-5 items-center rounded-md border border-[hsl(28_7%_78%)] bg-[hsl(30_8%_92%)] px-1.5 py-0 text-[10px] font-normal leading-none text-[hsl(28_7%_36%)] whitespace-nowrap";
const taskPlanBadgeClass = "inline-flex h-4 max-w-[4.25rem] items-center rounded-[6px] border border-[hsl(38_58%_74%)] bg-[hsl(40_92%_91%)] px-1.5 py-0 text-[9px] font-bold leading-none text-[hsl(34_64%_34%)] whitespace-nowrap truncate shrink-0";
const manualTaskBadgeClass = "inline-flex h-4 max-w-[4.25rem] items-center rounded-[6px] border border-[hsl(210_26%_76%)] bg-[hsl(210_38%_94%)] px-1.5 py-0 text-[9px] font-bold leading-none text-[hsl(212_34%_34%)] whitespace-nowrap truncate shrink-0";

const normalizeTaskTimeFromApi = (raw: string) => {
  const t = (raw || "").trim();
  const m = t.match(/^(\d{1,2}):(\d{2})/);
  if (m) {
    return `${String(Number(m[1])).padStart(2, "0")}:${String(Number(m[2])).padStart(2, "0")}`;
  }
  return normalizePumpTimeForDisplay(t);
};

const mapTaskTypeFromApi = (taskType: string | number | null | undefined): ScheduleTask["type"] => {
  const t = (taskType == null ? "" : String(taskType)).trim().toLowerCase();
  if (t === "0" || t === "pump" || t.includes("吸")) return "pump";
  if (t === "1" || t === "feed" || t.includes("喂")) return "feed";
  if (t === "2" || t === "custom" || t.includes("自定义")) return "custom";
  return "custom";
};

const mapTaskDoneFromApi = (taskDone: string) => {
  const doneRaw = (taskDone || "").trim().toLowerCase();
  if (doneRaw === "jump") return { done: true, adjusted: skippedMarker };
  if (doneRaw === "true") return { done: true, adjusted: undefined as string | undefined };
  return { done: false, adjusted: undefined as string | undefined };
};

const mapTaskSourceToUiSource = (taskSource: string): ScheduleTask["source"] => {
  const s = (taskSource || "").trim().toLowerCase();
  if (s.includes("mai") || s.includes("系统")) return "mai";
  return "manual";
};

const mapApiTaskToScheduleTask = (task: PlanTaskItem): ScheduleTask => {
  const doneState = mapTaskDoneFromApi(task.task_done);
  const type = mapTaskTypeFromApi(task.task_type);
  return {
    id: `srv-task-${task.task_id}`,
    taskId: task.task_id,
    taskTypeRaw: task.task_type,
    taskSourceRaw: task.task_source,
    taskDoneRaw: task.task_done,
    time: normalizeTaskTimeFromApi(task.task_time),
    type,
    title: task.task_content,
    done: doneState.done,
    adjusted: doneState.adjusted,
    source: mapTaskSourceToUiSource(task.task_source),
    doneSource: doneState.done ? "system" : undefined,
  };
};

const mapFeedingTypeToFeedType = (record: PumpRecord): number => {
  if (record.subLabel === "亲喂") return 0;
  if (record.subLabel === "瓶喂") return 1;
  return 2;
};

const buildFeedingUploadBody = (record: PumpRecord, feedAction: number): FeedingAddBody => {
  const isBreastFeed = record.subLabel === "亲喂";
  const feedMilkVolum = isBreastFeed
    ? Math.max(0, Number(record.durationMin) || 0)
    : Math.max(0, Number(record.totalMl) || 0);
  return {
    user_id: DEFAULT_CHAT_USER_ID,
    feed_type: mapFeedingTypeToFeedType(record),
    feed_action: feedAction,
    feed_time: record.time,
    feeding_title: record.recordTitle,
    feed_milk_volum: feedMilkVolum,
  };
};

const mapFeedingListItemToRecord = (item: FeedingListItem, date: string): PumpRecord => {
  const ft = Number(item.feed_type);
  const duration = Number(item.feed_duration) || 0;
  const volum = Number(item.feed_milk_volum) || 0;
  const isBreast = ft === 0;
  const subLabel = isBreast ? "亲喂" : ft === 2 ? "配方奶" : ("瓶喂" as const);
  const totalMl = isBreast ? 0 : volum;
  return {
    id: `feeding-api-${item.feeding_id}`,
    recordTitle: item.feeding_title ?? item.title,
    feedingId: item.feeding_id,
    feedAction: item.feed_action,
    date,
    time: normalizePumpTimeForDisplay(item.feed_time),
    durationMin: duration,
    leftMl: Math.floor(totalMl / 2),
    rightMl: Math.ceil(totalMl / 2),
    totalMl,
    source: "manual",
    mode: "deep",
    subLabel,
    category: "feeding",
  };
};

/** 任务主文案最多展示 max 个字（Unicode 码位），超出用 … 省略 */
const truncateTaskDisplay = (text: string, max = 10) => {
  const chars = [...text];
  if (chars.length <= max) return text;
  return `${chars.slice(0, max).join("")}...`;
};

/** 记录主类型文案（与奶量分列展示） */
const formatRecordContentLabel = (record: PumpRecord): string => {
  if (record.subLabel === "亲喂") return "亲喂";
  if (record.subLabel === "配方奶") return "配方奶";
  if (record.subLabel === "瓶喂") return "瓶喂母乳";
  if (record.subLabel === "补录") return "补录";
  return "吸奶";
};

const resolveRecordDisplayTitle = (record: PumpRecord): string => {
  return record.recordTitle || formatRecordContentLabel(record);
};

const formatRecordVolumeDisplay = (record: PumpRecord, volUnit: "mL" | "oz"): string => {
  if (record.subLabel === "亲喂") return `${record.durationMin || 0} min`;
  return `${formatVol(record.totalMl, volUnit)}${unitLabel(volUnit)}`;
};

/** 将接口时间字段规范为 HH:MM（支持 HH:MM:SS、ISO、yyyy-MM-dd HH:mm:ss） */
const normalizePumpTimeForDisplay = (pumpTime: string | null | undefined): string => {
  const t = typeof pumpTime === "string" ? pumpTime.trim() : "";
  if (!t) return "00:00";
  if (t.includes("T")) {
    const afterT = t.split("T")[1] ?? "";
    return afterT.slice(0, 5);
  }
  const m = t.match(/\b(\d{1,2}:\d{2})(?::\d{2})?\b/);
  if (m) {
    const [h, min] = m[1].split(":").map(Number);
    return `${String(h).padStart(2, "0")}:${String(min).padStart(2, "0")}`;
  }
  return "00:00";
};

const mapPumpMilkListItemToRecord = (item: PumpMilkListItem, date: string): PumpRecord => {
  const isSupplement = item.pump_type === 1;
  const vol = Number(item.pump_milk_volum) || 0;
  return {
    id: `pump-api-${item.pump_id}`,
    recordTitle: item.pump_title ?? item.title,
    pumpId: item.pump_id,
    pumpSource: item.pump_source,
    date,
    time: normalizePumpTimeForDisplay(item.pump_time),
    durationMin: 0,
    leftMl: Math.floor(vol / 2),
    rightMl: Math.ceil(vol / 2),
    totalMl: vol,
    source: isSupplement ? "manual" : "device",
    mode: "deep",
    subLabel: isSupplement ? "补录" : undefined,
    category: "inventory",
  };
};

const mergePumpMilkQueryIntoRecords = (prev: PumpRecord[], list: PumpMilkListItem[], dayDateStr: string): PumpRecord[] => {
  const feeding = prev.filter(isFeedingRecord);
  const planSynth = prev.filter((r) => !isFeedingRecord(r) && r.id.startsWith("task-record-"));
  const apiRows = list.map((item) => mapPumpMilkListItemToRecord(item, dayDateStr));
  return [...feeding, ...planSynth, ...apiRows].sort((a, b) => a.time.localeCompare(b.time));
};

const createRecordFromTask = (task: ScheduleTask, dateStr: string): PumpRecord | null => {
  if (task.type === "pump") {
    const totalMl = task.reason === "安心追奶" || task.reason === "追奶" ? 95 : 120;
    return {
      id: generatedRecordId(task.id) + "-" + dateStr,
      date: dateStr,
      time: task.time,
      durationMin: 20,
      leftMl: Math.floor(totalMl / 2),
      rightMl: Math.ceil(totalMl / 2),
      totalMl,
      source: "manual",
      mode: "deep",
      subLabel: "补录",
      category: "inventory",
      pumpSource: 2,
    };
  }

  if (task.type === "feed") {
    return {
      id: generatedRecordId(task.id) + "-" + dateStr,
      date: dateStr,
      time: task.time,
      durationMin: 18,
      leftMl: 0,
      rightMl: 0,
      totalMl: 0,
      source: "manual",
      mode: "deep",
      subLabel: "亲喂",
      category: "feeding",
    };
  }

  return null;
};

const Schedule: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [volUnit] = useVolumeUnit();
  
  const todayDate = useMemo(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }, []);
  const [selectedDate, setSelectedDate] = useState<Date>(todayDate);
  const [weekOffset, setWeekOffset] = useState(0);
  const displayMonthDate = useMemo(
    () => addDays(todayDate, weekOffset * 7),
    [todayDate, weekOffset]
  );
  const dateStr = format(selectedDate, "yyyy-MM-dd");
  const isSelectedToday = isSameDay(selectedDate, todayDate);
  const showBackToTodayFab = !isSelectedToday || weekOffset !== 0;
  const isSelectedPast = selectedDate.getTime() < todayDate.getTime();
  const milkPlanPageNotification = usePlanPageNotification(milkPlanNotificationConfig);
  const [milkPlanHighlightDates, setMilkPlanHighlightDates] = useState<string[]>([]);

  const [allTasks, setAllTasks] = useState<Record<string, ScheduleTask[]>>({});
  const [allRecords, setAllRecords] = useState<Record<string, PumpRecord[]>>({});

  const tasks = useMemo(() => allTasks[dateStr] || [], [allTasks, dateStr]);
  const records = useMemo(() => allRecords[dateStr] || [], [allRecords, dateStr]);

  const setTasks = useCallback((updater: React.SetStateAction<ScheduleTask[]>) => {
    setAllTasks(prev => ({
      ...prev,
      [dateStr]: typeof updater === "function" ? updater(prev[dateStr] || []) : updater
    }));
  }, [dateStr]);

  const setRecords = useCallback((updater: React.SetStateAction<PumpRecord[]>) => {
    setAllRecords(prev => ({
      ...prev,
      [dateStr]: typeof updater === "function" ? updater(prev[dateStr] || []) : updater
    }));
  }, [dateStr]);

  const [reminderOn, setReminderOn] = useState(true);
  const [reminderAlertOpen, setReminderAlertOpen] = useState(false);

  useEffect(() => {
    const payload = consumePlanPageNotification(milkPlanNotificationConfig);
    if (!payload) return;

    const todayKey = format(todayDate, "yyyy-MM-dd");
    const dates = (payload.dates ?? [])
      .filter((date) => /^\d{4}-\d{2}-\d{2}$/.test(date))
      .filter((date) => date > todayKey);
    const fallbackDates =
      payload.reason === "created" || payload.reason === "synced" || !payload.reason
        ? nextDateKeys(todayDate, 3)
        : [];
    setMilkPlanHighlightDates(dates.length > 0 ? dates : fallbackDates);

    const timer = window.setTimeout(() => {
      setMilkPlanHighlightDates([]);
    }, 6500);
    return () => window.clearTimeout(timer);
  }, [milkPlanPageNotification, todayDate]);

  const persistSystemReminderOn = useCallback(async (on: boolean) => {
    setReminderOn(on);
    try {
      await Preferences.set({ key: REMINDER_PREF_KEY, value: on ? "1" : "0" });
    } catch {
      /* ignore */
    }
    if (Capacitor.getPlatform() !== "android") return;
    try {
      await setNativeBackgroundNotifyEnabled(DEFAULT_CHAT_USER_ID, on);
      if (on) await requestNativeNotifySyncNow();
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const { value } = await Preferences.get({ key: REMINDER_PREF_KEY });
        if (cancelled) return;
        let on = true;
        if (value === "0") on = false;
        else if (value === "1") on = true;
        setReminderOn(on);
        if (Capacitor.getPlatform() !== "android") return;
        try {
          await setNativeBackgroundNotifyEnabled(DEFAULT_CHAT_USER_ID, on);
          if (on) await requestNativeNotifySyncNow();
        } catch {
          /* ignore */
        }
      } catch {
        /* ignore */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const handleReminderToggleClick = useCallback(() => {
    if (reminderOn) {
      setReminderAlertOpen(true);
      return;
    }
    void persistSystemReminderOn(true);
  }, [persistSystemReminderOn, reminderOn]);

  const openScheduleConversation = useCallback(() => {
    navigate("/", { state: { agentPrefill: "我想调整今天的吸乳排期" } });
  }, [navigate]);

  const [addTaskOpen, setAddTaskOpen] = useState(false);
  const [scheduleAdjusting, setScheduleAdjusting] = useState(false);
  const [pumpEntryOpen, setPumpEntryOpen] = useState(false);
  const [feedingEntryOpen, setFeedingEntryOpen] = useState(false);
  const [todayTaskInfoOpen, setTodayTaskInfoOpen] = useState(false);
  const [editTimePickerOpen, setEditTimePickerOpen] = useState(false);
  const editTitleInputRef = useRef<HTMLInputElement | null>(null);
  const addTaskDialogRef = useRef<AddTaskDialogHandle | null>(null);
  
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);
  const [editTime, setEditTime] = useState("");
  const [editTitle, setEditTitle] = useState("");
  const [pendingCompleteTask, setPendingCompleteTask] = useState<ScheduleTask | null>(null);
  const [planType, setPlanType] = useState<string>("none");
  const [deliveryYmd, setDeliveryYmd] = useState<string | null>(null);
  const [tasksLoading, setTasksLoading] = useState(false);
  const [recordsLoading, setRecordsLoading] = useState(false);
  const [taskCompletionRecordRefs, setTaskCompletionRecordRefs] = useState<
    Record<string, { pumpId?: number; feedingId?: number; taskTitle?: string }>
  >({});
  const [deletingTaskIds, setDeletingTaskIds] = useState<Record<string, true>>({});
  const [deletingRecordIds, setDeletingRecordIds] = useState<Record<string, true>>({});

  const startEdit = useCallback((task: ScheduleTask) => {
    if (task.done || task.adjusted === skippedMarker || !isSelectedToday) return;
    setEditingTaskId(task.id);
    setEditTime(task.time);
    setEditTitle(task.title);
  }, [isSelectedToday]);

  useEffect(() => {
    let cancelled = false;
    const ac = new AbortController();
    void (async () => {
      try {
        const info = await queryMomBabyInfo(DEFAULT_CHAT_USER_ID, { signal: ac.signal });
        if (cancelled) return;
        if (info.error === 0) {
          setDeliveryYmd(pickMomBabyDeliveryDateYmd(info));
        }
      } catch {
        if (!cancelled) setDeliveryYmd(null);
      }
    })();
    return () => {
      cancelled = true;
      ac.abort();
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const ac = new AbortController();
    setTasksLoading(true);
    void (async () => {
      try {
        const data = await queryCarePlan(
          {
            user_id: DEFAULT_CHAT_USER_ID,
            timestamp: dateStr,
          },
          { signal: ac.signal },
        );
        if (cancelled) return;
        if (data.error !== 0) return;
        setPlanType(normalizeApiPlanType(data.plan_type));
        const mapped = (data.task_list || [])
          .map(mapApiTaskToScheduleTask)
          .sort((a, b) => a.time.localeCompare(b.time));
        setAllTasks((prev) => ({ ...prev, [dateStr]: mapped }));
      } finally {
        if (!cancelled) setTasksLoading(false);
      }
    })();
    return () => {
      cancelled = true;
      ac.abort();
    };
  }, [dateStr]);

  useEffect(() => {
    let cancelled = false;
    const ac = new AbortController();
    setRecordsLoading(true);
    void (async () => {
      try {
        const [pumpData, feedingData] = await Promise.all([
          queryPumpMilkRecords({ user_id: DEFAULT_CHAT_USER_ID, timestamp: dateStr }, { signal: ac.signal }),
          queryFeedingRecords({ user_id: DEFAULT_CHAT_USER_ID, timestamp: dateStr }, { signal: ac.signal }),
        ]);
        if (cancelled) return;
        const pumpList = pumpData.error === 0 ? pumpData.pump_milk_list : [];
        const feedingList = feedingData.error === 0 ? feedingData.feed_list : [];
        const mapped = [
          ...pumpList.map((item) => mapPumpMilkListItemToRecord(item, dateStr)),
          ...feedingList.map((item) => mapFeedingListItemToRecord(item, dateStr)),
        ].sort((a, b) => a.time.localeCompare(b.time));
        setAllRecords((prev) => ({ ...prev, [dateStr]: mapped }));
      } finally {
        if (!cancelled) setRecordsLoading(false);
      }
    })();
    return () => {
      cancelled = true;
      ac.abort();
    };
  }, [dateStr]);

  const effectiveDeliveryYmd = deliveryYmd || babyData.birthDate;
  const postpartumDay = Math.max(0, calendarDaysSinceDeliveryOnLocal(effectiveDeliveryYmd, selectedDate) ?? 0);
  const currentPhase = getLactationPhase(postpartumDay);

  const sortedTasks = useMemo(() => [...tasks].sort((a, b) => a.time.localeCompare(b.time)), [tasks]);
  const actionTasks = useMemo(() => sortedTasks.filter(isActionTask), [sortedTasks]);
  const hasActionTasks = actionTasks.length > 0;
  const isFutureWithoutPlan = !isSelectedToday && !isSelectedPast && !hasActionTasks;
  const completedTasks = useMemo(() => actionTasks.filter((task) => task.done && !isSkipped(task)), [actionTasks]);
  const skippedTasks = useMemo(() => actionTasks.filter(isSkipped), [actionTasks]);
  const remainingTasks = useMemo(() => actionTasks.filter((task) => !task.done), [actionTasks]);
  const nextTask = remainingTasks[0] || null;
  const [scheduleNow, setScheduleNow] = useState(() => new Date());

  useEffect(() => {
    if (!isSelectedToday || !nextTask) return;
    setScheduleNow(new Date());
    const timer = window.setInterval(() => setScheduleNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, [isSelectedToday, nextTask?.id, nextTask?.time]);

  const inventoryRecords = useMemo(() => records.filter((record) => !isFeedingRecord(record)), [records]);
  const feedingRecords = useMemo(() => records.filter(isFeedingRecord), [records]);
  const inventoryTotal = useMemo(() => inventoryRecords.reduce((sum, record) => sum + record.totalMl, 0), [inventoryRecords]);
  const feedingTotal = useMemo(() => feedingRecords.reduce((sum, record) => sum + record.totalMl, 0), [feedingRecords]);
  const todayTaskPlanExplanation = useMemo(
    () =>
      buildTodayTaskPlanExplanation({
        postpartumDay,
        phaseLabel: currentPhase.label,
        planType,
        actionTaskCount: actionTasks.length,
        completedTaskCount: completedTasks.length,
        skippedTaskCount: skippedTasks.length,
        pumpRecordCount: inventoryRecords.length,
        feedingRecordCount: feedingRecords.length,
        inventoryTotal,
        feedingTotal,
        volUnit,
        loading: tasksLoading || recordsLoading,
      }),
    [
      actionTasks.length,
      completedTasks.length,
      currentPhase.label,
      feedingRecords.length,
      feedingTotal,
      inventoryRecords.length,
      inventoryTotal,
      planType,
      postpartumDay,
      recordsLoading,
      skippedTasks.length,
      tasksLoading,
      volUnit,
    ],
  );
  const recordsByTaskId = useMemo(() => {
    const map = new Map<string, PumpRecord[]>();
    for (const task of actionTasks) {
      const completionKey = taskCompletionRecordKey(dateStr, task.id);
      const knownRef = taskCompletionRecordRefs[completionKey];
      const matched = records.filter((record) => {
        if (record.id === `${generatedRecordId(task.id)}-${dateStr}`) return true;
        if (knownRef?.pumpId != null && record.pumpId === knownRef.pumpId) return true;
        if (knownRef?.feedingId != null && record.feedingId === knownRef.feedingId) return true;
        if (!task.done || record.time !== task.time) return false;
        if (task.type === "pump") {
          return !isFeedingRecord(record) && (record.pumpSource === 2 || record.recordTitle === task.title);
        }
        if (task.type === "feed") {
          return isFeedingRecord(record) && (record.feedAction === 1 || record.recordTitle === task.title);
        }
        return record.recordTitle === task.title;
      });
      if (matched.length > 0) {
        map.set(task.id, matched.sort((a, b) => a.time.localeCompare(b.time)));
      }
    }
    return map;
  }, [actionTasks, dateStr, records, taskCompletionRecordRefs]);
  const attachedRecordIds = useMemo(() => {
    const ids = new Set<string>();
    for (const taskRecords of recordsByTaskId.values()) {
      taskRecords.forEach((record) => ids.add(record.id));
    }
    return ids;
  }, [recordsByTaskId]);
  const standaloneRecords = useMemo(
    () => records.filter((record) => !attachedRecordIds.has(record.id)),
    [attachedRecordIds, records],
  );
  const executionTimelineEntries = useMemo(() => {
    const taskEntries = actionTasks.map((task) => ({ kind: "task" as const, time: task.time, task }));
    const recordEntries = standaloneRecords.map((record) => ({ kind: "record" as const, time: record.time, record }));
    return [...taskEntries, ...recordEntries].sort((a, b) => {
      const byTime = a.time.localeCompare(b.time);
      if (byTime !== 0) return byTime;
      if (a.kind === b.kind) return 0;
      return a.kind === "task" ? -1 : 1;
    });
  }, [actionTasks, standaloneRecords]);

  const nowTime = formatClockTime(scheduleNow);
  const overdueMins = nextTask ? timeDiffInMinutes(nowTime, nextTask.time) : 0;
  const overdueLevel = useMemo(() => {
    if (!isSelectedToday || overdueMins <= 0) return "none";
    if (overdueMins <= 40) return "mild";
    if (overdueMins <= 90) return "medium";
    return "severe";
  }, [isSelectedToday, overdueMins]);
  const nextTaskCountdown = useMemo(() => {
    if (!isSelectedToday || !nextTask) return null;
    const target = taskTimeOnDate(selectedDate, nextTask.time);
    if (!target) return null;
    const diffMs = target.getTime() - scheduleNow.getTime();
    return {
      overdue: diffMs < 0,
      value: formatCountdownDuration(Math.abs(diffMs)),
    };
  }, [isSelectedToday, nextTask, scheduleNow, selectedDate]);
  const completionPct = actionTasks.length > 0 ? Math.round((completedTasks.length / actionTasks.length) * 100) : 0;

  const applyServerTaskList = useCallback(
    (taskList: PlanTaskItem[]) => {
      const mapped = (taskList || [])
        .map(mapApiTaskToScheduleTask)
        .sort((a, b) => a.time.localeCompare(b.time));
      setAllTasks((prev) => ({ ...prev, [dateStr]: mapped }));
    },
    [dateStr],
  );

  const refreshTodayRecords = useCallback(async () => {
    const [pumpData, feedingData] = await Promise.all([
      queryPumpMilkRecords({ user_id: DEFAULT_CHAT_USER_ID, timestamp: dateStr }),
      queryFeedingRecords({ user_id: DEFAULT_CHAT_USER_ID, timestamp: dateStr }),
    ]);
    if (pumpData.error !== 0 || feedingData.error !== 0) {
      throw new Error("刷新记录失败，请稍后重试");
    }
    const mergedToday = [
      ...pumpData.pump_milk_list.map((item) => mapPumpMilkListItemToRecord(item, dateStr)),
      ...feedingData.feed_list.map((item) => mapFeedingListItemToRecord(item, dateStr)),
    ]
      .map((record) => {
        const matchedRef = Object.values(taskCompletionRecordRefs).find(
          (ref) => (record.pumpId != null && ref.pumpId === record.pumpId) || (record.feedingId != null && ref.feedingId === record.feedingId),
        );
        return matchedRef?.taskTitle && !record.recordTitle ? { ...record, recordTitle: matchedRef.taskTitle } : record;
      })
      .sort((a, b) => a.time.localeCompare(b.time));
    setAllRecords((prev) => ({ ...prev, [dateStr]: mergedToday }));
  }, [dateStr, taskCompletionRecordRefs]);

  const reviseTaskByApi = useCallback(
    async (task: ScheduleTask, next: { taskTime?: string; taskContent?: string; taskDone?: "true" | "false" | "jump" }) => {
      if (!task.taskId) {
        setTasks((prev) =>
          prev
            .map((t) =>
              t.id === task.id
                ? {
                    ...t,
                    time: next.taskTime ?? t.time,
                    title: next.taskContent ?? t.title,
                    done: next.taskDone ? next.taskDone !== "false" : t.done,
                    adjusted: next.taskDone === "jump" ? skippedMarker : undefined,
                  }
                : t,
            )
            .sort((a, b) => a.time.localeCompare(b.time)),
        );
        return;
      }
      const resp = await revisePlanTask({
        user_id: DEFAULT_CHAT_USER_ID,
        task_id: task.taskId,
        timestamp: dateStr,
        task_time: next.taskTime ?? task.time,
        task_content: next.taskContent ?? task.title,
        task_done: next.taskDone ?? (task.adjusted === skippedMarker ? "jump" : task.done ? "true" : "false"),
      });
      if (resp.error !== 0) throw new Error("更新任务失败，请稍后重试");
      applyServerTaskList(resp.task_list);
    },
    [applyServerTaskList, dateStr, setTasks],
  );

  const saveEdit = useCallback(
    async (taskId: string) => {
      const nextTitle = editTitle.trim();
      if (!nextTitle || !editTime) {
        setEditingTaskId(null);
        return;
      }
      const task = tasks.find((t) => t.id === taskId);
      if (!task) {
        setEditingTaskId(null);
        return;
      }
      try {
        await reviseTaskByApi(task, { taskTime: editTime, taskContent: nextTitle });
        setEditingTaskId(null);
      } catch (e) {
        alert(e instanceof Error ? e.message : "更新任务失败，请稍后重试");
        setEditTime(task.time);
        setEditTitle(task.title);
        setEditingTaskId(null);
      }
    },
    [editTitle, editTime, reviseTaskByApi, tasks],
  );

  const handleCurrentTaskComplete = useCallback(
    async (task: ScheduleTask) => {
      if (task.type === "pump") {
        setPendingCompleteTask(task);
        setPumpEntryOpen(true);
        return;
      }
      if (task.type === "feed") {
        setPendingCompleteTask(task);
        setFeedingEntryOpen(true);
        return;
      }
      await reviseTaskByApi(task, { taskDone: "true" });
    },
    [reviseTaskByApi],
  );

  const clearTaskCompletionArtifacts = useCallback(
    async (task: ScheduleTask) => {
      const completionKey = taskCompletionRecordKey(dateStr, task.id);
      const knownRef = taskCompletionRecordRefs[completionKey];

      if (task.type === "pump") {
        let targetPumpId = knownRef?.pumpId;
        if (targetPumpId == null) {
          const pumpData = await queryPumpMilkRecords({ user_id: DEFAULT_CHAT_USER_ID, timestamp: dateStr });
          if (pumpData.error !== 0) throw new Error("查询吸奶记录失败，请稍后重试");
          const matched = pumpData.pump_milk_list
            .filter(
              (item) =>
                item.pump_source === 2 &&
                normalizePumpTimeForDisplay(item.pump_time) === task.time,
            )
            .sort((a, b) => b.pump_id - a.pump_id);
          targetPumpId = matched[0]?.pump_id;
        }
        if (targetPumpId != null) {
          const del = await deletePumpMilkRecord({
            user_id: DEFAULT_CHAT_USER_ID,
            pump_id: targetPumpId,
          });
          if (del.error !== 0) throw new Error("删除吸奶记录失败，请稍后重试");
        }
      } else if (task.type === "feed") {
        let targetFeedingId = knownRef?.feedingId;
        if (targetFeedingId == null) {
          const feedingData = await queryFeedingRecords({ user_id: DEFAULT_CHAT_USER_ID, timestamp: dateStr });
          if (feedingData.error !== 0) throw new Error("查询喂养记录失败，请稍后重试");
          const matched = feedingData.feed_list
            .filter((item) => normalizePumpTimeForDisplay(item.feed_time) === task.time)
            .sort((a, b) => b.feeding_id - a.feeding_id);
          targetFeedingId = matched[0]?.feeding_id;
        }
        if (targetFeedingId != null) {
          const del = await deleteFeedingRecord({
            user_id: DEFAULT_CHAT_USER_ID,
            feeding_id: targetFeedingId,
          });
          if (del.error !== 0) throw new Error("删除喂养记录失败，请稍后重试");
        }
      }

      await refreshTodayRecords();
      setTaskCompletionRecordRefs((prev) => {
        const next = { ...prev };
        delete next[completionKey];
        return next;
      });
      setRecords((prev) => prev.filter((r) => r.id !== generatedRecordId(task.id) + "-" + dateStr));
    },
    [dateStr, refreshTodayRecords, setRecords, taskCompletionRecordRefs],
  );

  const clearTaskCompletionAndResetTask = useCallback(
    async (task: ScheduleTask) => {
      await clearTaskCompletionArtifacts(task);
      await reviseTaskByApi(task, { taskDone: "false" });
    },
    [clearTaskCompletionArtifacts, reviseTaskByApi],
  );

  const handleToggleTaskComplete = useCallback(
    async (task: ScheduleTask) => {
      try {
        if (task.done || task.adjusted === skippedMarker) {
          if (task.adjusted === skippedMarker) {
            await reviseTaskByApi(task, { taskDone: "false" });
            return;
          }
          await clearTaskCompletionAndResetTask(task);
        } else {
          await handleCurrentTaskComplete(task);
        }
      } catch (e) {
        alert(e instanceof Error ? e.message : "更新任务失败");
      }
    },
    [clearTaskCompletionAndResetTask, handleCurrentTaskComplete, reviseTaskByApi],
  );

  const handleDelay = useCallback(
    async (task: ScheduleTask) => {
      try {
        await reviseTaskByApi(task, { taskTime: addMinutes(task.time, 30), taskDone: "false" });
      } catch (e) {
        alert(e instanceof Error ? e.message : "顺延失败");
      }
    },
    [reviseTaskByApi],
  );

  const handleSkip = useCallback(
    async (task: ScheduleTask) => {
      try {
        await reviseTaskByApi(task, { taskDone: "jump" });
      } catch (e) {
        alert(e instanceof Error ? e.message : "跳过失败");
      }
    },
    [reviseTaskByApi],
  );

  const handleDeleteTask = useCallback(
    async (task: ScheduleTask) => {
      if (deletingTaskIds[task.id]) return;
      setDeletingTaskIds((prev) => ({ ...prev, [task.id]: true }));
      try {
        if (task.done && !isSkipped(task)) {
          await clearTaskCompletionArtifacts(task);
        }
        if (task.taskId != null) {
          const resp = await deletePlanTask({
            user_id: DEFAULT_CHAT_USER_ID,
            timestamp: dateStr,
            task_id: task.taskId,
          });
          if (resp.error !== 0) throw new Error("删除任务失败，请稍后重试");
          applyServerTaskList(resp.task_list);
          return;
        }
        setTasks((prev) => prev.filter((item) => item.id !== task.id));
      } finally {
        setDeletingTaskIds((prev) => {
          const next = { ...prev };
          delete next[task.id];
          return next;
        });
      }
    },
    [applyServerTaskList, clearTaskCompletionArtifacts, dateStr, deletingTaskIds, setTasks],
  );

  const handleAddTaskSubmit = useCallback(
    async (newTasksData: Array<{ type: "pump" | "feed" | "custom"; title: string; time: string }>) => {
      const bodyTaskList = newTasksData.map((t) => ({
        task_time: t.time,
        task_content: t.title,
        task_type: t.type === "pump" ? 0 : t.type === "feed" ? 1 : 2,
        task_source: "手动",
      }));
      const resp = await addPlanTasks({
        user_id: DEFAULT_CHAT_USER_ID,
        timestamp: dateStr,
        task_list: bodyTaskList,
      });
      if (resp.error !== 0) throw new Error("添加任务失败，请稍后重试");
      applyServerTaskList(resp.task_list);
    },
    [applyServerTaskList, dateStr],
  );

  const handleRecordSubmit = useCallback(
    async (record: PumpRecord) => {
      const taskTitle = pendingCompleteTask?.title;
      const merged: PumpRecord = { ...record, date: dateStr, recordTitle: taskTitle || record.recordTitle };

      const isTaskPumpComplete =
        pendingCompleteTask &&
        pendingCompleteTask.type === "pump" &&
        merged.category === "inventory" &&
        merged.subLabel === "补录";
      const isTaskFeedComplete = pendingCompleteTask && pendingCompleteTask.type === "feed" && merged.category === "feeding";

      if (isTaskPumpComplete) {
        const data = await uploadPumpMilkRecord({
          user_id: DEFAULT_CHAT_USER_ID,
          pump_type: 1,
          pump_source: 2,
          pump_time: merged.time,
          pump_title: merged.recordTitle,
          pump_milk_volum: merged.totalMl,
        });
        if (data.error !== 0) throw new Error("任务吸奶上报失败，请稍后重试");
        if (data.pump_id != null && pendingCompleteTask) {
          const completionKey = taskCompletionRecordKey(dateStr, pendingCompleteTask.id);
          setTaskCompletionRecordRefs((prev) => ({
            ...prev,
            [completionKey]: { ...(prev[completionKey] ?? {}), pumpId: data.pump_id, taskTitle: merged.recordTitle },
          }));
        }
        await reviseTaskByApi(pendingCompleteTask, { taskDone: "true" });
        await refreshTodayRecords();
        setPendingCompleteTask(null);
        return;
      }

      if (isTaskFeedComplete) {
        const feedResp = await addFeedingRecord(buildFeedingUploadBody(merged, 1));
        if (feedResp.error !== 0) throw new Error("任务喂养上报失败，请稍后重试");
        if (feedResp.feeding_id != null && pendingCompleteTask) {
          const completionKey = taskCompletionRecordKey(dateStr, pendingCompleteTask.id);
          setTaskCompletionRecordRefs((prev) => ({
            ...prev,
            [completionKey]: { ...(prev[completionKey] ?? {}), feedingId: feedResp.feeding_id, taskTitle: merged.recordTitle },
          }));
        }
        await reviseTaskByApi(pendingCompleteTask, { taskDone: "true" });
        await refreshTodayRecords();
        setPendingCompleteTask(null);
        return;
      }

      const shouldUploadPumpMilk = isSelectedToday && merged.category === "inventory" && merged.subLabel === "补录";
      const shouldUploadManualFeeding = isSelectedToday && merged.category === "feeding";
      if (shouldUploadPumpMilk) {
        const data = await uploadPumpMilkRecord({
          user_id: DEFAULT_CHAT_USER_ID,
          pump_type: 1,
          pump_source: 1,
          pump_time: merged.time,
          pump_title: merged.recordTitle,
          pump_milk_volum: merged.totalMl,
        });
        if (data.error !== 0) throw new Error("吸奶补录上报失败，请稍后重试");
        await refreshTodayRecords();
      } else if (shouldUploadManualFeeding) {
        const feedResp = await addFeedingRecord(buildFeedingUploadBody(merged, 0));
        if (feedResp.error !== 0) throw new Error("喂养记录上报失败，请稍后重试");
        await refreshTodayRecords();
      } else {
        setRecords((prev) =>
          [...prev.filter((item) => item.id !== merged.id), merged].sort((a, b) => a.time.localeCompare(b.time)),
        );
      }
    },
    [dateStr, isSelectedToday, pendingCompleteTask, refreshTodayRecords, reviseTaskByApi, setRecords],
  );

  const handleDeleteRecord = useCallback(
    async (record: PumpRecord) => {
      if (deletingRecordIds[record.id]) return;
      setDeletingRecordIds((prev) => ({ ...prev, [record.id]: true }));
      try {
        if (isFeedingRecord(record)) {
          if (record.feedingId == null) {
            throw new Error("未找到喂养记录ID，无法删除");
          }
          const del = await deleteFeedingRecord({
            user_id: DEFAULT_CHAT_USER_ID,
            feeding_id: record.feedingId,
          });
          if (del.error !== 0) {
            alert("删除喂养记录失败，请稍后重试");
            return;
          }
          await refreshTodayRecords();
          return;
        }

        if (record.pumpId != null) {
          const del = await deletePumpMilkRecord({
            user_id: DEFAULT_CHAT_USER_ID,
            pump_id: record.pumpId,
          });
          if (del.error !== 0) {
            alert("删除吸奶记录失败，请稍后重试");
            return;
          }
          await refreshTodayRecords();
          return;
        }

        // 本地临时记录（未上云）保持仅本地删除
        setRecords((prev) => prev.filter((r) => r.id !== record.id));
      } catch (e) {
        alert(e instanceof Error ? e.message : "删除失败，请稍后重试");
        return;
      } finally {
        setDeletingRecordIds((prev) => {
          const next = { ...prev };
          delete next[record.id];
          return next;
        });
      }
    },
    [deletingRecordIds, refreshTodayRecords, setRecords],
  );

  return (
    <div className="contents">
      <div className="flex flex-col min-h-0 bg-background w-full" style={{ height: "100vh", maxHeight: "100vh" }}>
        <TabPageTopReserve />
      <div className="px-4 pt-3 pb-1 flex-shrink-0">
        <p className="text-[13px] font-bold text-muted-foreground">
          {format(displayMonthDate, "yyyy年M月")}
        </p>
      </div>

      {/* Calendar Strip：周切换 + 7 日条 */}
      <div className="px-4 pb-2 flex-shrink-0 relative">
        <div className="flex justify-between items-center bg-card rounded-xl p-1 border border-border/50 shadow-sm">
          <button
            type="button"
            onClick={() => setWeekOffset((w) => w - 1)}
            className="p-1.5 rounded-lg text-muted-foreground hover:bg-secondary/80 active:scale-95 transition-all flex items-center justify-center shrink-0"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
          <div className="flex justify-around items-center flex-1 px-1">
            {Array.from({ length: 7 }, (_, i) => addDays(todayDate, weekOffset * 7 + i - 3)).map((date) => {
              const isSelected = isSameDay(date, selectedDate);
              const isToday = isSameDay(date, todayDate);
              const dateKey = format(date, "yyyy-MM-dd");
              const hasMilkPlanHighlight = milkPlanHighlightDates.includes(dateKey);
              const dayLabel = ["日", "一", "二", "三", "四", "五", "六"][date.getDay()];
              return (
                <button
                  key={date.toString()}
                  type="button"
                  onClick={() => setSelectedDate(date)}
                  className={cn(
                    "relative flex flex-col items-center justify-center w-[36px] h-[44px] rounded-[12px] transition-all duration-300",
                    isSelected
                      ? "bg-primary text-primary-foreground shadow-md shadow-primary/30 scale-105"
                      : hasMilkPlanHighlight
                        ? "bg-[#eef8f4] text-[#477a68] ring-1 ring-[#79b8a4]/45 shadow-[0_6px_14px_rgba(78,135,112,0.14)]"
                        : "hover:bg-secondary/80 text-muted-foreground active:scale-95"
                  )}
                >
                  {hasMilkPlanHighlight && !isSelected ? (
                    <span className="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-[#79b8a4] shadow-[0_0_0_4px_rgba(121,184,164,0.18)]">
                      <span className="absolute inset-0 rounded-full bg-[#79b8a4] opacity-45 animate-ping" />
                    </span>
                  ) : null}
                  <span className={cn("text-[9px] font-extrabold mb-0.5 transition-colors", isSelected ? "text-primary-foreground/90" : "text-muted-foreground/60")}>
                    {isToday ? "今" : dayLabel}
                  </span>
                  <span className={cn("text-[13px] font-black transition-colors", isSelected ? "text-primary-foreground" : isToday ? "text-primary" : hasMilkPlanHighlight ? "text-[#477a68]" : "text-foreground")}>
                    {format(date, "d")}
                  </span>
                </button>
              );
            })}
          </div>
          <button
            type="button"
            onClick={() => setWeekOffset((w) => w + 1)}
            className="p-1.5 rounded-lg text-muted-foreground hover:bg-secondary/80 active:scale-95 transition-all flex items-center justify-center shrink-0"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
        <AnimatePresence>
          {showBackToTodayFab && (
            <motion.button
              type="button"
              initial={{ opacity: 0, y: 10, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 10, scale: 0.96 }}
              transition={{ duration: 0.2 }}
              onClick={() => {
                setSelectedDate(todayDate);
                setWeekOffset(0);
              }}
              className="absolute right-5 -bottom-8 z-40 h-9 px-3 rounded-full bg-primary text-primary-foreground text-[12px] font-extrabold shadow-lg shadow-primary/30 active:scale-95 transition-transform"
            >
              今天
            </motion.button>
          )}
        </AnimatePresence>
      </div>

      <TabPageScrollRegion>
        {/* Context Header */}
        <div className="mx-4 mt-2 mb-5 p-4 rounded-[24px] border border-border/40 bg-card/40 shadow-sm relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-b from-primary/5 to-transparent pointer-events-none" />
          {!isFutureWithoutPlan && (
            <button
              type="button"
              aria-label={reminderOn ? "关闭计划提醒" : "开启计划提醒"}
              onClick={handleReminderToggleClick}
              className="absolute right-3 top-3 z-20 h-9 w-9 rounded-full bg-background/90 text-foreground shadow-sm border border-border/50 flex items-center justify-center transition-all active:scale-95"
            >
              {reminderOn ? <Bell className="h-4 w-4" /> : <BellOff className="h-4 w-4 text-muted-foreground" />}
            </button>
          )}
          <div className="relative z-10">
            <div className="pr-10">
              <h2 className="text-[16px] font-black text-foreground tracking-tight">
                {isFutureWithoutPlan
                  ? `${format(selectedDate, "M月d日")} 待规划`
                  : isSelectedToday
                    ? mapTodayPlanTypeToHeaderLabel(planType)
                    : isSelectedPast
                    ? mapPlanTypeToLabel(planType)
                    : `${format(selectedDate, "M月d日")} ${mapPlanTypeToLabel(planType)}`}
              </h2>
              {!isFutureWithoutPlan && (
                <p className="text-[11px] font-bold text-muted-foreground mt-1">
                  {formatPostpartumPhaseLabel(postpartumDay, currentPhase.label)}
                </p>
              )}
            </div>
            
            {!isFutureWithoutPlan && (
              <div className="mt-5">
                <div className="mb-2 flex items-center justify-between">
                  <p className="text-[12px] font-extrabold text-foreground/70">今日任务</p>
                  <span className="text-[13px] font-black text-foreground">{completedTasks.length}<span className="text-muted-foreground font-medium mx-0.5">/</span>{actionTasks.length}</span>
                </div>
                <div className="h-2.5 bg-secondary/70 rounded-full overflow-hidden shadow-inner">
                  <div className="h-full bg-gradient-to-r from-primary to-primary/80 rounded-full transition-all duration-500 shadow-sm" style={{ width: `${completionPct}%` }} />
                </div>
              </div>
            )}
          </div>
        </div>

        {isSelectedToday && !isFutureWithoutPlan && (
          <section className="mx-4 mb-5 rounded-[24px] border border-primary/15 bg-card/70 p-3.5 shadow-sm">
            <div className="flex items-start gap-3">
              <img
                key={`schedule-agent-avatar-${location.key}`}
                src={momcozyAgentAvatar}
                alt=""
                aria-hidden="true"
                className="schedule-agent-avatar-attention h-9 w-9 shrink-0 rounded-full object-cover shadow-sm"
              />
              <div className="min-w-0 flex-1">
                <p className="text-[13px] font-semibold leading-relaxed text-foreground">
                  已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我
                </p>
                <div className="mt-3 flex gap-2">
                  <button
                    type="button"
                    onClick={handleReminderToggleClick}
                    className="inline-flex h-8 items-center gap-1.5 rounded-full border border-border bg-background px-3 text-[12px] font-bold text-foreground shadow-sm active:scale-95"
                  >
                    {reminderOn ? <Bell className="h-3.5 w-3.5" /> : <BellOff className="h-3.5 w-3.5 text-muted-foreground" />}
                    提醒开关
                  </button>
                  <button
                    type="button"
                    onClick={openScheduleConversation}
                    className="inline-flex h-8 items-center gap-1.5 rounded-full bg-primary px-3 text-[12px] font-extrabold text-primary-foreground shadow-sm active:scale-95"
                  >
                    <MessageCircle className="h-3.5 w-3.5" />
                    对话
                  </button>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Hero: Next Action or Daily Summary */}
        {isSelectedToday ? (
          nextTask ? (
            <section className={cn(
              "mx-4 mb-5 rounded-[24px] p-4 border transition-all shadow-md",
              overdueLevel === "severe" ? "bg-gradient-to-br from-secondary/50 to-secondary/30 border-border/60" : "bg-gradient-to-br from-primary/15 via-primary/5 to-background border-primary/30 shadow-primary/10"
            )}>
              <div className="flex items-center gap-2 mb-3.5">
                <span className="text-[11px] font-extrabold text-primary tracking-wide">
                  待执行任务
                </span>
              </div>
              
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="text-[32px] leading-none font-black tracking-tighter text-foreground">
                    {nextTask.time}
                  </div>
                  <div className="text-[15px] font-extrabold mt-1.5 flex items-center gap-1.5 text-foreground/90">
                    <span className="text-base leading-none">{taskIcon[nextTask.type]}</span> 
                    <span className="truncate">{nextTask.title}</span>
                  </div>
                </div>
                {nextTaskCountdown ? (
                  <div className="shrink-0">
                    <div
                      className={cn(
                        "min-w-[86px] rounded-2xl border px-3 py-2",
                        nextTaskCountdown.overdue
                          ? "border-[hsl(0_72%_72%)] bg-[hsl(0_86%_95%)] text-[hsl(0_72%_48%)]"
                          : "border-[hsl(34_48%_78%)] bg-[hsl(34_78%_94%)] text-[hsl(31_53%_35%)]",
                      )}
                    >
                      <p className="text-[10px] font-extrabold leading-none">
                        {nextTaskCountdown.overdue ? "已超时" : "距离开始还剩"}
                      </p>
                      <p className="mt-1 text-[18px] font-black leading-none tabular-nums">
                        {nextTaskCountdown.value}
                      </p>
                    </div>
                  </div>
                ) : null}
              </div>

              <div className="mt-4 space-y-2">
                <>
                  <button 
                    onClick={() => void handleCurrentTaskComplete(nextTask)}
                    className="w-full h-[44px] bg-primary text-primary-foreground rounded-xl text-[14px] font-extrabold shadow-md shadow-primary/25 active:scale-[0.98] transition-all hover:bg-primary/90 hover:shadow-primary/30"
                  >
                    手动完成并记录数据
                  </button>
                  <div className="flex gap-2">
                    <button 
                      onClick={() => void handleDelay(nextTask)}
                      className="flex-1 h-10 bg-card border border-border text-foreground rounded-lg text-[12px] font-bold flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all shadow-sm hover:bg-secondary/50"
                    >
                      <Clock className="w-3.5 h-3.5 text-muted-foreground" /> 顺延半小时
                    </button>
                    <button 
                      onClick={() => void handleSkip(nextTask)}
                      className="flex-1 h-10 bg-card border border-border text-muted-foreground rounded-lg text-[12px] font-bold active:scale-[0.98] transition-all shadow-sm hover:bg-secondary/50"
                    >
                      跳过这次任务
                    </button>
                  </div>
                </>
              </div>
            </section>
          ) : !hasActionTasks ? (
            <section className="mx-4 mb-8 bg-secondary/30 rounded-[28px] p-6 border border-border/40 text-center">
              <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-3">
                <Clock className="w-8 h-8 text-primary" />
              </div>
              <h3 className="text-lg font-bold text-foreground">今天还没有计划任务</h3>
              <p className="text-[13px] text-muted-foreground mt-1">可以先从对话里生成计划并同步到日历，或手动添加任务。</p>
            </section>
          ) : (
            <section className="mx-4 mb-8 bg-secondary/30 rounded-[28px] p-6 border border-border/40 text-center">
              <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-3">
                <CheckCircle2 className="w-8 h-8 text-primary" />
              </div>
              <h3 className="text-lg font-bold text-foreground">{skippedTasks.length > 0 ? "今天的计划尚未全部完成哦" : "今天的计划已全部完成"}</h3>
              <p className="text-[13px] text-muted-foreground mt-1">
                {skippedTasks.length > 0 ? `顺利完成${completedTasks.length}个任务，有${skippedTasks.length}个任务被跳过` : "任务很棒地完成了，继续保持节奏就好。"}
              </p>
            </section>
          )
        ) : isSelectedPast ? (
          <section className="mx-4 mb-8 bg-secondary/30 rounded-[28px] p-6 border border-border/40 text-center">
            <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-3">
              <CheckCircle2 className="w-8 h-8 text-primary" />
            </div>
            <h3 className="text-lg font-bold text-foreground">{hasActionTasks ? "这天的计划已结束" : "这天没有计划任务"}</h3>
            <p className="text-[13px] text-muted-foreground mt-1">
              {hasActionTasks
                ? `共完成 ${completedTasks.length} 项任务，母乳产出 ${formatVol(inventoryTotal, volUnit)}${unitLabel(volUnit)}`
                : "没有看到当天的计划任务。"}
            </p>
          </section>
        ) : (
          <section className="mx-4 mb-8 bg-secondary/30 rounded-[28px] p-6 border border-border/40 text-center">
            <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-3">
              <Clock className="w-8 h-8 text-primary" />
            </div>
            <h3 className="text-lg font-bold text-foreground">{hasActionTasks ? "未来的计划" : "这天还没有计划"}</h3>
            {hasActionTasks && (
              <p className="text-[13px] text-muted-foreground mt-1">系统已为你提前规划了当天的吸乳和喂养日程</p>
            )}
          </section>
        )}

        {/* Timeline: Today's Tasks */}
        <section className="mx-4 mb-6">
          <div className="mb-4">
            <div className="flex items-center justify-between gap-3">
              <div className="flex min-w-0 items-center gap-1.5">
                <h3 className="text-[16px] font-black text-foreground tracking-tight">{isSelectedToday ? "今日任务" : "执行记录"}</h3>
                {isSelectedToday && (
                  <button
                    type="button"
                    aria-label="今日任务说明"
                    onClick={() => setTodayTaskInfoOpen(true)}
                    className="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-white/70 text-muted-foreground shadow-sm active:scale-95"
                  >
                    <HelpCircle className="h-3.5 w-3.5" />
                  </button>
                )}
              </div>
              <div className="flex items-center gap-2">
                {isSelectedToday && (
                  <>
                    <button
                      onClick={() => addTaskDialogRef.current?.openUploadPicker()}
                      disabled={scheduleAdjusting}
                      className="text-[12px] font-bold text-foreground px-3.5 py-1.5 bg-card border border-border hover:bg-secondary/50 rounded-full flex items-center gap-1 transition-colors shadow-sm active:scale-95 disabled:opacity-60 disabled:active:scale-100"
                    >
                      {scheduleAdjusting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <ImageIcon className="w-3.5 h-3.5" />}
                      调整日程
                    </button>
                    <button onClick={() => setAddTaskOpen(true)} className="text-[12px] font-bold text-foreground px-3.5 py-1.5 bg-card border border-border hover:bg-secondary/50 rounded-full flex items-center gap-1 transition-colors shadow-sm active:scale-95">
                      <Plus className="w-3.5 h-3.5" /> 添加任务
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
          
          <div className="space-y-0 relative">
            {tasksLoading && (
              <div className="py-2 text-[12px] text-muted-foreground">任务加载中…</div>
            )}
            {recordsLoading && (
              <div className="py-2 text-[12px] text-muted-foreground">记录加载中…</div>
            )}
            {!tasksLoading && !recordsLoading && executionTimelineEntries.length === 0 && (
              <div className="py-5 text-center text-[12px] font-medium text-muted-foreground">当天暂无执行内容</div>
            )}

            {executionTimelineEntries.map((entry) => {
              if (entry.kind === "record") {
                const record = entry.record;
                const deleting = Boolean(deletingRecordIds[record.id]);
                const isSupplementRecord = record.subLabel === "补录";
                return (
	                  <div key={`record-${record.id}`} className="min-w-0 py-0.5 bg-background">
                    <div className="min-w-0 pb-1">
                      <div className={cn("rounded-[16px] px-3 py-2.5 border shadow-sm min-w-0 relative", completedSourceCardClass, isSupplementRecord ? "overflow-visible" : "overflow-hidden")}>
                        {isSupplementRecord && (
                          <span className={cn(manualTaskBadgeClass, "pointer-events-none absolute left-0 -top-1 z-20")} title="手动添加">
                            手动添加
                          </span>
                        )}
                        <div className="flex items-center justify-between gap-2 min-w-0">
                          <div className="flex items-center gap-2 min-w-0 flex-1">
                            <span className="text-[13px] font-mono font-bold text-primary/70 shrink-0">{record.time}</span>
                            <span className="text-[15px] tracking-wide min-w-0 truncate text-foreground/80 font-bold" title={resolveRecordDisplayTitle(record)}>
                              {truncateTaskDisplay(resolveRecordDisplayTitle(record))}
                            </span>
	                          </div>
		                          <div className="flex items-center justify-end gap-1.5 shrink-0">
			                            <span className={recordValueBadgeClass}>
			                              {formatRecordVolumeDisplay(record, volUnit)}
			                            </span>
                                <span className={completedTaskBadgeClass}>
                                  {record.time}
                                </span>
                                <span className={completedTaskBadgeClass}>
                                  已完成
                                </span>
		                            <button
		                              type="button"
                              onClick={() => void handleDeleteRecord(record)}
                              disabled={deleting}
                              className={cn(
                                "w-7 h-7 flex items-center justify-center rounded-full transition-colors shrink-0",
                                deleting
                                  ? "text-muted-foreground/50 bg-secondary/50 cursor-not-allowed"
                                  : "text-muted-foreground hover:text-destructive hover:bg-destructive/10",
                              )}
                            >
                              {deleting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Trash2 className="w-3.5 h-3.5" />}
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              }

              const task = entry.task;
              const isNext = isSelectedToday && task.id === nextTask?.id;
              const isCompleted = task.done;
              const skipped = isSkipped(task);
              const matchedRecords = recordsByTaskId.get(task.id) ?? [];
              const matchedRecordSummary = matchedRecords.length > 0
                ? matchedRecords.map((record) => formatRecordVolumeDisplay(record, volUnit)).join(" / ")
                : null;
              const matchedRecordCompletionSummary = matchedRecords.length > 0
                ? matchedRecords.map((record) => record.time).join(" / ")
                : null;
              const deleting = Boolean(deletingTaskIds[task.id]);
              const isSmartTask = task.source === "mai";
              const taskPlanBadgeLabel = resolveSmartTaskPlanBadgeLabel(task, planType);
              const taskCornerBadge = taskPlanBadgeLabel
                ? { label: taskPlanBadgeLabel, className: taskPlanBadgeClass }
                : task.source === "manual"
                  ? { label: "手动添加", className: manualTaskBadgeClass }
                  : null;
              
              return (
                <div key={task.id} className="min-w-0 py-0.5 bg-background">
                  <div className="min-w-0 pb-1">
                    <div className={cn(
                      "rounded-[16px] px-3 py-2.5 border transition-all relative min-w-0",
                      editingTaskId === task.id ? "overflow-x-clip overflow-y-visible" : taskCornerBadge ? "overflow-visible" : "overflow-hidden",
                      isNext ? (isSmartTask ? smartNextCardClass : manualNextCardClass) : 
                      skipped ? skippedSourceCardClass : 
                      isCompleted ? completedSourceCardClass : 
                      cn(isSmartTask ? smartSourceCardClass : manualSourceCardClass, "shadow-sm"),
                      editingTaskId === task.id && "ring-2 ring-primary/30 border-primary/50 bg-card opacity-100 shadow-lg !grayscale-0"
                    )}>
                      {taskCornerBadge && editingTaskId !== task.id && (
                        <span className={cn(taskCornerBadge.className, "pointer-events-none absolute left-0 -top-1 z-20")} title={taskCornerBadge.label}>
                          {taskCornerBadge.label}
                        </span>
                      )}
                      <div className="relative z-10 min-h-[24px] min-w-0 flex items-center justify-between">
                        {editingTaskId === task.id ? (
                          <div 
                            className="grid w-full min-w-0 grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-2"
                            onBlur={(e) => {
                              if (editTimePickerOpen) return;
                              if (!e.currentTarget.contains(e.relatedTarget)) {
                                void saveEdit(task.id);
                              }
                            }}
                          >
                            <button
                              type="button"
                              onMouseDown={(e) => {
                                // Prevent blur auto-save when opening time picker.
                                e.preventDefault();
                              }}
                              onPointerDown={(e) => {
                                // Mobile pointer events may fire before click; keep edit mode active.
                                e.preventDefault();
                              }}
                              onClick={() => setEditTimePickerOpen(true)}
                              className="box-border h-7 w-[5.75rem] max-w-full shrink-0 rounded-md border border-primary/30 bg-background px-1.5 text-left text-[12px] font-mono font-bold text-foreground outline-none transition-all focus:border-primary focus:ring-1 focus:ring-primary/20 sm:w-[6.25rem] sm:px-2 sm:text-[13px]"
                              autoFocus
                            >
                              {editTime}
                            </button>
                            <div className="flex h-7 min-w-0 items-center rounded-md border border-primary/30 bg-background px-2 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary/20">
                              <span className="mr-1.5 shrink-0 text-[14px]">{taskIcon[task.type]}</span>
                              <input 
                                ref={editTitleInputRef}
                                type="text" 
                                value={editTitle} 
                                onChange={e => setEditTitle(e.target.value)}
                                className="h-full min-w-0 w-full flex-1 bg-transparent text-[13px] font-bold text-foreground outline-none"
                                onKeyDown={(e) => {
                                  if (e.key === 'Enter') void saveEdit(task.id);
                                }}
                              />
                            </div>
                            <button 
                              type="button"
                              onMouseDown={(e) => {
                                e.preventDefault();
                                e.stopPropagation();
                                void handleDeleteTask(task).catch((err) => {
                                  alert(err instanceof Error ? err.message : "删除任务失败，请稍后重试");
                                });
                              }}
                              disabled={deleting}
                              className={cn(
                                "flex h-7 w-7 shrink-0 items-center justify-center rounded-md transition-colors",
                                deleting
                                  ? "bg-secondary/50 text-muted-foreground/50 cursor-not-allowed"
                                  : "bg-destructive/10 text-destructive active:bg-destructive/20",
                              )}
                            >
                              {deleting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Trash2 className="w-3.5 h-3.5" />}
                            </button>
                          </div>
                        ) : (
                          <div className="flex items-center justify-between gap-2 w-full min-w-0">
                            <div 
                              className={cn(
                                "flex items-center gap-2 min-w-0 flex-1", 
                                !isCompleted && !skipped && isSelectedToday && "cursor-pointer hover:opacity-80 transition-opacity"
                              )}
                              onClick={() => startEdit(task)}
                            >
                              <span className={cn("text-[13px] font-mono font-bold shrink-0", skipped ? "text-muted-foreground/80 line-through" : isCompleted ? "text-primary/70" : "text-muted-foreground/80")}>{task.time}</span>
                              <span className={cn("text-[15px] tracking-wide min-w-0 truncate", skipped ? "text-muted-foreground line-through font-bold" : isCompleted ? "text-foreground/80 font-bold" : "text-foreground/90 font-extrabold")} title={task.title}>
                                {truncateTaskDisplay(task.title)}
                              </span>
                            </div>
                            <div className="flex min-w-0 items-center justify-end gap-1.5">
                              {!editingTaskId && (
                                <div
                                  className="flex min-w-0 items-center justify-end gap-1"
                                  onClick={(e) => e.stopPropagation()}
                                  onPointerDown={(e) => e.stopPropagation()}
                                >
	                                  {matchedRecordSummary && !skipped && (
                                    <span className={recordValueBadgeClass}>
                                      <span className="min-w-0 truncate">{matchedRecordSummary}</span>
                                    </span>
                                  )}
                                  {matchedRecordCompletionSummary && !skipped && (
                                    <span className={recordCompletionTimeBadgeClass}>
                                      {matchedRecordCompletionSummary}
                                    </span>
                                  )}
                                  {isCompleted && !skipped && <span className={completedTaskBadgeClass}>已完成</span>}
                                  {skipped && <span className={skippedTaskBadgeClass}>已跳过</span>}
			                                  {task.adjusted && !skipped && <Badge variant="outline" className="bg-background text-[10px] font-medium border-border/50 text-muted-foreground px-1.5 py-0 h-5 max-w-[7rem] truncate">{task.adjusted}</Badge>}
	                                </div>
	                              )}
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    void handleDeleteTask(task).catch((err) => {
                                      alert(err instanceof Error ? err.message : "删除任务失败，请稍后重试");
                                    });
                                  }}
                                  onPointerDown={(e) => e.stopPropagation()}
                                  disabled={deleting}
                                  className={cn(
                                    "w-7 h-7 flex items-center justify-center rounded-full transition-colors shrink-0",
                                    deleting
                                      ? "text-muted-foreground/50 bg-secondary/50 cursor-not-allowed"
                                      : "text-muted-foreground hover:text-destructive hover:bg-destructive/10",
                                  )}
                                >
                                  {deleting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Trash2 className="w-3.5 h-3.5" />}
                                </button>
	                            </div>
	                          </div>
	                        )}
	                      </div>
	                    </div>
	                  </div>
                </div>
              );
            })}
          </div>
          {isSelectedToday && (
            <div className="mt-3 grid grid-cols-2 gap-2.5">
              <button onClick={() => setPumpEntryOpen(true)} className="h-[40px] bg-white text-foreground rounded-[14px] text-[12px] font-bold flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform hover:bg-white/90">
                <Plus className="w-3.5 h-3.5" /> 吸奶补录
              </button>
              <button onClick={() => setFeedingEntryOpen(true)} className="h-[40px] bg-white text-foreground rounded-[14px] text-[12px] font-bold flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform hover:bg-white/90">
                <Plus className="w-3.5 h-3.5" /> 喂养记录
              </button>
            </div>
          )}
        </section>

      </TabPageScrollRegion>
      <TabPageEmbeddedNav />
      </div>
      <AnimatePresence>
        {todayTaskInfoOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/35 backdrop-blur-sm"
              onClick={() => setTodayTaskInfoOpen(false)}
            />
            <motion.section
              role="dialog"
              aria-modal="true"
              aria-label="今日任务说明"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.96 }}
              transition={{ duration: 0.18, ease: "easeOut" }}
              className="pointer-events-none fixed inset-0 z-[51] flex items-center justify-center px-6"
            >
              <div className="pointer-events-auto w-full max-w-[420px] rounded-3xl border border-white/70 bg-card px-5 py-4 shadow-2xl">
                <div className="mb-3 flex justify-end">
                  <button type="button" onClick={() => setTodayTaskInfoOpen(false)} className="rounded-full p-2 text-muted-foreground active:bg-muted">
                    <X className="h-4 w-4" />
                  </button>
                </div>
                <p className="whitespace-pre-line rounded-[22px] bg-muted/45 px-4 py-3.5 text-sm font-semibold leading-relaxed text-foreground">
                  {todayTaskPlanExplanation}
                </p>
              </div>
            </motion.section>
          </>
        )}
      </AnimatePresence>
      <ReminderAlert
        open={reminderAlertOpen}
        onConfirm={() => {
          void persistSystemReminderOn(false);
          setReminderAlertOpen(false);
        }}
        onCancel={() => setReminderAlertOpen(false)}
      />
      <TimeWheelPickerSheet
        open={editTimePickerOpen}
        value={editTime || "00:00"}
        title="设置任务时间"
        onClose={() => setEditTimePickerOpen(false)}
        onConfirm={(nextTime) => {
          setEditTime(nextTime);
          // Restore focus to the edit input so next outside click can trigger blur-save.
          requestAnimationFrame(() => editTitleInputRef.current?.focus());
        }}
      />
      <ManualEntryDialog
        open={pumpEntryOpen}
        onClose={() => {
          setPumpEntryOpen(false);
          setPendingCompleteTask(null);
        }}
        onSubmit={handleRecordSubmit}
        recordDateIso={dateStr}
        defaultTime={pendingCompleteTask?.type === "pump" ? pendingCompleteTask.time : null}
      />
      <FeedingEntryDialog
        open={feedingEntryOpen}
        onClose={() => {
          setFeedingEntryOpen(false);
          setPendingCompleteTask(null);
        }}
        onSubmit={handleRecordSubmit}
        recordDateIso={dateStr}
        defaultTime={pendingCompleteTask?.type === "feed" ? pendingCompleteTask.time : null}
      />
      <AddTaskDialog
        ref={addTaskDialogRef}
        open={addTaskOpen}
        onClose={() => setAddTaskOpen(false)}
        onSubmit={handleAddTaskSubmit}
        onRequestOpen={() => setAddTaskOpen(true)}
        onAnalyzingChange={setScheduleAdjusting}
      />
    </div>
  );
};

export default Schedule;
