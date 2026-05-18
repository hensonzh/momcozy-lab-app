import React from "react";
import { motion } from "framer-motion";
import { HelpCircle } from "lucide-react";
import { cn } from "@/lib/utils";

interface Props {
  side: "L" | "R";
  label?: string;
  progress: number;
  target: number;
  targetOffset?: number;
  flow: number;
  isLetdown: boolean;
  inExtend: boolean;
  extendTime: number;
  onHelpClick?: () => void;
}

const MilkProgressBar: React.FC<Props> = ({
  side, label: labelProp, progress, target, targetOffset = 10, flow, isLetdown, inExtend, extendTime, onHelpClick,
}) => {
  const label = labelProp || (side === "L" ? "Left" : "Right");
  const isLeft = side === "L";
  const showLabel = label !== "综合";
  const fmtExt = (s: number) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  const breathScale = inExtend ? 1 + Math.min(0.6, flow * 0.04) : 1;
  const baseHue = isLeft ? "343" : "340";

  const mainWidth = 90;
  const safeOffset = Math.max(0, Math.min(100, targetOffset));
  const greenStart = Math.max(0, Math.min(100, target - safeOffset));
  const greenEnd = Math.max(greenStart, Math.min(100, target + safeOffset));
  // 将“延长时间展示”与“游标是否进入延长段”解耦：
  // inExtend 用于文案/计时展示；游标位置和颜色以进度是否达到 100 为准。
  const cursorInExtend = progress >= 100;

  const cursorPct = cursorInExtend
    ? mainWidth + 5
    : Math.min(mainWidth, (progress / 100) * mainWidth);

  const greenLeftPct = (greenStart / 100) * 100;
  const greenRightPct = (greenEnd / 100) * 100;
  const targetTickPct = (target / 100) * 100;

  return (
    <div className="flex-1 flex flex-col">
      {/* Row 1: Side label + 100% + extend info */}
      <div className="relative px-0.5 mb-1 h-[16px]">
        {showLabel && <span className="text-[11px] font-bold text-muted-foreground">{label}</span>}
        <span
          className="absolute text-[8px] font-bold text-foreground/50 leading-none"
          style={{ left: `${mainWidth}%`, transform: 'translateX(-50%)', bottom: 0 }}
        >100%</span>
        <div
          className="absolute bottom-0 flex items-center gap-1 leading-none whitespace-nowrap"
          style={{ left: `${mainWidth}%`, transform: "translateX(calc(-100% - 2px))" }}
        >
          <span className="w-[5px] h-[5px] rounded-full bg-[hsl(25_80%_60%)]" />
          <span className="text-[8px] font-bold text-orange-500/80">延长吸乳</span>
          <span className="inline-flex w-[52px] justify-start overflow-hidden">
            <motion.span
              initial={false}
              animate={{ opacity: inExtend ? 1 : 0 }}
              transition={{ duration: 0.2 }}
              className="text-[8px] font-bold tabular-nums text-orange-500 whitespace-nowrap"
            >
              ⏱&nbsp;{fmtExt(extendTime)}
            </motion.span>
          </span>
        </div>
      </div>

      {/* Row 2: The bar */}
      <div className="relative h-[18px] flex overflow-visible">
        {/* Main segment (90%) */}
        <div className="relative rounded-l-full overflow-hidden bg-muted/30 border border-border/20" style={{ width: `${mainWidth}%`, height: '100%' }}>
          {/* Filled progress */}
          <div
            className="absolute inset-y-0 left-0 rounded-l-full transition-all duration-300"
            style={{
              width: `${Math.min(100, progress)}%`,
              background: `linear-gradient(90deg, hsl(${baseHue} 30% 88%), hsl(${baseHue} 40% 65%), hsl(${baseHue} 45% 35%))`,
            }}
          />
          {/* Green zone with gradient edges */}
          <div
            className="absolute inset-y-0"
            style={{
              left: `${greenLeftPct}%`,
              width: `${greenRightPct - greenLeftPct}%`,
              background: 'linear-gradient(90deg, hsl(158 55% 52% / 0) 0%, hsl(158 55% 52% / 0.55) 20%, hsl(158 55% 52% / 0.55) 80%, hsl(158 55% 52% / 0) 100%)',
            }}
          />
          {/* Quarter marks */}
          {[25, 50, 75].map(mark => (
            <div key={mark} className="absolute top-0 bottom-0" style={{ left: `${mark}%`, transform: 'translateX(-50%)' }}>
              <div className="w-px h-full bg-background/50" />
            </div>
          ))}
          {/* Target tick */}
          <div className="absolute" style={{ left: `${targetTickPct}%`, transform: 'translateX(-50%)', top: '-4px', bottom: '-4px' }}>
            <div className="w-[2px] h-full bg-foreground rounded-full shadow-sm" />
          </div>
        </div>
        {/* Gap */}
        <div className="w-[3px]" />
        {/* Extend segment (10%) */}
        <div className="relative rounded-r-full overflow-hidden border border-orange-300/40" style={{ width: '10%', height: '100%', background: 'hsl(25 80% 60%)' }} />

        {/* Moving cursor */}
        <motion.div
          className="absolute z-10 pointer-events-none"
          style={{ left: `${cursorPct}%`, top: '50%', x: '-50%', y: '-50%' }}
          animate={
            isLetdown && !cursorInExtend
              ? { scale: [1, 1.8, 1] }
              : cursorInExtend
                ? { scale: [1, breathScale, 1] }
                : {}
          }
          transition={
            isLetdown ? { duration: 0.6, repeat: Infinity, ease: "easeInOut" }
            : cursorInExtend ? { duration: 1.5 + Math.max(0, 2 - flow * 0.15), repeat: Infinity, ease: "easeInOut" }
            : {}
          }
        >
          <div className={cn(
            "w-4 h-4 rounded-full border-2 shadow-md",
            isLetdown ? "bg-orange-400 border-orange-200 shadow-orange-400/50"
            : cursorInExtend ? "bg-orange-400 border-orange-200 shadow-orange-400/40"
            : "bg-primary border-primary-foreground shadow-primary/30"
          )} />
        </motion.div>
      </div>

      {/* Row 3: Below-bar target/help only */}
      <div className="relative h-[20px] mt-[3px]">
        {/*
        Target indicator
        <div className="absolute flex items-start" style={{ left: `${(target / 100) * mainWidth}%`, transform: 'translateX(-50%)', top: 0 }}>
          <div className="flex items-center gap-[3px] bg-primary/10 border border-primary/30 rounded px-1 py-[2px]">
            <span className="text-[8px] leading-none">🎯</span>
            {onHelpClick && (
              <button
                onClick={(e) => { e.stopPropagation(); onHelpClick(); }}
                className="w-[12px] h-[12px] rounded-full bg-muted/60 flex items-center justify-center hover:bg-muted transition-colors"
              >
                <HelpCircle className="w-[8px] h-[8px] text-muted-foreground" />
              </button>
            )}
          </div>
        </div>
        */}

      </div>
    </div>
  );
};

export default React.memo(MilkProgressBar);
