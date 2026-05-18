import React, { useState, useMemo, useEffect } from "react";
import { motion } from "framer-motion";
import { ChevronDown, Check, ArrowRight } from "lucide-react";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { cn } from "@/lib/utils";
import { mockPlans, getActivePlanIds, LACTATION_PLAN_IDS, PARALLEL_PLAN_IDS, type MilestoneTask } from "@/data/planMockData";
import { useSchedulePlanContext } from "@/pages/schedule/SchedulePlanContext";
/* ── Helper: expand tasks by interval within milestone duration ── */
const expandTasks = (tasks: MilestoneTask[], durationWeeks: number) => {
  const totalDays = durationWeeks * 7;
  const items: { day: number; title: string; icon: string }[] = [];
  for (const t of tasks) {
    for (let d = 0; d < totalDays; d += t.intervalDays) {
      items.push({ day: d + 1, title: t.title, icon: t.icon });
    }
  }
  items.sort((a, b) => a.day - b.day);
  // Group by day, show first 6 unique days only for brevity
  const dayMap = new Map<number, typeof items>();
  for (const it of items) {
    const arr = dayMap.get(it.day) || [];
    arr.push(it);
    dayMap.set(it.day, arr);
  }
  const keys = [...dayMap.keys()].slice(0, 5);
  return keys.map((day) => ({ day, tasks: dayMap.get(day)! }));
};

