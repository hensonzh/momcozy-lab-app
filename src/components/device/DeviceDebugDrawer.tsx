import React, { useEffect, useMemo, useState } from "react";
import { GripVertical, Plus, X } from "lucide-react";
import { Drawer, DrawerContent } from "@/components/ui/drawer";
import { toast } from "@/hooks/use-toast";
import {
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

  return (
    <div className={cn("flex items-center overflow-hidden rounded-lg border border-[#ddd] bg-white", compact && "rounded-[8px]")}>
      <button
        type="button"
        className={cn("text-foreground", compact ? "h-8 w-7 text-sm" : "h-11 w-11 text-lg")}
        onClick={() => {
          const next = clamp(value - 1, min, max);
          onChange(next);
          setDraft(String(next));
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
          const next = clamp(value + 1, min, max);
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
  const [lineConfig, setLineConfig] = useState<SmartForceLineConfig>({
    workMode: 0,
    gearDisplay: 1,
    maxPressureKpa: 25,
    frequencyPcm: 50,
    holdTimeMs: 300,
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
      toast({ title: "查询成功" });
    } catch {
      toast({ title: "查询失败", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const loadSoft = async () => {
    setLoading(true);
    try {
      const result = await querySoftTransitionConfig(device.id);
      setSoftConfig(result);
      toast({ title: "查询成功" });
    } catch {
      toast({ title: "查询失败", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const loadLine = async () => {
    setLoading(true);
    try {
      const result = await querySmartForceLineConfig(device.id, lineConfig.workMode, lineConfig.gearDisplay);
      setLineConfig(result);
      toast({ title: "查询成功" });
    } catch {
      toast({ title: "查询失败", variant: "destructive" });
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
  }, [open, currentTab]);

  const addGoldStep = () => {
    if (goldSteps.length >= 10) {
      toast({ title: "最多 10 个步骤", variant: "destructive" });
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
    toast({ title: "步骤已删除" });
  };

  const updateGoldStep = (index: number, patch: Partial<GoldenRhythmStep>) => {
    setGoldSteps((prev) => prev.map((step, idx) => (idx === index ? { ...step, ...patch } : step)));
  };

  const saveGold = async () => {
    setLoading(true);
    try {
      await saveGoldenRhythmConfig(device.id, goldCustomModeId, goldSteps);
      toast({ title: "保存成功" });
    } catch {
      toast({ title: "保存失败", variant: "destructive" });
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
      toast({ title: "保存成功" });
    } catch {
      toast({ title: "保存失败", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const saveLine = async () => {
    setLoading(true);
    try {
      await saveSmartForceLineConfig(device.id, lineConfig);
      toast({ title: "保存成功" });
    } catch {
      toast({ title: "保存失败", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const emptyGold = goldSteps.length === 0;

  return (
    <Drawer open={open} onOpenChange={(next) => !next && onClose()}>
      <DrawerContent
        className="w-full max-w-md rounded-t-[20px] border-0 bg-white px-0 mx-auto"
        style={drawerHeight != null ? { height: `${drawerHeight}px`, maxHeight: `${drawerHeight}px` } : undefined}
      >
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
                      toast({ title: "步骤顺序已更新" });
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
            <div className="space-y-4">
              <div>
                <label className="mb-2 block text-[15px] text-foreground">工作模式</label>
                <div className="flex gap-2.5">
                  {[
                    { label: "刺激", value: 0 },
                    { label: "吸乳", value: 1 },
                  ].map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => setLineConfig((prev) => ({ ...prev, workMode: option.value as 0 | 1 }))}
                      className={cn(
                        "flex-1 rounded-[10px] border px-4 py-3 text-[15px]",
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

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">档位 1~15</label>
                <Stepper value={lineConfig.gearDisplay} min={1} max={15} onChange={(next) => setLineConfig((prev) => ({ ...prev, gearDisplay: next }))} />
              </div>

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">最大负压(kPa) 10~40</label>
                <Stepper value={lineConfig.maxPressureKpa} min={10} max={40} onChange={(next) => setLineConfig((prev) => ({ ...prev, maxPressureKpa: next }))} />
              </div>

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">吸放频率(pcm) 20~90</label>
                <Stepper value={lineConfig.frequencyPcm} min={20} max={90} onChange={(next) => setLineConfig((prev) => ({ ...prev, frequencyPcm: next }))} />
              </div>

              <div>
                <label className="mb-1.5 block text-[15px] text-foreground">吸力保持时间(ms) 0~1000</label>
                <Stepper value={lineConfig.holdTimeMs} min={0} max={1000} onChange={(next) => setLineConfig((prev) => ({ ...prev, holdTimeMs: next }))} />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <button type="button" onClick={() => void loadLine()} disabled={loading} className="h-12 rounded-xl border border-primary/20 bg-primary/10 text-[15px] font-semibold text-primary transition hover:bg-primary/15">
                  查询参数
                </button>
                <button
                  type="button"
                  onClick={() => void saveLine()}
                  disabled={loading}
                  className="h-12 rounded-xl bg-primary text-[15px] font-semibold text-primary-foreground shadow-[0_10px_24px_hsl(var(--mai-glow)/0.18)] transition hover:bg-primary/90"
                >
                  保存设置
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
