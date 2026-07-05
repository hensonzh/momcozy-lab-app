import { useEffect, useMemo, useRef, useState, type Dispatch, type SetStateAction } from "react";
import { isBleSupported } from "@/lib/ble";
import { deviceStore } from "@/lib/deviceStore";
import {
  getPumpAgentUploadProcessProgress,
  onPumpAgentUploadProcessProgress,
} from "@/lib/pumpAgentUpload";
import type { SessionState } from "./pumpSessionModel";

const FLOW_HISTORY_LEN = 60;
const MAX_BREAST_ML = 150;

interface Params {
  sessionState: SessionState;
  setFlowDataL: Dispatch<SetStateAction<number[]>>;
  setFlowDataR: Dispatch<SetStateAction<number[]>>;
  setProgressL: Dispatch<SetStateAction<number>>;
  setProgressR: Dispatch<SetStateAction<number>>;
  setProgressAll: Dispatch<SetStateAction<number>>;
}

export function usePumpRealDisplayRuntime(params: Params) {
  const {
    sessionState,
    setFlowDataL,
    setFlowDataR,
    setProgressL,
    setProgressR,
    setProgressAll,
  } = params;
  const [deviceSnapshot, setDeviceSnapshot] = useState(() => deviceStore.get());
  const [flowUiSnapshotL, setFlowUiSnapshotL] = useState(0);
  const [flowUiSnapshotR, setFlowUiSnapshotR] = useState(0);
  const tickRef = useRef(0);
  const lastFlowLRef = useRef(0);
  const lastFlowRRef = useRef(0);
  // 离线侧冻结所需缓存：记录上一次写入曲线缓冲区的有效值，离线时复用，保持视觉静止
  const lastBufferLRef = useRef(0);
  const lastBufferRRef = useRef(0);
  const lastLetdownLRef = useRef(false);
  const lastLetdownRRef = useRef(false);

  useEffect(() => {
    const sync = () => setDeviceSnapshot(deviceStore.get());
    sync();
    const unsub = deviceStore.subscribe(sync);
    return unsub;
  }, []);

  useEffect(() => {
    const latest = getPumpAgentUploadProcessProgress();
    setProgressL(Math.max(0, Math.round(latest.processL)));
    setProgressR(Math.max(0, Math.round(latest.processR)));
    setProgressAll(Math.max(0, Math.round(latest.processAll)));
    const unsubscribe = onPumpAgentUploadProcessProgress(({ processL, processR, processAll }) => {
      setProgressL(Math.max(0, Math.round(processL)));
      setProgressR(Math.max(0, Math.round(processR)));
      setProgressAll(Math.max(0, Math.round(processAll)));
    });
    return unsubscribe;
  }, [setProgressAll, setProgressL, setProgressR]);

  // 运行中：500ms 写入新点同时同步 BreastDrop/标签快照（与 last L2872-2885 对齐）
  // 双侧曲线 buffer 各自独立：
  //   - 仅当 leftRunning 时 push L buffer（离线/未运行时 L buffer 完全冻结、绝对静止）；
  //   - R buffer 同理；
  //   - label snapshot 使用 lastBufferL/RRef 冻结值，掉线侧数值保留掉线那一刻的值。
  useEffect(() => {
    if (sessionState !== "running") return;
    const timer = window.setInterval(() => {
      const { L, R } = deviceStore.get();
      const leftOnline = !!L?.connected;
      const rightOnline = !!R?.connected;
      const leftRunning = leftOnline && L?.pumpWorkState === 0x01;
      const rightRunning = rightOnline && R?.pumpWorkState === 0x01;
      if (!leftRunning && !rightRunning) return;
      tickRef.current += 1;

      if (leftRunning) {
        const newL = Math.max(0, typeof L?.bandpower === "number" ? L.bandpower : 0);
        const newLetdownL = typeof L?.moFlag === "number" && (L.moFlag & 0x01) !== 0;
        lastBufferLRef.current = newL;
        lastLetdownLRef.current = newLetdownL;
        setFlowDataL((prev) => [...prev.slice(-(FLOW_HISTORY_LEN - 1)), newL]);
      }
      if (rightRunning) {
        const newR = Math.max(0, typeof R?.bandpower === "number" ? R.bandpower : 0);
        const newLetdownR = typeof R?.moFlag === "number" && (R.moFlag & 0x01) !== 0;
        lastBufferRRef.current = newR;
        lastLetdownRRef.current = newLetdownR;
        setFlowDataR((prev) => [...prev.slice(-(FLOW_HISTORY_LEN - 1)), newR]);
      }

      // label 用冻结值：离线/未运行侧保持上一次有效值，不会跳变到 0
      setFlowUiSnapshotL(lastBufferLRef.current);
      setFlowUiSnapshotR(lastBufferRRef.current);
    }, 500);
    return () => window.clearInterval(timer);
  }, [sessionState, setFlowDataL, setFlowDataR]);

  // 非运行（idle / paused）：1s 节流读取设备 ref 同步快照（与 last L2823-2831 对齐）
  useEffect(() => {
    if (sessionState === "running") return;
    const timer = window.setInterval(() => {
      setFlowUiSnapshotL(lastFlowLRef.current);
      setFlowUiSnapshotR(lastFlowRRef.current);
    }, 1000);
    return () => window.clearInterval(timer);
  }, [sessionState]);

  const devL = deviceSnapshot.L;
  const devR = deviceSnapshot.R;
  const hasRealFlowL = !!(devL?.connected && devL.bandpower != null);
  const hasRealFlowR = !!(devR?.connected && devR.bandpower != null);
  const hasRealLetdownL = !!(devL?.connected && devL.moFlag != null);
  const hasRealLetdownR = !!(devR?.connected && devR.moFlag != null);
  const hasRealMilkL = !!(devL?.connected && devL.milkMl != null);
  const hasRealMilkR = !!(devR?.connected && devR.milkMl != null);
  const uiLeftOnline = !!devL?.connected;
  const uiRightOnline = !!devR?.connected;
  const leftDeviceAutoScene = uiLeftOnline && devL?.pumpScene === 1;
  const rightDeviceAutoScene = uiRightOnline && devR?.pumpScene === 1;

  const displayFlowL = hasRealFlowL ? Math.max(0, devL!.bandpower!) : 0;
  const displayFlowR = hasRealFlowR ? Math.max(0, devR!.bandpower!) : 0;
  lastFlowLRef.current = displayFlowL;
  lastFlowRRef.current = displayFlowR;

  const letdownL = hasRealLetdownL ? (devL!.moFlag! & 0x01) !== 0 : false;
  const letdownR = hasRealLetdownR ? (devR!.moFlag! & 0x01) !== 0 : false;

  const totalL = hasRealMilkL ? Math.round(devL!.milkMl!) : 0;
  const totalR = hasRealMilkR ? Math.round(devR!.milkMl!) : 0;
  const displayBottlePct = Math.min(
    100,
    uiLeftOnline && !uiRightOnline
      ? (totalL / MAX_BREAST_ML) * 100
      : !uiLeftOnline && uiRightOnline
        ? (totalR / MAX_BREAST_ML) * 100
        : uiLeftOnline && uiRightOnline
          ? ((totalL + totalR) / (MAX_BREAST_ML * 2)) * 100
          : 0,
  );

  /** 与 PumpSession_last aggregatePaused（L1853-1865）一致：在线侧任一为运行则视为未聚合暂停 */
  const aggregatePaused = useMemo(() => {
    if (!isBleSupported()) {
      return sessionState !== "running";
    }
    const L = deviceSnapshot.L;
    const R = deviceSnapshot.R;
    const parts: number[] = [];
    if (L?.connected) parts.push(L.pumpWorkState ?? 0);
    if (R?.connected) parts.push(R.pumpWorkState ?? 0);
    if (parts.length === 0) {
      return true;
    }
    return !parts.some((ws) => ws === 0x01);
  }, [deviceSnapshot, sessionState]);

  // 与 last L2833-2838 对齐：数值标签使用快照（曲线 path 由 ForceLinePanel 各自消费 flowDataL / flowDataR 直接绘制）
  const flowDisplayLabelL = flowUiSnapshotL;
  const flowDisplayLabelR = flowUiSnapshotR;

  return {
    flowDisplayLabelL,
    flowDisplayLabelR,
    letdownL,
    letdownR,
    isLetdown: letdownL || letdownR,
    totalL,
    totalR,
    displayBottlePct,
    leftDeviceOnline: uiLeftOnline,
    rightDeviceOnline: uiRightOnline,
    leftDeviceAutoScene,
    rightDeviceAutoScene,
    aggregatePaused,
  };
}
