import { useCallback, useEffect, useMemo, useRef, type Dispatch, type SetStateAction } from "react";
import { resetPumpAgentUploadProcessProgress } from "@/lib/pumpAgentUpload";
import { pushPumpMilkUploadForPumpSessionEnd } from "@/lib/pumpAutoEndSession";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import { usePumpMaiRuntime } from "./usePumpMaiRuntime";
import { usePumpMockRuntime } from "./usePumpMockRuntime";
import { usePumpDeviceControlRuntime } from "./usePumpDeviceControlRuntime";
import { usePumpAgentRuntime } from "./usePumpAgentRuntime";
import type { SessionState, SideState } from "./pumpSessionModel";
import { initialAiModeFromStore } from "./pumpSessionModel";

interface ControllerParams {
  calData: unknown;
  fromCalibration: boolean;
  targetGearL: number;
  targetGearR: number;
  left: SideState;
  right: SideState;
  aiMode: boolean;
  isSessionRunning: boolean;
  sessionState: SessionState;
  calPromptRunning: boolean;
  setBottlePct: Dispatch<SetStateAction<number>>;
  setFlowDataL: Dispatch<SetStateAction<number[]>>;
  setFlowDataR: Dispatch<SetStateAction<number[]>>;
  setProgressL: Dispatch<SetStateAction<number>>;
  setProgressR: Dispatch<SetStateAction<number>>;
  setProgressAll: Dispatch<SetStateAction<number>>;
  processAll: number;
  elapsed: number;
  setElapsed: Dispatch<SetStateAction<number>>;
  setAiMode: Dispatch<SetStateAction<boolean>>;
  setSessionState: Dispatch<SetStateAction<SessionState>>;
  setLeft: Dispatch<SetStateAction<SideState>>;
  setRight: Dispatch<SetStateAction<SideState>>;
  setDevicePowerOffOpen: Dispatch<SetStateAction<boolean>>;
  setManualConfirmOpen: Dispatch<SetStateAction<boolean>>;
  setFinishConfirmOpen: Dispatch<SetStateAction<boolean>>;
  navigateHome: () => void;
}

