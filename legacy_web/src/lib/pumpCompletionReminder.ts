import { Capacitor } from "@capacitor/core";
import { toast } from "@/components/ui/use-toast";
import { createScopedConsole } from "@/lib/logger";
import { getProcessAll, subscribeProcessAll } from "@/lib/pumpSessionProgress";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import type { SessionState } from "@/pages/pumpSession/pumpSessionModel";
import { showPumpCompletionLocalNotice } from "@/lib/pumpSessionNotification";

const log = createScopedConsole("PumpCompletionReminder");

const STORAGE_NOTIFIED = "pump_session_completion_100_notified";

const isAndroidNative = Capacitor.getPlatform() === "android";

const COMPLETION_TITLE = "吸奶已完成！";
const COMPLETION_DESC = "如感觉还有硬块或发胀，可以再吸一会帮助排空～";

function readNotified(): boolean {
  try {
    return sessionStorage.getItem(STORAGE_NOTIFIED) === "1";
  } catch {
    return false;
  }
}

function setNotified(): void {
  try {
    sessionStorage.setItem(STORAGE_NOTIFIED, "1");
  } catch {
    /* ignore */
  }
}

function clearNotified(): void {
  try {
    sessionStorage.removeItem(STORAGE_NOTIFIED);
  } catch {
    /* ignore */
  }
}

function shouldClearCompletionFlag(prev: SessionState, next: SessionState): boolean {
  if (next === "idle") return true;
  if (next === "running" && (prev === "idle" || prev === "ended")) return true;
  return false;
}

function showCompletionToast(): void {
  toast({
    title: COMPLETION_TITLE,
    description: COMPLETION_DESC,
  });
}

export function startPumpCompletionReminder(): void {
  if (typeof window === "undefined") return;

  let prevLifecycle: SessionState = pumpSessionLifecycle.getSessionState();
  pumpSessionLifecycle.subscribe((next) => {
    if (shouldClearCompletionFlag(prevLifecycle, next)) {
      clearNotified();
    }
    prevLifecycle = next;
  });

  let prevPct = clampPct(getProcessAll());

  subscribeProcessAll(() => {
    const now = clampPct(getProcessAll());
    const prev = prevPct;
    prevPct = now;

    if (now < 100) return;
    if (prev >= 100) return;
    if (!pumpSessionLifecycle.isActive()) return;
    if (readNotified()) return;

    setNotified();

    const onPump =
      typeof window !== "undefined" && window.location.pathname === "/pump";

    if (onPump) {
      showCompletionToast();
      return;
    }

    if (isAndroidNative) {
      void showPumpCompletionLocalNotice().catch((error) => {
        log.warn("showPumpCompletionLocalNotice failed", error);
        showCompletionToast();
      });
      return;
    }

    showCompletionToast();
  });
}

function clampPct(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
}
