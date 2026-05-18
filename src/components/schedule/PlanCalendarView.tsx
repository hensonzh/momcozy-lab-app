import React, { useState, useMemo, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { mockPlans, planColors, getActivePlanIds } from "@/data/planMockData";
import { useSchedulePlanContext } from "@/pages/schedule/SchedulePlanContext";

const WEEKDAYS = ["一", "二", "三", "四", "五", "六", "日"];

/** 接口返回的自定义 plan id 可能不在 planColors 中，回退到 maintain 配色 */
const planColorOrFallback = (planId: string) => planColors[planId] ?? planColors.maintain;

/* ── Helpers ── */
const addDays = (d: Date, n: number) => {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
};

const isSameDay = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

const daysInMonth = (year: number, month: number) => new Date(year, month + 1, 0).getDate();
const startDow = (year: number, month: number) => {
  const d = new Date(year, month, 1).getDay();
  return d === 0 ? 6 : d - 1; // Monday=0
};

interface DayCellPlan {
  planId: string;
  planName: string;
  emoji: string;
  milestoneLabel: string;
  isMilestoneStart: boolean;
}

/* ── Milestone accent colors per plan (vibrant) ── */
const milestoneAccents: Record<string, string> = {
  maintain: "bg-teal-500",
  chase: "bg-orange-500",
  wean: "bg-sky-500",
  fertility: "bg-pink-500",
  work: "bg-violet-500",
};

/* ── Component ── */
const PlanCalendarView: React.FC = () => {
  const { serverPlans } = useSchedulePlanContext();
  const displayPlans = serverPlans && serverPlans.length > 0 ? serverPlans : mockPlans;

  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth());
  const [tooltip, setTooltip] = useState<{ day: number; plans: DayCellPlan[] } | null>(null);
  const [activePlanIds, setActivePlanIds] = useState(getActivePlanIds);

  useEffect(() => {
    const handler = (e: Event) => setActivePlanIds((e as CustomEvent).detail);
    window.addEventListener("activePlansUpdated", handler);
    return () => window.removeEventListener("activePlansUpdated", handler);
  }, []);

  // Only show active plans on calendar
  const activePlans = displayPlans.filter((p) => activePlanIds.includes(p.id));

  const dayPlanMap = useMemo(() => {
    const map = new Map<number, DayCellPlan[]>();
    const totalDays = daysInMonth(year, month);

    for (const plan of activePlans) {
      for (const ms of plan.milestones) {
        const msStart = new Date(ms.startDate);
        const msEnd = addDays(msStart, ms.durationWeeks * 7);

        for (let d = 1; d <= totalDays; d++) {
          const cellDate = new Date(year, month, d);
          if (cellDate >= msStart && cellDate < msEnd) {
            const arr = map.get(d) || [];
            arr.push({
              planId: plan.id,
              planName: plan.name,
              emoji: plan.emoji,
              milestoneLabel: ms.label,
              isMilestoneStart: isSameDay(cellDate, msStart),
            });
            map.set(d, arr);
          }
        }
      }
    }
    return map;
  }, [year, month, activePlans]);

  const totalDays = daysInMonth(year, month);
  const offset = startDow(year, month);

  const prevMonth = () => {
    if (month === 0) { setYear(year - 1); setMonth(11); }
    else setMonth(month - 1);
    setTooltip(null);
  };
  const nextMonth = () => {
    if (month === 11) { setYear(year + 1); setMonth(0); }
    else setMonth(month + 1);
    setTooltip(null);
  };

  const handleDayClick = (day: number) => {
    const plans = dayPlanMap.get(day);
    if (plans && plans.length > 0) {
      setTooltip(tooltip?.day === day ? null : { day, plans });
    } else {
      setTooltip(null);
    }
  };

  const cells: (number | null)[] = [];
  for (let i = 0; i < offset; i++) cells.push(null);
  for (let d = 1; d <= totalDays; d++) cells.push(d);

  return (
    <div className="space-y-3">
      {/* Year/Month selector */}
      <div className="flex items-center justify-between px-1">
        <button onClick={prevMonth} className="p-1.5 rounded-lg hover:bg-secondary/40 transition-colors">
          <ChevronLeft className="w-4 h-4 text-muted-foreground" />
        </button>
        <div className="flex items-baseline gap-1.5">
          <span className="text-[15px] font-bold text-foreground">{year}年</span>
          <span className="text-[15px] font-bold text-primary">{month + 1}月</span>
        </div>
        <button onClick={nextMonth} className="p-1.5 rounded-lg hover:bg-secondary/40 transition-colors">
          <ChevronRight className="w-4 h-4 text-muted-foreground" />
        </button>
      </div>

      {/* Legend — only active plans */}
      <div className="flex flex-wrap gap-x-3 gap-y-1 px-1">
        {activePlans.map((p) => {
          const c = planColorOrFallback(p.id);
          return (
            <div key={p.id} className="flex items-center gap-1">
              <div className={cn("w-2.5 h-2.5 rounded-sm", c.bg, "border", c.border)} />
              <span className="text-[9px] text-muted-foreground">{p.emoji} {p.name}</span>
            </div>
          );
        })}
        <div className="flex items-center gap-1">
          <div className="w-2.5 h-2.5 rounded-full bg-gradient-to-br from-orange-400 to-pink-500 shadow-sm" />
          <span className="text-[9px] text-muted-foreground">里程碑起点</span>
        </div>
      </div>

      {/* Calendar grid */}
      <div className="rounded-xl border border-border/50 bg-secondary/10 p-2 overflow-hidden">
        <div className="grid grid-cols-7 mb-1">
          {WEEKDAYS.map((w) => (
            <div key={w} className="text-center text-[9px] font-semibold text-muted-foreground py-1">
              {w}
            </div>
          ))}
        </div>

        <div className="grid grid-cols-7 gap-[2px]">
          {cells.map((day, i) => {
            if (day === null) {
              return <div key={`blank-${i}`} className="aspect-square" />;
            }

            const plans = dayPlanMap.get(day) || [];
            const isToday =
              day === now.getDate() && month === now.getMonth() && year === now.getFullYear();
            const isSelected = tooltip?.day === day;

            // Deduplicate by planId, preferring entries with isMilestoneStart
            const uniquePlans = plans.reduce<DayCellPlan[]>((acc, p) => {
              const existing = acc.find((x) => x.planId === p.planId);
              if (!existing) {
                acc.push(p);
              } else if (p.isMilestoneStart && !existing.isMilestoneStart) {
                // Replace with milestone-start entry so the marker isn't lost
                acc[acc.indexOf(existing)] = p;
              }
              return acc;
            }, []);

            // Collect milestone starts per plan for this day
            const milestoneStarts = plans.filter((p) => p.isMilestoneStart);

            return (
              <button
                key={day}
                onClick={() => handleDayClick(day)}
                className={cn(
                  "aspect-square rounded-md flex flex-col items-center justify-center relative transition-all",
                  plans.length > 0 ? "cursor-pointer hover:ring-1 hover:ring-primary/30" : "cursor-default",
                  isSelected && "ring-2 ring-primary/50",
                  isToday && "ring-1 ring-primary/40"
                )}
              >
                {/* Background color bars — stacked vertically */}
                {uniquePlans.length > 0 && (
                  <div className="absolute inset-0 rounded-md overflow-hidden flex flex-col">
                    {uniquePlans.map((p) => {
                      const c = planColorOrFallback(p.planId);
                      const accent = milestoneAccents[p.planId] || "bg-primary";
                      const isMsStart = p.isMilestoneStart;
                      return (
                        <div
                          key={p.planId}
                          className={cn("flex-1 relative", c.bg)}
                        >
                          {/* Vibrant milestone start indicator on this color lane */}
                          {isMsStart && (
                            <div className={cn(
                              "absolute inset-x-0 top-0 bottom-0 opacity-80",
                              accent
                            )} />
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}

                {/* Day number */}
                <span className={cn(
                  "relative z-[1] text-[11px] font-medium leading-none",
                  milestoneStarts.length > 0 ? "font-black text-white drop-shadow-sm" :
                  isToday ? "font-bold text-primary" :
                  plans.length > 0 ? "text-foreground" : "text-muted-foreground/60"
                )}>
                  {day}
                </span>

                {/* Vibrant milestone dot */}
                {milestoneStarts.length > 0 && (
                  <div className="absolute bottom-[2px] left-1/2 -translate-x-1/2 flex gap-[2px] z-[1]">
                    {milestoneStarts.filter((p, i, a) => a.findIndex(x => x.planId === p.planId) === i).map((p) => (
                      <div
                        key={p.planId}
                        className={cn(
                          "w-1.5 h-1.5 rounded-full shadow-sm ring-1 ring-white/60",
                          milestoneAccents[p.planId] || "bg-primary"
                        )}
                      />
                    ))}
                  </div>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Tooltip */}
      <AnimatePresence>
        {tooltip && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 8 }}
            transition={{ duration: 0.25 }}
            className="rounded-xl border border-border/50 bg-card p-3 shadow-lg space-y-2"
          >
            <div className="flex items-center justify-between">
              <p className="text-[12px] font-bold text-foreground">
                {month + 1}月{tooltip.day}日 · 关联计划
              </p>
              <button onClick={() => setTooltip(null)} className="p-0.5 rounded hover:bg-secondary/40">
                <X className="w-3.5 h-3.5 text-muted-foreground" />
              </button>
            </div>
            {tooltip.plans
              .filter((p, i, a) => a.findIndex((x) => x.planId === p.planId) === i)
              .map((p) => {
                const c = planColorOrFallback(p.planId);
                const accent = milestoneAccents[p.planId] || "bg-primary";
                return (
                  <div
                    key={p.planId}
                    className={cn("flex items-center gap-2 px-2.5 py-1.5 rounded-lg border", c.bg, c.border)}
                  >
                    <span className="text-sm">{p.emoji}</span>
                    <div className="flex-1 min-w-0">
                      <p className={cn("text-[11px] font-bold", c.text)}>{p.planName}</p>
                      <p className="text-[9px] text-muted-foreground flex items-center gap-1">
                        {p.isMilestoneStart && (
                          <span className={cn("inline-block w-2 h-2 rounded-full", accent)} />
                        )}
                        {p.isMilestoneStart ? "里程碑起点：" : ""}
                        {p.milestoneLabel}
                      </p>
                    </div>
                  </div>
                );
              })}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default PlanCalendarView;
