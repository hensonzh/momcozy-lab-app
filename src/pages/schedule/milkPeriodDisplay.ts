/**
 * 根据 plan/milk_period 接口数据，生成 Milky.Way 泌乳周期栏展示用结构（开始月/日、持续时长、阶段间节点）。
 */
import type { MilkPeriodInfo } from "@/lib/agentApiTypes";

/** 静态文案：阶段名与参考区间（不随接口变化） */
export const MILKY_PHASE_STATIC = [
  { key: "colostrum", label: "初乳期", ref: "0–3天" },
  { key: "establish", label: "建立期", ref: "1–4周" },
  { key: "stable", label: "稳产期", ref: "1–6月" },
  { key: "weaning", label: "离乳期", ref: "6月+" },
] as const;

type PhaseKey = (typeof MILKY_PHASE_STATIC)[number]["key"];

const API_DATES: (keyof MilkPeriodInfo)[] = [
  "colostrum_period",
  "establishment_period",
  "stable_delivery_period",
  "weaning_period",
];

/** 将当天 0 点作为比较基准，避免时分秒干扰 */
function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/**
 * 解析接口返回的泌乳阶段开始时间。
 * @param s 原始字符串
 * @returns 有效则返回当天 0 点的 Date，否则 null
 */
export function parseMilkPeriodDate(s: string | undefined | null): Date | null {
  if (s == null) return null;
  const t = String(s).trim();
  if (t === "") return null;
  const m = t.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) {
    const y = Number(m[1]);
    const mo = Number(m[2]);
    const da = Number(m[3]);
    const d = new Date(y, mo - 1, da);
    return Number.isNaN(d.getTime()) ? null : startOfDay(d);
  }
  const ms = Date.parse(t);
  if (!Number.isNaN(ms)) return startOfDay(new Date(ms));
  return null;
}

/**
 * 计算两个日期（按日）之间的间隔天数，不含上界：等同「上界日 − 下界日」的天数差。
 * @param a 起始日
 * @param b 结束日
 * @returns 天数差，可能为负
 */
export function diffCalendarDays(a: Date, b: Date): number {
  const sa = startOfDay(a).getTime();
  const sb = startOfDay(b).getTime();
  return Math.round((sb - sa) / (24 * 3600 * 1000));
}

/**
 * 在给定日期上加减天数。
 * @param d 基准日
 * @param n 天数（可负）
 * @returns 新 Date（0 点）
 */
export function addCalendarDays(d: Date, n: number): Date {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  x.setDate(x.getDate() + n);
  return x;
}

/**
 * 将一段时长（含首尾日）格式化为：&lt;7 天用「X天」；≥7 且 &lt;30 天用「X周X天」；≥30 天用「X月X天」（按每满 30 天为 1 个月估算剩余天数，避免跨月日历边界误差）。
 * @param from 阶段首日
 * @param lastInclusive 阶段最后一日（含）
 * @returns 展示文案；无效区间返回 null
 */
export function formatPhaseSpanInclusive(from: Date, lastInclusive: Date): string | null {
  if (lastInclusive < from) return null;
  const inclusiveDays = diffCalendarDays(from, lastInclusive) + 1;
  if (inclusiveDays < 1) return null;
  if (inclusiveDays < 7) return `${inclusiveDays}天`;
  if (inclusiveDays < 30) {
    const w = Math.floor(inclusiveDays / 7);
    const d = inclusiveDays % 7;
    if (d === 0) return `${w}周`;
    return `${w}周${d}天`;
  }
  const months = Math.floor(inclusiveDays / 30);
  const days = inclusiveDays % 30;
  if (days === 0) return `${months}月`;
  return `${months}月${days}天`;
}

/**
 * 当前阶段「从阶段首日到今天（含）」的时长文案，规则同 {@link formatPhaseSpanInclusive}，但带「第」前缀（第X天 / 第X周X天 / 第X月X天）。
 * @param from 阶段首日
 * @param lastInclusive 通常为今天（含）
 * @returns 展示文案；无效区间返回 null
 */
export function formatCurrentPhaseSpanInclusive(from: Date, lastInclusive: Date): string | null {
  if (lastInclusive < from) return null;
  const inclusiveDays = diffCalendarDays(from, lastInclusive) + 1;
  if (inclusiveDays < 1) return null;
  if (inclusiveDays < 7) return `第${inclusiveDays}天`;
  if (inclusiveDays < 30) {
    const w = Math.floor(inclusiveDays / 7);
    const d = inclusiveDays % 7;
    if (d === 0) return `第${w}周`;
    return `第${w}周${d}天`;
  }
  const months = Math.floor(inclusiveDays / 30);
  const days = inclusiveDays % 30;
  if (days === 0) return `第${months}月`;
  return `第${months}月${days}天`;
}

/**
 * 未开始阶段：用阶段预计开始日的公历月份（1–12）展示为「≈n」；无有效日期时返回 "-/-"。
 * @param start 解析后的阶段开始日，可为未来日期
 * @returns 如 "≈7" 或 "-/-"
 */
export function formatFuturePhaseStartApprox(start: Date | null): string {
  if (!start) return "-/-";
  return `≈${start.getMonth() + 1}`;
}

/**
 * 格式化为月/日展示；无效为 "-/-"。
 * @param d 日期或 null
 * @returns 如 "3/15" 或 "-/-"
 */
