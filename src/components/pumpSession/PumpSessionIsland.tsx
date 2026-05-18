import React, { useCallback, useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { Droplets } from "lucide-react";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";
import { getProcessAll, subscribeProcessAll } from "@/lib/pumpSessionProgress";

const BAR_MIN_H = 56;

function statusLabel(sessionState: SessionState): string {
  if (sessionState === "running") return "进行中";
  if (sessionState === "paused") return "已暂停";
  return "";
}

function clampPct01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
}

const PumpSessionIsland: React.FC = () => {
  const navigate = useNavigate();
  const { pathname } = useLocation();

  const [sessionState, setSessionState] = useState<SessionState>(() =>
    pumpSessionLifecycle.getSessionState(),
  );
  const [processPct, setProcessPct] = useState(() =>
    clampPct01(getProcessAll()),
  );

  useEffect(() => {
    return pumpSessionLifecycle.subscribe((next) => {
      setSessionState(next);
      setProcessPct(clampPct01(getProcessAll()));
    });
  }, []);

  useEffect(() => {
    return subscribeProcessAll(() => {
      setProcessPct(clampPct01(getProcessAll()));
    });
  }, []);

  /** 离开吸乳页后须立即反映全局会话态；与 lifecycle.subscribe 回放互补，防御极端时序 */
  useEffect(() => {
    setSessionState(pumpSessionLifecycle.getSessionState());
    setProcessPct(clampPct01(getProcessAll()));
  }, [pathname]);

  const excludeRoute = pathname === "/media-viewer" || pathname === "/pump";

  const sessionActive = sessionState === "running" || sessionState === "paused";
  const showIsland = !excludeRoute && sessionActive;

  const pctRounded = clampPct01(processPct);
  const sub = statusLabel(sessionState);

  const goPump = useCallback(() => {
    navigate("/pump");
  }, [navigate]);

  if (!showIsland) return null;

  return (
    <div
      className="fixed inset-x-0 top-0 z-[120] flex w-full flex-col items-stretch pointer-events-none"
      aria-live="polite"
    >
      <div
        className="pointer-events-auto shrink-0 px-3"
        style={{ paddingTop: "var(--top-safe)" }}
      >
        <div
          role="region"
          aria-label="吸乳进程"
          className="relative overflow-hidden rounded-2xl border border-border/70 bg-card text-card-foreground shadow-xl"
        >
          <div
            className="flex cursor-pointer flex-col px-3 py-2.5 select-none active:bg-muted/40"
            style={{ minHeight: BAR_MIN_H }}
            role="link"
            tabIndex={0}
            aria-label={`当前吸乳进程 ${pctRounded}%，${sub}，点击进入吸乳页`}
            onClick={goPump}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                goPump();
              }
            }}
          >
            <div className="pointer-events-none flex items-start gap-2">
              <Droplets
                className="mt-1 h-4 w-4 shrink-0 text-primary"
                aria-hidden
              />

              <div className="min-w-0 flex-1 pt-0.5">
                <div className="truncate text-[15px] font-semibold text-foreground">
                  当前吸乳进程：{pctRounded}%
                </div>
              </div>

              <div className="pointer-events-none max-w-[40%] shrink-0 truncate pt-0.5 text-right text-[13px] text-muted-foreground">
                {sub}
              </div>
            </div>

            <div className="pointer-events-none mt-2 h-1 overflow-hidden rounded-full bg-muted">
              <motion.div
                className="h-full rounded-full bg-primary"
                initial={false}
                animate={{ width: `${pctRounded}%` }}
                transition={{ duration: 0.22, ease: "easeOut" }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PumpSessionIsland;
