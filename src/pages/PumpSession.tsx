import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { ArrowLeft, Minus, Plus, Pause, Play, Square, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { motion, AnimatePresence } from "framer-motion";
import { useVolumeUnit, formatVol } from "@/lib/volumeUnit";
import { deviceStore } from "@/lib/deviceStore";
import {
  pumpSessionLifecycle,
  getPumpSessionDeviceDerived,
  type PumpSessionEndedEvent,
  type PumpSessionEndReason,
} from "@/lib/pumpSessionLifecycle";
import { getProcessAll, setProcessAll } from "@/lib/pumpSessionProgress";
import { createScopedConsole } from "@/lib/logger";
import { toast } from "@/components/ui/use-toast";

const pumpSessionPageLogger = createScopedConsole("PumpSessionPage");
import {
  type PumpMode,
  type MockFlow,
  type SessionState,
  type SideState,
  initialElapsedFromStore,
  syncModeButtonHighlight,
} from "@/pages/pumpSession/pumpSessionModel";
import { usePumpSessionController } from "@/pages/pumpSession/usePumpSessionController";
import { usePumpCalibrationRuntime } from "@/pages/pumpSession/usePumpCalibrationRuntime";
import { usePumpRealDisplayRuntime } from "@/pages/pumpSession/usePumpRealDisplayRuntime";


// ═══════════════════════════════════════════════════════════════
// VISUAL SUB-COMPONENTS (Warm Cartoon Style)
// ═══════════════════════════════════════════════════════════════

// ─── Cute round breast with kawaii style ─────────────────────
const BreastDrop = React.memo(({ side, flow, drainPct, opacity, isLetdown }: {
  side: "L" | "R"; flow: number; drainPct: number; opacity: number; isLetdown: boolean;
}) => {
  const fill = Math.max(0, Math.min(100, 100 - drainPct));
  const fy = 78 - (fill / 100) * 54;
  const isLeft = side === "L";
  const mainHue = isLeft ? "343 45% 55%" : "340 50% 68%";
  const softHue = isLeft ? "350 65% 85%" : "340 40% 88%";
  const bubbleCount = Math.min(5, Math.floor(flow / 3));
  const label = isLeft ? "Left" : "Right";

  return (
    <motion.div
      animate={isLetdown
        ? { scale: [1, 1.08, 0.97, 1.05, 1] }
        : { scale: [1, 1.02, 1] }
      }
      transition={isLetdown
        ? { duration: 1.2, repeat: Infinity, ease: "easeInOut" }
        : { duration: 2.5, repeat: Infinity, ease: "easeInOut" }
      }
      className="flex flex-col items-center gap-1"
      style={{ opacity, willChange: "transform" }}
    >
      <div className="relative">
        {/* Outer glow ring during letdown */}
        {isLetdown && (
          <motion.div
            animate={{ scale: [1, 1.4, 1], opacity: [0.4, 0, 0.4] }}
            transition={{ duration: 1.5, repeat: Infinity }}
            className="absolute -inset-3 rounded-full"
            style={{ background: `radial-gradient(circle, hsl(${softHue} / 0.4), transparent 70%)` }}
          />
        )}
        <svg width="64" height="80" viewBox="0 0 64 84" className="overflow-visible drop-shadow-md">
          <defs>
            <clipPath id={`drop-${side}`}>
              <path d="M32,8 C32,8 6,30 6,52 C6,70 17,80 32,80 C47,80 58,70 58,52 C58,30 32,8 32,8 Z" />
            </clipPath>
            <radialGradient id={`dg-${side}`} cx="35%" cy="35%" r="65%">
              <stop offset="0%" stopColor={`hsl(${softHue})`} />
              <stop offset="60%" stopColor={`hsl(${mainHue} / 0.6)`} />
              <stop offset="100%" stopColor={`hsl(${mainHue} / 0.3)`} />
            </radialGradient>
            <linearGradient id={`dl-${side}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={`hsl(30 50% 95% / 0.9)`} />
              <stop offset="100%" stopColor={`hsl(${softHue} / 0.7)`} />
            </linearGradient>
            <filter id={`soft-${side}`}>
              <feGaussianBlur stdDeviation="0.8" />
            </filter>
          </defs>
          <ellipse cx="32" cy="54" rx="30" ry="28" fill={`hsl(${mainHue} / 0.08)`} filter={`url(#soft-${side})`} />
          <path d="M32,8 C32,8 6,30 6,52 C6,70 17,80 32,80 C47,80 58,70 58,52 C58,30 32,8 32,8 Z"
            fill={`url(#dg-${side})`} stroke={`hsl(${mainHue} / 0.25)`} strokeWidth="1.5" strokeLinejoin="round" />
          <g clipPath={`url(#drop-${side})`}>
            <rect x="0" y={fy} width="64" height={84 - fy} fill={`url(#dl-${side})`} className="transition-all duration-700" />
            {fill > 5 && (
              <>
                <path d={`M0,${fy + 2} Q16,${fy - 4} 32,${fy + 2} Q48,${fy + 6} 64,${fy + 2} V84 H0 Z`}
                  fill={`hsl(30 40% 92% / 0.4)`} className="breast-wave" />
                <path d={`M0,${fy + 3} Q20,${fy + 7} 40,${fy + 3} Q56,${fy - 1} 64,${fy + 3} V84 H0 Z`}
                  fill={`hsl(${softHue} / 0.2)`}
                  style={{ animation: "breast-wave-drift 3.5s ease-in-out infinite reverse" }} />
              </>
            )}
            {bubbleCount > 0 && Array.from({ length: bubbleCount }).map((_, i) => (
              <circle key={`b${i}`}
                cx={12 + i * 12 + Math.sin(i) * 5}
                cy={fy + 8 + i * 4}
                r={1.5 + (i % 2)}
                fill="white" opacity={0.35}>
                <animate attributeName="cy" values={`${fy + 10 + i * 3};${fy + 2};${fy + 10 + i * 3}`}
                  dur={`${1.5 + i * 0.3}s`} repeatCount="indefinite" />
                <animate attributeName="opacity" values="0.35;0.15;0.35"
                  dur={`${1.5 + i * 0.3}s`} repeatCount="indefinite" />
              </circle>
            ))}
          </g>
          <ellipse cx="22" cy="36" rx="8" ry="12" fill="white" opacity="0.2" transform="rotate(-20 22 36)" />
          <ellipse cx="20" cy="32" rx="3" ry="4.5" fill="white" opacity="0.3" transform="rotate(-15 20 32)" />
          <ellipse cx="32" cy="80" rx="4" ry="2.5" fill={`hsl(${mainHue} / 0.35)`} />
        </svg>
        {isLetdown && (
          <div className="absolute inset-0 pointer-events-none overflow-visible">
            {[...Array(4)].map((_, i) => (
              <motion.div key={`sp${i}`}
                animate={{
                  y: [-5, -25 - i * 8],
                  x: [0, (i % 2 === 0 ? 10 : -10)],
                  opacity: [0.8, 0],
                  scale: [0.5, 1.2],
                }}
                transition={{ duration: 1.5 + i * 0.3, repeat: Infinity, delay: i * 0.4 }}
                className="absolute text-[8px]"
                style={{ left: `${20 + i * 15}%`, top: "30%" }}
              >
                ✨
              </motion.div>
            ))}
          </div>
        )}
      </div>
      <div className="flex items-center gap-1.5">
        <span className={cn(
          "text-[10px] font-bold px-2 py-0.5 rounded-full shadow-sm",
          isLeft ? "bg-primary/15 text-primary" : "bg-mai-glow/15 text-mai-glow"
        )}>{label}</span>
        <motion.span
          key={flow.toFixed(1)}
          initial={{ scale: 1.3, opacity: 0.5 }}
          animate={{ scale: 1, opacity: 1 }}
          className="text-[12px] font-bold text-foreground tabular-nums"
        >
          {flow.toFixed(1)}
        </motion.span>
        {isLetdown && (
          <motion.span
            animate={{ rotate: [-5, 10, -5], scale: [1, 1.2, 1] }}
            transition={{ duration: 0.5, repeat: Infinity }}
            className="text-sm"
          >🌱</motion.span>
        )}
      </div>
    </motion.div>
  );
});
BreastDrop.displayName = "BreastDrop";

// ─── Cute flower pump ring with letdown color change ─────────
const PumpRing = React.memo(({ avgGear, isDeep, running, isLetdown }: {
  avgGear: number; isDeep: boolean; running: boolean; isLetdown: boolean;
}) => {
  const size = 68 + avgGear * 1.5;
  const baseDur = isDeep ? 5 : 2;
  const dur = isDeep ? baseDur * 1.5 : baseDur * 0.8;
  const breathScale = isDeep ? 1.3 * 1.3 : 1.3 * 0.5;
  const petalCount = 6;

  // Letdown: use vibrant warm orange/coral, normal: use default blush/primary
  const petalFillFrom = isLetdown ? "hsl(25 90% 65%)" : "hsl(var(--mai-blush))";
  const petalFillTo = isLetdown ? "hsl(15 80% 50%)" : "hsl(var(--primary))";
  const ringColor = isLetdown ? "hsl(25 85% 60%)" : "hsl(var(--mai-glow))";
  const ringOpacityBase = isLetdown ? 0.5 : 0.25;

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      {/* Breathing pulse rings - more visible */}
      {running && [0, 1, 2].map(i => {
        const scaleMax = 1 + (breathScale - 1 + i * 0.1);
        const baseOp = isLetdown ? 0.55 : 0.35;
        return (
          <motion.div key={i}
            animate={{
              scale: [1, scaleMax, 1],
              opacity: [baseOp - i * 0.08, baseOp + 0.25 - i * 0.06, baseOp - i * 0.08],
            }}
            transition={{ duration: isDeep ? 2 + i * 0.5 : 0.8 + i * 0.2, repeat: Infinity, ease: "easeInOut", delay: i * 0.3 }}
            className="absolute inset-0 rounded-full"
            style={{
              border: `2px solid ${ringColor}`,
              opacity: ringOpacityBase,
              margin: `-${i * 5}px`,
              boxShadow: isLetdown ? `0 0 12px 2px hsl(25 85% 60% / 0.3)` : undefined,
            }}
          />
        );
      })}
      {/* Flower petals */}
      <svg width={size} height={size} viewBox="0 0 64 64"
        style={{ animation: running ? `mandala-rotate ${dur}s linear infinite` : "none" }}>
        <defs>
          <radialGradient id="petal-g" cx="50%" cy="30%">
            <stop offset="0%" stopColor={petalFillFrom} stopOpacity="0.7" />
            <stop offset="100%" stopColor={petalFillTo} stopOpacity="0.3" />
          </radialGradient>
        </defs>
        {Array.from({ length: petalCount }).map((_, i) => {
          const a = (i / petalCount) * 360;
          return (
            <ellipse key={i}
              cx="32" cy="18"
              rx={5 + avgGear * 0.3} ry={10 + avgGear * 0.4}
              fill="url(#petal-g)"
              stroke={isLetdown ? "hsl(25 80% 55% / 0.5)" : "hsl(var(--mai-blush) / 0.3)"}
              strokeWidth="0.5"
              transform={`rotate(${a} 32 32)`}
              opacity={0.6 + (i % 2) * 0.2}
            />
          );
        })}
        <circle cx="32" cy="32" r="10" fill="hsl(var(--card))"
          stroke={isLetdown ? "hsl(25 80% 60% / 0.5)" : "hsl(var(--mai-blush) / 0.4)"} strokeWidth="1.5" />
        <circle cx="32" cy="32" r="6"
          fill={isLetdown ? "hsl(25 85% 65% / 0.3)" : "hsl(var(--mai-blush) / 0.2)"} />
        <circle cx="32" cy="32" r="3"
          fill={isLetdown ? "hsl(15 80% 50% / 0.5)" : "hsl(var(--primary) / 0.3)"} />
        <circle cx="30" cy="30" r="1.5" fill="white" opacity="0.4" />
      </svg>
      {/* Extra glow ring during letdown */}
      {isLetdown && running && (
        <motion.div
          animate={{ scale: [1, 1.6, 1], opacity: [0.3, 0, 0.3] }}
          transition={{ duration: 1.2, repeat: Infinity }}
          className="absolute rounded-full"
          style={{
            inset: '-12px',
            border: '2px solid hsl(25 85% 60% / 0.4)',
            boxShadow: '0 0 20px 4px hsl(25 85% 60% / 0.2)',
          }}
        />
      )}
    </div>
  );
});
PumpRing.displayName = "PumpRing";

// ─── Galaxy-flow tube connecting breast assembly to bottle ──────────
const FlowTube = React.memo(({ flowL, flowR, isLetdown }: {
  flowL: number; flowR: number; isLetdown: boolean;
}) => {
  const avg = (flowL + flowR) / 2;
  const glow = Math.min(1, 0.2 + avg * 0.06);
  const spd = Math.max(0.8, 3.5 - avg * 0.18);
  const cnt = Math.min(12, Math.floor(5 + avg * 0.7));
  const tubePath = "M0,18 C20,18 35,22 50,30 C65,38 78,44 100,44";
  const starCount = Math.min(18, Math.floor(8 + avg * 1.2));

  return (
    <svg
      width="112"
      height="96"
      viewBox="-28 -28 164 128"
      preserveAspectRatio="xMidYMid meet"
      className="overflow-visible"
      style={{ flexShrink: 0, overflow: "visible", display: "block" }}
    >
      <defs>
        {/* Galaxy nebula gradient — deep space with warm milky tones */}
        <linearGradient id="galaxy-outer" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="hsl(280 40% 25%)" stopOpacity="0.3" />
          <stop offset="30%" stopColor="hsl(260 35% 35%)" stopOpacity="0.4" />
          <stop offset="60%" stopColor="hsl(220 30% 40%)" stopOpacity="0.35" />
          <stop offset="100%" stopColor="hsl(200 25% 30%)" stopOpacity="0.3" />
        </linearGradient>
        <linearGradient id="galaxy-core" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="hsl(45 60% 90%)" stopOpacity="0.4" />
          <stop offset="25%" stopColor="hsl(35 50% 85%)" stopOpacity={0.5 + glow * 0.3} />
          <stop offset="50%" stopColor="hsl(280 30% 80%)" stopOpacity={0.4 + glow * 0.2} />
          <stop offset="75%" stopColor="hsl(220 40% 82%)" stopOpacity={0.5 + glow * 0.3} />
          <stop offset="100%" stopColor="hsl(45 55% 88%)" stopOpacity="0.4" />
        </linearGradient>
        <linearGradient id="galaxy-milky" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="hsl(45 70% 95%)" stopOpacity="0.7" />
          <stop offset="50%" stopColor="hsl(40 60% 93%)" stopOpacity={0.8 + glow * 0.2} />
          <stop offset="100%" stopColor="hsl(50 65% 94%)" stopOpacity="0.6" />
        </linearGradient>
        <filter id="galaxy-blur" x="-40%" y="-90%" width="180%" height="280%">
          <feGaussianBlur stdDeviation="5" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <filter id="galaxy-soft" x="-45%" y="-100%" width="190%" height="300%">
          <feGaussianBlur stdDeviation="3" />
        </filter>
        <filter id="star-glow" x="-250%" y="-250%" width="600%" height="600%">
          <feGaussianBlur stdDeviation="2" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <radialGradient id="star-radial">
          <stop offset="0%" stopColor="white" stopOpacity="0.9" />
          <stop offset="50%" stopColor="hsl(45 80% 90%)" stopOpacity="0.5" />
          <stop offset="100%" stopColor="hsl(260 30% 80%)" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Deep space ambient glow */}
      <path d={tubePath} fill="none" stroke="url(#galaxy-outer)" strokeWidth="30" strokeLinecap="round" filter="url(#galaxy-soft)" />
      {/* Nebula mid-layer */}
      <path d={tubePath} fill="none" stroke={isLetdown ? "hsl(25 60% 55% / 0.25)" : "hsl(260 30% 60% / 0.2)"} strokeWidth="22" strokeLinecap="round" filter="url(#galaxy-blur)" />
      {/* Galaxy core stream */}
      <path d={tubePath} fill="none" stroke="url(#galaxy-core)" strokeWidth="14" strokeLinecap="round" filter="url(#galaxy-blur)" />
      {/* Milky way center — bright creamy flow */}
      <path
        d={tubePath}
        fill="none"
        stroke="url(#galaxy-milky)"
        strokeWidth="6"
        strokeLinecap="round"
        opacity={avg > 0.3 ? 0.7 + glow * 0.3 : 0.15}
        style={{ transition: "opacity 0.5s" }}
      />
      {/* Bright specular core line */}
      <path d={tubePath} fill="none" stroke="white" strokeWidth="1.5" opacity={0.1 + glow * 0.15} strokeLinecap="round" />

      {/* Twinkling stars scattered along the tube */}
      {Array.from({ length: starCount }).map((_, i) => {
        const size = 0.8 + Math.random() * 1.8;
        const offset = (i / starCount) * 100;
        const yOff = -8 + Math.sin(i * 1.7) * 12;
        const xPos = offset;
        const t = xPos / 100;
        const approxX = t * 100;
        const approxY = 18 + t * 26 + yOff;
        const twinkleDur = 1.2 + (i % 5) * 0.4;
        const colors = ["hsl(45 80% 95%)", "hsl(260 50% 90%)", "hsl(200 60% 92%)", "hsl(340 40% 90%)", "white"];

        return (
          <circle key={`star${i}`} cx={approxX} cy={approxY} r={size} fill={colors[i % colors.length]} filter="url(#star-glow)">
            <animate
              attributeName="opacity"
              values={`${0.2 + (i % 3) * 0.15};${0.7 + (i % 2) * 0.3};${0.2 + (i % 3) * 0.15}`}
              dur={`${twinkleDur}s`}
              repeatCount="indefinite"
              begin={`${i * 0.15}s`}
            />
            <animate
              attributeName="r"
              values={`${size * 0.6};${size * 1.3};${size * 0.6}`}
              dur={`${twinkleDur * 1.2}s`}
              repeatCount="indefinite"
              begin={`${i * 0.1}s`}
            />
          </circle>
        );
      })}

      {/* Flowing milk-galaxy particles */}
      {avg > 0.3 && Array.from({ length: cnt }).map((_, i) => (
        <circle
          key={`gp${i}`}
          r={2 + (i % 3) * 1}
          fill={i % 3 === 0 ? "hsl(45 70% 95%)" : i % 3 === 1 ? "hsl(260 40% 88%)" : "hsl(200 50% 90%)"}
          opacity={glow * 0.6}
          filter="url(#star-glow)"
        >
          <animateMotion dur={`${spd + i * 0.12}s`} repeatCount="indefinite" path={tubePath} begin={`${i * (spd / cnt)}s`} />
          <animate
            attributeName="r"
            values={`${1.5 + i % 2};${3.5 + i % 2};${1.5 + i % 2}`}
            dur={`${1 + i * 0.15}s`}
            repeatCount="indefinite"
          />
        </circle>
      ))}

      {/* Letdown: golden comet particles */}
      {isLetdown && Array.from({ length: 8 }).map((_, i) => (
        <g key={`comet${i}`}>
          <circle r="3.5" fill="hsl(40 80% 75%)" opacity="0.7" filter="url(#star-glow)">
            <animateMotion dur={`${spd * 0.5 + i * 0.07}s`} repeatCount="indefinite" path={tubePath} begin={`${i * 0.15}s`} />
            <animate attributeName="r" values="2;5;2" dur={`${0.6 + i * 0.1}s`} repeatCount="indefinite" />
            <animate attributeName="opacity" values="0.7;0.2;0.7" dur={`${0.6 + i * 0.1}s`} repeatCount="indefinite" />
          </circle>
          <circle r="1.5" fill="hsl(45 90% 92%)" opacity="0.4">
            <animateMotion dur={`${spd * 0.5 + i * 0.07}s`} repeatCount="indefinite" path={tubePath} begin={`${i * 0.15 + 0.08}s`} />
          </circle>
        </g>
      ))}
    </svg>
  );
});
FlowTube.displayName = "FlowTube";

// ─── Large cylindrical collection tank with scale markings ──────
const BabyBottle = React.memo(({ pct, isLetdown, totalMl, unit, onToggleUnit }: {
  pct: number; isLetdown: boolean; totalMl?: number; unit?: "mL" | "oz"; onToggleUnit?: () => void;
}) => {
  const fillPct = Math.min(100, Math.max(0, pct));
  const displayVol = typeof totalMl === "number" && unit
    ? formatVol(totalMl, unit)
    : null;
  const cx = 60, bodyTop = 58, bodyBottom = 192;
  const bodyH = bodyBottom - bodyTop;
  const fillH = (fillPct / 100) * bodyH;
  const fillY = bodyBottom - fillH;
  const scaleMarks = [20, 40, 60, 80, 100, 120, 140, 160];
  const maxMl = 180;

  return (
    <motion.div
      animate={isLetdown ? { scale: [1, 1.02, 1] } : {}}
      transition={{ duration: 1.5, repeat: Infinity, ease: "easeInOut" }}
      className="flex flex-col items-center"
      style={{ willChange: "transform" }}
    >
      <div className="relative">
        <svg width="96" height="180" viewBox="0 0 120 215" className="overflow-visible drop-shadow-lg">
          <defs>
            <linearGradient id="baby-bottle-body" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="hsl(var(--primary) / 0.12)" />
              <stop offset="20%" stopColor="hsl(var(--primary) / 0.04)" />
              <stop offset="50%" stopColor="hsl(var(--background) / 0.6)" />
              <stop offset="80%" stopColor="hsl(var(--primary) / 0.05)" />
              <stop offset="100%" stopColor="hsl(var(--primary) / 0.15)" />
            </linearGradient>
            <linearGradient id="baby-bottle-milk" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="hsl(45 55% 92%)" />
              <stop offset="50%" stopColor="hsl(42 50% 88%)" />
              <stop offset="100%" stopColor="hsl(38 45% 85%)" />
            </linearGradient>
            <linearGradient id="baby-bottle-shine" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="white" stopOpacity="0" />
              <stop offset="12%" stopColor="white" stopOpacity="0.22" />
              <stop offset="35%" stopColor="white" stopOpacity="0.05" />
              <stop offset="100%" stopColor="white" stopOpacity="0" />
            </linearGradient>
            <clipPath id="baby-bottle-clip">
              <path d="M34 78 C34 66 43 58 50 58 H70 C77 58 86 66 86 78 V182 C86 192 78 200 68 200 H52 C42 200 34 192 34 182 Z" />
            </clipPath>
            <filter id="baby-bottle-shadow">
              <feDropShadow dx="0" dy="3" stdDeviation="5" floodColor="hsl(var(--primary) / 0.15)" floodOpacity="0.15" />
            </filter>
          </defs>

          <g filter="url(#baby-bottle-shadow)">
            <path d="M50 22 C50 14 70 14 70 22 V34 H50 Z" fill="hsl(var(--card))" stroke="hsl(var(--border))" strokeWidth="1" />
            <rect x="45" y="32" width="30" height="14" rx="4" fill="hsl(var(--secondary))" stroke="hsl(var(--border))" strokeWidth="1" />
            <rect x="47" y="44" width="26" height="18" rx="5" fill="hsl(var(--card))" stroke="hsl(var(--border))" strokeWidth="1" />
            <path
              d="M34 78 C34 66 43 58 50 58 H70 C77 58 86 66 86 78 V182 C86 192 78 200 68 200 H52 C42 200 34 192 34 182 Z"
              fill="url(#baby-bottle-body)"
              stroke="hsl(var(--border))"
              strokeWidth="1.2"
            />
          </g>

          <g clipPath="url(#baby-bottle-clip)">
            <rect x="34" y={fillY} width="52" height={bodyBottom - fillY + 12}
              fill="url(#baby-bottle-milk)" className="transition-all duration-500" />
            {fillPct > 3 && (
              <>
                <path d={`M34,${fillY + 1} Q47,${fillY - 4} 60,${fillY + 1} Q73,${fillY + 5} 86,${fillY + 1} V205 H34 Z`}
                  fill="hsl(45 50% 90% / 0.4)" className="breast-wave" />
                <path d={`M34,${fillY + 2} Q50,${fillY + 6} 64,${fillY + 2} Q78,${fillY - 2} 86,${fillY + 2} V205 H34 Z`}
                  fill="hsl(40 45% 87% / 0.25)" style={{ animation: "breast-wave-drift 3.5s ease-in-out infinite reverse" }} />
              </>
            )}
            {fillPct > 5 && [...Array(5)].map((_, i) => (
              <circle key={i} cx={42 + i * 9} cy={fillY + 12 + (i % 3) * 5} r={1.2 + (i % 2) * 0.5}
                fill="white" opacity="0.2">
                <animate attributeName="cy" values={`${fillY + 14 + i * 2};${fillY + 5};${fillY + 14 + i * 2}`}
                  dur={`${2 + i * 0.35}s`} repeatCount="indefinite" />
              </circle>
            ))}
          </g>

          {fillPct > 2 && (
            <ellipse cx={cx} cy={fillY} rx="25" ry="7"
              fill="hsl(45 50% 90% / 0.5)" stroke="hsl(45 50% 82% / 0.3)" strokeWidth="0.5"
              className="transition-all duration-500" />
          )}

          <path d="M34 78 C34 66 43 58 50 58 H70 C77 58 86 66 86 78 V182 C86 192 78 200 68 200 H52 C42 200 34 192 34 182 Z"
            fill="url(#baby-bottle-shine)" />
          <path d="M47 74 V178" stroke="white" strokeWidth="3" opacity="0.08" strokeLinecap="round" />
          <circle cx="34" cy="112" r="4" fill="hsl(var(--card))" stroke="hsl(var(--border))" strokeWidth="1" />
          <circle cx="86" cy="112" r="4" fill="hsl(var(--card))" stroke="hsl(var(--border))" strokeWidth="1" />

          {scaleMarks.map(ml => {
            const markY = bodyBottom - (ml / maxMl) * bodyH;
            const isMajor = ml % 40 === 0;
            if (markY < bodyTop + 8) return null;
            return (
              <line key={ml} x1={isMajor ? 72 : 76} y1={markY} x2="83" y2={markY}
                stroke="hsl(var(--muted-foreground))" strokeWidth={isMajor ? 0.8 : 0.4} opacity={isMajor ? 0.4 : 0.18} />
            );
          })}
        </svg>
        {isLetdown && (
          <motion.div
            animate={{ opacity: [0.15, 0.4, 0.15] }}
            transition={{ duration: 1.2, repeat: Infinity }}
            className="absolute inset-0 pointer-events-none"
            style={{ background: 'radial-gradient(ellipse at center 55%, hsl(42 50% 88% / 0.2), transparent 70%)' }}
          />
        )}
      </div>
      {displayVol !== null && unit && onToggleUnit && (
        <div className="flex items-center gap-1.5 mt-1">
          <span className="text-sm font-bold text-foreground tabular-nums">
            {displayVol}
            <span className="text-[10px] text-muted-foreground ml-0.5">{unit}</span>
          </span>
          <motion.button whileTap={{ scale: 0.85, rotate: 180 }} onClick={onToggleUnit}
            className="w-4 h-4 rounded-full bg-muted/50 flex items-center justify-center hover:bg-muted transition-colors">
            <RefreshCw className="w-2.5 h-2.5 text-muted-foreground" />
          </motion.button>
        </div>
      )}
    </motion.div>
  );
});
BabyBottle.displayName = "BabyBottle";

// MilkProgressBar is now imported from @/components/pump/MilkProgressBar

function initialProgressAllFromSnapshot(): number {
  const st = pumpSessionLifecycle.getSessionState();
  if (st === "idle") return 0;
  const g = getProcessAll();
  return Math.max(0, Math.min(100, Math.round(g)));
}

type AutoEndedUiKind = "offline-single" | "offline-both" | "pause-timeout";

/**
 * 自动结束提示已过时：与 lifecycle 清 lastEndedEvent 互补，避免挂载早于 reconcile。
 * - 离线结束：任一侧已 BLE 在线
 * - 暂停超时结束：任一侧已在线且上报运行中（与 reconcile 判定一致）
 */
function staleAutoEndedWhileDeviceRecovered(evt: PumpSessionEndedEvent): boolean {
  const { anyOnline, anyOnlineRunning } = getPumpSessionDeviceDerived();
  if (
    evt.reason === "device-offline-ended-single" ||
    evt.reason === "device-offline-ended-both"
  ) {
    return anyOnline;
  }
  if (evt.reason === "pause-timeout-ended") {
    return anyOnlineRunning;
  }
  return false;
}

// ═══════════════════════════════════════════════════════════════
// MAIN COMPONENT
// ═══════════════════════════════════════════════════════════════
const PumpSession: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const fromCalibration = searchParams.get("from") === "calibration";

  // Read calibration for ramp-up: start at cozy-2, ramp to cozy
  const calRaw = localStorage.getItem("calibration");
  const calData = calRaw ? JSON.parse(calRaw) : null;
  // From calibration: start at actual cozy gear; otherwise: cozy-2 with ramp-up
  const initGearL = calData?.L?.stimCozy ? (fromCalibration ? calData.L.stimCozy : Math.max(1, calData.L.stimCozy - 2)) : 5;
  const initGearR = calData?.R?.stimCozy ? (fromCalibration ? calData.R.stimCozy : Math.max(1, calData.R.stimCozy - 2)) : 5;
  const targetGearL = calData?.L?.stimCozy || 5;
  const targetGearR = calData?.R?.stimCozy || 5;

  const [left, setLeft] = useState<SideState>({ gear: initGearL, mode: "stimulate", flow: 0 });
  const [right, setRight] = useState<SideState>({ gear: initGearR, mode: "stimulate", flow: 0 });
  const [elapsed, setElapsed] = useState<number>(initialElapsedFromStore);
  const [sessionState, setSessionState] = useState<SessionState>(() => pumpSessionLifecycle.getSessionState());
  // 两侧曲线缓冲独立维护：仅当对应侧"在线且运行中"时才 push，离线/未运行时完全冻结，
  // ForceLinePanel 各自按自己 buffer 长度做 x 映射，分母不变 → 离线侧曲线绝对静止、不左移、不增长。
  const [flowDataL, setFlowDataL] = useState<number[]>([]);
  const [flowDataR, setFlowDataR] = useState<number[]>([]);
  const [bottlePct, setBottlePct] = useState(0);
  const [volumeUnit, toggleVolumeUnit] = useVolumeUnit();
  const [progressL, setProgressL] = useState(0);
  const [progressR, setProgressR] = useState(0);
  const [progressAll, setProgressAll] = useState(initialProgressAllFromSnapshot);
  const [manualConfirmOpen, setManualConfirmOpen] = useState(false);
  const [finishConfirmOpen, setFinishConfirmOpen] = useState(false);
  const [devicePowerOffOpen, setDevicePowerOffOpen] = useState(false);
  const [autoEndedDialogReason, setAutoEndedDialogReason] = useState<AutoEndedUiKind | null>(null);
  const [deviceNotConnectedOpen, setDeviceNotConnectedOpen] = useState(false);
  const [aiMode, setAiMode] = useState(true);
  const prevDeviceLetdownLRef = useRef<boolean | null>(null);
  const prevDeviceLetdownRRef = useRef<boolean | null>(null);
  const handledEndedEventAtRef = useRef<number>(0);

  // 与 last L1490-1500 对齐：3 秒内若仍无设备连接则提醒。
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const { L, R } = deviceStore.get();
      if (!L?.connected && !R?.connected) {
        setDeviceNotConnectedOpen(true);
      }
    }, 3000);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    return pumpSessionLifecycle.subscribe((next) => {
      setSessionState((prev) => (prev === next ? prev : next));
    });
  }, []);

  useEffect(() => {
    setProcessAll(progressAll);
  }, [progressAll]);

  useEffect(() => {
    const endReasonToUiKind = (reason: PumpSessionEndReason): AutoEndedUiKind | null => {
      if (reason === "device-offline-ended-single") return "offline-single";
      if (reason === "device-offline-ended-both") return "offline-both";
      if (reason === "pause-timeout-ended") return "pause-timeout";
      return null;
    };
    const shouldHandleEnded = (evt: PumpSessionEndedEvent): boolean => {
      if (evt.at <= handledEndedEventAtRef.current) return false;
      return endReasonToUiKind(evt.reason) != null;
    };
    const initial = pumpSessionLifecycle.getLastEndedEvent();
    if (initial && shouldHandleEnded(initial)) {
      handledEndedEventAtRef.current = initial.at;
      if (!staleAutoEndedWhileDeviceRecovered(initial)) {
        const k0 = endReasonToUiKind(initial.reason);
        if (k0) setAutoEndedDialogReason(k0);
      }
    }
    return pumpSessionLifecycle.subscribeEnded((evt) => {
      if (!shouldHandleEnded(evt)) return;
      handledEndedEventAtRef.current = evt.at;
      if (staleAutoEndedWhileDeviceRecovered(evt)) return;
      const k = endReasonToUiKind(evt.reason);
      if (k) setAutoEndedDialogReason(k);
    });
  }, []);
  const hasCalibration = !!(calData?.L?.stimCozy || calData?.R?.stimCozy);
  const {
    calPromptStep,
    setCalPromptStep,
    calPromptRunning,
    handleCalPromptNo,
    handleCalPromptDeclinedOk,
    handleCalDisableYes,
    handleCalDisableNo,
  } = usePumpCalibrationRuntime(hasCalibration);
  const handleCalPromptYes = () => {
    setCalPromptStep(null);
    navigate("/calibration");
  };

  const isSessionRunning = sessionState === "running";
  const isSessionEnded = sessionState === "ended";
  const {
    enablePumpSessionMockEffects,
    maiSessionBubble,
    setMaiSessionBubble,
    pauseResume,
    adjustGearL,
    adjustGearR,
    initialAiMode,
    setModeBoth,
    handleAiModeRequest,
    maiAssistantContent,
    maiAssistantLoading,
    maiAssistantError,
    sessionProgress,
    canToggleSession,
    handleSwitchToManual,
    confirmSwitchToManual,
    handleBack,
    confirmDevicePowerOff,
    handleFinish,
    confirmFinish,
  } = usePumpSessionController({
    calData,
    fromCalibration,
    targetGearL,
    targetGearR,
    left,
    right,
    aiMode,
    isSessionRunning,
    sessionState,
    calPromptRunning,
    setBottlePct,
    setFlowDataL,
    setFlowDataR,
    setProgressL,
    setProgressR,
    setProgressAll,
    processAll: progressAll,
    setElapsed,
    setAiMode,
    setSessionState,
    setLeft,
    setRight,
    setDevicePowerOffOpen,
    setManualConfirmOpen,
    setFinishConfirmOpen,
    navigateHome: () => navigate("/"),
  });
  const initAiRef = useRef(false);
  useEffect(() => {
    if (initAiRef.current) return;
    initAiRef.current = true;
    setAiMode(initialAiMode);
  }, [initialAiMode]);
  // TODO(agent-ui): AI/SSE outputs are intentionally not wired to UI yet.
  // Keep runtime active for conversation continuity and future UI binding.
  void maiAssistantContent;
  void maiAssistantLoading;
  void maiAssistantError;

  // Derived
  const {
    displayFlowL,
    displayFlowR,
    flowDisplayLabelL,
    flowDisplayLabelR,
    letdownL,
    letdownR,
    isLetdown,
    totalL,
    totalR,
    displayBottlePct,
    leftDeviceOnline,
    rightDeviceOnline,
    leftDeviceAutoScene,
    rightDeviceAutoScene,
    aggregatePaused,
  } = usePumpRealDisplayRuntime({
    left,
    right,
    flowDataL,
    flowDataR,
    bottlePct,
    sessionState,
    enablePumpSessionMockEffects,
    setFlowDataL,
    setFlowDataR,
    setProgressL,
    setProgressR,
    setProgressAll,
  });

  const fmt = (s: number) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;

  useEffect(() => {
    if (enablePumpSessionMockEffects) return;
    if (sessionState !== "running") return;

    const canTrackLetdownL = leftDeviceOnline && aiMode && leftDeviceAutoScene;
    const canTrackLetdownR = rightDeviceOnline && aiMode && rightDeviceAutoScene;

    if (canTrackLetdownL) {
      if (prevDeviceLetdownLRef.current === null) prevDeviceLetdownLRef.current = letdownL;
      const prevL = prevDeviceLetdownLRef.current;
      if (prevL !== letdownL) {
        toast({
          title: letdownL ? "左侧出奶开始了" : "左侧出奶减弱了",
          description: letdownL ? "将自动切换到吸乳模式，放松一点更顺畅" : "将自动切换到刺激模式，帮你再次带动出奶",
        });
      }
      prevDeviceLetdownLRef.current = letdownL;
    } else {
      prevDeviceLetdownLRef.current = null;
    }

    if (canTrackLetdownR) {
      if (prevDeviceLetdownRRef.current === null) prevDeviceLetdownRRef.current = letdownR;
      const prevR = prevDeviceLetdownRRef.current;
      if (prevR !== letdownR) {
        toast({
          title: letdownR ? "右侧出奶开始了" : "右侧出奶减弱了",
          description: letdownR ? "将自动切换到吸乳模式，放松一点更顺畅" : "将自动切换到刺激模式，帮你再次带动出奶",
        });
      }
      prevDeviceLetdownRRef.current = letdownR;
    } else {
      prevDeviceLetdownRRef.current = null;
    }
  }, [
    aiMode,
    enablePumpSessionMockEffects,
    leftDeviceAutoScene,
    leftDeviceOnline,
    letdownL,
    letdownR,
    rightDeviceAutoScene,
    rightDeviceOnline,
    sessionState,
  ]);

  const handlePrimarySessionAction = () => {
    void pauseResume();
  };

  // 与 last L1830-1843 对齐：离线侧固定档位 1 / 置灰展示。
  const sideOfflineL = !leftDeviceOnline;
  const sideOfflineR = !rightDeviceOnline;
  // 自动离线结束弹窗出现时，UI 立即按双侧离线渲染，避免连接态回写延迟导致中部文案滞后。
  const forceOfflineByAutoEnd =
    autoEndedDialogReason === "offline-single" || autoEndedDialogReason === "offline-both";
  const sideOfflineLFinal = forceOfflineByAutoEnd || sideOfflineL;
  const sideOfflineRFinal = forceOfflineByAutoEnd || sideOfflineR;
  const displayGearL = sideOfflineLFinal ? 1 : left.gear;
  const displayGearR = sideOfflineRFinal ? 1 : right.gear;

  const syncModeHighlight = syncModeButtonHighlight({
    enablePumpSessionMockEffects,
    leftOnline: leftDeviceOnline,
    rightOnline: rightDeviceOnline,
    leftMode: left.mode,
    rightMode: right.mode,
  });

  /** 顶栏状态文案：进行中会话与 last 一致用 aggregatePaused → 已暂停/运行中 */
  const headerSessionLabel =
    sessionState === "idle"
      ? "未开始"
      : sessionState === "ended"
        ? "已结束"
        : aggregatePaused
          ? "已暂停"
          : "运行中";

  const primarySessionActionLabel =
    sessionState === "idle" || sessionState === "ended"
      ? "启动"
      : aggregatePaused
        ? "继续"
        : "暂停";

  const lastButtonDiagRef = useRef<string>("");
  useEffect(() => {
    const sig = `${sessionState}|${aggregatePaused ? 1 : 0}|${primarySessionActionLabel}`;
    if (sig === lastButtonDiagRef.current) return;
    lastButtonDiagRef.current = sig;
    pumpSessionPageLogger.log("buttonLabelDiag(v3)", {
      sessionState,
      aggregatePaused,
      primarySessionActionLabel,
    });
  }, [sessionState, aggregatePaused, primarySessionActionLabel]);

  const modeMetaShort = (mode: PumpMode) =>
    mode === "stimulate" ? "刺激" : mode === "deep" ? "吸乳" : "混合";

  // ═══════════════════════════════════════════════════════════
  // RENDER
  // ═══════════════════════════════════════════════════════════
  const totalMl = totalL + totalR;

  return (
    <div className="fixed inset-0 z-50 flex justify-center bg-background">
    <motion.div
      initial={{ y: "100%", opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      exit={{ y: "100%", opacity: 0 }}
      transition={{ type: "spring", damping: 30, stiffness: 300 }}
      className="relative flex h-[100dvh] w-full max-w-lg touch-none flex-col overflow-hidden"
      style={{
        background: "radial-gradient(circle at 50% 0%, hsl(340 35% 94%) 0%, transparent 34%), linear-gradient(180deg, hsl(30 28% 98%) 0%, hsl(340 22% 96%) 54%, hsl(340 24% 94%) 100%)",
      }}
    >
      <div className="flex items-center justify-between px-3 pt-[max(env(safe-area-inset-top,0px),12px)] pb-2">
        <motion.button whileTap={{ scale: 0.9 }} onClick={handleBack}
          className="flex items-center gap-1 rounded-full py-1 pr-2 text-muted-foreground hover:text-foreground transition-colors">
          <ArrowLeft className="w-4 h-4" />
          <span className="text-[10px] font-semibold">返回</span>
        </motion.button>

        <div className="flex flex-col items-center">
          <p className="text-[11px] font-bold text-foreground">沉浸式吸乳</p>
          <motion.span
            key={sessionState === "idle" || sessionState === "ended" ? sessionState : aggregatePaused ? "p" : "r"}
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            className={cn(
              "px-2.5 py-0.5 rounded-full text-[8px] font-bold tracking-wider uppercase",
              sessionState === "idle" || sessionState === "ended"
                ? "bg-muted text-muted-foreground"
                : aggregatePaused
                  ? "bg-muted text-muted-foreground"
                  : "bg-primary/10 text-primary"
            )}
          >
            {headerSessionLabel}
          </motion.span>
        </div>

        <div className="w-[42px]" />
      </div>

      <div className="flex min-h-0 flex-1 flex-col overflow-hidden overscroll-none px-3 pb-3">
        <section className="rounded-[1.6rem] border border-primary/10 bg-card/80 p-4 shadow-[0_12px_34px_-24px_hsl(var(--primary))]">
          <div className="grid grid-cols-2 gap-3">
            <MetricPanel
              label="吸乳量"
              value={formatVol(totalMl, volumeUnit)}
              unit={volumeUnit}
              onClick={toggleVolumeUnit}
              emphasis
            />
            <MetricPanel label="时间" value={fmt(elapsed)} />
          </div>

          <div className="mt-4 flex items-center justify-between">
            <div>
              <p className="text-[10px] font-bold text-muted-foreground">本次吸乳进度</p>
            </div>
            <span className="text-sm font-extrabold text-primary">{Math.round(sessionProgress)}%</span>
          </div>
          <div className="mt-2 h-2.5 overflow-hidden rounded-full bg-secondary">
            <motion.div
              className="h-full rounded-full bg-primary"
              animate={{ width: `${sessionProgress}%` }}
              transition={{ duration: 0.3 }}
            />
          </div>
        </section>

        <section className="relative mt-2 flex min-h-[260px] flex-1 flex-col justify-between overflow-hidden rounded-[1.6rem] border border-border/30 bg-card/65 p-3 shadow-sm min-[380px]:min-h-[310px]">
          <div className="grid grid-cols-[70px_40px_auto_40px_70px] items-center justify-center gap-1 min-[380px]:grid-cols-[76px_44px_auto_44px_76px] min-[380px]:gap-2">
            <SideMetric
              label="左侧"
              value={`${totalL}ml`}
              meta={`${displayGearL}档 · ${modeMetaShort(left.mode)}`}
              active={false}
              align="right"
              offline={sideOfflineLFinal}
            />
            <SidePumpVisual side="L" flow={flowDisplayLabelL} totalMl={totalL} running={isSessionRunning} offline={sideOfflineLFinal} />
            <div className="scale-[0.88] min-[380px]:scale-95">
              <BabyBottle pct={displayBottlePct} isLetdown={false} />
            </div>
            <SidePumpVisual side="R" flow={flowDisplayLabelR} totalMl={totalR} running={isSessionRunning} offline={sideOfflineRFinal} />
            <SideMetric
              label="右侧"
              value={`${totalR}ml`}
              meta={`${displayGearR}档 · ${modeMetaShort(right.mode)}`}
              active={false}
              offline={sideOfflineRFinal}
            />
          </div>
          <div className="-mt-1 grid grid-cols-2 gap-2">
            <ForceLinePanel
              label="奶流强度曲线"
              sideLabel="Left"
              value={flowDisplayLabelL}
              points={flowDataL}
              active={letdownL}
              tone="hsl(18 82% 52%)"
              offline={sideOfflineLFinal}
            />
            <ForceLinePanel
              label="奶流强度曲线"
              sideLabel="Right"
              value={flowDisplayLabelR}
              points={flowDataR}
              active={letdownR}
              tone="hsl(340 56% 66%)"
              offline={sideOfflineRFinal}
            />
          </div>
        </section>

      </div>

      {/* ─── Control Console ───────────────────────────────── */}
      <div className="relative flex-shrink-0 px-3 pb-[max(env(safe-area-inset-bottom,0px),8px)] pt-2.5">
        <div className="relative rounded-[1.4rem] border border-border/40 bg-card/90 p-2.5 shadow-[0_14px_40px_-24px_hsl(var(--primary))] backdrop-blur-sm">
          <div className="mb-2">
            <p className="mb-1.5 text-[10px] font-bold text-muted-foreground">设备控制</p>
            <div className="grid grid-cols-2 gap-1 rounded-2xl bg-muted/40 p-1">
              <button onClick={() => void handleAiModeRequest(true)}
                className={cn("rounded-xl px-3 py-1.5 text-xs font-bold transition-all",
                  aiMode ? "bg-primary text-primary-foreground mai-shadow" : "text-muted-foreground")}>
                自动托管
              </button>
              <button onClick={() => { if (aiMode) handleSwitchToManual(); else return; }}
                className={cn("rounded-xl px-3 py-1.5 text-xs font-bold transition-all",
                  !aiMode ? "bg-primary text-primary-foreground mai-shadow" : "text-muted-foreground")}>
                手动调整
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between gap-2">
            <div className={cn("grid flex-1 grid-cols-2 gap-1 transition-all duration-300", aiMode && "opacity-40 pointer-events-none")}>
              <button onClick={() => setModeBoth("stimulate")}
                className={cn("rounded-xl px-3 py-2 text-[11px] font-bold transition-all flex items-center justify-center gap-1",
                  syncModeHighlight === "stimulate"
                    ? "bg-primary/90 text-primary-foreground shadow-sm" : "bg-card/60 text-muted-foreground border border-border/30")}>
                刺激模式
              </button>
              <button onClick={() => setModeBoth("deep")}
                className={cn("rounded-xl px-3 py-2 text-[11px] font-bold transition-all flex items-center justify-center gap-1",
                  syncModeHighlight === "deep"
                    ? "bg-accent text-accent-foreground shadow-sm" : "bg-card/60 text-muted-foreground border border-border/30")}>
                吸乳模式
              </button>
            </div>
          </div>

          <div className={cn("mt-1.5 grid grid-cols-2 gap-2", aiMode && "opacity-70")}>
            <div className={cn("rounded-2xl bg-muted/20 p-1.5", sideOfflineLFinal && "opacity-50 pointer-events-none")}>
              <p className="mb-0.5 text-[10px] font-bold text-primary">左侧档位</p>
              <div className="flex items-center justify-center gap-2">
              <motion.button whileTap={{ scale: 0.85 }} onClick={() => adjustGearL(-1)}
                disabled={sideOfflineLFinal}
                className="w-7 h-7 rounded-full bg-muted/70 flex items-center justify-center active:bg-muted disabled:opacity-50">
                <Minus className="w-3 h-3 text-foreground" />
              </motion.button>
              <motion.span key={displayGearL} initial={{ scale: 1.3, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
                className="text-xl font-bold text-foreground tabular-nums w-7 text-center">
                {displayGearL}
              </motion.span>
              <motion.button whileTap={{ scale: 0.85 }} onClick={() => adjustGearL(1)}
                disabled={sideOfflineLFinal}
                className="w-7 h-7 rounded-full bg-muted/70 flex items-center justify-center active:bg-muted disabled:opacity-50">
                <Plus className="w-3 h-3 text-foreground" />
              </motion.button>
              </div>
            </div>
            <div className={cn("rounded-2xl bg-muted/20 p-1.5", sideOfflineRFinal && "opacity-50 pointer-events-none")}>
              <p className="mb-0.5 text-[10px] font-bold text-mai-glow">右侧档位</p>
              <div className="flex items-center justify-center gap-2">
              <motion.button whileTap={{ scale: 0.85 }} onClick={() => adjustGearR(-1)}
                disabled={sideOfflineRFinal}
                className="w-7 h-7 rounded-full bg-muted/70 flex items-center justify-center active:bg-muted disabled:opacity-50">
                <Minus className="w-3 h-3 text-foreground" />
              </motion.button>
              <motion.span key={displayGearR} initial={{ scale: 1.3, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
                className="text-xl font-bold text-foreground tabular-nums w-7 text-center">
                {displayGearR}
              </motion.span>
              <motion.button whileTap={{ scale: 0.85 }} onClick={() => adjustGearR(1)}
                disabled={sideOfflineRFinal}
                className="w-7 h-7 rounded-full bg-muted/70 flex items-center justify-center active:bg-muted disabled:opacity-50">
                <Plus className="w-3 h-3 text-foreground" />
              </motion.button>
              </div>
            </div>
          </div>

          <div className="flex gap-2 mt-1.5">
            <motion.button whileTap={{ scale: canToggleSession ? 0.96 : 1 }} onClick={handlePrimarySessionAction}
              disabled={!canToggleSession}
              className={cn(
                "flex-1 py-2.5 rounded-2xl text-sm font-bold border flex items-center justify-center gap-1 transition-colors",
                canToggleSession ? "bg-card/70 border-border/40 text-foreground" : "bg-muted/50 border-border/20 text-muted-foreground"
              )}>
              {(sessionState === "ended" || sessionState === "idle" || aggregatePaused) ? <Play className="w-3 h-3" /> : <Pause className="w-3 h-3" />}
              {primarySessionActionLabel}
            </motion.button>
            <motion.button whileTap={{ scale: 0.96 }} onClick={handleFinish}
              disabled={isSessionEnded}
              className={cn(
                "flex-1 py-2.5 rounded-2xl text-sm font-bold flex items-center justify-center gap-1 transition-colors",
                isSessionEnded ? "bg-muted text-muted-foreground" : "bg-destructive text-destructive-foreground"
              )}>
              <Square className="w-2.5 h-2.5" /> 结束
            </motion.button>
          </div>
        </div>
      </div>

      {/* TODO(module-migration): keep last-version MaiSessionBubbles behavior.
         Component "@/components/pump/MaiSessionBubbles" is currently unavailable in this workspace.
         After component is restored, replace this inline bubble with MaiSessionBubbles. */}
      <AnimatePresence>
        {maiSessionBubble && (
          <motion.div
            initial={{ opacity: 0, y: 20, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -10, scale: 0.9 }}
            transition={{ type: "spring", damping: 22, stiffness: 280 }}
            className="absolute top-1/2 left-3 right-3 max-w-[28rem] mx-auto -translate-y-1/2 z-50"
          >
            <div className="relative bg-card/60 backdrop-blur-lg border border-border/30 rounded-2xl px-4 py-3 shadow-lg">
              <div className="flex items-start gap-2 mb-2">
                <span className="text-base">🤖</span>
                <p className="text-[12px] leading-relaxed text-foreground flex-1">{maiSessionBubble.text}</p>
                <button
                  type="button"
                  className="text-[10px] text-muted-foreground hover:text-foreground"
                  onClick={() => setMaiSessionBubble(null)}
                >
                  关闭
                </button>
              </div>
              {maiSessionBubble.actions && (
                <div className="flex gap-2 mt-2">
                  {maiSessionBubble.actions.map((act, i) => (
                    <motion.button
                      key={`${act.label}-${i}`}
                      whileTap={{ scale: 0.95 }}
                      onClick={act.action}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-[11px] font-bold transition-all",
                        i === 0
                          ? "bg-primary text-primary-foreground"
                          : "bg-muted/60 text-foreground border border-border/30"
                      )}
                    >
                      {act.label}
                    </motion.button>
                  ))}
                </div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* TODO(module-migration): keep last-version MaiChatDrawer behavior.
         Component "@/components/device/MaiChatDrawer" is currently unavailable in this workspace. */}

    </motion.div>

    <ConfirmDialog
      open={manualConfirmOpen}
      title="切换到手动模式？"
      description="切换到手动模式后，智能体将不再自动调整吸乳模式和档位"
      cancelLabel="取消切换"
      confirmLabel="确认切换"
      onCancel={() => setManualConfirmOpen(false)}
      onConfirm={confirmSwitchToManual}
    />

    <ConfirmDialog
      open={finishConfirmOpen}
      title="结束当前吸乳？"
      description="结束后将停止本次吸乳，并返回智能体主页"
      cancelLabel="继续吸乳"
      confirmLabel="确认结束"
      destructive
      onCancel={() => setFinishConfirmOpen(false)}
      onConfirm={confirmFinish}
    />

    <ConfirmDialog
      open={devicePowerOffOpen}
      title="检测到设备已关机"
      description="两侧设备均已关机，本次吸奶已结束。确认后将返回智能体主页。"
      confirmLabel="知道了"
      onConfirm={confirmDevicePowerOff}
    />

    <ConfirmDialog
      open={autoEndedDialogReason !== null}
      title={
        autoEndedDialogReason === "offline-single"
          ? "检测到设备已离线"
          : autoEndedDialogReason === "offline-both"
            ? "两侧设备均已离线"
            : "检测到设备长时间暂停"
      }
      description={
        autoEndedDialogReason === "offline-single"
          ? "检测到设备已离线，本次吸奶结束。确认后将返回智能体主页。"
          : autoEndedDialogReason === "offline-both"
            ? "两侧设备均已离线，本次吸奶自动结束。确认后将返回智能体主页。"
            : "所有在线设备已暂停超过10分钟，本次吸奶已自动结束。确认后将返回智能体主页。"
      }
      confirmLabel="知道了"
      onConfirm={() => {
        setAutoEndedDialogReason(null);
        void confirmFinish();
      }}
    />

    <ConfirmDialog
      open={deviceNotConnectedOpen}
      title="尚未检测到吸乳器"
      description="请确认吸乳器已开机并蓝牙就绪后再启动本次吸乳。"
      confirmLabel="知道了"
      onConfirm={() => setDeviceNotConnectedOpen(false)}
    />

    {/* ─── Calibration Prompt Dialog ─── */}
    <AnimatePresence>
      {calPromptStep !== null && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 z-[80] bg-foreground/40 backdrop-blur-sm"
          />
          <div className="absolute inset-0 z-[81] flex items-center justify-center px-4 pointer-events-none">
            <motion.div
              initial={{ scale: 0.92, opacity: 0, y: 12 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.92, opacity: 0, y: 12 }}
              className="w-full max-w-sm rounded-2xl border border-border bg-card p-5 shadow-2xl pointer-events-auto"
            >
              {calPromptStep === "ask" && (
                <>
                  <div className="flex items-center gap-2 mb-3">
                    <span className="text-2xl">🌸</span>
                    <h4 className="text-base font-bold text-foreground">个性化舒适档位</h4>
                  </div>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-2">
                    妈妈，检测到您还没有进行过<span className="font-bold text-primary">耐受度滴定</span>哦~
                  </p>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-2">
                    滴定可以帮您找到<span className="font-bold text-primary">最舒适且高效</span>的吸力档位，避免吸乳时疼痛或效率不佳 💕
                  </p>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-4">
                    只需要 <span className="font-bold text-primary">2分钟</span>，就能让每次吸乳都更舒适~
                  </p>
                  <div className="flex gap-3">
                    <Button variant="outline" onClick={handleCalPromptNo} className="flex-1 rounded-xl text-xs">
                      先跳过
                    </Button>
                    <Button onClick={handleCalPromptYes} className="flex-1 rounded-xl text-xs font-bold">
                      开始滴定
                    </Button>
                  </div>
                </>
              )}

              {calPromptStep === "declined" && (
                <>
                  <div className="flex items-center gap-2 mb-3">
                    <span className="text-2xl">💡</span>
                    <h4 className="text-base font-bold text-foreground">温馨提示</h4>
                  </div>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-2">
                    好的妈妈~ 本次将使用<span className="font-bold text-primary">默认档位</span>开始吸乳。
                  </p>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-2">
                    每个人对吸力的耐受度不同，进行滴定后 M.ai 能为您<span className="font-bold text-primary">智能匹配最佳吸力</span>，兼顾舒适与效率 🫶
                  </p>
                  <p className="text-[12px] text-muted-foreground leading-relaxed mb-4">
                    您可以随时在首页发起耐受度滴定~
                  </p>
                  <Button onClick={handleCalPromptDeclinedOk} className="w-full rounded-xl text-xs font-bold">
                    知道啦，开始吸乳
                  </Button>
                </>
              )}

              {calPromptStep === "disableAsk" && (
                <>
                  <div className="flex items-center gap-2 mb-3">
                    <span className="text-2xl">🤔</span>
                    <h4 className="text-base font-bold text-foreground">关闭舒适度提醒？</h4>
                  </div>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-2">
                    您已经连续跳过了 3 次耐受度滴定提醒。
                  </p>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-2">
                    <span className="font-bold text-primary">个性化舒适档位</span>能根据您的身体情况，自动调节到最合适的吸力，减少疼痛感，同时保证吸乳效率。
                  </p>
                  <p className="text-[13px] text-muted-foreground leading-relaxed mb-4">
                    是否要<span className="font-bold text-destructive">关闭</span>此提醒？关闭后不再弹出，您仍可在首页手动发起滴定。
                  </p>
                  <div className="flex gap-3">
                    <Button variant="outline" onClick={handleCalDisableYes} className="flex-1 rounded-xl text-xs">
                      关闭提醒
                    </Button>
                    <Button onClick={handleCalDisableNo} className="flex-1 rounded-xl text-xs font-bold">
                      保留提醒
                    </Button>
                  </div>
                </>
              )}
            </motion.div>
          </div>
        </>
      )}
    </AnimatePresence>
    </div>
  );
};

const SideMetric: React.FC<{
  label: string;
  value: string;
  meta: string;
  active: boolean;
  align?: "left" | "right";
  offline?: boolean;
}> = ({ label, value, meta, active, align = "left", offline = false }) => (
  <div className={cn("w-[82px] space-y-1", align === "right" ? "text-right" : "text-left", offline && "opacity-50")}>
    <p className={cn("text-[10px] font-bold", active ? "text-orange-500" : "text-muted-foreground")}>
      {label}
      {offline && <span className="ml-1 text-[9px] text-muted-foreground">(离线)</span>}
    </p>
    <p className="text-lg font-extrabold text-foreground tabular-nums">{value}</p>
    <p className="text-[10px] leading-tight text-muted-foreground">{meta}</p>
  </div>
);

const SidePumpVisual: React.FC<{
  side: "L" | "R";
  flow: number;
  totalMl: number;
  running: boolean;
  offline?: boolean;
}> = ({ side, flow, totalMl, running, offline = false }) => {
  const isLeft = side === "L";
  const tone = isLeft ? "hsl(18 82% 52%)" : "hsl(340 56% 66%)";
  const fillPct = Math.min(100, Math.max(8, totalMl * 3));
  const fillHeight = 38 * (fillPct / 100);
  const pulse = !offline && running && flow > 0.2;
  const dropPath = "M24 6 C24 6 10 22 10 39 C10 54 16 62 24 62 C32 62 38 54 38 39 C38 22 24 6 24 6 Z";

  return (
    <motion.div
      className={cn("relative flex h-[72px] items-center justify-center", offline && "opacity-50")}
      animate={pulse ? { scale: [1, 1.05, 1] } : { scale: 1 }}
      transition={{ duration: 1.1, repeat: pulse ? Infinity : 0, ease: "easeInOut" }}
    >
      <svg width="48" height="68" viewBox="0 0 48 68" className="overflow-visible">
        <defs>
          <linearGradient id={`pump-cup-${side}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={tone} stopOpacity="0.55" />
            <stop offset="48%" stopColor="hsl(var(--card))" stopOpacity="0.95" />
            <stop offset="100%" stopColor="hsl(var(--secondary))" stopOpacity="0.72" />
          </linearGradient>
          <linearGradient id={`pump-milk-${side}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="hsl(45 62% 91%)" />
            <stop offset="100%" stopColor="hsl(38 50% 84%)" />
          </linearGradient>
          <filter id={`pump-shadow-${side}`} x="-40%" y="-40%" width="180%" height="180%">
            <feDropShadow dx="0" dy="4" stdDeviation="5" floodColor="hsl(var(--primary) / 0.18)" floodOpacity="0.22" />
          </filter>
        </defs>

        <path
          d={isLeft ? "M33 34 C38 34 43 34 48 34" : "M0 34 C5 34 10 34 15 34"}
          fill="none"
          stroke="hsl(var(--border))"
          strokeWidth="4.5"
          strokeLinecap="round"
          opacity="0.65"
        />
        <path
          d={isLeft ? "M33 34 C38 34 43 34 48 34" : "M0 34 C5 34 10 34 15 34"}
          fill="none"
          stroke={tone}
          strokeWidth="2.2"
          strokeLinecap="round"
          opacity={pulse ? 0.6 : 0.28}
        />
        {pulse && (
          <circle r="2" fill={tone} opacity="0.75">
            <animateMotion
              dur="1s"
              repeatCount="indefinite"
              path={isLeft ? "M33 34 C38 34 43 34 48 34" : "M15 34 C10 34 5 34 0 34"}
            />
          </circle>
        )}

        <g filter={`url(#pump-shadow-${side})`}>
          <path d={dropPath} fill={`url(#pump-cup-${side})`} stroke={`${tone}55`} strokeWidth="1.1" />
          <clipPath id={`pump-fill-clip-${side}`}>
            <path d={dropPath} />
          </clipPath>
          <g clipPath={`url(#pump-fill-clip-${side})`}>
            <motion.rect
              x="10"
              y={62 - fillHeight}
              width="28"
              height={fillHeight + 8}
              fill={`url(#pump-milk-${side})`}
              animate={{ y: 62 - fillHeight, height: fillHeight + 8 }}
              transition={{ duration: 0.4 }}
            />
            {pulse && (
              <path
                d={`M10 ${62 - fillHeight + 2} Q17 ${62 - fillHeight - 2} 24 ${62 - fillHeight + 2} Q31 ${62 - fillHeight + 5} 38 ${62 - fillHeight + 2} V70 H10 Z`}
                fill="white"
                opacity="0.18"
                className="breast-wave"
              />
            )}
          </g>
          <path d="M17 15 C20 11 23 8 24 7" stroke="white" strokeWidth="3" opacity="0.22" strokeLinecap="round" />
          <ellipse cx="24" cy="43" rx="12" ry="5" fill="white" opacity="0.16" />
          <circle cx={isLeft ? 37 : 11} cy="34" r="4.1" fill="hsl(var(--card))" stroke="hsl(var(--border))" strokeWidth="1" />
          <circle cx={isLeft ? 37 : 11} cy="34" r="2.2" fill={tone} opacity={pulse ? 0.5 : 0.25} />
        </g>
      </svg>
    </motion.div>
  );
};

/** 奶流强度曲线纵轴固定为 0~1（与 BLE 归一化 bandpower 一致，见 ble.ts BLE_BANDPOWER_NORMALIZATION_ENABLED） */
function clampFlowChart01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.min(1, Math.max(0, n));
}

const ForceLinePanel: React.FC<{
  label: string;
  sideLabel: string;
  value: number;
  points: number[];
  active: boolean;
  tone: string;
  offline?: boolean;
}> = ({ label, sideLabel, value, points, active, tone, offline = false }) => {
  const displayNorm = clampFlowChart01(value);
  const pathPoints = useMemo(() => {
    // 该侧 buffer 完全独立：离线时不再 push，长度不变，x 映射分母不变，曲线绝对静止；
    // 在线运行时按 buffer 增长正常滚动。
    const values = points.length ? points : [value, value, value];
    return values.map((current, index) => {
      const x = values.length === 1 ? 0 : (index / (values.length - 1)) * 100;
      const yn = clampFlowChart01(current);
      const y = 56 - yn * 44;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(" ");
  }, [points, value]);

  return (
    <div className={cn("overflow-hidden rounded-2xl bg-secondary/70 px-2.5 py-2 shadow-inner", offline && "opacity-50")}>
      <div className="mb-1.5 flex items-start justify-between gap-2">
        <div>
          <p className="text-[10px] font-bold text-muted-foreground">
            {label}
            {offline && <span className="ml-1 text-[9px] text-muted-foreground">(离线)</span>}
          </p>
          <div className="mt-1 flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: tone }} />
            <span className="text-[9px] font-semibold text-muted-foreground">{sideLabel}</span>
          </div>
        </div>
        <span className={cn("text-[10px] font-extrabold tabular-nums", active ? "text-orange-500" : "text-foreground")}>
          {displayNorm.toFixed(2)}
        </span>
      </div>
      <svg viewBox="0 0 100 58" className="h-12 w-full overflow-hidden min-[380px]:h-14" preserveAspectRatio="none">
        <line x1="0" y1="56" x2="100" y2="56" stroke="hsl(var(--border))" strokeWidth="1" opacity="0.45" />
        <polyline
          points={pathPoints}
          fill="none"
          stroke={tone}
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <polyline
          points={`${pathPoints} 100,58 0,58`}
          fill={tone}
          opacity="0.08"
          stroke="none"
        />
      </svg>
    </div>
  );
};

const MetricPanel: React.FC<{
  label: string;
  value: string | number;
  unit?: string;
  emphasis?: boolean;
  onClick?: () => void;
}> = ({ label, value, unit, emphasis = false, onClick }) => {
  const content = (
    <>
      <p className="text-[10px] font-bold text-muted-foreground">{label}</p>
      <p className={cn("mt-1 font-extrabold tracking-tighter tabular-nums", emphasis ? "text-4xl text-primary" : "text-3xl text-foreground")}>
        {value}
        {unit && <span className="ml-1 text-sm font-bold text-muted-foreground">{unit}</span>}
      </p>
    </>
  );

  if (onClick) {
    return (
      <button onClick={onClick} className="rounded-2xl bg-secondary/55 px-3 py-2 text-left transition-colors hover:bg-secondary/70">
        {content}
      </button>
    );
  }

  return <div className="rounded-2xl bg-secondary/55 px-3 py-2">{content}</div>;
};

const ConfirmDialog: React.FC<{
  open: boolean;
  title: string;
  description: string;
  confirmLabel: string;
  cancelLabel?: string;
  destructive?: boolean;
  onConfirm: () => void;
  onCancel?: () => void;
}> = ({ open, title, description, confirmLabel, cancelLabel, destructive = false, onConfirm, onCancel }) => (
  <AnimatePresence>
    {open && (
      <>
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="absolute inset-0 z-[72] bg-foreground/35 backdrop-blur-sm"
          onClick={onCancel}
        />
        <div className="absolute inset-0 z-[73] flex items-center justify-center px-4 pointer-events-none">
          <motion.div
            initial={{ scale: 0.92, opacity: 0, y: 12 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            exit={{ scale: 0.92, opacity: 0, y: 12 }}
            className="w-full max-w-sm rounded-2xl border border-border bg-card p-5 shadow-2xl pointer-events-auto"
          >
            <h4 className="mb-2 text-base font-bold text-foreground">{title}</h4>
            <p className="mb-5 text-sm leading-relaxed text-muted-foreground">{description}</p>
            <div className="flex gap-3">
              {cancelLabel && onCancel && (
                <Button variant="outline" onClick={onCancel} className="flex-1 rounded-xl">
                  {cancelLabel}
                </Button>
              )}
              <Button
                onClick={onConfirm}
                variant={destructive ? "destructive" : "default"}
                className="flex-1 rounded-xl"
              >
                {confirmLabel}
              </Button>
            </div>
          </motion.div>
        </div>
      </>
    )}
  </AnimatePresence>
);

export default PumpSession;