export function formatMonthDaySlash(d: Date | null): string {
  if (!d) return "-/-";
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

/** 单阶段 UI 行（开始时间仅在阶段间圆点展示，不在列下方展示） */
export interface MilkyPhaseRow {
  key: PhaseKey;
  label: string;
  ref: string;
  durationDisplay: string;
  /** 已进入更后阶段且本阶段无开始日（跳过），进度条与文案置灰，不按「已完成」高亮 */
  phaseSkipped: boolean;
  barPassed: boolean;
  barActive: boolean;
  columnMuted: boolean;
}

/** 两阶段之间的圆点：下一阶段未开始时为「≈月份」；已开始则为「月/日」 */
export interface MilkyPhaseConnector {
  nextStartDisplay: string;
  connectorPassed: boolean;
}

export interface MilkyWayDisplayModel {
  phases: MilkyPhaseRow[];
  connectors: MilkyPhaseConnector[];
}

/**
 * 某阶段是否尚未开始（尚未进入任一已记录阶段，或当前阶段之后的阶段）。
 * @param phaseIndex 阶段下标 0..3
 * @param currentIdx 当前所处阶段；-1 表示今天早于所有有效开始日（或无任何有效开始日）
 */
function isPhaseNotStarted(phaseIndex: number, currentIdx: number): boolean {
  return currentIdx === -1 || (currentIdx >= 0 && phaseIndex > currentIdx);
}

/**
 * 在 i 之后查找第一个存在有效开始日的阶段下标（不要求连续，用于跳过中间阶段）。
 * @param starts 各阶段开始日
 * @param i 当前阶段下标
 * @returns 下标或 null
 */
function findNextPhaseWithValidStart(starts: (Date | null)[], i: number): number | null {
  for (let j = i + 1; j < starts.length; j++) {
    if (starts[j]) return j;
  }
  return null;
}

/**
 * 根据各阶段自身开始日解析「当前所处阶段」（可从任意阶段切入，不必经过初乳期）。
 * 规则：取最大的 i，满足 starts[i] 有效、今天 ≥ starts[i]，且不存在 j>i 使得 starts[j] 有效且今天 ≥ starts[j]。
 * @param starts 四个阶段开始日
 * @param t0 今天的 0 点
 * @returns 阶段下标 0..3，或 -1 表示尚未进入任一有效阶段
 */
export function resolveCurrentLactationPhaseIndex(starts: (Date | null)[], t0: Date): number {
  for (let i = starts.length - 1; i >= 0; i--) {
    const si = starts[i];
    if (!si || t0 < si) continue;
    let enteredLater = false;
    for (let j = i + 1; j < starts.length; j++) {
      const sj = starts[j];
      if (sj && t0 >= sj) {
        enteredLater = true;
        break;
      }
    }
    if (!enteredLater) return i;
  }
  return -1;
}

/**
 * 根据接口泌乳周期与「今天」生成展示模型。
 * @param info 接口 milk_period；null 表示未拉到或失败
 * @param today 当前日期（通常 new Date()）
 * @returns 四阶段 + 三处连接点
 */
export function buildMilkyWayDisplayModel(info: MilkPeriodInfo | null, today: Date): MilkyWayDisplayModel {
  const t0 = startOfDay(today);
  const starts: (Date | null)[] = !info
    ? [null, null, null, null]
    : API_DATES.map((k) => parseMilkPeriodDate(info[k]));

  const currentIdx = resolveCurrentLactationPhaseIndex(starts, t0);

  const phases: MilkyPhaseRow[] = MILKY_PHASE_STATIC.map((meta, i) => {
    const start = starts[i];
    const notStarted = isPhaseNotStarted(i, currentIdx);
    const isCurrent = currentIdx === i;
    const isPassed = currentIdx >= 0 && i < currentIdx;
    /** 无开始日且当前已在更后阶段：视为跳过，整列置灰 */
    const phaseSkipped = isPassed && !start;

    let durationDisplay: string;

    if (notStarted) {
      // 未开始：持续时长占位「-/-」（开始月份仅在阶段间圆点展示）
      durationDisplay = "-/-";
    } else {
      durationDisplay = "--";

      if (!start) {
        // 已处于更后阶段但本阶段无开始日：视为跳过，不套用其它阶段时间推算
        durationDisplay = "--";
      } else if (isPassed) {
        // 已结束时长：仅本阶段开始日 → 下一个「有开始日」的阶段前一日（可跨跳过的阶段）
        const nextJ = findNextPhaseWithValidStart(starts, i);
        const nextStart = nextJ !== null ? starts[nextJ] : null;
        if (nextStart && nextStart > start) {
          const lastDay = addCalendarDays(nextStart, -1);
          durationDisplay = formatPhaseSpanInclusive(start, lastDay) ?? "--";
        } else {
          durationDisplay = "--";
        }
      } else if (isCurrent) {
        durationDisplay = formatCurrentPhaseSpanInclusive(start, t0) ?? "--";
      }
    }

    return {
      key: meta.key,
      label: meta.label,
      ref: meta.ref,
      durationDisplay,
      phaseSkipped,
      // 跳过阶段不按「已完成」着色进度条
      barPassed: isPassed && !phaseSkipped,
      barActive: isCurrent,
      columnMuted: notStarted || phaseSkipped,
    };
  });

  const connectors: MilkyPhaseConnector[] = [0, 1, 2].map((i) => {
    const nextIdx = i + 1;
    const nextStart = starts[nextIdx];
    // 右侧阶段未开始时，间隔圆点与列内一致用「≈n」（公历月份）；已开始则用具体月/日
    const nextNotStarted = isPhaseNotStarted(nextIdx, currentIdx);
    const nextStartDisplay = nextNotStarted
      ? formatFuturePhaseStartApprox(nextStart)
      : formatMonthDaySlash(nextStart);
    const connectorPassed = currentIdx > i;
    return { nextStartDisplay, connectorPassed };
  });

  return { phases, connectors };
}
