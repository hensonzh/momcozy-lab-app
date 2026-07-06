import React, { useEffect, useMemo, useState } from "react";
import { Check, AlertCircle, AlertTriangle, GripVertical, Plus, X } from "lucide-react";
import { Drawer, DrawerContent } from "@/components/ui/drawer";
import { toast } from "@/hooks/use-toast";
import {
  buildB4SetGoldenRhythmPacket,
  buildB5SetSoftTransitionPacket,
  buildB6SetSmartForceLinePacket,
  buildE4QueryGoldenRhythmPacket,
  bytesToHex,
  queryGoldenRhythmConfig,
  querySmartForceLineConfig,
  querySoftTransitionConfig,
  saveGoldenRhythmConfig,
  saveSmartForceLineConfig,
  saveSoftTransitionConfig,
  type GoldenRhythmStep,
  type SmartForceLineConfig,
  type SoftTransitionConfig,
} from "@/lib/deviceDebugProtocol";
import type { DeviceInfo } from "@/data/mockData";
import { cn } from "@/lib/utils";
import defaultProgramParamsConfig from "@/../default_program_params_config.json";

type DebugTab = 0 | 1 | 2;

interface Props {
  open: boolean;
  side: "L" | "R";
  device: DeviceInfo;
  onClose: () => void;
}

const goldModeOptions = [
  { value: 0, label: "刺激" },
  { value: 1, label: "吸乳" },
  { value: 2, label: "5短1长" },
  { value: 5, label: "休息" },
];

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function Stepper({
  value,
  min,
  max,
  onChange,
  compact = false,
}: {
  value: number;
  min: number;
  max: number;
  onChange: (next: number) => void;
  compact?: boolean;
}) {
  const [draft, setDraft] = useState(String(value));

  useEffect(() => {
    setDraft(String(value));
  }, [value]);

  const commitDraft = () => {
    const trimmed = draft.trim();
    if (trimmed === "") {
      onChange(min);
      setDraft(String(min));
      return;
    }
    const parsed = Number(trimmed);
    if (!Number.isFinite(parsed)) {
      setDraft(String(value));
      return;
    }
    const next = clamp(parsed, min, max);
    onChange(next);
    setDraft(String(next));
  };

  // 获取当前显示的数值
  const getCurrentValue = () => {
    const parsed = Number(draft);
    return Number.isFinite(parsed) ? parsed : value;
  };

  return (
    <div className={cn("flex items-center overflow-hidden rounded-lg border border-[#ddd] bg-white", compact && "rounded-[8px]")}>
      <button
        type="button"
        className={cn("text-foreground", compact ? "h-8 w-7 text-sm" : "h-11 w-11 text-lg")}
        onClick={() => {
          const currentValue = getCurrentValue();
          console.log('Stepper - button click:', { currentValue, min, max });
          
          // 修复边界值bug：当currentValue已经是min时，再次减应该保持min不变
          if (currentValue <= min) {
            console.log('Stepper - already at min, keeping:', min);
            onChange(min);
            setDraft(String(min));
          } else {
            const next = clamp(currentValue - 1, min, max);
            console.log('Stepper - calculated next:', next);
            onChange(next);
            setDraft(String(next));
          }
        }}
      >
        -
      </button>
      <input
        type="text"
        inputMode="numeric"
        pattern="[0-9]*"
        value={draft}
        onChange={(e) => {
          const raw = e.target.value.replace(/[^\d]/g, "");
          setDraft(raw);
        }}
        onBlur={commitDraft}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            commitDraft();
            (e.currentTarget as HTMLInputElement).blur();
          }
        }}
        className={cn(
          "flex-1 min-w-0 border-x border-[#ddd] text-center outline-none",
          compact ? "h-8 text-[12px]" : "h-11 text-[15px]"
        )}
      />
      <button
        type="button"
        className={cn("text-foreground", compact ? "h-8 w-7 text-sm" : "h-11 w-11 text-lg")}
        onClick={() => {
          const currentValue = getCurrentValue();
          const next = clamp(currentValue + 1, min, max);
          onChange(next);
          setDraft(String(next));
        }}
      >
        +
      </button>
    </div>
  );
}

