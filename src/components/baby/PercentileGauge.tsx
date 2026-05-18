import React, { useState } from "react";
import { Pencil, Check } from "lucide-react";
import { cn } from "@/lib/utils";

interface PercentileGaugeProps {
  label: string;
  icon: string;
  unit: string;
  value: number;
  p25: number;
  p50: number;
  p75: number;
  min: number;
  max: number;
  hint?: string;
  onValueChange?: (newValue: number) => void;
}

const PercentileGauge: React.FC<PercentileGaugeProps> = ({ label, icon, unit, value, p25, p50, p75, min, max, hint, onValueChange }) => {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(String(value));

  const range = max - min;
  const pct = (v: number) => Math.max(0, Math.min(100, ((v - min) / range) * 100));

  const valuePos = pct(value);
  const p25Pos = pct(p25);
  const p50Pos = pct(p50);
  const p75Pos = pct(p75);

  let zone: "low" | "normal" | "high" = "normal";
  if (value < p25) zone = "low";
  else if (value > p75) zone = "high";

  const handleEdit = () => {
    setDraft(String(value));
    setEditing(true);
  };

  const handleConfirm = () => {
    const num = parseFloat(draft);
    if (!isNaN(num) && num >= min && num <= max) {
      onValueChange?.(num);
    }
    setEditing(false);
  };

  return (
    <div className="flex-1 space-y-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-1">
          <span className="text-[11px] font-semibold text-muted-foreground">{icon} {label}</span>
          {hint && (
            <span className="text-[9px] text-muted-foreground/60 max-w-[140px] truncate" title={hint}>
              ℹ️
            </span>
          )}
        </div>
        <div className="flex items-center gap-1.5">
          {editing ? (
            <>
              <input
                type="number"
                step="0.1"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleConfirm()}
                className="w-16 text-sm font-bold text-right border border-primary/30 rounded-lg px-1.5 py-0.5 bg-background focus:outline-none focus:ring-1 focus:ring-primary"
                autoFocus
              />
              <span className="text-[11px] text-muted-foreground">{unit}</span>
              <button onClick={handleConfirm} className="p-0.5 rounded-full hover:bg-primary/10 transition-colors">
                <Check className="w-3.5 h-3.5 text-primary" />
              </button>
            </>
          ) : (
            <>
              <span className={cn(
                "text-sm font-bold",
                zone === "low" ? "text-destructive" : zone === "high" ? "text-primary" : "text-foreground"
              )}>
                {value}{unit}
              </span>
              {onValueChange && (
                <button onClick={handleEdit} className="p-0.5 rounded-full hover:bg-secondary transition-colors">
                  <Pencil className="w-3 h-3 text-muted-foreground" />
                </button>
              )}
            </>
          )}
        </div>
      </div>

      {/* Hint text */}
      {hint && (
        <p className="text-[9px] text-muted-foreground/70 leading-tight -mt-1">{hint}</p>
      )}

      {/* Track */}
      <div className="relative h-3 bg-secondary/60 rounded-full overflow-visible">
        <div
          className="absolute top-0 h-full bg-primary/10 rounded-full"
          style={{ left: `${p25Pos}%`, width: `${p75Pos - p25Pos}%` }}
        />
        <div
          className="absolute top-0 h-full bg-primary/20 rounded-full"
          style={{ left: `${p25Pos}%`, width: `${p50Pos - p25Pos}%` }}
        />

        {[{ pos: p25Pos, l: "25th" }, { pos: p50Pos, l: "50th" }, { pos: p75Pos, l: "75th" }].map((m) => (
          <div key={m.l} className="absolute top-0 h-full flex flex-col items-center" style={{ left: `${m.pos}%` }}>
            <div className="w-px h-full bg-border" />
          </div>
        ))}

        <div
          className="absolute top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border-2 border-background shadow-md"
          style={{
            left: `${valuePos}%`,
            transform: `translateX(-50%) translateY(-50%)`,
            backgroundColor: zone === "low" ? "hsl(var(--destructive))" : "hsl(var(--primary))",
          }}
        />
      </div>

      <div className="flex justify-between text-[9px] text-muted-foreground/60">
        <span>25th</span>
        <span>50th</span>
        <span>75th</span>
      </div>
    </div>
  );
};

export default PercentileGauge;
