import React, { useEffect, useState, useMemo, useCallback, Suspense, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown, Info, Target, Droplets, Baby, Pencil, X } from "lucide-react";
import {
  Area, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Line, ComposedChart,
} from "recharts";
import { useVolumeUnit, formatVol, unitLabel } from "@/lib/volumeUnit";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import type {
  MomBabyInfoData,
  MomBabyTodayData,
  GrowthQueryData,
  PumpInfoLactationDayItem,
  GrowthRecord,
} from "@/lib/agentApiTypes";
import { pickMomBabyDeliveryDateYmd, calendarDaysSinceDeliveryLocal } from "@/lib/momBabyDelivery";
import { queryMomBabyInfo, queryMomBabyToday, getPumpInfo } from "@/lib/momPumpTwinAgentApi";
import { queryLatestGrowth, addGrowthRecord, reviseGrowthRecord, getGrowthHistory } from "@/lib/babyTwinAgentApi";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import {
  consumeStatusGrowthHighlightPending,
  STATUS_GROWTH_HIGHLIGHT_EVENT,
} from "@/lib/statusGrowthHighlight";

import momAvatar from "@/assets/mom-avatar-felt.png";
import babyAvatar from "@/assets/baby-avatar-felt.png";

/** `/v1/mom-baby/*`、`/v1/growth/*`、`/v1/pump/info/get` 已接入部分；乳房健康仍为演示占位。 */

/** 母乳趋势 / 成长曲线：压缩左右与底部留白，同时保证刻度文本不被裁切 */
const STATUS_OVERVIEW_CHART_MARGIN = { top: 8, right: 14, left: 0, bottom: 8 } as const;

type BabyRecordRow = { date: string; weightKg: number; heightCm: number; headCm: number };

const BreastModel = React.lazy(() => import("@/components/mom/BreastModel"));

