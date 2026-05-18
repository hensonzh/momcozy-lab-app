import React, { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

interface TimeWheelPickerSheetProps {
  open: boolean;
  value: string;
  title?: string;
  onClose: () => void;
  onConfirm: (time: string) => void;
}

const pad2 = (n: number) => String(n).padStart(2, "0");

const TimeWheelPickerSheet: React.FC<TimeWheelPickerSheetProps> = ({
  open,
  value,
  title = "设置时间",
  onClose,
  onConfirm,
}) => {
  const [hour, setHour] = useState("00");
  const [minute, setMinute] = useState("00");
  const hourRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const minuteRefs = useRef<Array<HTMLButtonElement | null>>([]);

  const hours = useMemo(() => Array.from({ length: 24 }, (_, i) => pad2(i)), []);
  const minutes = useMemo(() => Array.from({ length: 60 }, (_, i) => pad2(i)), []);

  useEffect(() => {
    if (!open) return;
    const [h = "00", m = "00"] = value.split(":");
    setHour(hours.includes(h) ? h : "00");
    setMinute(minutes.includes(m) ? m : "00");
  }, [open, value, hours, minutes]);

  useEffect(() => {
    if (!open) return;
    const hourIdx = Number(hour);
    const minuteIdx = Number(minute);
    hourRefs.current[hourIdx]?.scrollIntoView({ block: "center", behavior: "smooth" });
    minuteRefs.current[minuteIdx]?.scrollIntoView({ block: "center", behavior: "smooth" });
  }, [open, hour, minute]);

  const handleConfirm = () => {
    onConfirm(`${hour}:${minute}`);
    onClose();
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[90] bg-foreground/30 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ y: "100%", opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: "100%", opacity: 0 }}
            transition={{ type: "spring", damping: 28, stiffness: 300 }}
            className="fixed inset-x-0 bottom-0 z-[91] rounded-t-3xl bg-card border-t border-border shadow-2xl px-5 pt-5 pb-6"
          >
            <div className="text-center mb-4">
              <p className="text-[16px] font-bold text-foreground">{title}</p>
            </div>

            <div className="mb-4 rounded-2xl border border-primary/30 bg-primary/10 py-3 text-center">
              <p className="text-[11px] font-semibold tracking-wide text-primary/80">当前调节时间</p>
              <p className="mt-0.5 text-[30px] leading-none font-black text-primary tabular-nums">
                {hour}:{minute}
              </p>
            </div>

            <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-2 mb-5">
              <div className="h-44 overflow-y-auto rounded-2xl border border-border/50 bg-secondary/20 py-2">
                {hours.map((h, idx) => (
                  <button
                    key={h}
                    ref={(el) => (hourRefs.current[idx] = el)}
                    onClick={() => setHour(h)}
                    className={`w-full h-9 text-center text-[16px] font-semibold transition-colors ${
                      hour === h ? "text-primary bg-primary/10" : "text-muted-foreground hover:bg-secondary/60"
                    }`}
                  >
                    {h}
                  </button>
                ))}
              </div>
              <span className="text-[18px] font-bold text-muted-foreground">:</span>
              <div className="h-44 overflow-y-auto rounded-2xl border border-border/50 bg-secondary/20 py-2">
                {minutes.map((m, idx) => (
                  <button
                    key={m}
                    ref={(el) => (minuteRefs.current[idx] = el)}
                    onClick={() => setMinute(m)}
                    className={`w-full h-9 text-center text-[16px] font-semibold transition-colors ${
                      minute === m ? "text-primary bg-primary/10" : "text-muted-foreground hover:bg-secondary/60"
                    }`}
                  >
                    {m}
                  </button>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2.5">
              <button
                onClick={onClose}
                className="h-11 rounded-xl bg-secondary/80 text-foreground text-[14px] font-bold"
              >
                取消
              </button>
              <button
                onClick={handleConfirm}
                className="h-11 rounded-xl bg-primary text-primary-foreground text-[14px] font-bold"
              >
                确认
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default TimeWheelPickerSheet;
