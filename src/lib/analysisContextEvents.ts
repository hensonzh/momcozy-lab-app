import type { AgentAnalysisCard, AgentAnalysisCardSection } from "@/lib/agentApiTypes";
import { getAgUiThreadIdForRequest } from "@/lib/agentConversationSession";
import { apiRequestRaw } from "@/lib/http";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

const ANALYSIS_CONTEXT_MAX_CHARS = 640;
const MILK_ANALYSIS_WINDOW_DAYS = 7;
const MILK_ANALYSIS_INCLUDE_TODAY = false;

function compactText(value: unknown): string {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function truncateContextText(value: string): string {
  const text = compactText(value);
  if (text.length <= ANALYSIS_CONTEXT_MAX_CHARS) return text;
  return `${text.slice(0, ANALYSIS_CONTEXT_MAX_CHARS - 1)}…`;
}

function metricText(section: AgentAnalysisCardSection): string {
  if (!Array.isArray(section.metrics)) return "";
  return section.metrics
    .map((metric) => {
      const label = compactText(metric.label);
      const value = compactText(metric.value);
      const detail = compactText(metric.detail);
      if (!label || !value) return "";
      return detail ? `${label}=${value}(${detail})` : `${label}=${value}`;
    })
    .filter(Boolean)
    .join("，");
}

function sectionText(section: AgentAnalysisCardSection): string {
  const title = compactText(section.title);
  const metrics = metricText(section);
  const items = Array.isArray(section.items) ? section.items.map(compactText).filter(Boolean).join("；") : "";
  const body = compactText(section.body);
  const content = [metrics, items || body].filter(Boolean).join("；");
  if (!content) return "";
  return title ? `${title}：${content}` : content;
}

function summarizeSections(sections: AgentAnalysisCard["sections"]): string {
  if (!Array.isArray(sections)) return "";
  return sections.map(sectionText).filter(Boolean).slice(0, 4).join("；");
}

function cardHeadline(card?: AgentAnalysisCard): string {
  return compactText((card as (AgentAnalysisCard & { headline?: unknown }) | undefined)?.headline);
}

export function buildMilkAnalysisContextText(params: {
  message: string;
  analysisCard?: AgentAnalysisCard;
  chatMessageId?: string;
}): string {
  const card = params.analysisCard;
  const status = compactText(card?.status_label || card?.status);
  const subtitle = compactText(card?.subtitle);
  const headline = cardHeadline(card) || compactText(params.message);
  const sectionSummary = summarizeSections(card?.sections);
  const chatMessageId = compactText(params.chatMessageId);

  return truncateContextText(
    [
      "已生成预置奶量分析",
      "性质：消息提醒提前生成，不是当前用户消息触发的实时工具调用",
      "服务链：/v1/analysis/create(type=milk_analysis) -> evaluate_milk_status；等价分析口径：milk_assessment_evaluate",
      `参数：window_days=${MILK_ANALYSIS_WINDOW_DAYS}, include_today=${String(MILK_ANALYSIS_INCLUDE_TODAY)}`,
      subtitle ? `窗口：${subtitle}` : "窗口：最近7个完整日",
      "口径：不包含当天未完整记录；使用服务端生成时已同步到当前日期的数据",
      status ? `状态：${status}` : "",
      headline ? `结论：${headline}` : "",
      sectionSummary ? `卡片摘要：${sectionSummary}` : "",
      chatMessageId ? `chat_message_id：${chatMessageId}` : "",
    ]
      .filter(Boolean)
      .join("；"),
  );
}

export async function recordMilkAnalysisContextEvent(params: {
  message: string;
  analysisCard?: AgentAnalysisCard;
  chatMessageId?: string;
}): Promise<void> {
  const threadId = getAgUiThreadIdForRequest().trim();
  if (!threadId) return;
  const contextText = buildMilkAnalysisContextText(params);
  if (!contextText) return;
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai";
  try {
    await apiRequestRaw("/api/client-event", {
      method: "POST",
      body: {
        thread_id: threadId,
        user_id: DEFAULT_CHAT_USER_ID,
        event_type: "milk_analysis_generated",
        label: "已生成奶量分析",
        occurred_at: new Date().toISOString(),
        locale: "zh-CN",
        timezone: timeZone,
        metadata: {
          user_id: DEFAULT_CHAT_USER_ID,
          source: "device_reminder",
          reminder_type: "milk_analysis_reminder",
          analysis_type: "milk_analysis",
          equivalent_tool_name: "milk_assessment_evaluate",
          service_handler: "evaluate_milk_status",
          window_days: MILK_ANALYSIS_WINDOW_DAYS,
          include_today: MILK_ANALYSIS_INCLUDE_TODAY,
          chat_message_id: params.chatMessageId || "",
          status: params.analysisCard?.status || "",
          status_label: params.analysisCard?.status_label || "",
          context_text: contextText,
        },
      },
    });
  } catch {
    // Context injection is best-effort; notification and report-card display are already complete.
  }
}