export function usePumpSessionController(params: ControllerParams) {
  const {
    left,
    right,
    aiMode,
    calData,
    fromCalibration,
    targetGearL,
    targetGearR,
    isSessionRunning,
    sessionState,
    calPromptRunning,
    setBottlePct,
    setFlowDataL,
    setFlowDataR,
    setProgressL,
    setProgressR,
    setProgressAll,
    processAll,
    elapsed,
    setElapsed,
    setAiMode,
    setSessionState,
    setLeft,
    setRight,
    setDevicePowerOffOpen,
    setManualConfirmOpen,
    setFinishConfirmOpen,
    navigateHome,
  } = params;

  const mockRuntime = usePumpMockRuntime({
    sessionState,
    calData,
    fromCalibration,
    targetGearL,
    targetGearR,
    left,
    right,
    aiMode,
    isSessionRunning,
    calPromptRunning,
    setLeft,
    setRight,
    setElapsed,
    setBottlePct,
    setFlowDataL,
    setFlowDataR,
    setProgressL,
    setProgressR,
    setProgressAll,
  });
  const agentRuntime = usePumpAgentRuntime();
  const maiRuntime = usePumpMaiRuntime({
    isSessionRunning: sessionState === "running",
    leftMode: left.mode,
    rightMode: right.mode,
    onActionClick: (text) => {
      if (text.trim()) agentRuntime.sendAgentQuery(text.trim());
    },
  });
  const deviceControlRuntime = usePumpDeviceControlRuntime({
    left,
    right,
    aiMode,
    enablePumpSessionMockEffects: mockRuntime.enablePumpSessionMockEffects,
    sessionState,
    setSessionState,
    setLeft,
    setRight,
    setElapsed,
    setAiMode,
  });

  const initialAiMode = useMemo(() => initialAiModeFromStore(), []);
  const sessionProgress = Math.max(0, Math.min(100, processAll));
  const canToggleSession = true;
  const setModeBoth = useCallback((mode: SideState["mode"]) => {
    void deviceControlRuntime.setModeBoth(mode);
  }, [deviceControlRuntime]);

  const handleAiModeRequest = useCallback(async (next: boolean) => {
    return deviceControlRuntime.handleAiModeRequest(next);
  }, [deviceControlRuntime]);

  const handleMockHigh = useCallback(() => {
    if (mockRuntime.mockFlow === "high") {
      mockRuntime.setMockFlow("off");
      return;
    }
    setModeBoth("stimulate");
    mockRuntime.setMockFlow("high");
  }, [mockRuntime, setModeBoth]);

  const handleMockLow = useCallback(() => {
    if (mockRuntime.mockFlow === "low") {
      mockRuntime.setMockFlow("off");
      return;
    }
    setModeBoth("deep");
    mockRuntime.setMockFlow("low");
  }, [mockRuntime, setModeBoth]);

  const summaryPushedRef = useRef(false);
  const summaryPushingRef = useRef(false);
  const pumpMilkUploadedRef = useRef(false);
  const pushStopPumpAgentSummary = agentRuntime.pushStopPumpAgentSummary;
  const stopPumpWithBleFn = deviceControlRuntime.stopPumpWithBle;

  const finalizePumpSession = useCallback(async (options?: { navigateAfter?: boolean }) => {
    if (summaryPushedRef.current) {
      setSessionState("ended");
      if (options?.navigateAfter) navigateHome();
      return;
    }
    if (summaryPushingRef.current) return;
    summaryPushingRef.current = true;
    if (pumpSessionLifecycle.getSessionState() !== "ended") {
      pumpSessionLifecycle.markSessionEnded("user-confirm");
    }
    const endedEvent = pumpSessionLifecycle.getLastEndedEvent();
    setSessionState("ended");
    setLeft((p) => ({ ...p, flow: 0 }));
    setRight((p) => ({ ...p, flow: 0 }));
    try {
      await stopPumpWithBleFn();
    } catch (error) {
      console.error("[PumpSession] stopPumpWithBle failed:", error);
    }
    if (!pumpMilkUploadedRef.current) {
      try {
        await pushPumpMilkUploadForPumpSessionEnd(endedEvent);
        pumpMilkUploadedRef.current = true;
      } catch (error) {
        console.error("[PumpSession] pushPumpMilkUploadForPumpSessionEnd failed:", error);
      }
    }
    try {
      await pushStopPumpAgentSummary(endedEvent, { displayedDurationSeconds: elapsed });
      summaryPushedRef.current = true;
      resetPumpAgentUploadProcessProgress();
      if (options?.navigateAfter) navigateHome();
    } catch (error) {
      console.error("[PumpSession] pushStopPumpAgentSummary failed:", error);
    } finally {
      summaryPushingRef.current = false;
    }
  }, [elapsed, navigateHome, pushStopPumpAgentSummary, stopPumpWithBleFn, setLeft, setRight, setSessionState]);

  const handleStopPump = useCallback(async () => {
    await finalizePumpSession();
  }, [finalizePumpSession]);

  useEffect(() => {
    const handleDevicePowerOff = () => {
      if (pumpSessionLifecycle.getSessionState() === "ended") return;
      void handleStopPump();
      setDevicePowerOffOpen(true);
    };
    window.addEventListener("pump-device-end", handleDevicePowerOff);
    window.addEventListener("pump-device-power-off", handleDevicePowerOff);
    return () => {
      window.removeEventListener("pump-device-end", handleDevicePowerOff);
      window.removeEventListener("pump-device-power-off", handleDevicePowerOff);
    };
  }, [handleStopPump, setDevicePowerOffOpen]);

  const handleFinish = useCallback(() => {
    if (sessionState !== "ended") setFinishConfirmOpen(true);
  }, [sessionState, setFinishConfirmOpen]);

  const confirmFinish = useCallback(async () => {
    setFinishConfirmOpen(false);
    await finalizePumpSession({ navigateAfter: true });
  }, [finalizePumpSession, setFinishConfirmOpen]);

  const handleSwitchToManual = useCallback(() => {
    if (aiMode) setManualConfirmOpen(true);
  }, [aiMode, setManualConfirmOpen]);

  const confirmSwitchToManual = useCallback(() => {
    setManualConfirmOpen(false);
    void handleAiModeRequest(false);
  }, [handleAiModeRequest, setManualConfirmOpen]);

  const handleBack = useCallback(() => {
    navigateHome();
  }, [navigateHome]);

  const confirmDevicePowerOff = useCallback(() => {
    setDevicePowerOffOpen(false);
    navigateHome();
  }, [navigateHome, setDevicePowerOffOpen]);

  return {
    ...mockRuntime,
    ...maiRuntime,
    ...deviceControlRuntime,
    ...agentRuntime,
    initialAiMode,
    sessionProgress,
    canToggleSession,
    setModeBoth,
    handleAiModeRequest,
    handleMockHigh,
    handleMockLow,
    handleSwitchToManual,
    confirmSwitchToManual,
    handleBack,
    confirmDevicePowerOff,
    handleFinish,
    confirmFinish,
  };
}
