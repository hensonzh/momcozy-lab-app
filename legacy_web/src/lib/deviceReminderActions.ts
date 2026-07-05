import { toast } from "@/components/ui/sonner";
import { recordMilkAnalysisContextEvent } from "@/lib/analysisContextEvents";
import { createDailyAndMomBabyAnalysis } from "@/lib/agentApi";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { getAgUiThreadIdForRequest } from "@/lib/agentConversationSession";
import {
  appendAgentHubAnalysisMessage,
  appendAgentHubNotificationMessage,
} from "@/lib/agentHubChatMessages";
import { personalizeNotificationText } from "@/lib/agentNotificationMessages";
import { apiRequestRaw } from "@/lib/http";
import { showNativeReminder } from "@/lib/mmcBackgroundNotify";
import { queueMilkAnalysisReminderFollowup } from "@/lib/milkAnalysisReminderFollowup";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

export type DeviceReminderActionKey =
  | "task_reminder"
  | "daily_summary"
  | "mom_baby"
  | "milk_analysis"
  | "growth_update"
  | "health_issue";

const MOM_BABY_CONTEXT_MAX_CHARS = 320;
const TASK_REMINDER_MESSAGE =
  "妈妈，吸奶/喂养时间还有15分钟就到咯，可以提前准备一下哦～";
export const HEALTH_ISSUE_NOTIFICATION_MESSAGE =
  "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗";

function compactText(value: unknown): string {
  return String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
}

function truncateContextText(value: string): string {
  const text = compactText(value);
  if (text.length <= MOM_BABY_CONTEXT_MAX_CHARS) return text;
  return `${text.slice(0, MOM_BABY_CONTEXT_MAX_CHARS - 1)}…`;
}

function buildMomBabyAdviceContextText(
  message: string,
  analysisCard?: AgentAnalysisCard,
): string {
  const sections = Array.isArray(analysisCard?.sections)
    ? analysisCard.sections
    : [];
  const sectionText = sections
    .map((section) => {
      const title = compactText(section.title);
      const items = Array.isArray(section.items)
        ? section.items.map(compactText).filter(Boolean).join("；")
        : "";
      const body = compactText(section.body);
      const content = items || body;
      return title && content ? `${title}：${content}` : content || "";
    })
    .filter(Boolean)
    .join("；");
  const statusText = analysisCard?.status_label
    ? `状态：${compactText(analysisCard.status_label)}；`
    : "";
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
  const timeZone =
    Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai";
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
          context_text: buildMomBabyAdviceContextText(
            params.message,
            params.analysisCard,
          ),
        },
      },
    });
  } catch {
    // Context injection is best-effort; the card itself has already been generated.
  }
}

async function notifyByNativeOrToast(options: {
  title: string;
  message: string;
  path?: string;
  notifyJson?: string;
}): Promise<void> {
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
}

async function handleDailySummary(): Promise<void> {
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
    notifyJson: JSON.stringify({
      event: "summary",
      body: message,
      chatMessageId,
      analysis_card: data.analysis_card,
    }),
  });
  appendAgentHubAnalysisMessage(message, {
    kind: "daily_summary",
    id: chatMessageId,
    analysisCard: data.analysis_card,
  });
}

async function handleMomBabyAnalysis(): Promise<void> {
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
    notifyJson: JSON.stringify({
      event: "mom_baby",
      body: message,
      chatMessageId,
      analysis_card: data.analysis_card,
    }),
  });
  appendAgentHubAnalysisMessage(message, {
    kind: "mom_baby",
    id: chatMessageId,
    analysisCard: data.analysis_card,
  });
  void recordMomBabyAdviceContextEvent({
    message,
    analysisCard: data.analysis_card,
    chatMessageId,
  });
}

async function handleMilkAnalysis(): Promise<void> {
  const data = await createDailyAndMomBabyAnalysis({
    user_id: DEFAULT_CHAT_USER_ID,
    type: "milk_analysis",
  });
  const analysisContext = data.analysis_context ?? data.analysis_card;
  const message = await personalizeNotificationText(
    data.message?.trim() || "已生成奶量分析。",
  );
  const chatMessageId = `analysis-milk_analysis-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  await notifyByNativeOrToast({
    title: "奶量分析",
    message,
    path: "/",
    notifyJson: JSON.stringify({
      event: "milk_analysis",
      body: message,
      chatMessageId,
      analysis_card: data.analysis_card,
      analysis_context: data.analysis_context,
    }),
  });
  appendAgentHubAnalysisMessage(message, {
    kind: "milk_analysis",
    id: chatMessageId,
    analysisCard: data.analysis_card,
    notification: true,
  });
  void recordMilkAnalysisContextEvent({
    message,
    analysisCard: analysisContext,
    chatMessageId,
  });
  queueMilkAnalysisReminderFollowup({
    chatMessageId,
    message,
    analysisContext,
  });
}

function handleGrowthUpdateNotify(): void {
  void notifyByNativeOrToast({
    title: "生长发育更新提醒",
    message: "建议更新一下宝宝生长数据哦～这样能更好地帮你进行奶量管理",
    path: "/status?mmcNotify=growth",
    notifyJson: JSON.stringify({ event: "grown" }),
  });
}

function handleTaskReminderNotify(): void {
  void notifyByNativeOrToast({
    title: "任务提醒",
    message: TASK_REMINDER_MESSAGE,
    path: "/schedule?mmcNotify=1",
  });
}

async function handleHealthIssueNotify(): Promise<void> {
  const chatMessageId = `notification-health_issue-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const message = await personalizeNotificationText(
    HEALTH_ISSUE_NOTIFICATION_MESSAGE,
  );
  await notifyByNativeOrToast({
    title: "健康问题通知",
    message,
    path: "/",
    notifyJson: JSON.stringify({
      event: "health_issue",
      body: message,
      chatMessageId,
    }),
  });
  appendAgentHubNotificationMessage(message, {
    kind: "health_issue",
    id: chatMessageId,
  });
}

export function getDeviceReminderActionTitle(
  actionKey: DeviceReminderActionKey,
): string {
  switch (actionKey) {
    case "task_reminder":
      return "任务提醒";
    case "daily_summary":
      return "每日奶量总结";
    case "mom_baby":
      return "每日泌乳建议";
    case "milk_analysis":
      return "奶量分析";
    case "growth_update":
      return "宝宝生长发育指标更新";
    case "health_issue":
      return "健康问题通知";
  }
}

export async function executeDeviceReminderAction(
  actionKey: DeviceReminderActionKey,
): Promise<void> {
  switch (actionKey) {
    case "task_reminder":
      handleTaskReminderNotify();
      return;
    case "daily_summary":
      await handleDailySummary();
      return;
    case "mom_baby":
      await handleMomBabyAnalysis();
      return;
    case "milk_analysis":
      await handleMilkAnalysis();
      return;
    case "growth_update":
      handleGrowthUpdateNotify();
      return;
    case "health_issue":
      await handleHealthIssueNotify();
      return;
  }
}
