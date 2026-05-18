import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { useVolumeUnit, unitLabel } from "@/lib/volumeUnit";
import type { PumpRecord } from "@/data/mockData";

type FeedingType = "配方奶" | "亲喂" | "瓶喂母乳";

interface FeedingEntryDialogProps {
  open: boolean;
  onClose: () => void;
  /** 提交新建或编辑后的喂养记录；可传入 async 由父组件负责 HTTP */
  onSubmit: (record: PumpRecord) => void | Promise<void>;
  editRecord?: PumpRecord | null;
  /** 新增记录时的日期 YYYY-MM-DD，默认当天 */
  recordDateIso?: string;
  /** 新建时预填喂养时间（如从计划任务带入 HH:mm）；无效或未传则用当前时间 */
  defaultTime?: string | null;
}

const feedingTypes: { key: FeedingType; label: string; color: string }[] = [
  { key: "配方奶", label: "🧪 配方奶", color: "mai-warm" },
  { key: "亲喂", label: "🤱 亲喂", color: "accent" },
  { key: "瓶喂母乳", label: "🍼 瓶喂母乳", color: "primary" },
];

const FeedingEntryDialog: React.FC<FeedingEntryDialogProps> = ({
  open,
  onClose,
  onSubmit,
  editRecord,
  recordDateIso,
  defaultTime,
}) => {
  const [feedingType, setFeedingType] = useState<FeedingType>("配方奶");
  const [value, setValue] = useState("");
  const [feedStartTime, setFeedStartTime] = useState(() => {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  });
  const [volUnit] = useVolumeUnit();
  const [submitBusy, setSubmitBusy] = useState(false);

  useEffect(() => {
    if (open) setSubmitBusy(false);
  }, [open]);

  useEffect(() => {
    if (editRecord) {
      if (editRecord.subLabel === "亲喂") {
        setFeedingType("亲喂");
        setValue(editRecord.durationMin > 0 ? String(editRecord.durationMin) : "");
        setFeedStartTime(editRecord.time || "08:00");
      } else if (editRecord.subLabel === "配方奶") {
        setFeedingType("配方奶");
        const val = volUnit === "oz" ? +(editRecord.totalMl * 0.033814).toFixed(1) : editRecord.totalMl;
        setValue(val > 0 ? String(val) : "");
      } else {
        setFeedingType("瓶喂母乳");
        const val = volUnit === "oz" ? +(editRecord.totalMl * 0.033814).toFixed(1) : editRecord.totalMl;
        setValue(val > 0 ? String(val) : "");
      }
    } else {
      setFeedingType("配方奶");
      setValue("");
      const raw = (defaultTime ?? "").trim();
      const m = raw.match(/^(\d{1,2}):(\d{2})/);
      const fromPreset =
        m &&
        `${String(Number(m[1])).padStart(2, "0")}:${String(Number(m[2])).padStart(2, "0")}`;
      const now = new Date();
      const nowStr = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
      setFeedStartTime(fromPreset || nowStr);
    }
  }, [editRecord, open, defaultTime]);

  const isVolume = feedingType !== "亲喂";
  const inputLabel = feedingType === "亲喂" ? "亲喂时长" : `${feedingType === "配方奶" ? "配方奶量" : "瓶喂母乳量"} (${unitLabel(volUnit)})`;
  const placeholder = feedingType === "亲喂" ? "例如: 15" : volUnit === "oz" ? "例如: 3.5" : "例如: 100";

  const handleSubmit = async () => {
    const time = feedStartTime;
    const newRecordDate =
      recordDateIso?.trim() || new Date().toISOString().slice(0, 10);
    const rawVal = parseFloat(value) || 0;

    let totalMl = 0;
    let durationMin = 0;

    if (feedingType === "亲喂") {
      durationMin = rawVal;
    } else {
      totalMl = volUnit === "oz" ? Math.round(rawVal / 0.033814) : rawVal;
    }

    const subLabel = feedingType === "瓶喂母乳" ? "瓶喂" as const : feedingType as "配方奶" | "亲喂";

    const record: PumpRecord = editRecord
      ? {
          ...editRecord,
          totalMl,
          leftMl: Math.round(totalMl / 2),
          rightMl: Math.ceil(totalMl / 2),
          durationMin,
          source: "manual",
          subLabel,
          category: "feeding",
        }
      : {
          id: `feeding-${Date.now()}`,
          date: newRecordDate,
          time,
          durationMin,
          leftMl: Math.round(totalMl / 2),
          rightMl: Math.ceil(totalMl / 2),
          totalMl,
          source: "manual",
          mode: "deep",
          subLabel,
          category: "feeding",
        };
    setSubmitBusy(true);
    try {
      await Promise.resolve(onSubmit(record));
      onClose();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "提交失败，请稍后重试";
      alert(msg);
    } finally {
      setSubmitBusy(false);
    }
  };

  const isValid = feedingType === "亲喂" ? true : (parseFloat(value) || 0) > 0;

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
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-foreground">
                {editRecord ? "修改喂养记录" : "+ 喂养记录"}
              </h3>
              <button onClick={onClose} className="p-1 rounded-full hover:bg-secondary transition-colors">
                <X className="w-5 h-5 text-muted-foreground" />
              </button>
            </div>

            {/* Type selection */}
            <div className="flex gap-2 mb-4">
              {feedingTypes.map((t) => (
                <button
                  key={t.key}
                  onClick={() => { setFeedingType(t.key); setValue(""); }}
                  className={cn(
                    "flex-1 py-2.5 rounded-xl text-xs font-semibold transition-all border",
                    feedingType === t.key
                      ? t.key === "配方奶"
                        ? "bg-mai-warm/15 border-mai-warm/30 text-foreground"
                        : t.key === "亲喂"
                          ? "bg-accent/20 border-accent/30 text-foreground"
                          : "bg-primary/10 border-primary/20 text-foreground"
                      : "bg-muted/50 border-border text-muted-foreground hover:bg-muted"
                  )}
                >
                  {t.label}
                </button>
              ))}
            </div>

            {/* Input fields */}
            <div className="space-y-2.5 mb-4">
              {/* Time — always shown */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-muted-foreground mb-0.5 block">喂养时间</label>
                  <input
                    type="time"
                    value={feedStartTime}
                    onChange={(e) => setFeedStartTime(e.target.value)}
                    className="w-full h-9 rounded-xl bg-muted/60 border border-border/50 px-2.5 text-sm text-foreground outline-none focus:border-primary/50 transition-colors"
                  />
                </div>
                {feedingType === "亲喂" ? (
                  <div>
                    <label className="text-[11px] font-semibold text-muted-foreground mb-0.5 block">
                      时长 <span className="text-muted-foreground/50 font-normal">(选填)</span>
                    </label>
                    <div className="flex items-center gap-1">
                      <Input
                        type="number"
                        value={value}
                        onChange={(e) => setValue(e.target.value)}
                        placeholder="15"
                        className="h-9 text-center font-bold rounded-xl"
                      />
                      <span className="text-[10px] text-muted-foreground shrink-0">min</span>
                    </div>
                  </div>
                ) : (
                  <div>
                    <label className="text-[11px] font-semibold text-muted-foreground mb-0.5 block">
                      {feedingType === "配方奶" ? "配方奶量" : "瓶喂奶量"} ({unitLabel(volUnit)})
                    </label>
                    <Input
                      type="number"
                      value={value}
                      onChange={(e) => setValue(e.target.value)}
                      placeholder={volUnit === "oz" ? "3.5" : "100"}
                      className="h-9 text-center font-bold rounded-xl"
                    />
                  </div>
                )}
              </div>
              {feedingType === "亲喂" && (
                <p className="text-[9px] text-muted-foreground/60 italic">🤱 亲喂时长可用于粗略估算奶量，不作为精确依据</p>
              )}
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

export default FeedingEntryDialog;
