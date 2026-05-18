import React from "react";
import { cn } from "@/lib/utils";

interface PillGroupsProps {
  prenatalConsultActive?: boolean;
  deviceGuidanceActive?: boolean;
  milkManagementActive?: boolean;
  healthConsultActive?: boolean;
  /** 开始吸奶前置检查（滴定 / 设备等）进行中 */
  startPumpBusy?: boolean;
  /** 吸乳页会话进行中（running / paused），主界面 pill 显示「吸奶中」样式 */
  pumpSessionActive?: boolean;
  onStartPump: () => void;
  onPrenatalConsult: () => void;
  onDeviceGuidance: () => void;
  onMilkManagement: () => void;
  onHealthConsult: () => void;
}

const PillGroups: React.FC<PillGroupsProps> = ({
  prenatalConsultActive = false,
  deviceGuidanceActive = false,
  milkManagementActive = false,
  healthConsultActive = false,
  startPumpBusy = false,
  pumpSessionActive = false,
  onStartPump,
  onPrenatalConsult,
  onDeviceGuidance,
  onMilkManagement,
  onHealthConsult,
}) => {
  const pills: Array<{
    label: string;
    onClick: () => void;
    disabled?: boolean;
    /** 非 disabled 时覆盖默认主色 pill 样式 */
    activeClassName?: string;
  }> = [
    {
      label: "产前咨询",
      onClick: onPrenatalConsult,
      disabled: prenatalConsultActive,
    },
    {
      label: "设备指导",
      onClick: onDeviceGuidance,
      disabled: deviceGuidanceActive,
    },
    {
      label: startPumpBusy ? "检查中…" : pumpSessionActive ? "吸奶中" : "开始吸奶",
      onClick: onStartPump,
      disabled: startPumpBusy,
      /** 与 AgentHub 用户发送消息气泡一致：bg-primary text-primary-foreground */
      activeClassName:
        !startPumpBusy && pumpSessionActive
          ? "bg-primary text-primary-foreground shadow-sm hover:bg-primary/90 border border-transparent"
          : undefined,
    },
    {
      label: "奶量管理",
      onClick: onMilkManagement,
      disabled: milkManagementActive,
    },
    {
      label: "健康咨询",
      onClick: onHealthConsult,
      disabled: healthConsultActive,
    },
  ];

  return (
    <div className="flex-shrink-0 px-2 py-1.5">
      <div className="flex gap-1.5 overflow-x-auto scrollbar-hide items-center">
        {pills.map((pill, idx) => (
          <button
            key={`p-${idx}`}
            onClick={pill.onClick}
            disabled={pill.disabled}
            className={cn(
              "flex-shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition-colors",
              pill.disabled && "bg-muted text-muted-foreground cursor-not-allowed",
              !pill.disabled &&
                (pill.activeClassName ?? "bg-primary/15 text-primary hover:bg-primary/25 border border-primary/30"),
            )}
          >
            {pill.label}
          </button>
        ))}
      </div>
    </div>
  );
};

export default PillGroups;
