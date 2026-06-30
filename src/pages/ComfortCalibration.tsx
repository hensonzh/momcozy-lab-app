import React, { useState, useEffect, useRef, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { ArrowLeft, CheckCircle2 } from "lucide-react";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { sendB1SetPumpParams, sendF1SetUserParams } from "@/lib/ble";
import { deviceStore } from "@/lib/deviceStore";
import { uploadPumpThreshold } from "@/lib/agentApi";
import { ApiError } from "@/lib/http";
import { createScopedConsole } from "@/lib/logger";
import { getRuntimeUserId } from "@/lib/debugUserConfig";
import { buildCalibrationAutoStartRoute, startPumpAfterCalibration } from "@/pages/pumpSession/calibrationAutoStart";

/* Types */
type Side = "L" | "R";
type Mode = "stimulate" | "deep";
type Phase =
  | "wear"
  | "explainSides"
  | "modeIntro"
  | "testing"
  | "modeRest"
  | "sideResult"
  | "finalResult";

interface SideResult {
  stimGear: number;
  deepGear: number;
}

const MAX_GEAR = 15;
const DEFAULT_PUMP_USER_ID = getRuntimeUserId(import.meta.env.VITE_DEFAULT_USER_ID as string | undefined);
const CALIBRATION_HUB_NOTICE_KEY = "calibrationHubNotice";
const console = createScopedConsole("ComfortCalibration");

const ComfortCalibration: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const mockMode = searchParams.get("mock") === "1";

  const [phase, setPhase] = useState<Phase>("wear");
  const [gear, setGear] = useState(1);
  const [currentSide, setCurrentSide] = useState<Side>("L");
  const [currentMode, setCurrentMode] = useState<Mode>("stimulate");
  const [firstSide, setFirstSide] = useState<Side>("L");
  const [results, setResults] = useState<{ L?: SideResult; R?: SideResult }>({});
  const [pendingStimGear, setPendingStimGear] = useState<number | null>(null);
  const [restCountdown, setRestCountdown] = useState(5);
  const [applied, setApplied] = useState(false);
  const [skippedOtherSide, setSkippedOtherSide] = useState(false);
  const [gearActionLocked, setGearActionLocked] = useState(false);
  const [gearActionCountdown, setGearActionCountdown] = useState<number | null>(null);
  const [confirmGearReady, setConfirmGearReady] = useState(false);

  const scrollRef = useRef<HTMLDivElement>(null);
  const phaseRef = useRef(phase);
  const gearRef = useRef(gear);
  const currentSideRef = useRef(currentSide);
  const currentModeRef = useRef(currentMode);
  const thresholdUploadedRef = useRef(false);
  const gearActionLockTimerRef = useRef<number | null>(null);

  useEffect(() => { phaseRef.current = phase; }, [phase]);
  useEffect(() => { gearRef.current = gear; }, [gear]);
  useEffect(() => { currentSideRef.current = currentSide; }, [currentSide]);
  useEffect(() => { currentModeRef.current = currentMode; }, [currentMode]);

  useEffect(() => {
    setGearActionLocked(false);
    setGearActionCountdown(null);
    setConfirmGearReady(false);
    if (gearActionLockTimerRef.current !== null) {
      window.clearInterval(gearActionLockTimerRef.current);
      gearActionLockTimerRef.current = null;
    }
  }, [phase, currentSide, currentMode]);

  useEffect(() => {
    return () => {
      if (gearActionLockTimerRef.current !== null) {
        window.clearInterval(gearActionLockTimerRef.current);
      }
    };
  }, []);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [phase, gear]);

  useEffect(() => {
    if (mockMode) return;
    const shouldShowFinalResultButton =
      phase === "sideResult" && (Boolean(results[otherSide(currentSide)]) || skippedOtherSide);
    if (!shouldShowFinalResultButton || thresholdUploadedRef.current) return;

    const leftResult = results.L;
    const rightResult = results.R;
    if (!leftResult || !rightResult) return;

    thresholdUploadedRef.current = true;
    uploadPumpThreshold({
      user_id: DEFAULT_PUMP_USER_ID,
      stimulate_level_l: leftResult.stimGear,
      deep_level_l: leftResult.deepGear,
      stimulate_level_r: rightResult.stimGear,
      deep_level_r: rightResult.deepGear,
    }).then((data) => {
      console.log("[ComfortCalibration] uploadPumpThreshold 上报成功，data:", JSON.stringify(data));
    }).catch((error) => {
      thresholdUploadedRef.current = false;
      console.error(`[ComfortCalibration] uploadPumpThreshold 上报失败：${error}`);
      if (error instanceof ApiError) {
        console.error(
          "[ComfortCalibration] uploadPumpThreshold ApiError apiStatus=",
          error.apiStatus,
          "message=",
          error.message,
          "完整信封 raw:",
          JSON.stringify(error.raw),
        );
      }
    });
  }, [mockMode, phase, results, currentSide, skippedOtherSide]);

  useEffect(() => {
    if (phase !== "finalResult") {
      localStorage.setItem("calibrationInProgress", "true");
    }
    if (phase === "finalResult") {
      localStorage.removeItem("calibrationInProgress");
    }
  }, [phase]);

  useEffect(() => {
    return () => {
      const notice = phaseRef.current === "finalResult" ? "completed" : "incomplete";
      localStorage.setItem(CALIBRATION_HUB_NOTICE_KEY, notice);
      if (mockMode) return;
      if (phaseRef.current === "testing") {
        const deviceInfo = deviceStore.get()[currentSideRef.current];
        if (deviceInfo?.connected && deviceInfo.deviceId) {
          try {
            const modeB1 = currentModeRef.current === "stimulate" ? 0 : 1;
            const adjustedGear = gearRef.current - 1;
            sendB1SetPumpParams(deviceInfo.deviceId, 0, modeB1, adjustedGear, 0);
          } catch (error) {
            console.error(`[B1指令] 发送停止失败：${error}`);
          }
        }
      }
    };
  }, [mockMode]);

  // Rest countdown between stim -> deep
  useEffect(() => {
    if (phase !== "modeRest") return;
    setRestCountdown(5);
    const t = setInterval(() => {
      setRestCountdown(prev => {
        if (prev <= 1) {
          clearInterval(t);
          setCurrentMode("deep");
          setGear(1);
          setPhase("modeIntro");
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(t);
  }, [phase]);

  const sideLabel = (s: Side) => s === "L" ? "左侧" : "右侧";
  const modeLabel = (m: Mode) => m === "stimulate" ? "刺激模式" : "吸乳模式";
  const otherSide = (s: Side): Side => s === "L" ? "R" : "L";

  const startGearActionLock = () => {
    setGearActionLocked(true);
    setGearActionCountdown(3);
    if (gearActionLockTimerRef.current !== null) {
      window.clearInterval(gearActionLockTimerRef.current);
    }
    gearActionLockTimerRef.current = window.setInterval(() => {
      setGearActionCountdown((prev) => {
        if (prev === null || prev <= 1) {
          setGearActionLocked(false);
          if (gearActionLockTimerRef.current !== null) {
            window.clearInterval(gearActionLockTimerRef.current);
            gearActionLockTimerRef.current = null;
          }
          return null;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const sendB1Command = async (side: Side, mode: Mode, targetGear: number) => {
    const adjustedGear = targetGear - 1;
    if (mockMode) {
      console.log(
        `[ComfortCalibration][mock] skip B1 command: side=${side}, mode=${mode}, gear=${adjustedGear}`
      );
      return true;
    }
    const deviceInfo = deviceStore.get()[side];
    if (!deviceInfo?.connected || !deviceInfo.deviceId) {
      alert(`${sideLabel(side)}设备未连接，请先连接设备后再开始测试。`);
      return false;
    }
    try {
      const modeB1 = mode === "stimulate" ? 0 : 1;
      await sendB1SetPumpParams(deviceInfo.deviceId, 1, modeB1, adjustedGear, 0);
      return true;
    } catch (error) {
      console.error(`[B1指令] 发送失败：${error}`);
      alert("发送指令失败，请重试。");
      return false;
    }
  };

  const handleConfirmGear = async () => {
    const deviceInfo = deviceStore.get()[currentSide];
    if (!mockMode && deviceInfo?.connected && deviceInfo.deviceId) {
      try {
        const modeB1 = 0; // 刺激模式
        const stimGear = currentMode === "stimulate" ? gear : pendingStimGear ?? gear;
        const adjustedGear = stimGear - 1;
        await sendB1SetPumpParams(deviceInfo.deviceId, 0, modeB1, adjustedGear, 1);
      } catch (error) {
        console.error(`[B1指令] 发送停止失败：${error}`);
      }
    }

    if (currentMode === "stimulate") {
      setPendingStimGear(gear);
      setGear(0);
      setPhase("modeRest");
    } else {
      const sideResult: SideResult = { stimGear: pendingStimGear!, deepGear: gear };
      setResults(prev => ({ ...prev, [currentSide]: sideResult }));

      const currentDeviceInfo = deviceStore.get()[currentSide];
      if (mockMode) {
        console.log(`[ComfortCalibration][mock] skip F1 command: side=${currentSide}`);
      } else if (currentDeviceInfo?.connected && currentDeviceInfo.deviceId) {
        try {
          const stimulateGear = pendingStimGear! - 1;
          const lactateGear = gear - 1;
          console.log(
            `[ComfortCalibration][F1] 准备下发当前侧滴定结果: side=${currentSide}, deviceId=${currentDeviceInfo.deviceId}, stimulate=${stimulateGear}, deep=${lactateGear}, persist=1`
          );
          await sendF1SetUserParams(currentDeviceInfo.deviceId, stimulateGear, lactateGear, 1);
          console.log(
            `[ComfortCalibration][F1] 当前侧滴定结果下发成功: side=${currentSide}, deviceId=${currentDeviceInfo.deviceId}`
          );
        } catch (error) {
          console.error(`[ComfortCalibration][F1] 当前侧滴定结果下发失败: side=${currentSide}, error=${error}`);
        }
      } else {
        console.log(`[ComfortCalibration][F1] 当前侧设备不可用，跳过下发: side=${currentSide}`);
      }

      setGear(0);
      setPhase("sideResult");
    }
  };

  const handlePickSide = (side: Side) => {
    const deviceInfo = deviceStore.get()[side];
    if (!mockMode && (!deviceInfo?.connected || !deviceInfo.deviceId)) {
      alert(`${sideLabel(side)}设备未连接，请先连接设备后再开始测试。`);
      return;
    }
    setFirstSide(side);
    setCurrentSide(side);
    setCurrentMode("stimulate");
    setGear(1);
    setPendingStimGear(null);
    setSkippedOtherSide(false);
    setPhase("modeIntro");
  };

  const handleStartOtherSide = () => {
    const other = otherSide(firstSide);
    const deviceInfo = deviceStore.get()[other];
    if (!mockMode && (!deviceInfo?.connected || !deviceInfo.deviceId)) {
      alert(`${sideLabel(other)}设备未连接，请先连接设备后再开始测试。`);
      return;
    }
    setCurrentSide(other);
    setCurrentMode("stimulate");
    setGear(1);
    setPendingStimGear(null);
    setSkippedOtherSide(false);
    setPhase("modeIntro");
  };

  const handleSkipOtherSide = async () => {
    const otherSideKey = currentSide === "L" ? "R" : "L";
    const currentResult = results[currentSide];
    const otherDeviceInfo = deviceStore.get()[otherSideKey];

    if (mockMode) {
      console.log(`[ComfortCalibration][mock] skip other-side F1/B1 commands: side=${otherSideKey}`);
    } else if (otherDeviceInfo?.connected && otherDeviceInfo.deviceId && currentResult) {
      try {
        const stimulateGear = currentResult.stimGear - 1;
        const lactateGear = currentResult.deepGear - 1;
        console.log(
          `[ComfortCalibration][F1] 准备下发跳过侧滴定结果: side=${otherSideKey}, deviceId=${otherDeviceInfo.deviceId}, stimulate=${stimulateGear}, deep=${lactateGear}, persist=1`
        );
        await sendF1SetUserParams(otherDeviceInfo.deviceId, stimulateGear, lactateGear, 1);
        console.log(
          `[ComfortCalibration][F1] 跳过侧滴定结果下发成功: side=${otherSideKey}, deviceId=${otherDeviceInfo.deviceId}`
        );
        // 跳过另一侧时，若设备在线，同步下发 B1 停止指令（自动场景：刺激模式 + 刺激档位）。
        await sendB1SetPumpParams(otherDeviceInfo.deviceId, 0, 0, stimulateGear, 1);
        console.log(
          `[ComfortCalibration][B1] 跳过侧停止指令下发成功: side=${otherSideKey}, deviceId=${otherDeviceInfo.deviceId}, mode=stimulate, gear=${stimulateGear}, scene=auto`
        );
      } catch (error) {
        console.error(`[ComfortCalibration] 跳过侧指令下发失败: side=${otherSideKey}, error=${error}`);
      }
    } else {
      console.log(
        `[ComfortCalibration][F1] 跳过侧未下发: side=${otherSideKey}, deviceConnected=${Boolean(otherDeviceInfo?.connected)}, hasResult=${Boolean(currentResult)}`
      );
    }

    if (currentResult) {
      setResults(prev => ({ ...prev, [otherSideKey]: currentResult }));
    }

    setSkippedOtherSide(true);
  };

  const doApply = (res: { L?: SideResult; R?: SideResult }) => {
    setApplied(true);
    const L = res.L;
    const R = res.R;
    const finalL = L || R;
    const finalR = R || L;
    localStorage.setItem("calibration", JSON.stringify({
      L: finalL ? { stimCozy: finalL.stimGear, deepCozy: finalL.deepGear } : undefined,
      R: finalR ? { stimCozy: finalR.stimGear, deepCozy: finalR.deepGear } : undefined,
      stimCozy: (L || R)!.stimGear,
      deepCozy: (L || R)!.deepGear,
      maxSafe: MAX_GEAR,
      timestamp: Date.now(),
    }));
  };

  const [autoCountdown, setAutoCountdown] = useState(3);
  const totalSteps = 7;
  const progressIndex = useMemo(() => {
    const map: Record<Phase, number> = {
      wear: 1,
      explainSides: 2,
      modeIntro: currentMode === "stimulate" ? 3 : 5,
      testing: currentMode === "stimulate" ? 4 : 6,
      modeRest: 5,
      sideResult: 6,
      finalResult: 7,
    };
    return map[phase];
  }, [phase, currentMode]);

  const handleBackToAgentHub = () => {
    navigate(-1);
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-center bg-background">
      <div className="flex h-[100dvh] w-full max-w-lg flex-col bg-background">
        <div className="flex-shrink-0 border-b border-border/50 bg-background px-3 pb-2.5 pt-[max(env(safe-area-inset-top,0px),16px)]">
          <div className="flex items-center gap-3">
            <button onClick={handleBackToAgentHub} className="-ml-1 rounded-full p-2 transition-colors hover:bg-secondary">
              <ArrowLeft className="h-5 w-5 text-foreground" />
            </button>
            <div className="min-w-0 flex-1">
              <h1 className="text-[15px] font-bold leading-tight text-foreground">舒适负压调节</h1>
              <p className="truncate text-[10px] text-muted-foreground">每一步确认一个动作，找到你的舒适档位</p>
            </div>
            <span className="text-[11px] font-bold text-primary">{progressIndex}/{totalSteps}</span>
          </div>
          <div className="mt-2.5 h-1.5 overflow-hidden rounded-full bg-secondary">
            <motion.div
              className="h-full rounded-full bg-primary"
              animate={{ width: `${(progressIndex / totalSteps) * 100}%` }}
              transition={{ duration: 0.25 }}
            />
          </div>
        </div>

        <main
          ref={scrollRef}
          className="min-h-0 flex-1 overflow-y-auto overscroll-y-contain px-3 py-3 pb-[max(env(safe-area-inset-bottom,0px),12px)]"
          style={{ WebkitOverflowScrolling: "touch" }}
        >
          <motion.div
            key={`${phase}-${currentSide}-${currentMode}`}
            initial={{ opacity: 0, x: 16 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.25 }}
            className="flex min-h-full flex-col justify-center py-2"
          >
            {phase === "wear" && (
              <StepCard
                eyebrow="动作确认 1"
                title="请先正确穿戴吸奶器"
                description="确认法兰/硅胶塞贴合，左右主机放置稳定。穿戴完成后再进入吸力调节，能减少空吸带来的不适。"
                primaryLabel="我已穿戴好"
                onPrimary={() => setPhase("explainSides")}
              />
            )}

            {phase === "explainSides" && (
              <StepCard
                eyebrow="动作确认 2"
                title="了解本次调节方式"
                description="我们会分别测试左右两侧，每侧包含刺激模式和吸乳模式两种模式。你只需要慢慢加档，感到不适就减档，最终确认未感不适时的最大档位。"
              >
                <div className="grid grid-cols-2 gap-2.5">
                  <Button onClick={() => handlePickSide("L")} className="h-11 rounded-2xl font-bold">先测左侧</Button>
                  <Button onClick={() => handlePickSide("R")} variant="outline" className="h-11 rounded-2xl font-bold">先测右侧</Button>
                </div>
              </StepCard>
            )}

            {phase === "modeIntro" && (
              <StepCard
                eyebrow={`${sideLabel(currentSide)} · ${modeLabel(currentMode)}`}
                title={`准备测试${modeLabel(currentMode)}`}
                description={`请确认当前正在调节${sideLabel(currentSide)}。开始后吸奶器会以 1 档运行，你可以逐步加档。`}
                primaryLabel="准备好了，开始"
                onPrimary={async () => {
                  const success = await sendB1Command(currentSide, currentMode, 1);
                  if (success) {
                    setGear(1);
                    setPhase("testing");
                  }
                }}
              />
            )}

            {phase === "testing" && (
              <StepCard
                eyebrow={`${sideLabel(currentSide)} · ${modeLabel(currentMode)}`}
                title="调节到舒适最大档"
              >
                <GearControl
                  gear={gear}
                  actionCountdown={gearActionCountdown}
                />
                <p className="text-center text-[10px] leading-relaxed text-muted-foreground/80">
                  未感不适时持续加档, 感受到略微不适时减1~2档, 恢复到舒适档位
                </p>
                <div className="flex justify-between gap-2.5">
                  <GearActionButton
                    disabled={gearActionLocked || gear <= 1}
                    tone="danger"
                    onClick={async () => {
                      const newGear = Math.max(1, gear - 1);
                      if (newGear !== gear) {
                        const success = await sendB1Command(currentSide, currentMode, newGear);
                        if (success) {
                          setGear(newGear);
                          setConfirmGearReady(true);
                          startGearActionLock();
                        }
                      }
                    }}
                  >
                    略感不适，减一档
                  </GearActionButton>
                  <GearActionButton
                    disabled={gearActionLocked || gear >= MAX_GEAR}
                    tone="success"
                    onClick={async () => {
                      const newGear = Math.min(MAX_GEAR, gear + 1);
                      if (newGear !== gear) {
                        const success = await sendB1Command(currentSide, currentMode, newGear);
                        if (success) {
                          setGear(newGear);
                          setConfirmGearReady(newGear === MAX_GEAR);
                          startGearActionLock();
                        }
                      }
                    }}
                  >
                    未感不适，加一档
                  </GearActionButton>
                </div>
                <button
                  onClick={() => {
                    void handleConfirmGear();
                  }}
                  disabled={!confirmGearReady || gearActionLocked}
                  className={cn(
                    "h-12 w-full rounded-2xl border-2 border-primary/40 bg-primary/10 px-3 text-[13px] font-bold text-primary transition-all active:scale-95",
                    (!confirmGearReady || gearActionLocked) && "opacity-40 active:scale-100"
                  )}
                >
                  确认使用目前档位
                </button>
              </StepCard>
            )}

            {phase === "modeRest" && (
              <StepCard
                eyebrow={`${sideLabel(currentSide)} · 刺激模式完成`}
                title="稍作休息，准备吸乳模式"
                description={`${sideLabel(currentSide)}刺激模式舒适档位已记录为 ${pendingStimGear} 档。休息结束后进入吸乳模式测试。`}
              >
                <div className="rounded-2xl bg-secondary p-4 text-center">
                  <p className="text-[11px] text-muted-foreground">自动进入下一步</p>
                  <p className="mt-0.5 text-3xl font-extrabold text-primary">{restCountdown}s</p>
                </div>
              </StepCard>
            )}

            {phase === "sideResult" && results[currentSide] && (
              <StepCard
                eyebrow={`${sideLabel(currentSide)}完成`}
                title={`${sideLabel(currentSide)}舒适档位已记录`}
                description="你可以继续测试另一侧，也可以先跳过。若跳过，另一侧会暂时沿用当前侧档位。"
              >
                <ResultGrid result={results[currentSide]!} />
                <div className="grid grid-cols-2 gap-2.5">
                  {results[otherSide(currentSide)] || skippedOtherSide ? (
                    <Button onClick={() => setPhase("finalResult")} className="col-span-2 h-11 rounded-2xl font-bold">
                      查看完整结果
                    </Button>
                  ) : (
                    <>
                      <Button onClick={handleStartOtherSide} className="h-11 rounded-2xl text-xs font-bold">
                        测试{sideLabel(otherSide(currentSide))}
                      </Button>
                      <Button onClick={() => { void handleSkipOtherSide(); }} variant="outline" className="h-11 rounded-2xl text-xs font-bold">
                        先跳过
                      </Button>
                    </>
                  )}
                </div>
              </StepCard>
            )}

            {phase === "finalResult" && (
              <FinalResultBlock
                results={results}
                applied={applied}
                doApply={doApply}
                sideLabel={sideLabel}
                navigate={navigate}
                countdown={autoCountdown}
                setCountdown={setAutoCountdown}
                mockMode={mockMode}
              />
            )}
          </motion.div>
        </main>
      </div>
    </div>
  );
};

/* FinalResultBlock for ComfortCalibration page */
const FinalResultBlock: React.FC<{
  results: { L?: SideResult; R?: SideResult };
  applied: boolean;
  doApply: (res: { L?: SideResult; R?: SideResult }) => void;
  sideLabel: (s: Side) => string;
  navigate: ReturnType<typeof useNavigate>;
  countdown: number;
  setCountdown: React.Dispatch<React.SetStateAction<number>>;
  mockMode?: boolean;
}> = ({ results, applied, doApply, sideLabel, navigate, countdown, setCountdown, mockMode = false }) => {
  const appliedRef = useRef(false);
  const autoStartRef = useRef(false);

  useEffect(() => {
    if (!appliedRef.current) {
      appliedRef.current = true;
      doApply(results);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- finalResult 挂载时应用一次当前结果；补依赖会重复写入校准结果
  }, []);

  useEffect(() => {
    if (mockMode) return;
    const t = setInterval(() => {
      setCountdown((prev: number) => {
        if (prev <= 1) {
          clearInterval(t);
          if (!autoStartRef.current) {
            autoStartRef.current = true;
            void (async () => {
              await startPumpAfterCalibration(results);
              navigate(buildCalibrationAutoStartRoute());
            })();
          }
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 倒计时按 finalResult 挂载启动一次；补 results/navigate 会重置自动启动时序
  }, [mockMode]);

  const testedSide = results.L ? "L" : "R";
  const onlyOneSide = !results.L || !results.R;

  return (
    <StepCard
      eyebrow="调节完成"
      title="已设置你的专属舒适档位"
      description="M.ai 会用舒适档位-2 开始，再逐步增强到舒适档位，帮助你更平稳地进入吸奶。"
    >
      {results.L && results.R ? (
        <div className="grid grid-cols-1 gap-2.5 min-[380px]:grid-cols-2">
          <ResultGrid title="左侧" result={results.L} />
          <ResultGrid title="右侧" result={results.R} />
        </div>
      ) : (
        <ResultGrid title={`${sideLabel(testedSide as Side)}，另一侧沿用`} result={results[testedSide]!} />
      )}
      <div className="rounded-2xl border border-primary/20 bg-primary/10 p-4 text-center">
        <CheckCircle2 className="mx-auto h-6 w-6 text-primary" />
        <p className="mt-2 text-sm font-bold text-primary">
          {mockMode ? "设计模式：已跳过自动开始" : `${countdown}s 后自动开始吸奶`}
        </p>
      </div>
    </StepCard>
  );
};

const StepCard: React.FC<{
  eyebrow: string;
  title: string;
  description?: string;
  primaryLabel?: string;
  onPrimary?: () => void | Promise<void>;
  children?: React.ReactNode;
}> = ({ eyebrow, title, description, primaryLabel, onPrimary, children }) => (
  <section className="w-full space-y-4 rounded-[1.35rem] border border-border/60 bg-card p-4 shadow-sm">
    <div className="space-y-1.5">
      <p className="text-[10px] font-bold uppercase tracking-wider text-primary">{eyebrow}</p>
      <h2 className="text-lg font-extrabold leading-snug text-foreground">{title}</h2>
      {description ? <p className="text-[13px] leading-relaxed text-muted-foreground">{description}</p> : null}
    </div>
    {children}
    {primaryLabel && onPrimary && (
      <Button onClick={onPrimary} className="h-11 w-full rounded-2xl font-bold">
        {primaryLabel}
      </Button>
    )}
  </section>
);

const GearControl: React.FC<{
  gear: number;
  actionCountdown: number | null;
}> = ({ gear, actionCountdown }) => (
  <div className="flex flex-col items-center justify-center gap-2 py-1">
    <div className="relative flex h-24 w-24 items-center justify-center rounded-full border-4 border-primary/20 min-[380px]:h-28 min-[380px]:w-28">
      <motion.div key={gear} initial={{ scale: 0.7, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="text-3xl font-bold text-primary min-[380px]:text-4xl">
        {gear}
      </motion.div>
      <span className="absolute bottom-2 text-[10px] font-medium text-muted-foreground">档位</span>
      <svg className="absolute inset-0 h-full w-full -rotate-90" viewBox="0 0 100 100">
        <circle
          cx="50"
          cy="50"
          r="46"
          fill="none"
          stroke="hsl(var(--primary))"
          strokeWidth="3"
          strokeLinecap="round"
          strokeDasharray={`${(gear / MAX_GEAR) * 289} 289`}
          className="transition-all duration-500"
        />
      </svg>
    </div>
    <div className="h-12">
      {actionCountdown !== null ? (
        <motion.div
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          className="flex flex-col items-center rounded-full border border-primary/20 bg-primary/10 px-4 py-1 text-[11px] font-semibold leading-tight text-primary"
        >
          <span>请感受舒适情况</span>
          <motion.span
            key={`action-countdown-value-${actionCountdown}`}
            initial={{ opacity: 0.65 }}
            animate={{ opacity: 1 }}
            className="mt-0.5 font-mono text-[12px]"
          >
            {actionCountdown}s
          </motion.span>
        </motion.div>
      ) : null}
    </div>
  </div>
);

const GearActionButton: React.FC<{
  onClick: () => void | Promise<void>;
  disabled: boolean;
  tone: "danger" | "success";
  children: React.ReactNode;
}> = ({ disabled, onClick, tone, children }) => (
  <button
    type="button"
    onClick={() => { void onClick(); }}
    disabled={disabled}
    className={cn(
      "h-11 w-[12.5rem] max-w-[46vw] rounded-2xl border-2 border-primary/40 bg-primary/10 px-3 text-[12px] font-bold transition-all active:scale-95",
      tone === "danger" ? "text-red-700" : "text-green-600",
      disabled && "opacity-40 active:scale-100",
    )}
  >
    {children}
  </button>
);

const ResultGrid: React.FC<{ title?: string; result: SideResult }> = ({ title, result }) => (
  <div className="space-y-2 rounded-2xl bg-secondary/70 p-2.5">
    {title && <p className="text-center text-xs font-bold text-foreground">{title}</p>}
    <div className="grid grid-cols-2 gap-2">
      <div className="rounded-xl bg-background/70 p-2 text-center">
        <p className="text-[10px] text-muted-foreground">刺激</p>
        <p className="text-base font-bold text-primary">{result.stimGear} 档</p>
      </div>
      <div className="rounded-xl bg-background/70 p-2 text-center">
        <p className="text-[10px] text-muted-foreground">吸乳</p>
        <p className="text-base font-bold text-primary">{result.deepGear} 档</p>
      </div>
    </div>
  </div>
);

export default ComfortCalibration;
