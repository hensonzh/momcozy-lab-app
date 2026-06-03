import { useCallback, useEffect, useRef, type Dispatch, type SetStateAction } from "react";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";
import {
  ensureProtocolNotify,
  isBleSupported,
  powerOffDeviceAndUpdateStore,
  queryDeviceStatusAndUpdateStore,
  sendB1SetPumpParams,
  subscribeProtocolNotifications,
} from "@/lib/ble";
import {
  markPumpAgentUploadProcessStepPause,
  markPumpAgentUploadProcessStepStop,
  setPumpAgentUploadOperationSource,
} from "@/lib/pumpAgentUpload";
import { CT_ACK } from "@/lib/bleProtocol";
import type { D0OperationRecord } from "@/lib/bleProtocol";
import { patchGearMemory, readGearB1FromMemory } from "@/lib/pumpGearMemory";
import {
  fromProtocolGear,
  fromProtocolPumpMode,
  MAX_GEAR,
  MIN_GEAR,
  toProtocolGear,
  toProtocolMode,
  type SessionState,
  type SideState,
} from "./pumpSessionModel";
import { createScopedConsole } from "@/lib/logger";

interface PumpDeviceControlRuntimeParams {
  left: SideState;
  right: SideState;
  aiMode: boolean;
  enablePumpSessionMockEffects: boolean;
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

export function usePumpDeviceControlRuntime(params: PumpDeviceControlRuntimeParams) {
  const {
    left,
    right,
    aiMode,
    enablePumpSessionMockEffects,
    sessionState,
    setSessionState,
    setLeft,
    setRight,
    setElapsed,
    setAiMode,
  } = params;
  const deviceRuntimeLogger = createScopedConsole("PumpDeviceControlRuntime");
  const hasSwitchedFromAutoToManualRef = useRef(false);
  const d0UnsubRef = useRef<Partial<Record<DeviceSide, () => void>>>({});
  const d0DeviceIdRef = useRef<Partial<Record<DeviceSide, string>>>({});
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

    const runningDurations = [
      leftRunning && typeof L?.duration === "number" ? L.duration : undefined,
      rightRunning && typeof R?.duration === "number" ? R.duration : undefined,
    ].filter((duration): duration is number => duration != null);
    if (runningDurations.length > 0) setElapsed(Math.max(...runningDurations));
  }, [setAiMode, setElapsed, setLeft, setRight]);

  const applyD0ToSide = useCallback((side: DeviceSide, d: D0OperationRecord) => {
    const ws = d.afterStartStop === 1 ? 0x01 : 0x00;
    const modeB1 = Math.max(0, Math.min(2, d.afterMode)) as 0 | 1 | 2;
    const gearB1 = Math.max(0, Math.min(14, d.afterGear));
    const scene: 0 | 1 = d.afterAutoFlag !== 0 ? 1 : 0;
    const setter = side === "L" ? setLeft : setRight;
    setter((prev) => ({
      ...prev,
      mode: fromProtocolPumpMode(modeB1),
      gear: fromProtocolGear(gearB1),
    }));

    const current = deviceStore.get()[side];
    if (current) {
      const isRunning = ws === 0x01;
      const hasValidDuration = typeof d.duration === "number" && d.duration > 0;
      deviceStore.setDevice(side, {
        ...current,
        pumpScene: scene,
        pumpWorkState: ws,
        pumpMode: modeB1,
        gear: gearB1,
        duration: !isRunning && hasValidDuration ? d.duration : current.duration,
      });
    }
    syncUiFromStore();
  }, [setLeft, setRight, syncUiFromStore]);

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

  const reconcileDeviceListeners = useCallback(() => {
    const snapshot = deviceStore.get();
    (["L", "R"] as const).forEach((side) => {
      const dev = snapshot[side];
      const connected = !!dev?.connected;
      const deviceId = dev?.deviceId;
      const boundDeviceId = d0DeviceIdRef.current[side];
      if (connected && deviceId) {
        if (boundDeviceId !== deviceId) {
          d0UnsubRef.current[side]?.();
          d0UnsubRef.current[side] = subscribeProtocolNotifications(deviceId, (cid, data) => {
            if (cid !== 0xd0) return;
            applyD0ToSide(side, data as D0OperationRecord);
          });
          d0DeviceIdRef.current[side] = deviceId;
        }
      } else {
        d0UnsubRef.current[side]?.();
        delete d0UnsubRef.current[side];
        delete d0DeviceIdRef.current[side];
      }
    });
  }, [applyD0ToSide]);

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
    const ui = side === "L" ? left : right;
    const modeB1 = (dev.pumpMode ?? toProtocolMode(ui.mode)) as 0 | 1 | 2;
    const gearB1 = dev.gear ?? toProtocolGear(ui.gear);
    const workState = dev.pumpWorkState ?? 0x00;
    return { deviceId: dev.deviceId, modeB1, gearB1, workState, store: dev };
  }, [left, right]);

  const sendB1WithRetry = useCallback(async (
    deviceId: string,
    startStop: 0 | 1,
    mode: 0 | 1 | 2,
    gear: number,
    scene: 0 | 1,
  ) => {
    const first = await sendB1SetPumpParams(deviceId, startStop, mode, gear, scene);
    if (first?.ct === CT_ACK) return true;
    const second = await sendB1SetPumpParams(deviceId, startStop, mode, gear, scene);
    return second?.ct === CT_ACK;
  }, []);

  const persistPumpSnapshot = useCallback((
    side: DeviceSide,
    modeB1: 0 | 1 | 2,
    gearB1: number,
    workState: number,
    scene: 0 | 1,
  ) => {
    const cur = deviceStore.get()[side];
    if (!cur) return;
    const memPatch = patchGearMemory(cur, scene, modeB1, gearB1);
    deviceStore.setDevice(side, {
      ...cur,
      ...memPatch,
      pumpMode: modeB1,
      gear: gearB1,
      pumpWorkState: workState,
      pumpScene: scene,
    });
  }, []);

  useEffect(() => {
    if (!isBleSupported()) return;
    syncUiFromStore();
    const unsub = deviceStore.subscribe(syncUiFromStore);
    return unsub;
  }, [syncUiFromStore]);

  useEffect(() => {
    if (!isBleSupported()) return;
    reconcileDeviceListeners();
    handleConnectionDelta();
    const unsub = deviceStore.subscribe(() => {
      reconcileDeviceListeners();
      handleConnectionDelta();
    });
    return () => {
      unsub();
      (["L", "R"] as const).forEach((side) => {
        d0UnsubRef.current[side]?.();
        delete d0UnsubRef.current[side];
        delete d0DeviceIdRef.current[side];
      });
      if (reconnectTimerRef.current != null) window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    };
  }, [handleConnectionDelta, reconcileDeviceListeners]);

  useEffect(() => {
    if (!isBleSupported()) return;
    const { L, R } = deviceStore.get();
    if (L?.connected && L.deviceId) void queryDeviceStatusAndUpdateStore(L.deviceId, "L");
    if (R?.connected && R.deviceId) void queryDeviceStatusAndUpdateStore(R.deviceId, "R");
  }, []);

  // 旧的 500ms 轮询 updateRunningState 已删除：会话状态由 pumpSessionLifecycle（基于 deviceStore 订阅 + 边缘触发）统一推进。

  useEffect(() => {
    if (enablePumpSessionMockEffects) return;
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
  }, [enablePumpSessionMockEffects, sessionState, setElapsed]);

  const applyGearDelta = useCallback((side: DeviceSide, delta: number, source: "app" | "agent" = "app") => {
    const setter = side === "L" ? setLeft : setRight;
    setPumpAgentUploadOperationSource(side, source);
    setter((prev) => {
      const next = Math.max(MIN_GEAR, Math.min(MAX_GEAR, prev.gear + delta));
      if (isBleSupported()) {
        const stored = deviceStore.get()[side];
        if (stored?.connected && stored.deviceId) {
          const modeB1 = ((stored.pumpMode ?? toProtocolMode(prev.mode)) as 0 | 1 | 2);
          const gearB1 = toProtocolGear(next);
          const ws = stored.pumpWorkState ?? 0x00;
          const ss: 0 | 1 = ws === 0x01 ? 1 : 0;
          const scene: 0 | 1 = aiMode ? 1 : 0;
          const deviceId = stored.deviceId;
          void (async () => {
            const ok = await sendB1WithRetry(deviceId, ss, modeB1, gearB1, scene);
            if (!ok) return;
            persistPumpSnapshot(side, modeB1, gearB1, ws, scene);
          })();
        }
      }
      return { ...prev, gear: next };
    });
  }, [aiMode, persistPumpSnapshot, sendB1WithRetry, setLeft, setRight]);

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
      if (enablePumpSessionMockEffects) {
        setSessionState((prev) => (prev === "running" ? "paused" : "running"));
      }
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
    const scene: 0 | 1 = aiMode ? 1 : 0;
    setPumpAgentUploadOperationSource("both", "app");
    let anyFailed = false;
    for (const it of items) {
      const { side, deviceId, modeB1, gearB1, workState } = it;
      if (nextStart === 1 && workState !== 0x00) continue;
      if (nextStart === 0 && workState !== 0x01) continue;
      if (nextStart === 0) markPumpAgentUploadProcessStepPause(side);
      const ok = await sendB1WithRetry(
        deviceId,
        nextStart,
        modeB1,
        gearB1,
        scene,
      );
      if (!ok) {
        anyFailed = true;
        continue;
      }
      persistPumpSnapshot(side, modeB1, gearB1, nextStart === 1 ? 0x01 : 0x00, scene);
      if (side === "L") setLeft((prev) => ({ ...prev, gear: fromProtocolGear(gearB1) }));
      else setRight((prev) => ({ ...prev, gear: fromProtocolGear(gearB1) }));
    }
    if (!anyFailed) {
      setSessionState(nextStart === 1 ? "running" : "paused");
      return;
    }
    const refreshed = deviceStore.get();
    const hasRunning = (["L", "R"] as const).some((side) => refreshed[side]?.connected && refreshed[side]?.pumpWorkState === 0x01);
    setSessionState(hasRunning ? "running" : "paused");
  }, [aiMode, enablePumpSessionMockEffects, persistPumpSnapshot, sendB1WithRetry, sessionState, setLeft, setRight, setSessionState, sideB1Params]);

  // 与 last L3322-3363 对齐：activeSide==="SYNC" 等价于双侧顺序写入。
  const setModeBoth = useCallback(async (mode: SideState["mode"]) => {
    const applyModeForSide = async (side: DeviceSide) => {
      const scene: 0 | 1 = aiMode ? 1 : 0;
      const modeB1 = toProtocolMode(mode);
      const dev = deviceStore.get()[side];
      const ui = side === "L" ? left : right;
      const fallback = dev?.gear ?? toProtocolGear(ui.gear);
      const remembered = readGearB1FromMemory(dev, scene, modeB1, fallback);
      if (side === "L") setLeft((prev) => ({ ...prev, mode, gear: fromProtocolGear(remembered) }));
      else setRight((prev) => ({ ...prev, mode, gear: fromProtocolGear(remembered) }));
      if (!isBleSupported() || !dev?.connected || !dev.deviceId) return;
      const ws = dev.pumpWorkState ?? 0x00;
      const ss: 0 | 1 = ws === 0x01 ? 1 : 0;
      const ok = await sendB1WithRetry(dev.deviceId, ss, modeB1, remembered, scene);
      if (!ok) return;
      persistPumpSnapshot(side, modeB1, remembered, ws, scene);
    };
    setPumpAgentUploadOperationSource("both", "app");
    await applyModeForSide("L");
    await applyModeForSide("R");
  }, [aiMode, left, persistPumpSnapshot, right, sendB1WithRetry, setLeft, setRight]);

  const setModeL = useCallback(async (mode: SideState["mode"]) => {
    const scene: 0 | 1 = aiMode ? 1 : 0;
    const modeB1 = toProtocolMode(mode);
    const dev = deviceStore.get().L;
    const fallback = dev?.gear ?? toProtocolGear(left.gear);
    const remembered = readGearB1FromMemory(dev, scene, modeB1, fallback);
    setPumpAgentUploadOperationSource("L", "app");
    setLeft((prev) => ({ ...prev, mode, gear: fromProtocolGear(remembered) }));
    if (!isBleSupported() || !dev?.connected || !dev.deviceId) return;
    const ws = dev.pumpWorkState ?? 0x00;
    const ss: 0 | 1 = ws === 0x01 ? 1 : 0;
    const ok = await sendB1WithRetry(dev.deviceId, ss, modeB1, remembered, scene);
    if (!ok) return;
    persistPumpSnapshot("L", modeB1, remembered, ws, scene);
  }, [aiMode, left.gear, persistPumpSnapshot, sendB1WithRetry, setLeft]);

  const setModeR = useCallback(async (mode: SideState["mode"]) => {
    const scene: 0 | 1 = aiMode ? 1 : 0;
    const modeB1 = toProtocolMode(mode);
    const dev = deviceStore.get().R;
    const fallback = dev?.gear ?? toProtocolGear(right.gear);
    const remembered = readGearB1FromMemory(dev, scene, modeB1, fallback);
    setPumpAgentUploadOperationSource("R", "app");
    setRight((prev) => ({ ...prev, mode, gear: fromProtocolGear(remembered) }));
    if (!isBleSupported() || !dev?.connected || !dev.deviceId) return;
    const ws = dev.pumpWorkState ?? 0x00;
    const ss: 0 | 1 = ws === 0x01 ? 1 : 0;
    const ok = await sendB1WithRetry(dev.deviceId, ss, modeB1, remembered, scene);
    if (!ok) return;
    persistPumpSnapshot("R", modeB1, remembered, ws, scene);
  }, [aiMode, persistPumpSnapshot, right.gear, sendB1WithRetry, setRight]);

  const copyManualMemoryFromAi = useCallback((side: DeviceSide) => {
    const cur = deviceStore.get()[side];
    if (!cur?.pumpGearMemoryAi) return;
    deviceStore.setDevice(side, {
      ...cur,
      pumpGearMemoryManual: {
        stimulate: cur.pumpGearMemoryAi.stimulate,
        deep: cur.pumpGearMemoryAi.deep,
      },
    });
  }, []);

  const copyAiMemoryFromCalib = useCallback((side: DeviceSide) => {
    const cur = deviceStore.get()[side];
    if (!cur?.pumpGearCalib) return;
    deviceStore.setDevice(side, {
      ...cur,
      pumpGearMemoryAi: {
        stimulate: cur.pumpGearCalib.stimulate,
        deep: cur.pumpGearCalib.deep,
      },
    });
  }, []);

  const handleAiModeRequest = useCallback(async (next: boolean) => {
    const prev = aiMode;
    deviceRuntimeLogger.log("handleAiModeRequest:start", {
      prevAiMode: prev,
      nextAiMode: next,
    });
    setAiMode(next);
    const scene: 0 | 1 = next ? 1 : 0;
    const isFirstAutoToManual = !next && prev === true && !hasSwitchedFromAutoToManualRef.current;
    let shouldMarkSwitchedFromAutoToManual = false;
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
    const items = (["L", "R"] as const)
      .map((side) => {
        const p = sideB1Params(side);
        return p == null ? null : { side, ...p };
      })
      .filter((x): x is NonNullable<typeof x> => x != null);
    if (items.length === 0) return true;
    let anyFailed = false;
    for (const it of items) {
      const { side, deviceId, modeB1, gearB1, workState, store } = it;
      let ss: 0 | 1;
      let finalModeB1: 0 | 1 | 2 = modeB1;
      const fallback = store.gear ?? toProtocolGear(side === "L" ? left.gear : right.gear);
      let finalGearB1 = gearB1;
      if (next && prev === false) {
        ss = 1;
        finalModeB1 = 0;
        finalGearB1 = store.pumpGearCalib?.stimulate ?? readGearB1FromMemory(store, 1, 0, fallback);
        copyAiMemoryFromCalib(side);
      } else if (!next && prev === true) {
        ss = 1;
        finalModeB1 = modeB1;
        if (isFirstAutoToManual) {
          if (finalModeB1 === 0) {
            finalGearB1 = store.pumpGearMemoryAi?.stimulate ?? readGearB1FromMemory(store, 1, 0, fallback);
          } else if (finalModeB1 === 1) {
            finalGearB1 = store.pumpGearMemoryAi?.deep ?? readGearB1FromMemory(store, 1, 1, fallback);
          } else {
            finalGearB1 =
              store.pumpGearMemoryAi?.stimulate ??
              store.pumpGearMemoryAi?.deep ??
              readGearB1FromMemory(store, 1, finalModeB1, fallback);
          }
          copyManualMemoryFromAi(side);
          shouldMarkSwitchedFromAutoToManual = true;
        } else {
          finalGearB1 = readGearB1FromMemory(store, 0, finalModeB1, fallback);
        }
      } else {
        finalGearB1 = readGearB1FromMemory(store, scene, modeB1, fallback);
        ss = workState === 0x01 ? 1 : 0;
      }
      deviceRuntimeLogger.log("handleAiModeRequest:before-send", {
        side,
        deviceId,
        prevAiMode: prev,
        nextAiMode: next,
        from: { modeB1, gearB1, workState, pumpScene: store.pumpScene ?? null },
        send: { ss, finalModeB1, finalGearB1, scene },
      });
      const ok = await sendB1WithRetry(deviceId, ss, finalModeB1, finalGearB1, scene);
      deviceRuntimeLogger.log("handleAiModeRequest:after-send", {
        side,
        deviceId,
        ok,
      });
      if (!ok) {
        anyFailed = true;
        deviceRuntimeLogger.warn("handleAiModeRequest:send-failed", {
          side,
          deviceId,
          send: { ss, finalModeB1, finalGearB1, scene },
        });
        continue;
      }
      const nextPumpWs = ss === 1 ? 0x01 : 0x00;
      persistPumpSnapshot(side, finalModeB1, finalGearB1, nextPumpWs, scene);
      const persisted = deviceStore.get()[side];
      deviceRuntimeLogger.log("handleAiModeRequest:after-persist", {
        side,
        persisted: persisted
          ? {
              pumpMode: persisted.pumpMode ?? null,
              gear: persisted.gear ?? null,
              pumpWorkState: persisted.pumpWorkState ?? null,
              pumpScene: persisted.pumpScene ?? null,
            }
          : null,
      });
      if (side === "L") setLeft((p) => ({ ...p, gear: fromProtocolGear(finalGearB1) }));
      else setRight((p) => ({ ...p, gear: fromProtocolGear(finalGearB1) }));
    }
    if (shouldMarkSwitchedFromAutoToManual) {
      hasSwitchedFromAutoToManualRef.current = true;
    }
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
  }, [aiMode, copyAiMemoryFromCalib, copyManualMemoryFromAi, deviceRuntimeLogger, left.gear, persistPumpSnapshot, right.gear, sendB1WithRetry, setAiMode, setLeft, setRight, sideB1Params]);

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
        const cur = deviceStore.get()[it.side];
        if (cur) {
          deviceStore.setDevice(it.side, { ...cur, pumpWorkState: 0x00 });
        }
      } catch (error) {
        console.error(`[PumpSession] stopPumpWithBle FE failed side=${it.side}:`, error);
      }
    }
  }, [setElapsed, sideB1Params]);

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
