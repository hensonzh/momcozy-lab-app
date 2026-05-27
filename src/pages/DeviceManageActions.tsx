import React, { useCallback, useMemo, useState } from "react";
import { ChevronLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";
import { toast } from "@/components/ui/sonner";
import { createDailyAndMomBabyAnalysis } from "@/lib/agentApi";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { getAgUiThreadIdForRequest } from "@/lib/agentConversationSession";
import { showNativeReminder } from "@/lib/mmcBackgroundNotify";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import { appendAgentHubAnalysisMessage } from "@/lib/agentHubChatMessages";
import { apiRequestRaw } from "@/lib/http";

type ActionKey = "task_reminder" | "daily_summary" | "mom_baby" | "growth_update";

const actionItems: Array<{ key: ActionKey; label: string }> = [
  { key: "task_reminder", label: "任务提醒" },
  { key: "daily_summary", label: "每日奶量总结" },
  { key: "mom_baby", label: "每日泌乳建议" },
  { key: "growth_update", label: "宝宝生长发育指标更新" },
];

const MOM_BABY_CONTEXT_MAX_CHARS = 320;
const TASK_REMINDER_MESSAGE = "妈妈，吸奶/喂养时间还有15分钟就到咯，可以提前准备一下哦～";

function compactText(value: unknown): string {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function truncateContextText(value: string): string {
  const text = compactText(value);
  if (text.length <= MOM_BABY_CONTEXT_MAX_CHARS) return text;
  return `${text.slice(0, MOM_BABY_CONTEXT_MAX_CHARS - 1)}…`;
}

function buildMomBabyAdviceContextText(message: string, analysisCard?: AgentAnalysisCard): string {
  const sections = Array.isArray(analysisCard?.sections) ? analysisCard.sections : [];
  const sectionText = sections
    .map((section) => {
      const title = compactText(section.title);
      const items = Array.isArray(section.items) ? section.items.map(compactText).filter(Boolean).join("；") : "";
      const body = compactText(section.body);
      const content = items || body;
      return title && content ? `${title}：${content}` : content || "";
    })
    .filter(Boolean)
    .join("；");
  const statusText = analysisCard?.status_label ? `状态：${compactText(analysisCard.status_label)}；` : "";
  const content = sectionText || compactText(message);
  return truncateContextText(`已生成每日泌乳建议：${statusText}${content}`);
}

async function recordMomBabyAdviceContextEvent(params: {
  message: string;
  analysisCard?: AgentAnalysisCard;
  chatMessageId: string;
}): Promise<void> {
  const threadId = getAgUiThreadIdForRequest().trim();
  if (!threadId) return;
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai";
  try {
    await apiRequestRaw("/api/client-event", {
      method: "POST",
      body: {
        thread_id: threadId,
        user_id: DEFAULT_CHAT_USER_ID,
        event_type: "mom_baby_advice_generated",
        label: "已生成每日泌乳建议",
        occurred_at: new Date().toISOString(),
        locale: "zh-CN",
        timezone: timeZone,
        metadata: {
          user_id: DEFAULT_CHAT_USER_ID,
          source: "device-manage-actions",
          chat_message_id: params.chatMessageId,
          status_label: params.analysisCard?.status_label || "",
          context_text: buildMomBabyAdviceContextText(params.message, params.analysisCard),
        },
      },
    });
  } catch {
    // Context injection is best-effort; the card itself has already been generated.
  }
}

const DeviceManageActions: React.FC = () => {
  const navigate = useNavigate();
  const [loadingKey, setLoadingKey] = useState<ActionKey | null>(null);

  const notifyByNativeOrToast = useCallback(
    async (options: {
      title: string;
      message: string;
      path?: string;
      notifyJson?: string;
    }) => {
      const body = options.message.trim();
      if (!body) return;
      try {
        await showNativeReminder({
          title: options.title,
          body,
          path: options.path ?? "/",
          notifyJson: options.notifyJson,
        });
      } catch {
        toast(options.title, { description: body });
      }
    },
    [],
  );

  const handleDailySummary = useCallback(async () => {
    setLoadingKey("daily_summary");
    try {
      const data = await createDailyAndMomBabyAnalysis({
        user_id: DEFAULT_CHAT_USER_ID,
        type: "daily_summary",
      });
      const message = data.message?.trim() || "已生成每日奶量总结。";
      const chatMessageId = `analysis-daily_summary-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      await notifyByNativeOrToast({
        title: "每日奶量总结",
        message,
        path: "/",
        notifyJson: JSON.stringify({ event: "summary", body: message, chatMessageId, analysis_card: data.analysis_card }),
      });
      appendAgentHubAnalysisMessage(message, { kind: "daily_summary", id: chatMessageId, analysisCard: data.analysis_card });
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "请求失败，请稍后重试";
      toast("每日奶量总结", { description: message });
    } finally {
      setLoadingKey(null);
    }
  }, [notifyByNativeOrToast]);

  const handleMomBabyAnalysis = useCallback(async () => {
    setLoadingKey("mom_baby");
    try {
      const data = await createDailyAndMomBabyAnalysis({
        user_id: DEFAULT_CHAT_USER_ID,
        type: "mom_baby",
      });
      const message = data.message?.trim() || "已生成每日泌乳建议。";
      const chatMessageId = `analysis-mom_baby-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      await notifyByNativeOrToast({
        title: "每日泌乳建议",
        message,
        path: "/",
        notifyJson: JSON.stringify({ event: "mom_baby", body: message, chatMessageId, analysis_card: data.analysis_card }),
      });
      appendAgentHubAnalysisMessage(message, { kind: "mom_baby", id: chatMessageId, analysisCard: data.analysis_card });
      void recordMomBabyAdviceContextEvent({
        message,
        analysisCard: data.analysis_card,
        chatMessageId,
      });
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "请求失败，请稍后重试";
      toast("每日泌乳建议", { description: message });
    } finally {
      setLoadingKey(null);
    }
  }, [notifyByNativeOrToast]);

  const handleGrowthUpdateNotify = useCallback(() => {
    const description = "建议更新一下宝宝生长数据哦～这样能更好地帮你进行奶量管理";
    void notifyByNativeOrToast({
      title: "生长发育更新提醒",
      message: description,
      path: "/status?mmcNotify=growth",
      notifyJson: JSON.stringify({ event: "grown" }),
    });
  }, [notifyByNativeOrToast]);

  const handleTaskReminderNotify = useCallback(() => {
    void notifyByNativeOrToast({
      title: "任务提醒",
      message: TASK_REMINDER_MESSAGE,
      path: "/schedule?mmcNotify=1",
    });
  }, [notifyByNativeOrToast]);

  const actionHandlers = useMemo<Record<ActionKey, () => void | Promise<void>>>(
    () => ({
      task_reminder: handleTaskReminderNotify,
      daily_summary: handleDailySummary,
      mom_baby: handleMomBabyAnalysis,
      growth_update: handleGrowthUpdateNotify,
    }),
    [handleTaskReminderNotify, handleDailySummary, handleMomBabyAnalysis, handleGrowthUpdateNotify],
  );

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
              onClick={() => void actionHandlers[item.key]()}
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
