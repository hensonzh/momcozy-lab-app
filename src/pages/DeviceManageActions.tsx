import React, { useMemo, useState } from "react";
import { ChevronLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";
import { toast } from "@/components/ui/sonner";
import {
  executeDeviceReminderAction,
  type DeviceReminderActionKey,
} from "@/lib/deviceReminderActions";

type ActionKey = DeviceReminderActionKey;

const actionItems: Array<{ key: ActionKey; label: string }> = [
  { key: "task_reminder", label: "任务提醒" },
  { key: "daily_summary", label: "每日奶量总结" },
  { key: "mom_baby", label: "每日泌乳建议" },
  { key: "growth_update", label: "宝宝生长发育指标更新" },
];

const DeviceManageActions: React.FC = () => {
  const navigate = useNavigate();
  const [loadingKey, setLoadingKey] = useState<ActionKey | null>(null);

  const actionHandlers = useMemo<Record<ActionKey, () => void | Promise<void>>>(
    () => ({
      task_reminder: () => executeDeviceReminderAction("task_reminder"),
      daily_summary: () => executeDeviceReminderAction("daily_summary"),
      mom_baby: () => executeDeviceReminderAction("mom_baby"),
      growth_update: () => executeDeviceReminderAction("growth_update"),
    }),
    [],
  );

  const handleActionClick = async (actionKey: ActionKey): Promise<void> => {
    setLoadingKey(actionKey);
    try {
      await actionHandlers[actionKey]();
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "请求失败，请稍后重试";
      toast(actionItems.find((item) => item.key === actionKey)?.label || "设备提醒", { description: message });
    } finally {
      setLoadingKey(null);
    }
  };

  return (
    <div className="flex flex-col min-h-0 bg-background w-full" style={{ height: "100vh", maxHeight: "100vh" }}>
      <TabPageTopReserve />
      <div className="flex-shrink-0 px-4 pt-5 pb-2 flex items-center gap-2">
        <button
          type="button"
          onClick={() => navigate("/device")}
          className="w-9 h-9 rounded-full border border-border/50 bg-card text-foreground flex items-center justify-center shadow-sm active:scale-95 transition-transform"
          aria-label="返回设备页"
        >
          <ChevronLeft className="w-4 h-4" />
        </button>
        <h1 className="text-lg font-bold text-foreground">设备提醒</h1>
      </div>

      <TabPageScrollRegion>
        <div className="px-4 pt-2 pb-6 space-y-3">
          {actionItems.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => void handleActionClick(item.key)}
              disabled={loadingKey === item.key}
              className="w-full rounded-2xl border border-border/60 bg-card px-4 py-4 text-left text-[16px] font-semibold text-foreground shadow-sm active:scale-[0.99] transition-transform disabled:opacity-60 disabled:pointer-events-none"
            >
              {loadingKey === item.key ? "处理中..." : item.label}
            </button>
          ))}
        </div>
      </TabPageScrollRegion>

      <TabPageEmbeddedNav />
    </div>
  );
};

export default DeviceManageActions;
