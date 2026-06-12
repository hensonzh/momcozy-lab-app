import React from "react";
import { cn } from "@/lib/utils";
import {
  getHubPillClickIntent,
  getHubPillDefinitions,
  normalizeMomStage,
  type HubPillAction,
  type MomStage,
} from "./pillGroupsModel";
import { getRuntimeMomStage } from "@/lib/debugUserConfig";

interface PillGroupsProps {
  momStage?: MomStage;
  /** 开始吸奶前置检查（滴定 / 设备等）进行中 */
  startPumpBusy?: boolean;
  /** 吸乳页会话进行中（running / paused），主界面 pill 显示「吸奶中」样式 */
  pumpSessionActive?: boolean;
  onFillInput: (text: string) => void;
  onStartPump: () => void;
}

const PillGroups: React.FC<PillGroupsProps> = ({
  momStage = normalizeMomStage(getRuntimeMomStage(import.meta.env.VITE_MOM_STAGE as string | undefined)),
  startPumpBusy = false,
  pumpSessionActive = false,
  onFillInput,
  onStartPump,
}) => {
  const handlePillClick = (action: HubPillAction) => {
    const intent = getHubPillClickIntent(action);
    if (intent.type === "triggerStartPump") {
      onStartPump();
      return;
    }
    onFillInput(intent.text);
  };

  const pills = getHubPillDefinitions({ momStage, startPumpBusy, pumpSessionActive });

  return (
    <div className="flex-shrink-0 px-2 py-1.5">
      <div className="flex gap-1.5 overflow-x-auto scrollbar-hide items-center">
        {pills.map((pill, idx) => (
          <button
            key={`p-${idx}`}
            onClick={() => handlePillClick(pill.action)}
            disabled={pill.disabled}
            className={cn(
              "flex-shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition-colors",
              pill.disabled && "bg-muted text-muted-foreground cursor-not-allowed",
              !pill.disabled &&
                (pill.active
                  ? "bg-primary text-primary-foreground shadow-sm hover:bg-primary/90 border border-transparent"
                  : "border border-[#d9bdc7] bg-background text-[#a76778] hover:bg-[#fff7fa] hover:border-[#cfa8b5]"),
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
