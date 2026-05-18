import { useEffect, useRef, useState, type Dispatch, type SetStateAction } from "react";
import type { MockFlow, SessionState, SideState } from "./pumpSessionModel";

const FLOW_HISTORY_LEN = 60;
const HIGH_FLOW_MULT = 2.0;
const LOW_FLOW_MULT = 0.8;
const MAX_GEAR = 10;
const MOCK_HIGH_BASE = 14;
const MOCK_LOW_BASE = 1.5;

export function usePumpMockRuntime(params: {
  sessionState: SessionState;
  calData: unknown;
  fromCalibration: boolean;
  targetGearL: number;
  targetGearR: number;
  left: SideState;
  right: SideState;
  aiMode: boolean;
  isSessionRunning: boolean;
  calPromptRunning: boolean;
  setLeft: Dispatch<SetStateAction<SideState>>;
  setRight: Dispatch<SetStateAction<SideState>>;
  setElapsed: Dispatch<SetStateAction<number>>;
  setBottlePct: Dispatch<SetStateAction<number>>;
  setFlowDataL: Dispatch<SetStateAction<number[]>>;
  setFlowDataR: Dispatch<SetStateAction<number[]>>;
  setProgressL: Dispatch<SetStateAction<number>>;
  setProgressR: Dispatch<SetStateAction<number>>;
  setProgressAll: Dispatch<SetStateAction<number>>;
}) {
  const {
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
  } = params;
  const [mockFlow, setMockFlow] = useState<MockFlow>("off");
  const enablePumpSessionMockEffects = false;
  const tickRef = useRef(0);
  const rampedRef = useRef(false);
  const leftFlowRef = useRef(0);
  const rightFlowRef = useRef(0);
  const letdownLRef = useRef(false);
  const letdownRRef = useRef(false);

  leftFlowRef.current = left.flow;
  rightFlowRef.current = right.flow;
  letdownLRef.current = left.flow > left.gear * HIGH_FLOW_MULT;
  letdownRRef.current = right.flow > right.gear * HIGH_FLOW_MULT;

  void sessionState;

  useEffect(() => {
    if (!enablePumpSessionMockEffects) return;
    if (!calData || rampedRef.current || fromCalibration) return;
    const step1 = setTimeout(() => {
      setLeft((p) => ({ ...p, gear: Math.min(targetGearL - 1, MAX_GEAR) }));
      setRight((p) => ({ ...p, gear: Math.min(targetGearR - 1, MAX_GEAR) }));
    }, 10000);
    const step2 = setTimeout(() => {
      setLeft((p) => ({ ...p, gear: Math.min(targetGearL, MAX_GEAR) }));
      setRight((p) => ({ ...p, gear: Math.min(targetGearR, MAX_GEAR) }));
      rampedRef.current = true;
    }, 20000);
    return () => {
      clearTimeout(step1);
      clearTimeout(step2);
    };
  }, [calData, enablePumpSessionMockEffects, fromCalibration, setLeft, setRight, targetGearL, targetGearR]);

  useEffect(() => {
    if (!enablePumpSessionMockEffects) return;
    if (sessionState !== "running" || !calPromptRunning) return;
    const computeFlow = (prev: SideState, mock: MockFlow, tick: number, off: number): number => {
      if (mock === "high") return MOCK_HIGH_BASE + (Math.random() - 0.5) * 3 - off;
      if (mock === "low") return MOCK_LOW_BASE + (Math.random() - 0.5) * 1 - off * 0.3;
      const base = prev.mode === "deep" ? prev.gear * 1.8 : prev.gear * 0.8;
      const ld = tick > 30 + off * 5 && tick < 45 + off * 5 ? 4 : 0;
      return Math.max(0, base + ld + (Math.random() - 0.5) * 2);
    };
    const iv = setInterval(() => {
      tickRef.current += 1;
      const tick = tickRef.current;
      setElapsed((e) => e + 1);
      setLeft((p) => ({ ...p, flow: computeFlow(p, mockFlow, tick, 0) }));
      setRight((p) => ({ ...p, flow: computeFlow(p, mockFlow, tick, 1) }));
      setBottlePct((prev) => {
        const avgFlow = (leftFlowRef.current + rightFlowRef.current) / 2;
        const increment = Math.max(0, avgFlow * 0.055);
        return Math.min(100, prev + increment);
      });
    }, 1000);
    return () => clearInterval(iv);
  }, [calPromptRunning, enablePumpSessionMockEffects, mockFlow, sessionState, setBottlePct, setElapsed, setLeft, setRight]);

  useEffect(() => {
    if (!enablePumpSessionMockEffects) return;
    if (sessionState !== "running" || !calPromptRunning) return;
    const iv = setInterval(() => {
      // Mock 路径下双侧始终视为在线运行，分别 push 到独立 buffer
      setFlowDataL((prev) => [...prev.slice(-(FLOW_HISTORY_LEN - 1)), leftFlowRef.current]);
      setFlowDataR((prev) => [...prev.slice(-(FLOW_HISTORY_LEN - 1)), rightFlowRef.current]);
    }, 500);
    return () => clearInterval(iv);
  }, [calPromptRunning, enablePumpSessionMockEffects, sessionState, setFlowDataL, setFlowDataR]);

  useEffect(() => {
    if (!enablePumpSessionMockEffects) return;
    if (sessionState !== "running" || !calPromptRunning) return;
    const iv = setInterval(() => {
      let nextL = 0;
      let nextR = 0;
      setProgressL((p) => {
        nextL = p >= 100 ? p : Math.min(100, p + Math.max(0.05, leftFlowRef.current * 0.12));
        return nextL;
      });
      setProgressR((p) => {
        nextR = p >= 100 ? p : Math.min(100, p + Math.max(0.05, rightFlowRef.current * 0.12));
        return nextR;
      });
      setProgressAll(Math.round((nextL + nextR) / 2));
    }, 500);
    return () => clearInterval(iv);
  }, [calPromptRunning, enablePumpSessionMockEffects, sessionState, setProgressAll, setProgressL, setProgressR]);

  useEffect(() => {
    if (!enablePumpSessionMockEffects) return;
    if (!aiMode || !isSessionRunning) return;
    if (left.flow > left.gear * HIGH_FLOW_MULT && left.mode === "stimulate") setLeft((p) => ({ ...p, mode: "deep" }));
    if (right.flow > right.gear * HIGH_FLOW_MULT && right.mode === "stimulate") setRight((p) => ({ ...p, mode: "deep" }));
    if (left.flow <= left.gear * LOW_FLOW_MULT && left.mode === "deep") setLeft((p) => ({ ...p, mode: "stimulate" }));
    if (right.flow <= right.gear * LOW_FLOW_MULT && right.mode === "deep") setRight((p) => ({ ...p, mode: "stimulate" }));
  }, [aiMode, enablePumpSessionMockEffects, isSessionRunning, left.flow, left.gear, left.mode, right.flow, right.gear, right.mode, setLeft, setRight]);

  return {
    mockFlow,
    setMockFlow,
    enablePumpSessionMockEffects,
  };
}
