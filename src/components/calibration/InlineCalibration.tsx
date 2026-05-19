import React, { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { motion, AnimatePresence } from "framer-motion";
import { Minus, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { sendB1SetPumpParams, sendF1SetUserParams } from "@/lib/ble";
import { deviceStore } from "@/lib/deviceStore";
import { uploadPumpThreshold } from "@/lib/agentApi";
import { ApiError } from "@/lib/http";
import { getRuntimeUserId } from "@/lib/debugUserConfig";

/* ── types ── */
type Side = "L" | "R";
type Mode = "stimulate" | "deep";
type Step =
  | "wear"
  | "explainSides"
  | "pickSide"
  | "modeIntro"
  | "testing"
  | "modeRest"
  | "sideResult"
  | "askOtherSide"
  | "finalResult"
  | "askPump"
  | "done";

interface SideResult {
  stimGear: number;
  deepGear: number;
}

interface CalibrationData {
  L?: SideResult;
  R?: SideResult;
  timestamp: number;
}

const MAX_GEAR = 15;
const DEFAULT_PUMP_USER_ID = getRuntimeUserId(import.meta.env.VITE_DEFAULT_USER_ID as string | undefined);

interface Props {
  onComplete?: () => void;
}

const InlineCalibration: React.FC<Props> = ({ onComplete }) => {
  const navigate = useNavigate();
  const [step, setStep] = useState<Step>("wear");
  const [gear, setGear] = useState(1);
  const [currentSide, setCurrentSide] = useState<Side>("L");
  const [currentMode, setCurrentMode] = useState<Mode>("stimulate");
  const [firstSide, setFirstSide] = useState<Side>("L");
  const [results, setResults] = useState<{ L?: SideResult; R?: SideResult }>({});
  const [pendingStimGear, setPendingStimGear] = useState<number | null>(null);
  const [restCountdown, setRestCountdown] = useState(5);
  const [applied, setApplied] = useState(false);
  const [skippedOtherSide, setSkippedOtherSide] = useState(false);
  const [gearTimer, setGearTimer] = useState(0);
  const [milkConfirmed, setMilkConfirmed] = useState(false);

  const containerRef = useRef<HTMLDivElement>(null);
  
  // 使用ref保存最新状态，避免useEffect依赖项变化导致的问题
  const stepRef = useRef(step);
  const gearRef = useRef(gear);
  const currentSideRef = useRef(currentSide);
  const currentModeRef = useRef(currentMode);
  const thresholdUploadedRef = useRef(false);
  
  useEffect(() => { stepRef.current = step; }, [step]);
  useEffect(() => { gearRef.current = gear; }, [gear]);
  useEffect(() => { currentSideRef.current = currentSide; }, [currentSide]);
  useEffect(() => { currentModeRef.current = currentMode; }, [currentMode]);

  useEffect(() => {
    setTimeout(() => containerRef.current?.scrollIntoView({ behavior: "smooth", block: "end" }), 100);
  }, [step, gear]);

  // 完成两侧滴定（含跳过另一侧）并出现“查看完整结果”按钮时，上报一次滴定阈值到 AGENT
  useEffect(() => {
    const shouldShowFinalResultButton =
      step === "sideResult" && (Boolean(results[otherSide(currentSide)]) || skippedOtherSide);
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
      console.log("[InlineCalibration] uploadPumpThreshold 上报成功，data:", JSON.stringify(data));
    }).catch((error) => {
      thresholdUploadedRef.current = false;
      console.error(`[InlineCalibration] uploadPumpThreshold 上报失败：${error}`);
      if (error instanceof ApiError) {
        console.error(
          "[InlineCalibration] uploadPumpThreshold ApiError apiStatus=",
          error.apiStatus,
          "message=",
          error.message,
          "完整信封 raw:",
          JSON.stringify(error.raw),
        );
      }
    });
  }, [step, results, currentSide, skippedOtherSide]);

  // 页面加载时检查设备连接状态
  useEffect(() => {
    const { L, R } = deviceStore.get();
    console.log(`[InlineCalibration] 页面加载时设备状态: L=${JSON.stringify(L)}, R=${JSON.stringify(R)}`);
    const hasConnectedDevice = (L?.connected || false) || (R?.connected || false);
    console.log(`[InlineCalibration] 页面加载时是否有连接设备: ${hasConnectedDevice}`);
    
    if (!hasConnectedDevice) {
      console.log(`[InlineCalibration] 设备未连接，显示弹窗提醒`);
      alert("请先连接吸奶器设备后再进行舒适负压滴定。");
    }
  }, []);

  // 跟踪滴定状态
  useEffect(() => {
    // 当进入滴定流程（非finalResult）时，设置滴定进行中标志
    if (step !== "finalResult") {
      localStorage.setItem('calibrationInProgress', 'true');
      console.log(`[InlineCalibration] 滴定进行中，设置calibrationInProgress标志，当前步骤: ${step}`);
    }
    // 当测试完成时，清除滴定进行中标志
    if (step === "finalResult") {
      localStorage.removeItem('calibrationInProgress');
      console.log(`[InlineCalibration] 测试完成，清除calibrationInProgress标志`);
    }
  }, [step]);

  // Gear dwell timer: reset on gear change, tick every second during 'adjust' step
  useEffect(() => {
    setGearTimer(0);
    if (step !== "testing") return;
    const t = setInterval(() => setGearTimer(prev => prev + 1), 1000);
    return () => clearInterval(t);
  }, [gear, step]);

  // 组件卸载时，如果处于 testing 步骤，发送停止指令。
  // calibrationInProgress 仍保留至滴定 finalResult 或本逻辑需要由 Hub 侧识别「未完成的 cal 卡片」；舒适档展示改读本地缓存，不依赖此标志。
  useEffect(() => {
    return () => {
      if (stepRef.current === "testing") {
        console.log(`[InlineCalibration] 组件卸载时处于testing步骤，发送停止指令`);
        const deviceInfo = deviceStore.get()[currentSideRef.current];
        if (deviceInfo?.connected && deviceInfo.deviceId) {
          try {
            // 转换模式：刺激模式为0，深度模式为1
            const modeB1 = currentModeRef.current === "stimulate" ? 0 : 1;
            // 将挡位值修改为当前页面挡位值-1
            const adjustedGear = gearRef.current - 1;
            // 场景为手动（0），启停为停止（0）
            sendB1SetPumpParams(deviceInfo.deviceId, 0, modeB1, adjustedGear, 0);
            console.log(`[B1指令] 发送成功：${sideLabel(currentSideRef.current)} ${modeLabel(currentModeRef.current)} 模式 停止，档位=${adjustedGear}`);
          } catch (error) {
            console.error(`[B1指令] 发送停止失败：${error}`);
          }
        }
      }
    };
  }, []);

  // Rest countdown between stim → deep
  useEffect(() => {
    if (step !== "modeRest") return;
    setRestCountdown(5);
    const t = setInterval(() => {
      setRestCountdown(prev => {
        if (prev <= 1) {
          clearInterval(t);
          setCurrentMode("deep");
          setGear(1);
          setMilkConfirmed(false);
          setStep("modeIntro");
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(t);
  }, [step]);

  const sideLabel = (s: Side) => s === "L" ? "左侧" : "右侧";
  const modeLabel = (m: Mode) => m === "stimulate" ? "刺激阵列" : "深度吸乳";
  const otherSide = (s: Side): Side => s === "L" ? "R" : "L";

  // 发送B1指令的函数
  const sendB1Command = async (side: Side, mode: Mode, gear: number) => {
    // 将挡位值修改为当前页面挡位值-1
    const adjustedGear = gear - 1;
    console.log(`[InlineCalibration] 准备发送B1指令：侧别=${sideLabel(side)}, 模式=${modeLabel(mode)}, 页面档位=${gear}, 发送档位=${adjustedGear}`);
    const deviceInfo = deviceStore.get()[side];
    console.log(`[InlineCalibration] 设备信息：${JSON.stringify(deviceInfo)}`);
    if (!deviceInfo?.connected || !deviceInfo.deviceId) {
      console.log(`[InlineCalibration] ${sideLabel(side)}设备未连接，无法发送B1指令`);
      alert(`${sideLabel(side)}设备未连接，请先连接设备后再开始测试。`);
      return false;
    }

    try {
      // 转换模式：刺激模式为0，深度模式为1
      const modeB1 = mode === "stimulate" ? 0 : 1;
      // 场景为手动（0），启停为运行（1）
      console.log(`[InlineCalibration] 执行sendB1SetPumpParams：deviceId=${deviceInfo.deviceId}, start=1, mode=${modeB1}, gear=${adjustedGear}, scene=0`);
      await sendB1SetPumpParams(deviceInfo.deviceId, 1, modeB1, adjustedGear, 0);
      console.log(`[B1指令] 发送成功：${sideLabel(side)} ${modeLabel(mode)} 模式 ${adjustedGear} 档`);
      return true;
    } catch (error) {
      console.error(`[B1指令] 发送失败：${error}`);
      alert(`发送指令失败，请重试。`);
      return false;
    }
  };

  const handleConfirmGear = async () => {
    // 发送停止指令
    const deviceInfo = deviceStore.get()[currentSide];
    if (deviceInfo?.connected && deviceInfo.deviceId) {
      try {
        // 点击“就这个档位了~”时，固定按刺激模式舒适档位发送停止指令
        const modeB1 = 0; // 刺激模式
        const stimGear = currentMode === "stimulate" ? gear : pendingStimGear ?? gear;
        // 挡位按协议发送页面值-1；场景为自动（1），启停为停止（0）
        const adjustedGear = stimGear - 1;
        await sendB1SetPumpParams(deviceInfo.deviceId, 0, modeB1, adjustedGear, 1);
        console.log(`[B1指令] 发送成功：${sideLabel(currentSide)} 刺激阵列 模式 停止，档位=${adjustedGear}`);
      } catch (error) {
        console.error(`[B1指令] 发送停止失败：${error}`);
      }
    }

    if (currentMode === "stimulate") {
      setPendingStimGear(gear);
      setGear(0);
      setStep("modeRest");
    } else {
      // deep mode done — save side result
      const sideResult: SideResult = {
        stimGear: pendingStimGear!,
        deepGear: gear,
      };
      setResults(prev => ({ ...prev, [currentSide]: sideResult }));
      
      // 完成一侧滴定后，将舒适挡位通过sendF1SetUserParams下发到该侧设备
      const currentDeviceInfo = deviceStore.get()[currentSide];
      if (currentDeviceInfo?.connected && currentDeviceInfo.deviceId) {
        try {
          // 挡位参数应为页面显示挡位值-1
          const stimulateGear = pendingStimGear! - 1;
          const lactateGear = gear - 1;
          // 有效性参数为1
          const persist = 1;
          
          console.log(`[F1指令] 准备发送舒适挡位：侧别=${sideLabel(currentSide)}, 刺激档位=${stimulateGear}, 深度档位=${lactateGear}, 有效性=${persist}`);
          await sendF1SetUserParams(currentDeviceInfo.deviceId, stimulateGear, lactateGear, persist);
          console.log(`[F1指令] 发送成功：${sideLabel(currentSide)} 舒适挡位已设置`);
        } catch (error) {
          console.error(`[F1指令] 发送失败：${error}`);
        }
      }
      
      setGear(0);
      setStep("sideResult");
    }
  };

  const handlePickSide = (side: Side) => {
    // 检查选择的设备是否在线
    const deviceInfo = deviceStore.get()[side];
    console.log(`[InlineCalibration] 选择测试侧别 ${sideLabel(side)} 时设备状态: ${JSON.stringify(deviceInfo)}`);
    if (!deviceInfo?.connected || !deviceInfo.deviceId) {
      console.log(`[InlineCalibration] ${sideLabel(side)}设备未连接，显示弹窗提醒`);
      alert(`${sideLabel(side)}设备未连接，请先连接设备后再开始测试。`);
      return;
    }
    
    setFirstSide(side);
    setCurrentSide(side);
    setCurrentMode("stimulate");
    setGear(1);
    setPendingStimGear(null);
    setSkippedOtherSide(false);
    setMilkConfirmed(true); // stim mode doesn't need milk confirm
    setStep("modeIntro");
  };

  const handleStartOtherSide = () => {
    const other = otherSide(firstSide);
    
    // 检查选择的设备是否在线
    const deviceInfo = deviceStore.get()[other];
    console.log(`[InlineCalibration] 开始测试另一侧 ${sideLabel(other)} 时设备状态: ${JSON.stringify(deviceInfo)}`);
    if (!deviceInfo?.connected || !deviceInfo.deviceId) {
      console.log(`[InlineCalibration] ${sideLabel(other)}设备未连接，显示弹窗提醒`);
      alert(`${sideLabel(other)}设备未连接，请先连接设备后再开始测试。`);
      return;
    }
    
    setCurrentSide(other);
    setCurrentMode("stimulate");
    setGear(1);
    setPendingStimGear(null);
    setSkippedOtherSide(false);
    setMilkConfirmed(true); // stim mode doesn't need milk confirm
    setStep("modeIntro");
  };

  const handleSkipOtherSide = async () => {
    // 如果用户选择了跳过另一侧，且另一侧设备也处于连接状态，则将相同的参数下发到另一侧设备
    const otherSideKey = currentSide === "L" ? "R" : "L";
    const currentResult = results[currentSide];
    const otherDeviceInfo = deviceStore.get()[otherSideKey];
    
    if (otherDeviceInfo?.connected && otherDeviceInfo.deviceId && currentResult) {
      try {
        // 挡位参数应为页面显示挡位值-1
        const stimulateGear = currentResult.stimGear - 1;
        const lactateGear = currentResult.deepGear - 1;
        // 有效性参数为1
        const persist = 1;
        
        console.log(`[F1指令] 准备发送舒适挡位到另一侧：侧别=${sideLabel(otherSideKey)}, 刺激档位=${stimulateGear}, 深度档位=${lactateGear}, 有效性=${persist}`);
        await sendF1SetUserParams(otherDeviceInfo.deviceId, stimulateGear, lactateGear, persist);
        console.log(`[F1指令] 发送成功：${sideLabel(otherSideKey)} 舒适挡位已设置`);
      } catch (error) {
        console.error(`[F1指令] 发送到另一侧失败：${error}`);
      }
    }

    // 跳过另一侧时，沿用已测侧结果用于完整结果展示
    if (currentResult) {
      setResults(prev => ({ ...prev, [otherSideKey]: currentResult }));
    }
    
    setSkippedOtherSide(true);
  };

  const doApply = (res: { L?: SideResult; R?: SideResult }) => {
    setApplied(true);
    const L = res.L;
    const R = res.R;
    // If only one side tested, copy to the other side as default
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

  /* ── Bubble ── */
  const Bubble: React.FC<{ children: React.ReactNode; delay?: number }> = ({ children, delay = 0 }) => (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay, duration: 0.3 }}
      className="flex gap-2 items-start"
    >
      <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed">
        {children}
      </div>
    </motion.div>
  );

  /* ── FinalResultView ── auto-apply + 3s auto-navigate */
  const FinalResultView: React.FC<{
    results: { L?: SideResult; R?: SideResult };
    applied: boolean;
    doApply: (res: { L?: SideResult; R?: SideResult }) => void;
    sideLabel: (s: Side) => string;
    onComplete?: () => void;
    navigate: ReturnType<typeof useNavigate>;
  }> = ({ results, applied, doApply, sideLabel, onComplete, navigate }) => {
    const [countdown, setCountdown] = useState(3);
    const appliedRef = useRef(false);

    // Auto-apply on mount
    useEffect(() => {
      if (!appliedRef.current) {
        appliedRef.current = true;
        doApply(results);
      }
    }, []);

    // 3s countdown then navigate
    useEffect(() => {
      const t = setInterval(() => {
        setCountdown(prev => {
          if (prev <= 1) {
            clearInterval(t);
            onComplete?.();
            navigate("/pump?from=calibration");
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      return () => clearInterval(t);
    }, []);

    const onlyOneSide = !results.L || !results.R;
    const testedSide = results.L ? "L" : "R";

    return (
      <>
        <Bubble>太棒了妈妈！🎉 测试完成，已自动为您设置专属舒适档位~</Bubble>
        <Bubble delay={0.25}>
          <div className="space-y-2">
            {results.L && results.R ? (
              <div className="space-y-2">
                <p className="text-[12px] font-medium">左右两侧的最大舒适档位：</p>
                <div className="grid grid-cols-2 gap-1.5">
                  {(["L", "R"] as Side[]).map(s => (
                    <div key={s} className="rounded-xl bg-secondary p-2">
                      <p className="text-[9px] text-muted-foreground text-center mb-1">{sideLabel(s)}</p>
                      <div className="flex justify-around">
                        <div className="text-center">
                          <p className="text-[8px] text-muted-foreground">刺激</p>
                          <p className="text-sm font-bold text-primary">{results[s]!.stimGear}档</p>
                        </div>
                        <div className="text-center">
                          <p className="text-[8px] text-muted-foreground">深度</p>
                          <p className="text-sm font-bold text-primary">{results[s]!.deepGear}档</p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="space-y-1.5">
                <p className="text-[12px] font-medium">{sideLabel(testedSide as Side)}最大舒适档位：</p>
                <div className="grid grid-cols-2 gap-1.5">
                  <div className="rounded-xl bg-secondary p-2 text-center">
                    <p className="text-[9px] text-muted-foreground">刺激模式</p>
                    <p className="text-base font-bold text-primary">{results[testedSide]!.stimGear} 档</p>
                  </div>
                  <div className="rounded-xl bg-secondary p-2 text-center">
                    <p className="text-[9px] text-muted-foreground">深度模式</p>
                    <p className="text-base font-bold text-primary">{results[testedSide]!.deepGear} 档</p>
                  </div>
                </div>
                <p className="text-[10px] text-muted-foreground">（{sideLabel(testedSide === "L" ? "R" : "L" as Side)}已默认使用相同档位）</p>
              </div>
            )}
          </div>
        </Bubble>
        <Bubble delay={0.5}>
          ✅ 档位已自动设置！M.ai 会用<span className="font-bold text-primary">舒适档位-2</span>开始，再渐强到舒适档位，帮您更平稳地进入吸乳~ 🌸
          <div className="mt-1.5 text-center">
            <span className="inline-block bg-secondary rounded-full px-3 py-1 text-sm font-bold text-primary">
              {countdown}s 后自动开始吸乳
            </span>
          </div>
        </Bubble>
      </>
    );
  };

  /* ── Gear Control ── */
  const GearControl = () => (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="space-y-3">
      {/* Mode + Side label */}
      <div className="flex flex-col items-center gap-0.5">
        <span className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider">
          {sideLabel(currentSide)} · {modeLabel(currentMode)}
        </span>
      </div>

      {/* Gear ring with +/- buttons */}
      <div className="flex items-center justify-center gap-4">
        {/* Minus button */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={async () => {
              const newGear = Math.max(1, gear - 1);
              if (newGear !== gear) {
                const success = await sendB1Command(currentSide, currentMode, newGear);
                if (success) {
                  setGear(newGear);
                }
              }
            }}
            disabled={gear <= 1}
            className={cn(
              "w-10 h-10 rounded-full border-2 border-primary/30 flex items-center justify-center transition-all active:scale-90",
              gear <= 1 ? "opacity-30" : "hover:bg-primary/10"
            )}
          >
            <Minus className="w-4 h-4 text-primary" />
          </button>
          <p className="text-[9px] text-muted-foreground text-center max-w-[72px] leading-tight">
            疼痛了就减一档
          </p>
        </div>

        {/* Gear circle + timer */}
        <div className="flex flex-col items-center gap-1.5">
          <div className="relative w-20 h-20 rounded-full border-[3px] border-primary/20 flex flex-col items-center justify-center">
            <motion.div key={gear} initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
              className="text-2xl font-bold text-primary leading-none">{gear}</motion.div>
            <span className="text-[8px] text-muted-foreground font-medium mt-0.5">档位</span>
            <svg className="absolute inset-0 w-full h-full -rotate-90" viewBox="0 0 100 100">
              <circle cx="50" cy="50" r="46" fill="none" stroke="hsl(var(--primary))" strokeWidth="3.5" strokeLinecap="round"
                strokeDasharray={`${(gear / MAX_GEAR) * 289} 289`} className="transition-all duration-700" />
            </svg>
          </div>
          <motion.div
            key={`timer-${gear}`}
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            className="rounded-full bg-primary/10 border border-primary/20 px-3 py-0.5 flex items-center gap-1"
          >
            <span className="text-[11px] font-mono font-semibold text-primary">{gearTimer}s</span>
            <span className="text-[9px] text-muted-foreground">停留</span>
          </motion.div>
        </div>

        {/* Plus button */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={async () => {
              const newGear = Math.min(MAX_GEAR, gear + 1);
              if (newGear !== gear) {
                const success = await sendB1Command(currentSide, currentMode, newGear);
                if (success) {
                  setGear(newGear);
                }
              }
            }}
            disabled={gear >= MAX_GEAR}
            className={cn(
              "w-10 h-10 rounded-full border-2 border-primary/30 flex items-center justify-center transition-all active:scale-90",
              gear >= MAX_GEAR ? "opacity-30" : "hover:bg-primary/10"
            )}
          >
            <Plus className="w-4 h-4 text-primary" />
          </button>
          <p className="text-[9px] text-muted-foreground text-center whitespace-nowrap leading-tight">
            可以接受就加档
          </p>
        </div>
      </div>

      {/* Guidance + confirm */}
      <div className="space-y-2 px-2">
        {!milkConfirmed && (
          <p className="text-[11px] text-center text-muted-foreground leading-snug">
            💡 请先调节档位让吸奶器运行，<span className="font-bold text-primary">出奶后</span>再确认，空吸时会比实际感受更疼哦~
          </p>
        )}
        {milkConfirmed && (
          <p className="text-[11px] text-center text-muted-foreground leading-snug">
            💡 我们要找到<span className="font-bold text-primary">不疼痛时的最大档位</span>——如果加档感到疼了，就减一档，等感觉舒服了就选定它~
          </p>
        )}
        <button
          onClick={() => {
            if (!milkConfirmed) {
              setMilkConfirmed(true);
            } else {
              handleConfirmGear();
            }
          }}
          className="w-full rounded-xl px-2.5 py-2.5 text-[12px] font-bold border-2 border-primary/40 bg-primary/10 text-primary active:scale-95 transition-all"
        >
          {milkConfirmed ? "✅ 就这个档位了~" : "🍼 已经出奶了"}
        </button>
      </div>
    </motion.div>
  );

  return (
    <div ref={containerRef} className="space-y-3">
      {/* WEAR */}
      <Bubble>
        妈妈，为了帮您找到最舒适的吸力，请先正确贴合并穿戴好吸奶器。穿戴好后告诉我哦~ 💕
      </Bubble>

      {step === "wear" && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }} className="flex justify-center">
          <Button onClick={() => setStep("explainSides")} size="sm" className="rounded-2xl px-5 text-xs font-bold">
            ✅ 穿戴好了，开始吧
          </Button>
        </motion.div>
      )}

      {/* EXPLAIN SIDES */}
      {step !== "wear" && (
        <Bubble delay={0.1}>
          收到！妈妈，左右两侧的乳房对吸力的耐受可能不太一样哦~ 为了给每一侧都找到最舒服的档位，我们会<span className="font-bold text-primary">分别测试左右两侧</span>，每侧测试刺激和深度两种模式 🫶
        </Bubble>
      )}

      {step === "explainSides" && (
        <Bubble delay={0.3}>
          测试时我会让吸奶器运行，您来手动调节档位。往上加档感受一下，如果疼了就减一档，找到不疼时的最大档位就好啦~ 很简单的！💪
        </Bubble>
      )}

      {/* PICK SIDE */}
      {step === "explainSides" && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }} className="space-y-2">
          <Bubble delay={0.4}>想先测试哪一侧呢？</Bubble>
          <div className="flex gap-2 justify-center">
            <Button onClick={() => handlePickSide("L")} size="sm" className="rounded-2xl px-5 text-xs font-bold flex-1">
              先测左侧
            </Button>
            <Button onClick={() => handlePickSide("R")} size="sm" variant="outline" className="rounded-2xl px-5 text-xs font-bold flex-1">
              先测右侧
            </Button>
          </div>
        </motion.div>
      )}

      {/* MILK CONFIRM step removed — merged into GearControl button */}

      {/* MODE INTRO */}
      {step === "modeIntro" && (
        <>
          <Bubble>
            好的~ 现在开始测试{sideLabel(currentSide)}的<span className="font-bold text-primary">【{modeLabel(currentMode)}】</span>模式。请慢慢调整档位，找到舒适的最大吸力~ 🌸
          </Bubble>
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }} className="flex justify-center">
            <Button onClick={async () => {
              const success = await sendB1Command(currentSide, currentMode, 1);
              if (success) {
                setGear(1);
                setStep("testing");
              }
            }} size="sm" className="rounded-2xl px-5 text-xs font-bold">
              准备好了，开始
            </Button>
          </motion.div>
        </>
      )}

      {/* TESTING — manual gear control */}
      {step === "testing" && <GearControl />}

      {/* MODE REST — stim done, transitioning to deep */}
      {step === "modeRest" && (
        <Bubble>
          好的！{sideLabel(currentSide)}的刺激模式舒适档位已记录为 <span className="font-bold text-primary">{pendingStimGear} 档</span> 💗 休息一下，接下来测试<span className="font-bold text-primary">【深度吸乳】</span>模式~
          <div className="mt-1.5 text-center">
            <span className="inline-block bg-secondary rounded-full px-3 py-1 text-sm font-bold text-primary">
              {restCountdown}s 后开始
            </span>
          </div>
        </Bubble>
      )}

      {/* SIDE RESULT — one side completed */}
      {step === "sideResult" && results[currentSide] && (
        <>
          <Bubble>
            棒！{sideLabel(currentSide)}测试完成 🎉
          </Bubble>
          <Bubble delay={0.2}>
            <div className="space-y-1.5">
              <p className="text-[12px] font-medium">{sideLabel(currentSide)}的舒适档位：</p>
              <div className="grid grid-cols-2 gap-1.5">
                <div className="rounded-xl bg-secondary p-2 text-center">
                  <p className="text-[9px] text-muted-foreground">刺激模式</p>
                  <p className="text-base font-bold text-primary">{results[currentSide]!.stimGear} 档</p>
                </div>
                <div className="rounded-xl bg-secondary p-2 text-center">
                  <p className="text-[9px] text-muted-foreground">深度模式</p>
                  <p className="text-base font-bold text-primary">{results[currentSide]!.deepGear} 档</p>
                </div>
              </div>
            </div>
          </Bubble>
        </>
      )}

      {/* ASK OTHER SIDE */}
      {step === "sideResult" && !results[otherSide(currentSide)] && !skippedOtherSide && (
        <>
          <Bubble delay={0.4}>
            接下来要测试<span className="font-bold text-primary">{sideLabel(otherSide(currentSide))}</span>吗？左右两侧的耐受度往往不同，<span className="font-bold text-primary">两侧都测一下</span>才能获得最优的舒适体验哦~ 😊
          </Bubble>
          <Bubble delay={0.55}>
            <span className="text-[11px] text-muted-foreground">💡 如果跳过，{sideLabel(otherSide(currentSide))}会默认使用{sideLabel(currentSide)}的档位设置</span>
          </Bubble>
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.7 }} className="flex gap-2 justify-center">
            <Button onClick={handleStartOtherSide} size="sm" className="rounded-2xl px-4 text-xs font-bold flex-1">
              测试{sideLabel(otherSide(currentSide))}
            </Button>
            <Button variant="outline" onClick={handleSkipOtherSide} size="sm" className="rounded-2xl px-4 text-xs font-medium flex-1">
              先跳过
            </Button>
          </motion.div>
        </>
      )}

      {/* Continue to final result after both sides done or other side skipped */}
      {step === "sideResult" && (results[otherSide(currentSide)] || skippedOtherSide) && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }} className="flex justify-center">
          <Button onClick={() => setStep("finalResult")} size="sm" className="rounded-2xl px-5 text-xs font-bold">
            查看完整结果
          </Button>
        </motion.div>
      )}

      {/* FINAL RESULT — auto-apply + auto-navigate */}
      {step === "finalResult" && (
        <FinalResultView results={results} applied={applied} doApply={doApply} sideLabel={sideLabel} onComplete={onComplete} navigate={navigate} />
      )}
    </div>
  );
};

export default InlineCalibration;