const DeviceDebugDrawer: React.FC<Props> = ({ open, side, device, onClose }) => {
  const [drawerHeight, setDrawerHeight] = useState<number | null>(null);
  const [currentTab, setCurrentTab] = useState<DebugTab>(0);
  const [goldCustomModeId, setGoldCustomModeId] = useState(0);
  const [goldSteps, setGoldSteps] = useState<GoldenRhythmStep[]>([]);
  const [softConfig, setSoftConfig] = useState<SoftTransitionConfig>({
    enabled: 0,
    stepKpa: 1,
    stepCount: 1,
    transitionGear: 1,
  });
  
  // 居中弹窗提示状态
  const [centerToast, setCenterToast] = useState<{
    visible: boolean;
    title: string;
    description?: string;
    type: 'success' | 'error' | 'warning';
  }>({
    visible: false,
    title: '',
    type: 'success',
  });
  
  // 自定义居中提示函数
  const showCenterToast = (title: string, description?: string, type: 'success' | 'error' | 'warning' = 'success') => {
    setCenterToast({ visible: true, title, description, type });
    setTimeout(() => {
      setCenterToast(prev => ({ ...prev, visible: false }));
    }, 500); // 0.5秒后消失
  };
  
  const [lineConfig, setLineConfig] = useState<SmartForceLineConfig>({
    workMode: 0,
    gearDisplay: 1,
    maxPressureKpa: 25,
    frequencyPcm: 50,
    holdTimeMs: 300,
    buildTimeA: 180,
    releaseTimeC: 400,
    restTimeD: 40,
    cycleT: 667,
    dutyCycle: 33,
    ratio: "2.2:4.4",
  });
  const [loading, setLoading] = useState(false);
  const [dragIdx, setDragIdx] = useState<number | null>(null);
  const [dragOverIdx, setDragOverIdx] = useState<number | null>(null);
  const sideLabel = side === "L" ? "左主机" : "右主机";
  const deviceInfo = useMemo(() => `已连接：${sideLabel} | SN: ${device.serialNumber}`, [device.serialNumber, sideLabel]);

  useEffect(() => {
    if (!open || typeof window === "undefined") return;
    const viewportHeight = window.visualViewport?.height ?? window.innerHeight;
    setDrawerHeight(Math.round(viewportHeight * 0.88));
  }, [open]);

  const loadGold = async () => {
    setLoading(true);
    try {
      const result = await queryGoldenRhythmConfig(device.id, goldCustomModeId);
      setGoldCustomModeId(result.customModeId);
      setGoldSteps(result.steps);
      showCenterToast("查询成功");
    } catch {
      showCenterToast("查询失败", undefined, 'error');
    } finally {
      setLoading(false);
    }
  };

  const loadSoft = async () => {
    setLoading(true);
    try {
      const result = await querySoftTransitionConfig(device.id);
      setSoftConfig(result);
      showCenterToast("查询成功");
    } catch {
      showCenterToast("查询失败", undefined, 'error');
    } finally {
      setLoading(false);
    }
  };

  const loadLine = async () => {
    setLoading(true);
    try {
      const result = await querySmartForceLineConfig(device.id, lineConfig.workMode, lineConfig.gearDisplay);
      
      // 根据读取到的模式+档位自动查表，只填充a、c默认值（不覆盖查询到的负压、频率、保持时间）
      const defaultParams = getDefaultParams(result.workMode, result.gearDisplay);
      
      // 自动计算周期T、d、占空比、比值
      const calculated = calculateLineParams({
        ...result,
        buildTimeA: defaultParams.buildTimeA,  // 只使用查表的a值
        releaseTimeC: defaultParams.releaseTimeC  // 只使用查表的c值
      });
      
      setLineConfig({
        ...result,
        buildTimeA: defaultParams.buildTimeA,  // 只使用查表的a值
        releaseTimeC: defaultParams.releaseTimeC,  // 只使用查表的c值
        ...calculated
      });
      
      showCenterToast("参数读取成功", `已从设备读取模式${result.workMode === 0 ? '刺激' : '吸乳'} 档位${result.gearDisplay}的参数`);
    } catch (error) {
      showCenterToast("读取失败", "无法从设备读取参数，请检查连接", 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!open) return;
    setCurrentTab(0);
  }, [open, side, device.id]);

  useEffect(() => {
    if (!open) return;
    if (currentTab === 0) void loadGold();
    if (currentTab === 1) void loadSoft();
    if (currentTab === 2) void loadLine();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 仅在打开/切换 tab 时读取配置；load* 依赖表单草稿，加入后会在读取回填时重复请求
  }, [open, currentTab]);

  const addGoldStep = () => {
    if (goldSteps.length >= 10) {
      showCenterToast("最多 10 个步骤", undefined, 'error');
      return;
    }
    setGoldSteps((prev) => [
      ...prev,
      {
        index: prev.length,
        mode: 1,
        gearDisplay: 6,
        frequency: 0,
        durationSec: 12,
        milkBurstEnabled: 0,
        flexibleEnabled: 0,
        reserved1: 0,
        reserved2: 0,
      },
    ]);
  };

  const deleteGoldStep = (index: number) => {
    setGoldSteps((prev) => prev.filter((_, idx) => idx !== index));
    showCenterToast("步骤已删除");
  };

  const updateGoldStep = (index: number, patch: Partial<GoldenRhythmStep>) => {
    setGoldSteps((prev) => prev.map((step, idx) => (idx === index ? { ...step, ...patch } : step)));
  };

  const saveGold = async () => {
    setLoading(true);
    try {
      await saveGoldenRhythmConfig(device.id, goldCustomModeId, goldSteps);
      showCenterToast("保存成功");
    } catch {
      showCenterToast("保存失败", undefined, 'error');
    } finally {
      setLoading(false);
    }
  };

  const saveSoft = async () => {
    setLoading(true);
    try {
      const normalized = {
        ...softConfig,
        transitionGear: clamp(softConfig.transitionGear, 1, 10),
      } satisfies SoftTransitionConfig;
      setSoftConfig(normalized);
      await saveSoftTransitionConfig(device.id, normalized);
      showCenterToast("保存成功");
    } catch {
      showCenterToast("保存失败", undefined, 'error');
    } finally {
      setLoading(false);
    }
  };

  const saveLine = async () => {
    setLoading(true);
    try {
      await saveSmartForceLineConfig(device.id, lineConfig);
      showCenterToast("保存成功");
    } catch {
      showCenterToast("保存失败", undefined, 'error');
    } finally {
      setLoading(false);
    }
  };

  const emptyGold = goldSteps.length === 0;

  // 智能力线联动计算逻辑
  const calculateLineParams = (config: SmartForceLineConfig) => {
    const { workMode, gearDisplay, frequencyPcm, holdTimeMs, buildTimeA = 180, releaseTimeC = 400 } = config;
    
    // 1. 周期计算公式
    const cycleT = Math.round((60 * 1000) / frequencyPcm);
    
    // 2. b+d总和计算公式
    const bdSum = cycleT - buildTimeA - releaseTimeC;
    
    // 3. 占空比 - 从查表获取电机占空比
    const dutyCycle = config.dutyCycle || 67;
    
    // 4. 比值计算公式 - 保留一位小数且和为10
    const ratioA = ((buildTimeA + holdTimeMs) / cycleT) * 10;
    const ratioB = 10 - ratioA;
    const ratio = `${ratioA.toFixed(1)}:${ratioB.toFixed(1)}`;
    
    return {
      cycleT,
      dutyCycle,
      ratio,
      restTimeD: bdSum - holdTimeMs
    };
  };

  // 从JSON配置中获取默认参数
  const getDefaultParams = (workMode: 0 | 1, gearDisplay: number) => {
    const key = `${workMode}_${gearDisplay}` as keyof typeof defaultProgramParamsConfig.cycle;
    const config = defaultProgramParamsConfig.cycle[key];
    
    if (!config) {
      return {
        maxPressureKpa: 25,
        frequencyPcm: 50,
        buildTimeA: 180,
        holdTimeMs: 300,
        releaseTimeC: 400,
        restTimeD: 40,
        dutyCycle: 67
      };
    }
    
    return {
      maxPressureKpa: config.pressure,
      frequencyPcm: config.freq,
      buildTimeA: config.a,
      holdTimeMs: config.b,
      releaseTimeC: config.c,
      restTimeD: config.d,
      dutyCycle: config.duty || 67
    };
  };

  // 计算频率的最大范围（基于当前模式+档位的JSON查表参数，b=0, d=0）
  const getFrequencyMax = (workMode: 0 | 1, gearDisplay: number) => {
    const defaultParams = getDefaultParams(workMode, gearDisplay);
    return Math.floor((60 * 1000) / (defaultParams.buildTimeA + defaultParams.releaseTimeC));
  };

  // 恢复默认参数
  const resetToDefault = () => {
    const defaultParams = getDefaultParams(lineConfig.workMode, lineConfig.gearDisplay);
    
    // 计算b+d的总和
    const cycleT = Math.round((60 * 1000) / defaultParams.frequencyPcm);
    const bdSum = cycleT - defaultParams.buildTimeA - defaultParams.releaseTimeC;
    
    // 保持时间使用JSON默认值，休息时间根据联动关系计算
    const calculated = calculateLineParams({
      ...lineConfig,
      ...defaultParams,
      holdTimeMs: defaultParams.holdTimeMs,
      restTimeD: bdSum - defaultParams.holdTimeMs
    });
    
    setLineConfig(prev => ({
      ...prev,
      ...defaultParams,
      holdTimeMs: defaultParams.holdTimeMs,
      restTimeD: bdSum - defaultParams.holdTimeMs,
      ...calculated
    }));
    
    showCenterToast("已恢复默认参数", `模式${lineConfig.workMode === 0 ? '刺激' : '吸乳'} 档位${lineConfig.gearDisplay}`);
  };

  // 参数校验
  const validateLineConfig = (config: SmartForceLineConfig): string | null => {
    const { maxPressureKpa, frequencyPcm, holdTimeMs, restTimeD, buildTimeA = 180, releaseTimeC = 400 } = config;
    
    if (maxPressureKpa < 10 || maxPressureKpa > 40) {
      return "负压压力超出范围(10-40kPa)";
    }
    if (frequencyPcm < 1 || frequencyPcm > getFrequencyMax(lineConfig.workMode, lineConfig.gearDisplay)) {
      return "频率超出范围";
    }
    
    // 计算b+d的最大和（动态范围）
    const cycleT = Math.round((60 * 1000) / frequencyPcm);
    const bdSum = cycleT - buildTimeA - releaseTimeC;
    
    if (holdTimeMs < 0 || holdTimeMs > bdSum) {
      return `保持时间超出范围(0-${bdSum}ms)`;
    }
    if (restTimeD < 0 || restTimeD > bdSum) {
      return `休息时间超出范围(0-${bdSum}ms)`;
    }
    
    return null;
  };

  // 更新配置并重新计算
  const updateLineConfig = (updates: Partial<SmartForceLineConfig>) => {
    setLineConfig(prev => {
      const newConfig = { ...prev, ...updates };
      const calculated = calculateLineParams(newConfig);
      return { ...newConfig, ...calculated };
    });
  };

  // b与d强制联动规则
  const updateHoldTime = (value: number) => {
    const { buildTimeA = 180, releaseTimeC = 400, frequencyPcm } = lineConfig;
    const cycleT = Math.round((60 * 1000) / frequencyPcm);
    const bdSum = cycleT - buildTimeA - releaseTimeC;
    
    // 修复边界错误：确保b+d的和等于bdSum
    const newHoldTime = Math.max(0, Math.min(value, bdSum));
    const newRestTime = bdSum - newHoldTime;
    
    // 调试信息：打印计算过程
    console.log('updateHoldTime:', { value, bdSum, newHoldTime, newRestTime });
    
    // 调试：检查更新后的实际值
    setTimeout(() => {
      console.log('After updateHoldTime - lineConfig:', {
        holdTimeMs: lineConfig.holdTimeMs,
        restTimeD: lineConfig.restTimeD
      });
    }, 100);
    
    updateLineConfig({
      holdTimeMs: newHoldTime,
      restTimeD: newRestTime
    });
  };

  const updateRestTime = (value: number) => {
    const { buildTimeA = 180, releaseTimeC = 400, frequencyPcm } = lineConfig;
    const cycleT = Math.round((60 * 1000) / frequencyPcm);
    const bdSum = cycleT - buildTimeA - releaseTimeC;
    
    // 修复边界错误：确保b+d的和等于bdSum
    const newRestTime = Math.max(0, Math.min(value, bdSum));
    const newHoldTime = bdSum - newRestTime;
    
    // 调试信息：打印计算过程
    console.log('updateRestTime:', { value, bdSum, newRestTime, newHoldTime });
    
    updateLineConfig({
      holdTimeMs: newHoldTime,
      restTimeD: newRestTime
    });
  };

  return (
    <Drawer open={open} onOpenChange={(next) => !next && onClose()}>
      <DrawerContent
        className="w-full max-w-md rounded-t-[20px] border-0 bg-white px-0 mx-auto"
        style={drawerHeight != null ? { height: `${drawerHeight}px`, maxHeight: `${drawerHeight}px` } : undefined}
      >
        {/* 居中弹窗提示 */}
        {centerToast.visible && (
          <div style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: 'rgba(0, 0, 0, 0.3)',
            zIndex: 9999,
          }}>
            <div style={{
              backgroundColor: '#ffffff',
              borderRadius: '12px',
              padding: '20px',
              minWidth: '280px',
              maxWidth: '320px',
              boxShadow: '0 4px 20px rgba(0, 0, 0, 0.2)',
              textAlign: 'center',
            }}>
              <div style={{
                width: '48px',
                height: '48px',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 12px',
                backgroundColor: centerToast.type === 'success' ? '#dcfce7' : centerToast.type === 'error' ? '#fee2e2' : '#fef3c7',
              }}>
                {centerToast.type === 'success' && <Check style={{ width: '24px', height: '24px', color: '#16a34a' }} />}
                {centerToast.type === 'error' && <AlertCircle style={{ width: '24px', height: '24px', color: '#dc2626' }} />}
                {centerToast.type === 'warning' && <AlertTriangle style={{ width: '24px', height: '24px', color: '#ca8a04' }} />}
              </div>
              <div style={{ fontSize: '18px', fontWeight: '600', color: '#1f2937' }}>{centerToast.title}</div>
              {centerToast.description && (
                <div style={{ fontSize: '14px', color: '#6b7280', marginTop: '8px' }}>{centerToast.description}</div>
              )}
            </div>
          </div>
        )}
        
        <div className="border-b border-[#eee] px-4 pb-4 pt-3">
          <div className="mb-3 flex items-start justify-between">
            <div>
              <div className="text-lg font-semibold text-foreground">设备参数调试</div>
              <div className="mt-1 text-[13px] text-muted-foreground">{deviceInfo}</div>
            </div>
            <button type="button" onClick={onClose} className="text-2xl text-muted-foreground">
              <X className="h-5 w-5" />
            </button>
          </div>

          <div className="grid grid-cols-3 rounded-none bg-[#f7f8fa]">
            {["黄金韵律", "柔性过渡", "智能力线"].map((label, index) => (
              <button
                key={label}
                type="button"
                onClick={() => setCurrentTab(index as DebugTab)}
                className={cn(
                  "border-b-2 px-1 py-3 text-[15px]",
                  currentTab === index ? "border-primary bg-primary/5 font-medium text-primary" : "border-transparent text-foreground"
                )}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-4 pb-6 pt-4">
          {currentTab === 0 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="text-[15px] font-medium text-foreground">步骤参数</div>
              </div>

              <div className="space-y-3">
                {emptyGold && (
                  <div className="rounded-xl bg-[#f9fafb] p-4 text-center text-sm text-muted-foreground">还没有步骤，点击下方 + 添加</div>
                )}
                {goldSteps.map((step, idx) => (
                  <div
                    key={idx}
                    draggable
                    onDragStart={(e) => {
                      setDragIdx(idx);
                      e.dataTransfer.effectAllowed = "move";
                      e.dataTransfer.dropEffect = "move";
                      e.dataTransfer.setData("text/plain", String(idx));
                    }}
                    onDragOver={(e) => {
                      e.preventDefault();
                      e.dataTransfer.dropEffect = "move";
                      setDragOverIdx(idx);
                    }}
                    onDrop={() => {
                      if (dragIdx == null || dragIdx === idx) return;
                      setGoldSteps((prev) => {
                        const next = [...prev];
                        const dragged = next[dragIdx];
                        next.splice(dragIdx, 1);
                        next.splice(idx, 0, dragged);
                        return next;
                      });
                      setDragIdx(null);
                      setDragOverIdx(null);
                      showCenterToast("步骤顺序已更新");
                    }}
                    onDragEnd={() => {
                      setDragIdx(null);
                      setDragOverIdx(null);
                    }}
                    className={cn(
                      "rounded-[10px] bg-[#f9fafb] p-3 transition-all",
                      dragIdx === idx && "opacity-60",
                      dragOverIdx === idx && dragIdx !== idx && "ring-2 ring-primary/40 ring-offset-2"
                    )}
                  >
                    <div className="mb-3 flex items-center justify-between">
                      <div className="flex items-center gap-2 text-sm font-medium text-foreground">
                        <GripVertical className="h-4 w-4 text-muted-foreground" />
                        <span>步骤 {idx + 1}</span>
                      </div>
                      <button type="button" onClick={() => deleteGoldStep(idx)} className="text-sm text-[#ff4d4f]">
                        删除
                      </button>
                    </div>

                    <div className="grid grid-cols-3 gap-2">
                      <div className="min-w-0">
                        <label className="mb-1 block text-[12px] text-foreground">模式</label>
                        <select
                          value={step.mode}
                          onChange={(e) => updateGoldStep(idx, { mode: Number(e.target.value) })}
                          className="h-9 w-full rounded-[8px] border border-[#ddd] px-2 text-[12px]"
                        >
                          {goldModeOptions.map((option) => (
                            <option key={option.value} value={option.value}>
                              {option.label}
                            </option>
                          ))}
                        </select>
                      </div>

                      <div className="min-w-0">
                        <label className="mb-1 block text-[12px] text-foreground">档位</label>
                        <Stepper compact value={step.gearDisplay} min={1} max={15} onChange={(next) => updateGoldStep(idx, { gearDisplay: next })} />
                      </div>

                      <div className="min-w-0">
                        <label className="mb-1 block text-[12px] text-foreground">时间(s)</label>
                        <Stepper compact value={step.durationSec} min={0} max={1800} onChange={(next) => updateGoldStep(idx, { durationSec: next })} />
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex justify-center">
                <button
                  type="button"
                  onClick={addGoldStep}
                  className="flex h-[50px] w-[50px] items-center justify-center rounded-full bg-primary text-primary-foreground shadow-[0_10px_24px_hsl(var(--mai-glow)/0.22)]"
                >
                  <Plus className="h-5 w-5" />
                </button>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <button type="button" onClick={() => void loadGold()} disabled={loading} className="h-12 rounded-xl border border-primary/20 bg-primary/10 text-[15px] font-semibold text-primary transition hover:bg-primary/15">
                  查询参数
                </button>
                <button
                  type="button"
                  onClick={() => void saveGold()}
                  disabled={loading}
                  className="h-12 rounded-xl bg-primary text-[15px] font-semibold text-primary-foreground shadow-[0_10px_24px_hsl(var(--mai-glow)/0.18)] transition hover:bg-primary/90"
                >
                  保存设置
                </button>
              </div>
            </div>
          )}

          {currentTab === 1 && (
            <div className="space-y-4">
              <div>
                <label className="mb-2 block text-[15px] text-foreground">柔性使能</label>
                <div className="flex gap-2.5">
                  {[
                    { label: "未使能", value: 0 },
                    { label: "使能", value: 1 },
                  ].map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => setSoftConfig((prev) => ({ ...prev, enabled: option.value as 0 | 1 }))}
                      className={cn(
                        "flex-1 rounded-[10px] border px-4 py-3 text-[15px]",
                        softConfig.enabled === option.value
                          ? "border-primary bg-primary text-primary-foreground"
                          : "border-border bg-card text-foreground hover:border-primary/25 hover:bg-primary/5"
                      )}
                    >
                      {option.label}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">柔性步进(kPa) 1~10</label>
                <Stepper value={softConfig.stepKpa} min={1} max={10} onChange={(next) => setSoftConfig((prev) => ({ ...prev, stepKpa: next }))} />
              </div>

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">柔性步数 1~10</label>
                <Stepper value={softConfig.stepCount} min={1} max={10} onChange={(next) => setSoftConfig((prev) => ({ ...prev, stepCount: next }))} />
              </div>

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">启动跨度 1~10</label>
                <Stepper value={softConfig.transitionGear} min={1} max={10} onChange={(next) => setSoftConfig((prev) => ({ ...prev, transitionGear: next }))} />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <button type="button" onClick={() => void loadSoft()} disabled={loading} className="h-12 rounded-xl border border-primary/20 bg-primary/10 text-[15px] font-semibold text-primary transition hover:bg-primary/15">
                  查询参数
                </button>
                <button
                  type="button"
                  onClick={() => void saveSoft()}
                  disabled={loading}
                  className="h-12 rounded-xl bg-primary text-[15px] font-semibold text-primary-foreground shadow-[0_10px_24px_hsl(var(--mai-glow)/0.18)] transition hover:bg-primary/90"
                >
                  保存设置
                </button>
              </div>
            </div>
          )}

          {currentTab === 2 && (
            <div className="space-y-2">
              {/* 第一行：模式选择 */}
              <div>
                <label className="mb-1 block text-[14px] text-foreground">模式选择</label>
                <div className="flex gap-2">
                  {[
                    { label: "刺激", value: 0 },
                    { label: "吸乳", value: 1 },
                  ].map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => {
                        // 修改模式时，相当于进行一次依据最新模式+档位的查表的恢复默认
                        const newMode = option.value as 0 | 1;
                        const defaultParams = getDefaultParams(newMode, lineConfig.gearDisplay);
                        const cycleT = Math.round((60 * 1000) / defaultParams.frequencyPcm);
                        const bdSum = cycleT - defaultParams.buildTimeA - defaultParams.releaseTimeC;
                        
                        // 相当于执行一次恢复默认操作，保持时间使用JSON默认值
                        updateLineConfig({ 
                          workMode: newMode,
                          maxPressureKpa: defaultParams.maxPressureKpa,
                          frequencyPcm: defaultParams.frequencyPcm,
                          buildTimeA: defaultParams.buildTimeA,
                          releaseTimeC: defaultParams.releaseTimeC,
                          dutyCycle: defaultParams.dutyCycle,
                          holdTimeMs: defaultParams.holdTimeMs, // 保持时间使用JSON默认值
                          restTimeD: bdSum - defaultParams.holdTimeMs // 休息时间根据联动关系计算
                        });
                      }}
                      className={cn(
                        "flex-1 rounded-[8px] border px-3 py-2 text-[14px]",
                        lineConfig.workMode === option.value
                          ? "border-primary bg-primary text-primary-foreground"
                          : "border-border bg-card text-foreground hover:border-primary/25 hover:bg-primary/5"
                      )}
                    >
                      {option.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* 第二行：左侧参数和右侧参数 */}
              <div className="grid grid-cols-2 gap-3">
                {/* 左侧：档位、压力、频率、占空比 */}
                <div className="space-y-2">
                  <div>
                     <label className="mb-1 block text-[14px] text-foreground">档位 (档)</label>
                     <div className="text-xs text-muted-foreground mb-1">1-15档</div>
                     <Stepper value={lineConfig.gearDisplay} min={1} max={15} onChange={(next) => {
                       // 修改档位时，相当于进行一次依据最新模式+档位的查表的恢复默认
                       const defaultParams = getDefaultParams(lineConfig.workMode, next);
                       const cycleT = Math.round((60 * 1000) / defaultParams.frequencyPcm);
                       const bdSum = cycleT - defaultParams.buildTimeA - defaultParams.releaseTimeC;
                       
                       // 相当于执行一次恢复默认操作，保持时间使用JSON默认值
                       updateLineConfig({ 
                         gearDisplay: next,
                         maxPressureKpa: defaultParams.maxPressureKpa,
                         frequencyPcm: defaultParams.frequencyPcm,
                         buildTimeA: defaultParams.buildTimeA,
                         releaseTimeC: defaultParams.releaseTimeC,
                         dutyCycle: defaultParams.dutyCycle,
                         holdTimeMs: defaultParams.holdTimeMs, // 保持时间使用JSON默认值
                         restTimeD: bdSum - defaultParams.holdTimeMs // 休息时间根据联动关系计算
                       });
                     }} />
                   </div>
                   
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">压力 (kPa)</label>
                     <div className="text-xs text-muted-foreground mb-1">{lineConfig.workMode === 0 ? '刺激模式:10-25' : '吸乳模式:18-36'}</div>
                     <input
                       type="number"
                       value={lineConfig.maxPressureKpa}
                       readOnly
                       className="h-11 w-full rounded-[8px] border border-border bg-muted px-3 text-[14px] text-muted-foreground"
                     />
                   </div>
                   
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">频率 (cpm)</label>
                     <div className="text-xs text-muted-foreground mb-1">1-{getFrequencyMax(lineConfig.workMode, lineConfig.gearDisplay)}</div>
                     <Stepper value={lineConfig.frequencyPcm} min={1} max={getFrequencyMax(lineConfig.workMode, lineConfig.gearDisplay)} onChange={(next) => {
                       // 当频率变化时，重新计算b+d总和，并将b设为0，d设为最大值
                       const cycleT = Math.round((60 * 1000) / next);
                       const bdSum = cycleT - (lineConfig.buildTimeA || 180) - (lineConfig.releaseTimeC || 400);
                       
                       updateLineConfig({ 
                         frequencyPcm: next,
                         holdTimeMs: 0, // b设为0
                         restTimeD: Math.max(0, bdSum) // d设为最大值
                       });
                     }} />
                   </div>
                   
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">占空比 (%)</label>
                     <div className="text-xs text-muted-foreground mb-1">0-100</div>
                     <input
                       type="text"
                       value={`${lineConfig.dutyCycle || 33}%`}
                       readOnly
                       className="h-11 w-full rounded-[8px] border border-border bg-muted px-3 text-[14px] text-muted-foreground"
                     />
                   </div>
                </div>

                {/* 右侧：a、b、c、d */}
                 <div className="space-y-2">
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">建压时间 a(ms)</label>
                     <div className="text-xs text-muted-foreground mb-1">{lineConfig.workMode === 0 ? '刺激模式:180-570' : '吸乳模式:400-1600'}</div>
                     <input
                       type="number"
                       value={lineConfig.buildTimeA || 180}
                       readOnly
                       className="h-11 w-full rounded-[8px] border border-border bg-muted px-3 text-[14px] text-muted-foreground"
                     />
                   </div>
                   
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">保持时间 b(ms)</label>
                     <div className="text-xs text-muted-foreground mb-1">0-{((lineConfig.cycleT || 667) - (lineConfig.buildTimeA || 180) - (lineConfig.releaseTimeC || 400))}</div>
                     <Stepper value={lineConfig.holdTimeMs} min={0} max={((lineConfig.cycleT || 667) - (lineConfig.buildTimeA || 180) - (lineConfig.releaseTimeC || 400))} onChange={updateHoldTime} />
                   </div>
                   
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">泄压时间 c(ms)</label>
                     <div className="text-xs text-muted-foreground mb-1">{lineConfig.workMode === 0 ? '刺激模式:400-500' : '吸乳模式:600-1000'}</div>
                     <input
                       type="number"
                       value={lineConfig.releaseTimeC || 400}
                       readOnly
                       className="h-11 w-full rounded-[8px] border border-border bg-muted px-3 text-[14px] text-muted-foreground"
                     />
                   </div>
                   
                   <div>
                     <label className="mb-1 block text-[14px] text-foreground">休息时间 d(ms)</label>
                     <div className="text-xs text-muted-foreground mb-1">0-{((lineConfig.cycleT || 667) - (lineConfig.buildTimeA || 180) - (lineConfig.releaseTimeC || 400))}</div>
                     <input
                       type="text"
                       value={lineConfig.restTimeD ?? 0}
                       readOnly
                       className="h-11 w-full rounded-[8px] border border-border bg-muted px-3 text-[14px] text-muted-foreground"
                     />
                   </div>
                 </div>
              </div>

              {/* 比值显示 */}
              <div className="text-center">
                <label className="block text-[14px] text-foreground">比值 (a+b):(c+d) {lineConfig.ratio || "2.2:4.4"}</label>
              </div>

              {/* 底部功能按钮 */}
              <div className="grid grid-cols-3 gap-2 pt-1">
                <button 
                  type="button" 
                  onClick={() => void loadLine()} 
                  disabled={loading} 
                  className="h-10 rounded-xl border border-primary/20 bg-primary/10 text-[13px] font-semibold text-primary transition hover:bg-primary/15"
                >
                  读取
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const error = validateLineConfig(lineConfig);
                    if (error) {
                      showCenterToast("参数校验失败", error, 'error');
                      return;
                    }
                    void saveLine();
                  }}
                  disabled={loading}
                  className="h-10 rounded-xl bg-primary text-[13px] font-semibold text-primary-foreground shadow-[0_6px_16px_hsl(var(--mai-glow)/0.15)] transition hover:bg-primary/90"
                >
                  配置
                </button>
                <button
                  type="button"
                  onClick={resetToDefault}
                  disabled={loading}
                  className="h-10 rounded-xl border border-border/50 bg-card/50 text-[13px] font-semibold text-foreground transition hover:bg-card"
                >
                  恢复默认
                </button>
              </div>
            </div>
          )}
        </div>
      </DrawerContent>
    </Drawer>
  );
};

export default DeviceDebugDrawer;
