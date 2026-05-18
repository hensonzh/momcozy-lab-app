import React, { useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { CheckCircle2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { ScheduleTask } from "@/data/mockData";
import { pumpRecords, dailySummary } from "@/data/mockData";

interface Props {
  open: boolean;
  onClose: () => void;
  tasks: ScheduleTask[];
}

const DayEndSummary: React.FC<Props> = ({ open, onClose, tasks }) => {
  const allTasks = tasks.filter((t) => t.type !== "meeting" && !t.id.startsWith("blocked-"));
  const doneTasks = allTasks.filter((t) => t.done);
  const manualCount = doneTasks.filter((t) => t.doneSource === "manual").length;
  const systemCount = doneTasks.filter((t) => t.doneSource === "system").length;
  const undoneTasks = allTasks.filter((t) => !t.done);

  // Today's milk data from system records
  const todayStr = "2026-03-09"; // mock today
  const todayMilkTotal = useMemo(() => {
    const todayRecords = pumpRecords.filter((r) => r.date === todayStr);
    return todayRecords.reduce((s, r) => s + r.totalMl, 0);
  }, []);

  const todayFeedingTotal = useMemo(() => {
    const last = dailySummary[dailySummary.length - 1];
    return last?.total || 0;
  }, []);

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[80] bg-foreground/40 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ scale: 0.85, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.85, opacity: 0 }}
            className="fixed z-[80] inset-0 m-auto w-[88vw] max-w-sm h-fit bg-card border border-border rounded-2xl shadow-2xl overflow-hidden"
          >
            {/* Header */}
            <div className="flex items-center gap-2.5 px-4 pt-4 pb-2">
              <MaiAvatar emotion="happy" size="sm" animate />
              <div>
                <p className="text-sm font-bold text-foreground">今日日结</p>
                <p className="text-[10px] text-muted-foreground">
                  {doneTasks.length}/{allTasks.length} 项已完成
                </p>
              </div>
            </div>

            {/* Today's milk summary card */}
            <div className="px-4 pb-2">
              <div className="flex gap-2">
                <div className="flex-1 rounded-xl bg-primary/5 border border-primary/15 px-3 py-2 text-center">
                  <p className="text-[9px] text-muted-foreground mb-0.5">🍼 今日总奶量</p>
                  <p className="text-[16px] font-bold text-primary">{todayMilkTotal}<span className="text-[10px] font-normal text-muted-foreground ml-0.5">ml</span></p>
                </div>
                <div className="flex-1 rounded-xl bg-accent/30 border border-accent-foreground/10 px-3 py-2 text-center">
                  <p className="text-[9px] text-muted-foreground mb-0.5">🤱 宝宝总喂养量</p>
                  <p className="text-[16px] font-bold text-foreground">{todayFeedingTotal}<span className="text-[10px] font-normal text-muted-foreground ml-0.5">ml</span></p>
                </div>
              </div>
            </div>

            {/* Stats badges */}
            <div className="px-4 pb-2 flex items-center gap-2 flex-wrap">
              {manualCount > 0 && (
                <Badge variant="secondary" className="text-[9px] px-1.5 py-0.5 bg-accent/60 text-accent-foreground/80">
                  ✋ 手动 {manualCount}
                </Badge>
              )}
              {systemCount > 0 && (
                <Badge variant="secondary" className="text-[9px] px-1.5 py-0.5 bg-primary/10 text-primary">
                  ⚙️ 系统 {systemCount}
                </Badge>
              )}
              {undoneTasks.length > 0 && (
                <Badge variant="outline" className="text-[9px] px-1.5 py-0.5 border-muted-foreground/30 text-muted-foreground">
                  未完成 {undoneTasks.length}
                </Badge>
              )}
            </div>

            <div className="px-4 pb-4">
              <div className="space-y-1 max-h-[35vh] overflow-y-auto py-1">
                {allTasks.map((task) => {
                  const isDone = task.done;

                  return (
                    <div
                      key={task.id}
                      className={`flex items-center gap-2 px-2.5 py-1.5 rounded-lg ${isDone ? "bg-secondary/30" : "bg-muted/20"}`}
                    >
                      <span className="text-[11px] font-mono text-muted-foreground w-10">{task.time}</span>
                      <span
                        className={`text-[12px] font-medium flex-1 ${
                          isDone ? "line-through text-muted-foreground/60" : "text-foreground/50"
                        }`}
                      >
                        {task.title}
                      </span>
                      {isDone && task.doneSource && (
                        <Badge
                          variant="secondary"
                          className={`text-[8px] px-1 py-0 h-3.5 shrink-0 ${
                            task.doneSource === "manual"
                              ? "bg-accent/60 text-accent-foreground/80"
                              : "bg-primary/10 text-primary"
                          }`}
                        >
                          {task.doneSource === "manual" ? "手动" : "系统"}
                        </Badge>
                      )}
                      {isDone && <CheckCircle2 className="w-3 h-3 text-primary/40 shrink-0" />}
                      {!isDone && (
                        <span className="text-[9px] text-muted-foreground/50">未完成</span>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default DayEndSummary;
