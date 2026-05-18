import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useVolumeUnit, unitLabel } from "@/lib/volumeUnit";
import type { PumpRecord } from "@/data/mockData";

interface ManualEntryDialogProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (record: PumpRecord) => void | Promise<void>;
  editRecord?: PumpRecord | null;
  /** 新建记录时的日期 YYYY-MM-DD，默认当天 */
  recordDateIso?: string;
  /** 新建时预填开始时间（如从计划任务带入 HH:mm）；无效或未传则用当前时间 */
  defaultTime?: string | null;
}

const ManualEntryDialog: React.FC<ManualEntryDialogProps> = ({
  open,
  onClose,
  onSubmit,
  editRecord,
  recordDateIso,
  defaultTime,
}) => {
  const [volUnit] = useVolumeUnit();
  const isOz = volUnit === "oz";
  const convToDisplay = (ml: number) => isOz ? +(ml * 0.033814).toFixed(1) : ml;
  const convToMl = (val: number) => isOz ? Math.round(val / 0.033814) : val;

  const [startTime, setStartTime] = useState(() => {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  });
  const [leftMl, setLeftMl] = useState("");
  const [rightMl, setRightMl] = useState("");
  const [duration, setDuration] = useState("");
  const [submitBusy, setSubmitBusy] = useState(false);

  useEffect(() => {
    if (open) setSubmitBusy(false);
  }, [open]);

  useEffect(() => {
    if (editRecord) {
      setStartTime(editRecord.time || "08:00");
      setLeftMl(String(convToDisplay(editRecord.leftMl)));
      setRightMl(String(convToDisplay(editRecord.rightMl)));
      setDuration(editRecord.durationMin > 0 ? String(editRecord.durationMin) : "");
    } else {
      const raw = (defaultTime ?? "").trim();
      const m = raw.match(/^(\d{1,2}):(\d{2})/);
      const fromPreset =
        m &&
        `${String(Number(m[1])).padStart(2, "0")}:${String(Number(m[2])).padStart(2, "0")}`;
      const now = new Date();
      const nowStr = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
      setStartTime(fromPreset || nowStr);
      setLeftMl("");
      setRightMl("");
      setDuration("");
    }
  }, [editRecord, open, defaultTime]);

  const leftVal = parseFloat(leftMl) || 0;
  const rightVal = parseFloat(rightMl) || 0;
  const totalDisplay = isOz ? +(leftVal + rightVal).toFixed(1) : leftVal + rightVal;
  const isValid = totalDisplay > 0;

  const handleSubmit = async () => {
    const leftMlVal = convToMl(leftVal);
    const rightMlVal = convToMl(rightVal);
    const totalMlVal = leftMlVal + rightMlVal;
    const dur = parseInt(duration, 10) || 0;
    const newRecordDate = recordDateIso?.trim() || new Date().toISOString().slice(0, 10);

    const record: PumpRecord = editRecord
      ? {
          ...editRecord,
          time: startTime,
          totalMl: totalMlVal,
          leftMl: leftMlVal,
          rightMl: rightMlVal,
          durationMin: dur,
          source: "manual",
          subLabel: "补录",
          category: "inventory",
        }
      : {
          id: `manual-${Date.now()}`,
          date: newRecordDate,
          time: startTime,
          durationMin: dur,
          leftMl: leftMlVal,
          rightMl: rightMlVal,
          totalMl: totalMlVal,
          source: "manual",
          mode: "deep",
          subLabel: "补录",
          category: "inventory",
        };
    setSubmitBusy(true);
    try {
      await Promise.resolve(onSubmit(record));
      onClose();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "操作失败，请稍后重试";
      alert(msg);
    } finally {
      setSubmitBusy(false);
    }
  };

  const uLabel = unitLabel(volUnit);

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-foreground/20 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ y: "100%", opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: "100%", opacity: 0 }}
            transition={{ type: "spring", damping: 28, stiffness: 300 }}
            className="fixed inset-x-0 bottom-0 z-50 rounded-t-3xl bg-card border-t border-border shadow-2xl px-5 pt-4 pb-8"
          >
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-foreground">
                {editRecord ? "修改吸奶补录" : "🤱 吸奶补录"}
              </h3>
              <button onClick={onClose} className="p-1 rounded-full hover:bg-secondary transition-colors">
                <X className="w-5 h-5 text-muted-foreground" />
              </button>
            </div>

            {/* Description */}
            <p className="text-[11px] text-muted-foreground leading-relaxed mb-4 bg-secondary/50 rounded-xl px-3 py-2">
              📝 吸奶补录是指<span className="font-semibold text-foreground">吸奶器未连接APP时或者通过其他方式</span>获取的母乳，通过手动录入的方式计入可用母乳库存。
            </p>

            <div className="space-y-3 mb-4">
              {/* Start time */}
              <div>
                <label className="text-xs font-semibold text-muted-foreground mb-1 block">开始吸奶时间</label>
                <input
                  type="time"
                  value={startTime}
                  onChange={(e) => setStartTime(e.target.value)}
                  className="w-full h-10 rounded-xl bg-muted/60 border border-border/50 px-3 text-sm text-foreground outline-none focus:border-primary/50 transition-colors"
                />
              </div>

              {/* Left / Right */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-xs font-semibold text-muted-foreground mb-1 block">吸奶量（左侧）</label>
                  <div className="flex items-center gap-1.5">
                    <input
                      type="number"
                      inputMode="decimal"
                      min="0"
                      value={leftMl}
                      onChange={(e) => setLeftMl(e.target.value)}
                      placeholder="0"
                      className="min-w-0 flex-1 h-10 rounded-xl bg-muted/60 border border-border/50 px-3 text-sm text-foreground placeholder:text-muted-foreground/40 outline-none focus:border-primary/50 transition-colors text-center font-bold"
                      autoFocus
                    />
                    <span className="text-xs text-muted-foreground w-6 shrink-0 text-center">{uLabel}</span>
                  </div>
                </div>
                <div>
                  <label className="text-xs font-semibold text-muted-foreground mb-1 block">吸奶量（右侧）</label>
                  <div className="flex items-center gap-1.5">
                    <input
                      type="number"
                      inputMode="decimal"
                      min="0"
                      value={rightMl}
                      onChange={(e) => setRightMl(e.target.value)}
                      placeholder="0"
                      className="min-w-0 flex-1 h-10 rounded-xl bg-muted/60 border border-border/50 px-3 text-sm text-foreground placeholder:text-muted-foreground/40 outline-none focus:border-primary/50 transition-colors text-center font-bold"
                    />
                    <span className="text-xs text-muted-foreground w-6 shrink-0 text-center">{uLabel}</span>
                  </div>
                </div>
              </div>

              {/* Total display */}
              {isValid && (
                <motion.div
                  initial={{ opacity: 0, y: -4 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="text-center py-1.5 rounded-lg bg-primary/10 border border-primary/15"
                >
                  <span className="text-xs text-muted-foreground">总奶量：</span>
                  <span className="text-sm font-bold text-primary">{totalDisplay} {uLabel}</span>
                </motion.div>
              )}

              {/* Duration (optional) */}
              <div>
                <label className="text-xs font-semibold text-muted-foreground mb-1 block">
                  吸奶时长 <span className="text-muted-foreground/50 font-normal">（选填）</span>
                </label>
                <div className="flex items-center gap-1.5">
                  <input
                    type="number"
                    inputMode="numeric"
                    min="0"
                    value={duration}
                    onChange={(e) => setDuration(e.target.value.replace(/\D/g, ""))}
                    placeholder="例如 15"
                    className="w-24 h-10 rounded-xl bg-muted/60 border border-border/50 px-3 text-sm text-foreground placeholder:text-muted-foreground/40 outline-none focus:border-primary/50 transition-colors"
                  />
                  <span className="text-xs text-muted-foreground">min</span>
                </div>
              </div>
            </div>

            <Button
              onClick={() => void handleSubmit()}
              disabled={!isValid || submitBusy}
              className="w-full h-12 rounded-xl text-base font-bold"
            >
              {submitBusy ? "提交中…" : editRecord ? "确认修改" : "添加记录"}
            </Button>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default ManualEntryDialog;