/* ── Component ── */
const MilestoneTimeline: React.FC = () => {
  const { serverPlans } = useSchedulePlanContext();
  const displayPlans = serverPlans && serverPlans.length > 0 ? serverPlans : mockPlans;

  const [activePlanIds, setActivePlanIds] = useState(getActivePlanIds);

  useEffect(() => {
    const handler = (e: Event) => setActivePlanIds((e as CustomEvent).detail);
    window.addEventListener("activePlansUpdated", handler);
    return () => window.removeEventListener("activePlansUpdated", handler);
  }, []);

  const activePlans = displayPlans.filter((p) => activePlanIds.includes(p.id));
  const [selectedPlanId, setSelectedPlanId] = useState(activePlans[0]?.id || "maintain");
  const [dropdownOpen, setDropdownOpen] = useState(false);

  const plan = displayPlans.find((p) => p.id === selectedPlanId) || displayPlans[0] || mockPlans[0];

  const expanded = useMemo(() => {
    return plan.milestones.map((ms) => ({
      ...ms,
      expandedTasks: expandTasks(ms.tasks, ms.durationWeeks),
    }));
  }, [plan]);

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr);
    return `${d.getMonth() + 1}/${d.getDate()}`;
  };

  return (
    <div className="space-y-3">
      {/* Plan selector */}
      <div className="relative">
        <button
          onClick={() => setDropdownOpen(!dropdownOpen)}
          className="flex items-center gap-2 px-3 py-2 rounded-xl bg-secondary/30 border border-border/50 w-full text-left hover:bg-secondary/50 transition-colors"
        >
          <span className="text-base">{plan.emoji}</span>
          <span className="text-[13px] font-bold text-foreground flex-1">{plan.name}</span>
          {activePlans.length > 1 && (
            <span className="text-[9px] text-muted-foreground bg-muted rounded-full px-1.5 py-0.5">
              {activePlans.length}个计划并行
            </span>
          )}
          <ChevronDown className={cn("w-3.5 h-3.5 text-muted-foreground transition-transform", dropdownOpen && "rotate-180")} />
        </button>

        {/* Dropdown */}
        {dropdownOpen && (
          <motion.div
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            className="absolute z-20 top-full mt-1 left-0 right-0 bg-card border border-border rounded-xl shadow-lg overflow-hidden"
          >
            {displayPlans.map((p) => {
              const isActive = activePlanIds.includes(p.id);
              const isLactation = (LACTATION_PLAN_IDS as readonly string[]).includes(p.id);
              const isWork = (PARALLEL_PLAN_IDS as readonly string[]).includes(p.id);
              const activeFertility = activePlanIds.includes("fertility");
              const activeWork = activePlanIds.includes("work");
              // Work can parallel with maintain/chase/wean but not fertility
              const canParallel = isWork && !activeFertility;
              const isMutualWithFertility = isWork && activeFertility;
              return (
                <button
                  key={p.id}
                  onClick={() => { setSelectedPlanId(p.id); setDropdownOpen(false); }}
                  className={cn(
                    "flex items-center gap-2 w-full px-3 py-2.5 text-left transition-colors",
                    p.id === selectedPlanId ? "bg-primary/10" : "hover:bg-secondary/30",
                    !isActive && "opacity-50"
                  )}
                >
                  <span className="text-sm">{p.emoji}</span>
                  <span className="text-[12px] font-medium text-foreground flex-1">{p.name}</span>
                  {isWork && canParallel && (
                    <span className="text-[7px] text-muted-foreground bg-muted rounded px-1 py-0.5">可并行</span>
                  )}
                  {isMutualWithFertility && (
                    <span className="text-[7px] text-destructive/70 bg-destructive/10 rounded px-1 py-0.5">与待产互斥</span>
                  )}
                  {isActive && (
                    <span className="text-[8px] text-primary font-semibold bg-primary/10 rounded-full px-1.5 py-0.5">进行中</span>
                  )}
                  {!isActive && isLactation && !isWork && (
                    <span className="text-[7px] text-muted-foreground/50">互斥</span>
                  )}
                  {p.id === "fertility" && activeWork && !isActive && (
                    <span className="text-[7px] text-destructive/70 bg-destructive/10 rounded px-1 py-0.5">与返工互斥</span>
                  )}
                  {p.id === selectedPlanId && <Check className="w-3.5 h-3.5 text-primary" />}
                </button>
              );
            })}
          </motion.div>
        )}
      </div>

      {/* Close dropdown on outside click */}
      {dropdownOpen && (
        <div className="fixed inset-0 z-10" onClick={() => setDropdownOpen(false)} />
      )}

      {/* Vertical Timeline */}
      <div className="relative pl-5">
        {/* Timeline line */}
        <div className="absolute left-[9px] top-2 bottom-2 w-[2px] bg-border/40 rounded-full" />

        {expanded.map((ms, idx) => {
          const isCurrent = idx === plan.currentMilestoneIndex;
          const isPast = idx < plan.currentMilestoneIndex;
          const isFuture = idx > plan.currentMilestoneIndex;

          return (
            <motion.div
              key={ms.id}
              initial={{ opacity: 0, x: -12 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: idx * 0.08, duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
              className="relative mb-5 last:mb-0"
            >
              {/* Timeline dot */}
              <div className={cn(
                "absolute -left-5 top-0 w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center z-[1]",
                isCurrent
                  ? "border-primary bg-primary/20 shadow-[0_0_8px_hsl(var(--primary)/0.3)]"
                  : isPast
                    ? "border-primary/60 bg-primary/40"
                    : "border-border bg-background"
              )}>
                {isPast && <Check className="w-2.5 h-2.5 text-primary-foreground" />}
                {isCurrent && <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />}
              </div>

              {/* Current arrow indicator */}
              {isCurrent && (
                <motion.div
                  initial={{ opacity: 0, x: -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.3, duration: 0.5 }}
                  className="absolute -left-[52px] top-0 flex items-center"
                >
                  <ArrowRight className="w-4 h-4 text-primary" />
                </motion.div>
              )}

              {/* Start date */}
              <div className="flex items-center gap-2 mb-1.5">
                <span className={cn(
                  "text-[10px] font-mono font-bold",
                  isCurrent ? "text-primary" : isPast ? "text-muted-foreground" : "text-muted-foreground/50"
                )}>
                  {formatDate(ms.startDate)}
                </span>
                <span className={cn(
                  "text-[12px] font-bold",
                  isCurrent ? "text-foreground" : isPast ? "text-foreground/70" : "text-muted-foreground/60"
                )}>
                  {ms.label}
                </span>
                <span className={cn(
                  "text-[9px]",
                  isCurrent ? "text-primary/60" : "text-muted-foreground/40"
                )}>
                  {ms.durationWeeks}周
                </span>
              </div>

              {/* Mai encouragement for current milestone */}
              {isCurrent && (
                <motion.div
                  initial={{ opacity: 0, y: 6 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.4, duration: 0.5 }}
                  className="flex items-start gap-2 mb-2 px-2.5 py-2 rounded-lg bg-primary/5 border border-primary/15"
                >
                  <MaiAvatar emotion="encourage" size="xs" animate />
                  <p className="text-[11px] text-foreground/80 leading-relaxed flex-1">
                    {plan.maiSummary}
                  </p>
                </motion.div>
              )}

              {/* Tasks within this milestone */}
              <div className={cn(
                "space-y-0.5 rounded-lg overflow-hidden",
                isFuture && "opacity-40"
              )}>
                {ms.expandedTasks.map((dayGroup, di) => (
                  <div key={di} className="flex items-start gap-2 px-2 py-1 bg-secondary/15 rounded-md">
                    <span className="text-[9px] font-mono text-muted-foreground w-7 shrink-0 pt-0.5">
                      D{dayGroup.day}
                    </span>
                    <div className="flex flex-wrap gap-x-3 gap-y-0.5 flex-1">
                      {dayGroup.tasks.map((t, ti) => (
                        <span key={ti} className="flex items-center gap-0.5 text-[11px] text-foreground/80">
                          <span className="text-[10px]">{t.icon}</span>
                          {t.title}
                        </span>
                      ))}
                    </div>
                  </div>
                ))}
                {ms.expandedTasks.length > 0 && (
                  <p className="text-[8px] text-muted-foreground/40 px-2 py-0.5 italic">
                    ··· 按间隔循环至第{ms.durationWeeks}周
                  </p>
                )}
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
};

export default MilestoneTimeline;
