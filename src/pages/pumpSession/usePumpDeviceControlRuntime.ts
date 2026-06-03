import { useCallback, useEffect, useRef, type Dispatch, type SetStateAction } from "react";
import { Capacitor } from "@capacitor/core";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";
import {
  ensureProtocolNotify,
  isBleSupported,
  nativeAdjustGearForSide,
  nativeSetModeForSide,
  nativeSetSceneForSide,
  nativeSetStartStopForSide,
  powerOffDeviceAndUpdateStore,
  queryDeviceStatusAndUpdateStore,
} from "@/lib/ble";
import {
  markPumpAgentUploadProcessStepPause,
  markPumpAgentUploadProcessStepStop,
  onPumpAgentUploadProcessProgress,
  refreshPumpAgentUploadNativeProgressSnapshot,
  setPumpAgentUploadOperationSource,
} from "@/lib/pumpAgentUpload";
import {
  fromProtocolGear,
  fromProtocolPumpMode,
  MAX_GEAR,
  MIN_GEAR,
  toProtocolMode,
  type SessionState,
  type SideState,
} from "./pumpSessionModel";
import { createScopedConsole } from "@/lib/logger";

interface PumpDeviceControlRuntimeParams {
  left: SideState;
  right: SideState;
  aiMode: boolean;
  sessionState: SessionState;
  setSessionState: Dispatch<SetStateAction<SessionState>>;
  setLeft: Dispatch<SetStateAction<SideState>>;
  setRight: Dispatch<SetStateAction<SideState>>;
  setElapsed: Dispatch<SetStateAction<number>>;
  setAiMode: Dispatch<SetStateAction<boolean>>;
}

const nextRunningDuration = (running: boolean, duration: unknown): number | undefined => {
  if (!running) return undefined;
  return typeof duration === "number" ? duration + 1 : 1;
};

const isAndroidNativeRuntime = Capacitor.getPlatform() === "android";