/* ── Expandable Section Component ── */
const Expandable: React.FC<{
  title: string;
  icon: React.ReactNode;
  badge?: React.ReactNode;
  summary?: React.ReactNode;
  children: React.ReactNode;
  defaultOpen?: boolean;
  className?: string;
}> = ({ title, icon, badge, summary, children, defaultOpen = false, className = "" }) => {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={`mx-4 mb-3 rounded-2xl bg-card border border-border/40 shadow-sm overflow-hidden ${className}`}
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
      {line(row.actualMl, "吸乳总量", "hsl(343 40% 27%)")}
      {line(row.estimatedMl, "含亲喂估算", "hsl(343 40% 35%)")}
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

const dash = "—";

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

/** 取体重/身高/头围三条测量时间中最晚的一条，用于「最近一次」说明 */
function latestGrowthMeasurementCaption(g: GrowthQueryData): string | null {
  const bestMs = latestGrowthMesTimestampMs(g);
  if (bestMs !== null) {
    const d = new Date(bestMs);
    return `${d.toLocaleDateString("zh-CN")} ${d.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" })}`;
  }
  const times = [g.weight_mes_time, g.height_mes_time, g.head_mes_time].filter(
    (t): t is string => typeof t === "string" && t.trim().length > 0,
  );
  if (!times.length) return null;
  return times[times.length - 1].trim().slice(0, 19);
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
  const [unit] = useVolumeUnit();
  const isOz = unit === "oz";
  const conv = useCallback((ml: number) => (isOz ? +(ml * 0.033814).toFixed(1) : ml), [isOz]);

  const [deliveryYmd, setDeliveryYmd] = useState<string | null>(null);
  const [momBabyInfo, setMomBabyInfo] = useState<MomBabyInfoData | null>(null);
  const [momBabyToday, setMomBabyToday] = useState<MomBabyTodayData | null>(null);
  const [momBabyLoading, setMomBabyLoading] = useState(true);
  const [todayQueryLoading, setTodayQueryLoading] = useState(true);
  const [momBabyErr, setMomBabyErr] = useState<string | null>(null);

  const [lactationInfoList, setLactationInfoList] = useState<PumpInfoLactationDayItem[]>([]);
  const [pumpInfoLoading, setPumpInfoLoading] = useState(true);

  const [growthLoading, setGrowthLoading] = useState(true);
  const [latestGrowth, setLatestGrowth] = useState<GrowthQueryData | null>(null);
  const [showGrowthServerMeta, setShowGrowthServerMeta] = useState(true);
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
  const growthMetricsRef = useRef<HTMLDivElement | null>(null);
  const growthBlinkTimerRef = useRef<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    const ac = new AbortController();

    setMomBabyLoading(true);
    setMomBabyErr(null);
    void (async () => {
      try {
        const data = await queryMomBabyInfo(DEFAULT_CHAT_USER_ID, { signal: ac.signal });
        if (cancelled) return;
        if (data.error !== 0) {
          setMomBabyInfo(null);
          setDeliveryYmd(null);
          setMomBabyErr("未取得有效的妈妈宝宝档案信息");
          return;
        }
        setMomBabyInfo(data);
        setDeliveryYmd(pickMomBabyDeliveryDateYmd(data));
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setMomBabyInfo(null);
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
        setShowGrowthServerMeta(true);
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
    void (async () => {
      try {
        const data = await getPumpInfo(DEFAULT_CHAT_USER_ID, { signal: ac.signal });
        if (cancelled) return;
        if (data.error !== 0 || !Array.isArray(data.lactation_info_list)) {
          setLactationInfoList([]);
          return;
        }
        setLactationInfoList(data.lactation_info_list);
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        if (cancelled) return;
        setLactationInfoList([]);
      } finally {
        if (!cancelled) setPumpInfoLoading(false);
      }
    })();

    return () => {
      cancelled = true;
      ac.abort();
    };
  }, []);

  const babyDaysSinceBirth = deliveryYmd ? calendarDaysSinceDeliveryLocal(deliveryYmd) : null;
  const babyAgeDays =
    typeof babyDaysSinceBirth === "number" ? Math.max(0, babyDaysSinceBirth) : null;
  const postpartumWeeks =
    typeof babyAgeDays === "number" ? Math.floor(babyAgeDays / 7) : null;

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
  const todayForecastMl = useMemo(
    () => (momBabyToday ? mlFromApi(momBabyToday.feeding_forecast_volum) : null),
    [momBabyToday],
  );

  const [windowSize, setWindowSize] = useState<7 | 30>(7);
  const [growthCurveType, setGrowthCurveType] = useState<"weight" | "height">("weight");

  const lactationRowsMl = useMemo(
    () => buildLactationTrendRowsMl(lactationInfoList),
    [lactationInfoList],
  );

  const trendData = useMemo((): LactationTrendPoint[] => {
    const dateKeys = buildRecentDateKeys(windowSize);
    const recentRows = lactationRowsMl.slice(Math.max(0, lactationRowsMl.length - windowSize));
    const rowStart = Math.max(0, dateKeys.length - recentRows.length);
    return dateKeys.map((dateKey, idx) => {
      const row = idx >= rowStart ? recentRows[idx - rowStart] : null;
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

  const growthMeasCaption =
    showGrowthServerMeta && latestGrowth ? latestGrowthMeasurementCaption(latestGrowth) : null;

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

  return (
    <>
      <div className="relative mx-4 mb-4 flex items-center justify-between mt-2">
        <div className="flex items-center gap-3">
          <div className="relative">
            <img src={momAvatar} alt="Mom" className="w-14 h-14 rounded-full border-2 border-primary/20 object-cover" />
            <img src={babyAvatar} alt="Baby" className="w-8 h-8 rounded-full border-2 border-background object-cover absolute -bottom-2 -right-2" />
          </div>
          <div>
            <h1 className="text-base font-bold text-foreground">妈妈和宝宝状态概览</h1>
            <p className="text-[11px] text-muted-foreground">
              {momBabyLoading ? (
                "正在加载妈妈和宝宝信息…"
              ) : momBabyErr ? (
                "产后和宝宝档案待绑定"
              ) : typeof postpartumWeeks === "number" && typeof babyAgeDays === "number" ? (
                <>产后第 {postpartumWeeks} 周 · 宝宝已出生 {babyAgeDays} 天</>
              ) : (
                "暂无有效分娩日期，请完善档案后重试"
              )}
            </p>
          </div>
        </div>
      </div>

      <div className="mx-4 mb-4">
        <div className="rounded-[24px] bg-gradient-to-b from-primary/10 to-transparent border border-primary/20 p-4 shadow-sm relative overflow-hidden">
          <div className="flex items-start gap-3 relative z-10">
            <div className="w-10 h-10 rounded-full border-2 border-background shadow-sm shrink-0 bg-background overflow-hidden flex items-center justify-center">
              <MaiAvatar emotion="happy" size="sm" animate={false} className="!w-8 !h-8" />
            </div>
            <div className="flex-1 space-y-3.5 pt-0.5">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-xs font-extrabold text-foreground">泌乳建议</span>
                </div>
                <p className="text-[11px] text-muted-foreground leading-relaxed font-medium whitespace-pre-wrap">
                  {momBabyLoading
                    ? "加载中…"
                    : (momBabyInfo?.lactation_advice ?? "").trim() ||
                      "暂无泌乳建议，记录吸乳数据后将由服务端生成摘要。"}
                </p>
              </div>
              <div className="h-px bg-border/50" />
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-xs font-extrabold text-foreground">喂养建议</span>
                </div>
                <p className="text-[11px] text-muted-foreground leading-relaxed font-medium whitespace-pre-wrap">
                  {momBabyLoading ? (
                    "加载中…"
                  ) : (momBabyInfo?.feeding_advice ?? "").trim() ? (
                    (momBabyInfo?.feeding_advice ?? "").trim()
                  ) : typeof babyMetrics.weightKg === "number" ? (
                    <>同龄参考：日摄入量约 {formatVol(120 * babyMetrics.weightKg, unit)}–{formatVol(180 * babyMetrics.weightKg, unit)}{unitLabel(unit)}。按需喂养即可。</>
                  ) : (
                    "暂无喂养建议。录入宝宝体重后可查看结合体重的摄入参考。"
                  )}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="mx-4 mb-4 grid grid-cols-2 gap-3">
        <div className="rounded-2xl bg-primary/5 border border-primary/10 p-3 flex flex-col items-center justify-center">
          <p className="text-[11px] font-bold text-primary/80 mb-1 flex items-center gap-1"><Droplets className="w-3 h-3"/> 今日母乳产出</p>
          <p className="text-xl font-black text-primary">
            {todayQueryLoading ? (
              <span className="text-muted-foreground">…</span>
            ) : todayPumpMl !== null ? (
              <>
                {formatVol(todayPumpMl, unit)}<span className="text-[11px] font-bold ml-0.5">{unitLabel(unit)}</span>
              </>
            ) : (
              dash
            )}
          </p>
        </div>
        <div className="rounded-2xl bg-secondary/30 border border-border/50 p-3 flex flex-col items-center justify-center">
          <p className="text-[11px] font-bold text-muted-foreground mb-1 flex items-center gap-1"><Baby className="w-3 h-3"/> 今日宝宝摄入/预估</p>
          <div className="flex items-baseline gap-1">
            <p className="text-xl font-black text-foreground">
              {todayQueryLoading ? (
                <span className="text-muted-foreground">…</span>
              ) : todayFeedMl !== null ? (
                formatVol(todayFeedMl, unit)
              ) : (
                dash
              )}
            </p>
            <p className="text-[10px] font-medium text-muted-foreground">
              /{" "}
              {todayQueryLoading ? (
                "…"
              ) : todayForecastMl !== null ? (
                `${formatVol(todayForecastMl, unit)}${unitLabel(unit)}`
              ) : (
                dash
              )}
            </p>
          </div>
        </div>
      </div>

      <div className="mx-4 mb-4">
        <div className="flex items-center justify-between mb-2 px-1">
          <h2 className="text-sm font-bold text-foreground">宝宝成长记录</h2>
          <button
            type="button"
            onClick={() => {
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
            }}
            className="text-[11px] text-primary font-medium flex items-center gap-1 bg-primary/10 px-2.5 py-1 rounded-full active:scale-95 transition-transform"
          >
            <Pencil className="w-3 h-3" /> 修改指标
          </button>
        </div>
        <div
          ref={growthMetricsRef}
          className={`rounded-[24px] bg-card border border-border/40 p-4 shadow-sm transition-all duration-200 ${
            growthMetricsBlinkOn ? "ring-2 ring-amber-400/80 shadow-[0_0_0_4px_rgba(251,191,36,0.22)]" : ""
          }`}
        >
          <div className="flex items-center justify-between">
            <div className="flex-1 text-center border-r border-border/40">
              <p className="text-[11px] text-muted-foreground font-medium mb-1">体重</p>
              <p className="text-lg font-black text-foreground">
                {growthLoading ? (
                  <span className="text-muted-foreground">…</span>
                ) : typeof babyMetrics.weightKg === "number" ? (
                  babyMetrics.weightKg
                ) : (
                  dash
                )}
                <span className="text-[10px] font-medium ml-0.5 text-muted-foreground">kg</span>
              </p>
            </div>
            <div className="flex-1 text-center border-r border-border/40">
              <p className="text-[11px] text-muted-foreground font-medium mb-1">身高</p>
              <p className="text-lg font-black text-foreground">
                {growthLoading ? (
                  <span className="text-muted-foreground">…</span>
                ) : typeof babyMetrics.heightCm === "number" ? (
                  babyMetrics.heightCm
                ) : (
                  dash
                )}
                <span className="text-[10px] font-medium ml-0.5 text-muted-foreground">cm</span>
              </p>
            </div>
            <div className="flex-1 text-center">
              <p className="text-[11px] text-muted-foreground font-medium mb-1">头围</p>
              <p className="text-lg font-black text-foreground">
                {growthLoading ? (
                  <span className="text-muted-foreground">…</span>
                ) : typeof babyMetrics.headCm === "number" ? (
                  babyMetrics.headCm
                ) : (
                  dash
                )}
                <span className="text-[10px] font-medium ml-0.5 text-muted-foreground">cm</span>
              </p>
            </div>
          </div>
          {growthLoading ? (
            <p className="text-[10px] text-muted-foreground text-center mt-3 px-1">正在加载最近一次生长发育记录…</p>
          ) : growthMeasCaption ? (
            <p className="text-[10px] text-muted-foreground text-center mt-3 px-1 leading-relaxed">
              最近一次测量：{growthMeasCaption}
            </p>
          ) : showGrowthServerMeta ? (
            <p className="text-[10px] text-muted-foreground text-center mt-3 px-1">
              {latestGrowth ? "最近一次测量时间暂无" : "暂无生长发育记录"}
            </p>
          ) : null}
        </div>
      </div>

      <Expandable
        title="母乳趋势"
        icon={<div className="w-6 h-6 rounded-full bg-primary/15 flex items-center justify-center"><Target className="w-3.5 h-3.5 text-primary" /></div>}
      >
        <div className="flex justify-between items-center mb-2">
          <div className="flex items-center gap-2 text-[9px]">
            <div className="flex items-center gap-1">
              <div className="w-3 h-[2px] bg-[hsl(343_40%_27%)]"></div>
              <span className="text-muted-foreground">吸乳总量</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-[2px] border-b border-dashed border-[hsl(343_40%_27%)] opacity-40"></div>
              <span className="text-muted-foreground">含亲喂估算</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-2 bg-[hsl(158_55%_52%)] opacity-25"></div>
              <span className="text-muted-foreground">目标参考区间</span>
            </div>
          </div>
          <div className="flex rounded-full bg-muted/60 p-0.5 text-[10px] font-medium">
            <button type="button" onClick={() => setWindowSize(7)} className={`px-2 py-0.5 rounded-full ${windowSize === 7 ? "bg-primary text-primary-foreground" : "text-muted-foreground"}`}>周</button>
            <button type="button" onClick={() => setWindowSize(30)} className={`px-2 py-0.5 rounded-full ${windowSize === 30 ? "bg-primary text-primary-foreground" : "text-muted-foreground"}`}>月</button>
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
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(340 20% 90%)" />
                <XAxis
                  dataKey="dateKey"
                  ticks={lactationTrendDateTicks}
                  tickFormatter={formatLactationTrendDateTick}
                  tick={{ fontSize: 9 }}
                  stroke="hsl(343 15% 50%)"
                  interval={0}
                  minTickGap={8}
                  tickMargin={6}
                  padding={{ left: 0, right: 8 }}
                />
                <YAxis
                  tick={{ fontSize: 9 }}
                  stroke="hsl(343 15% 50%)"
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
                  fill="hsl(158 55% 52%)"
                  fillOpacity={0.22}
                  dot={false}
                  activeDot={false}
                  isAnimationActive={false}
                />
                <Line
                  type="monotone"
                  dataKey="estimated"
                  stroke="hsl(343 40% 27%)"
                  strokeDasharray="5 5"
                  strokeWidth={1.5}
                  strokeOpacity={0.55}
                  dot={windowSize === 7 ? { r: 2 } : false}
                />
                <Line
                  type="monotone"
                  dataKey="actual"
                  stroke="hsl(343 40% 27%)"
                  strokeWidth={2.5}
                  dot={
                    windowSize === 7
                      ? { r: 3, strokeWidth: 2, fill: "hsl(var(--background))", stroke: "hsl(343 40% 27%)" }
                      : false
                  }
                  activeDot={{ r: 5 }}
                />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        )}
      </Expandable>

      <Expandable
        title="宝宝成长曲线"
        icon={<div className="w-6 h-6 rounded-full bg-secondary flex items-center justify-center"><Baby className="w-3.5 h-3.5 text-foreground" /></div>}
      >
        <div className="flex justify-between items-center mb-2">
          <div className="flex items-center gap-2 text-[9px]">
            <div className="flex items-center gap-1">
              <div className="w-3 h-[2px] bg-[hsl(var(--primary))]"></div>
              <span className="text-muted-foreground">实际测量</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-2 bg-[hsl(var(--primary))] opacity-30"></div>
              <span className="text-muted-foreground">同龄参考区间</span>
            </div>
          </div>
          <div className="flex rounded-full bg-muted/60 p-0.5 text-[9px] font-medium">
            <button type="button" onClick={() => setGrowthCurveType("weight")} className={`px-2 py-0.5 rounded-full ${growthCurveType === "weight" ? "bg-primary text-primary-foreground" : "text-muted-foreground"}`}>体重</button>
            <button type="button" onClick={() => setGrowthCurveType("height")} className={`px-2 py-0.5 rounded-full ${growthCurveType === "height" ? "bg-primary text-primary-foreground" : "text-muted-foreground"}`}>身高</button>
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
                    <stop offset="0%" stopColor="hsl(var(--primary))" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="hsl(var(--primary))" stopOpacity={0.15} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" opacity={0.35} vertical={false} />
                <XAxis
                  dataKey="week"
                  ticks={growthChartWeekTicks}
                  tick={{ fontSize: 9 }}
                  stroke="hsl(343 15% 50%)"
                  interval={0}
                  tickMargin={6}
                  padding={{ left: 0, right: 8 }}
                />
                <YAxis
                  tick={{ fontSize: 9 }}
                  stroke="hsl(343 15% 50%)"
                  width={42}
                  domain={growthYAxisDomains?.weight ?? [2.5, 7]}
                  allowDecimals
                  tickFormatter={(v) => formatGrowthChartYTick(v, "kg")}
                />
                <Tooltip contentStyle={{ fontSize: 11 }} />
                <Area type="monotone" dataKey="wP75" stroke="none" fill="url(#growthBandPrimary)" name="P75参考" fillOpacity={1} />
                <Area type="monotone" dataKey="wP25" stroke="none" fill="hsl(var(--card))" name="P25参考" fillOpacity={1} />
                <Line type="monotone" dataKey="weight" name="体重" stroke="hsl(var(--primary))" strokeWidth={3} dot={{ r: 4, strokeWidth: 1.5, fill: "hsl(var(--background))", stroke: "hsl(var(--primary))" }} />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="h-[188px] w-full min-w-0 max-w-full">
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={growthChartData} margin={STATUS_OVERVIEW_CHART_MARGIN}>
                <defs>
                  <linearGradient id="growthBandSecondary" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="hsl(158 55% 52%)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="hsl(158 55% 52%)" stopOpacity={0.15} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" opacity={0.35} vertical={false} />
                <XAxis
                  dataKey="week"
                  ticks={growthChartWeekTicks}
                  tick={{ fontSize: 9 }}
                  stroke="hsl(343 15% 50%)"
                  interval={0}
                  tickMargin={6}
                  padding={{ left: 0, right: 8 }}
                />
                <YAxis
                  tick={{ fontSize: 9 }}
                  stroke="hsl(343 15% 50%)"
                  width={42}
                  domain={growthYAxisDomains?.height ?? [46, 64]}
                  allowDecimals
                  tickFormatter={(v) => formatGrowthChartYTick(v, "cm")}
                />
                <Tooltip contentStyle={{ fontSize: 11 }} />
                <Area type="monotone" dataKey="hP75" stroke="none" fill="url(#growthBandSecondary)" name="P75参考" fillOpacity={1} />
                <Area type="monotone" dataKey="hP25" stroke="none" fill="hsl(var(--card))" name="P25参考" fillOpacity={1} />
                <Line type="monotone" dataKey="height" name="身高" stroke="hsl(158 55% 52%)" strokeWidth={3} dot={{ r: 4, strokeWidth: 1.5, fill: "hsl(var(--background))", stroke: "hsl(158 55% 52%)" }} />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        )}
      </Expandable>

      <Expandable
        title="乳房健康"
        icon={<div className="w-6 h-6 rounded-full bg-primary/15 flex items-center justify-center"><Info className="w-3.5 h-3.5 text-primary" /></div>}
      >
        <Suspense fallback={<div className="h-[160px] flex items-center justify-center text-xs text-muted-foreground">加载 3D 模型…</div>}>
          <div className="flex justify-center gap-6 mb-3">
            <BreastModel side="L" status="normal" />
            <BreastModel side="R" status="attention" />
          </div>
        </Suspense>
        <div className="flex gap-4 justify-center text-[10px] mt-2">
          <span className="text-emerald-600 font-medium">左侧：未见异常</span>
          <span className="text-red-500 font-medium">右侧：需要关注</span>
        </div>
      </Expandable>

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
                      setShowGrowthServerMeta(true);
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
