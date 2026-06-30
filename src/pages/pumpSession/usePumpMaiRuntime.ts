import { useEffect, useRef, useState } from "react";
import { onPumpAgentUploadProcessReply } from "@/lib/pumpAgentUpload";
import { pumpEncourageLibrary } from "@/assets/pumpEncourageLibrary";
import type { MaiSessionBubble, PumpMode } from "./pumpSessionModel";

const ENCOURAGE_BUBBLE_VISIBLE_MS = 3000;
const ENCOURAGE_BUBBLE_MIN_DELAY_MS = 30000;
const ENCOURAGE_BUBBLE_MAX_DELAY_MS = 60000;
const ENABLE_ENCOURAGE_BUBBLE = false;
const ENABLE_PROCESS_REPLY_BUBBLE = false;
const PROCESS_REPLY_BUBBLE_DEDUP_MS = 30000;

export function usePumpMaiRuntime(params: {
  isSessionRunning: boolean;
  leftMode: PumpMode;
  rightMode: PumpMode;
  onActionClick?: (text: string) => void;
}) {
  const { isSessionRunning, leftMode, rightMode, onActionClick } = params;
  const [maiSessionBubble, setMaiSessionBubble] = useState<MaiSessionBubble | null>(null);
  const encourageBubbleTimerRef = useRef<number | null>(null);
  const encourageHideTimerRef = useRef<number | null>(null);
  const lastProcessReplyTextRef = useRef("");
  const lastProcessReplyAtRef = useRef(0);
  const onActionClickRef = useRef(onActionClick);

  useEffect(() => {
    onActionClickRef.current = onActionClick;
  }, [onActionClick]);

  useEffect(() => {
    const unsubscribe = onPumpAgentUploadProcessReply(({ text, buttons }) => {
      if (!ENABLE_PROCESS_REPLY_BUBBLE) return;
      const cleanText = text.trim();
      const actionList = (buttons ?? [])
        .filter((btn) => Boolean(btn.text || btn.value))
        .map((btn) => ({
          label: btn.text || btn.value,
          action: () => {
            onActionClickRef.current?.(btn.value || btn.text || "");
            setMaiSessionBubble(null);
          },
        }));
      if (!cleanText && actionList.length === 0) return;
      const dedupKey = `${cleanText}::${actionList.map((item) => item.label).join("|")}`;
      const now = Date.now();
      if (
        dedupKey === lastProcessReplyTextRef.current &&
        now - lastProcessReplyAtRef.current < PROCESS_REPLY_BUBBLE_DEDUP_MS
      ) {
        return;
      }
      lastProcessReplyTextRef.current = dedupKey;
      lastProcessReplyAtRef.current = now;
      setMaiSessionBubble({
        text: cleanText || "M.ai 有新的建议",
        ...(actionList.length > 0 ? { actions: actionList } : {}),
      });
    });
    return unsubscribe;
  }, []);

  useEffect(() => {
    if (!ENABLE_ENCOURAGE_BUBBLE) return;
    if (!isSessionRunning) return;
    const clearTimers = () => {
      if (encourageBubbleTimerRef.current != null) {
        window.clearTimeout(encourageBubbleTimerRef.current);
        encourageBubbleTimerRef.current = null;
      }
      if (encourageHideTimerRef.current != null) {
        window.clearTimeout(encourageHideTimerRef.current);
        encourageHideTimerRef.current = null;
      }
    };
    const scheduleNext = () => {
      const delay = ENCOURAGE_BUBBLE_MIN_DELAY_MS + Math.floor(
        Math.random() * (ENCOURAGE_BUBBLE_MAX_DELAY_MS - ENCOURAGE_BUBBLE_MIN_DELAY_MS + 1),
      );
      encourageBubbleTimerRef.current = window.setTimeout(() => {
        const pool = leftMode === "deep" || rightMode === "deep"
          ? pumpEncourageLibrary.deep
          : pumpEncourageLibrary.stimulate;
        const picked = pool[Math.floor(Math.random() * pool.length)];
        setMaiSessionBubble({ text: picked });
        encourageHideTimerRef.current = window.setTimeout(() => {
          setMaiSessionBubble((prev) => (prev?.text === picked && !prev.actions ? null : prev));
          scheduleNext();
        }, ENCOURAGE_BUBBLE_VISIBLE_MS);
      }, delay);
    };
    scheduleNext();
    return clearTimers;
  }, [isSessionRunning, leftMode, rightMode]);

  return {
    maiSessionBubble,
    setMaiSessionBubble,
    enableEncourageBubble: ENABLE_ENCOURAGE_BUBBLE,
    enableProcessReplyBubble: ENABLE_PROCESS_REPLY_BUBBLE,
  };
}