export function usePumpDeviceControlRuntime(params: PumpDeviceControlRuntimeParams) {
  const {
    left,
    right,
    aiMode,
    sessionState,
    setSessionState,
    setLeft,
    setRight,
    setElapsed,
    setAiMode,
  } = params;
  const deviceRuntimeLogger = createScopedConsole("PumpDeviceControlRuntime");
  const prevConnectedSidesRef = useRef<DeviceSide[]>([]);
  const reconnectTimerRef = useRef<number | null>(null);

  const syncUiFromStore = useCallback(() => {
    const { L, R } = deviceStore.get();
    const leftOnline = !!L?.connected;
    const rightOnline = !!R?.connected;
    const leftRunning = leftOnline && L?.pumpWorkState === 0x01;
    const rightRunning = rightOnline && R?.pumpWorkState === 0x01;

    if (leftOnline && rightOnline && L?.pumpScene != null && R?.pumpScene != null) {
      if (L.pumpScene === R.pumpScene) setAiMode(L.pumpScene === 1);
      else setAiMode(false);
    } else if (leftOnline && L?.pumpScene != null) {
      setAiMode(L.pumpScene === 1);
    } else if (rightOnline && R?.pumpScene != null) {
      setAiMode(R.pumpScene === 1);
    }

    // 左右设备状态各自独立同步：双侧模式不一致（例如一侧自动切吸乳）时也必须刷新对应侧 UI，
    // 否则会残留进页初值（如 cozy-2）并导致档位/模式显示错误。
    if (leftOnline && L?.pumpMode != null && L?.gear != null) {
      setLeft((prev) => ({
        ...prev,
        mode: fromProtocolPumpMode(L.pumpMode as number),
        gear: fromProtocolGear(L.gear),
      }));
    }
    if (rightOnline && R?.pumpMode != null && R?.gear != null) {
      setRight((prev) => ({
        ...prev,
        mode: fromProtocolPumpMode(R.pumpMode as number),
        gear: fromProtocolGear(R.gear),
      }));
    }

    // 会话状态由 pumpSessionLifecycle（订阅 deviceStore 后边缘触发）统一推进，本处不再直接写 sessionState，
    // 避免「设备已连接但未启动」的窗口期被误判为 paused。

    if (!isAndroidNativeRuntime) {
      const runningDurations = [
        leftRunning && typeof L?.duration === "number" ? L.duration : undefined,
        rightRunning && typeof R?.duration === "number" ? R.duration : undefined,
      ].filter((duration): duration is number => duration != null);
      if (runningDurations.length > 0) setElapsed(Math.max(...runningDurations));
    }
  }, [setAiMode, setElapsed, setLeft, setRight]);

  const handleNewDeviceConnection = useCallback(async (deviceId: string, side: DeviceSide) => {
    try {
      await ensureProtocolNotify(deviceId).catch(() => {});
      await queryDeviceStatusAndUpdateStore(deviceId, side).catch(() => {});
      await new Promise((resolve) => window.setTimeout(resolve, 500));
      syncUiFromStore();
    } catch {
      // ignore
    }
  }, [syncUiFromStore]);

  const handleConnectionDelta = useCallback(() => {
    const { L, R } = deviceStore.get();
    const currentConnectedSides: DeviceSide[] = [];
    if (L?.connected) currentConnectedSides.push("L");
    if (R?.connected) currentConnectedSides.push("R");
    const prevConnectedSides = prevConnectedSidesRef.current;
    const newConnectedSides = currentConnectedSides.filter((side) => !prevConnectedSides.includes(side));
    const disconnectedSides = prevConnectedSides.filter((side) => !currentConnectedSides.includes(side));

    // 必须先更新 prev ref，再执行任何会触发 deviceStore 通知的副作用，
    // 否则 setDevice 同步触发的递归回调里会读到旧 prev ref，
    // 把同一侧再次识别为「刚断开」并继续 setDevice，导致主线程同步无限递归 → UI 卡死。
    prevConnectedSidesRef.current = currentConnectedSides;

    if (newConnectedSides.length > 0) {
      if (reconnectTimerRef.current != null) window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = window.setTimeout(() => {
        newConnectedSides.forEach((side) => {
          const device = deviceStore.get()[side];
          if (device?.connected && device.deviceId) {
            void handleNewDeviceConnection(device.deviceId, side);
          }
        });
      }, 1000);
    }

    if (disconnectedSides.length > 0) {
      disconnectedSides.forEach((side) => {
        const current = deviceStore.get()[side];
        if (!current) return;
        // 幂等保护：duration 已为 0 直接跳过，避免无意义的 setDevice 触发整链订阅者
        if (current.duration === 0) return;
        deviceStore.setDevice(side, { ...current, duration: 0 });
      });
    }
  }, [handleNewDeviceConnection]);

  const sideB1Params = useCallback((side: DeviceSide) => {
    const dev = deviceStore.get()[side];
    if (!dev?.connected || !dev.deviceId) return null;
    const workState = dev.pumpWorkState ?? 0x00;
    return { deviceId: dev.deviceId, workState };
  }, []);

  useEffect(() => {
    if (!isBleSupported()) return;
    syncUiFromStore();
    const unsub = deviceStore.subscribe(syncUiFromStore);
    return unsub;
  }, [syncUiFromStore]);

  useEffect(() => {
    if (!isBleSupported()) return;
    handleConnectionDelta();
    const unsub = deviceStore.subscribe(handleConnectionDelta);
    return () => {
      unsub();
      if (reconnectTimerRef.current != null) window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    };
  }, [handleConnectionDelta]);

  useEffect(() => {
    if (!isBleSupported()) return;
    const { L, R } = deviceStore.get();
    if (L?.connected && L.deviceId) void queryDeviceStatusAndUpdateStore(L.deviceId, "L");
    if (R?.connected && R.deviceId) void queryDeviceStatusAndUpdateStore(R.deviceId, "R");
  }, []);

  // 旧的 500ms 轮询 updateRunningState 已删除：会话状态由 pumpSessionLifecycle（基于 deviceStore 订阅 + 边缘触发）统一推进。

  useEffect(() => {
    if (!isAndroidNativeRuntime) return;
    void refreshPumpAgentUploadNativeProgressSnapshot();
    return onPumpAgentUploadProcessProgress(({ elapsedSeconds }) => {
      if (typeof elapsedSeconds === "number" && Number.isFinite(elapsedSeconds)) {
        setElapsed(Math.max(0, Math.round(elapsedSeconds)));
      }
    });
  }, [setElapsed]);

  useEffect(() => {
    if (isAndroidNativeRuntime) return;
    if (sessionState !== "running") return;
    const timer = window.setInterval(() => {
      const { L, R } = deviceStore.get();
      const leftOnline = !!L?.connected;
      const rightOnline = !!R?.connected;
      const leftRunning = leftOnline && L?.pumpWorkState === 0x01;
      const rightRunning = rightOnline && R?.pumpWorkState === 0x01;
      if (!leftRunning && !rightRunning) return;

      const nextDurationL = nextRunningDuration(leftRunning, L?.duration);
      const nextDurationR = nextRunningDuration(rightRunning, R?.duration);
      const runningDurations = [nextDurationL, nextDurationR].filter((duration): duration is number => duration != null);
      if (runningDurations.length > 0) setElapsed(Math.max(...runningDurations));

      if (leftRunning && L && nextDurationL != null) {
        deviceStore.setDevice("L", { ...L, duration: nextDurationL });
      }
      if (rightRunning && R && nextDurationR != null) {
        deviceStore.setDevice("R", { ...R, duration: nextDurationR });
      }
    }, 1000);
    return () => window.clearInterval(timer);
  }, [sessionState, setElapsed]);

  const applyGearDelta = useCallback((side: DeviceSide, delta: number, source: "app" | "agent" = "app") => {
    const setter = side === "L" ? setLeft : setRight;
    setPumpAgentUploadOperationSource(side, source);
    setter((prev) => {
      const next = Math.max(MIN_GEAR, Math.min(MAX_GEAR, prev.gear + delta));
      if (isBleSupported()) {
        const stored = deviceStore.get()[side];
        if (stored?.connected && stored.deviceId) {
          void (async () => {
            const ok = await nativeAdjustGearForSide(side, delta);
            if (ok) syncUiFromStore();
          })();
        }
      }
      return { ...prev, gear: next };
    });
  }, [setLeft, setRight, syncUiFromStore]);

  const pauseResume = useCallback(async () => {
    if (!isBleSupported()) {
      setSessionState((prev) => (prev === "running" ? "paused" : "running"));
      return;
    }
    const items = (["L", "R"] as const)
      .map((side) => {
        const p = sideB1Params(side);
        return p == null ? null : { side, ...p };
      })
      .filter((x): x is NonNullable<typeof x> => x != null);
    if (items.length === 0) {
      return;
    }
    // 与 last handlePauseResume 一致：按设备实际启停聚合方向下发，避免 sessionState 与上报短暂不一致时误操作
    let nextStart: 0 | 1;
    if (sessionState === "idle" || sessionState === "ended") {
      nextStart = 1;
    } else {
      const anyRunningBle = (["L", "R"] as const).some((side) => {
        const d = deviceStore.get()[side];
        return !!d?.connected && d.pumpWorkState === 0x01;
      });
      nextStart = anyRunningBle ? 0 : 1;
    }
    setPumpAgentUploadOperationSource("both", "app");
    let anyFailed = false;
    for (const it of items) {
      const { side, workState } = it;
      if (nextStart === 1 && workState !== 0x00) continue;
      if (nextStart === 0 && workState !== 0x01) continue;
      if (nextStart === 0) markPumpAgentUploadProcessStepPause(side);
      const ok = await nativeSetStartStopForSide(side, nextStart);
      if (!ok) {
        anyFailed = true;
        continue;
      }
      syncUiFromStore();
    }
    if (!anyFailed) {
      setSessionState(nextStart === 1 ? "running" : "paused");
      return;
    }
    const refreshed = deviceStore.get();
    const hasRunning = (["L", "R"] as const).some((side) => refreshed[side]?.connected && refreshed[side]?.pumpWorkState === 0x01);
    setSessionState(hasRunning ? "running" : "paused");
  }, [sessionState, setSessionState, sideB1Params, syncUiFromStore]);

  // 与 last L3322-3363 对齐：activeSide==="SYNC" 等价于双侧顺序写入。
  const setModeBoth = useCallback(async (mode: SideState["mode"]) => {
    const applyModeForSide = async (side: DeviceSide) => {
      const modeB1 = toProtocolMode(mode);
      const dev = deviceStore.get()[side];
      const ui = side === "L" ? left : right;
      if (side === "L") setLeft((prev) => ({ ...prev, mode }));
      else setRight((prev) => ({ ...prev, mode }));
      if (!isBleSupported() || !dev?.connected || !dev.deviceId) return;
      const ok = await nativeSetModeForSide(side, modeB1);
      if (ok) syncUiFromStore();
    };
    setPumpAgentUploadOperationSource("both", "app");
    await applyModeForSide("L");
    await applyModeForSide("R");
  }, [left, right, setLeft, setRight, syncUiFromStore]);

  const setModeL = useCallback(async (mode: SideState["mode"]) => {
    const modeB1 = toProtocolMode(mode);
    const dev = deviceStore.get().L;
    setPumpAgentUploadOperationSource("L", "app");
    setLeft((prev) => ({ ...prev, mode }));
    if (!isBleSupported() || !dev?.connected || !dev.deviceId) return;
    const ok = await nativeSetModeForSide("L", modeB1);
    if (ok) syncUiFromStore();
  }, [setLeft, syncUiFromStore]);

  const setModeR = useCallback(async (mode: SideState["mode"]) => {
    const modeB1 = toProtocolMode(mode);
    const dev = deviceStore.get().R;
    setPumpAgentUploadOperationSource("R", "app");
    setRight((prev) => ({ ...prev, mode }));
    if (!isBleSupported() || !dev?.connected || !dev.deviceId) return;
    const ok = await nativeSetModeForSide("R", modeB1);
    if (ok) syncUiFromStore();
  }, [setRight, syncUiFromStore]);

  const handleAiModeRequest = useCallback(async (next: boolean) => {
    const prev = aiMode;
    deviceRuntimeLogger.log("handleAiModeRequest:start", {
      prevAiMode: prev,
      nextAiMode: next,
    });
    setAiMode(next);
    const scene: 0 | 1 = next ? 1 : 0;
    if (!isBleSupported()) {
      deviceRuntimeLogger.log("handleAiModeRequest:ble-not-supported", {
        prevAiMode: prev,
        nextAiMode: next,
      });
      const cur = deviceStore.get();
      (["L", "R"] as const).forEach((side) => {
        const d = cur[side];
        if (!d) return;
        deviceStore.setDevice(side, { ...d, pumpScene: scene });
      });
      return true;
    }
    const items = (["L", "R"] as const).filter((side) => {
      const dev = deviceStore.get()[side];
      return !!dev?.connected && !!dev.deviceId;
    });
    if (items.length === 0) return true;
    let anyFailed = false;
    for (const side of items) {
      const ok = await nativeSetSceneForSide(side, scene);
      deviceRuntimeLogger.log("handleAiModeRequest:after-send", {
        side,
        ok,
      });
      if (!ok) {
        anyFailed = true;
        deviceRuntimeLogger.warn("handleAiModeRequest:send-failed", {
          side,
          scene,
        });
        continue;
      }
    }
    syncUiFromStore();
    if (!anyFailed) {
      deviceRuntimeLogger.log("handleAiModeRequest:done", {
        prevAiMode: prev,
        nextAiMode: next,
        result: "success",
      });
      return true;
    }
    deviceRuntimeLogger.warn("handleAiModeRequest:done", {
      prevAiMode: prev,
      nextAiMode: next,
      result: "partial-failed",
    });
    setAiMode(prev);
    return false;
  }, [aiMode, deviceRuntimeLogger, setAiMode, syncUiFromStore]);

  /** 结束吸乳：对在线设备下发 FE 关机指令（非 B1 暂停） */
  const stopPumpWithBle = useCallback(async () => {
    if (!isBleSupported()) return;
    const items = (["L", "R"] as const)
      .map((side) => {
        const p = sideB1Params(side);
        return p == null ? null : { side, deviceId: p.deviceId };
      })
      .filter((x): x is NonNullable<typeof x> => x != null);
    if (items.length === 0) return;
    setPumpAgentUploadOperationSource("both", "app");
    markPumpAgentUploadProcessStepStop("both");
    for (const it of items) {
      try {
        await powerOffDeviceAndUpdateStore(it.deviceId, it.side);
        syncUiFromStore();
      } catch (error) {
        console.error(`[PumpSession] stopPumpWithBle FE failed side=${it.side}:`, error);
      }
    }
  }, [sideB1Params, syncUiFromStore]);

  return {
    pauseResume,
    setModeBoth,
    setModeL,
    setModeR,
    handleAiModeRequest,
    stopPumpWithBle,
    adjustGearL: (delta: number, source: "app" | "agent" = "app") => applyGearDelta("L", delta, source),
    adjustGearR: (delta: number, source: "app" | "agent" = "app") => applyGearDelta("R", delta, source),
  };
}
