import { afterEach, describe, expect, it } from "vitest";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { appendAgentHubAnalysisMessage } from "@/lib/agentHubChatMessages";
import { buildMilkAnalysisReminderFollowupPrompt, consumeMilkAnalysisReminderFollowup, queueMilkAnalysisReminderFollowup } from "@/lib/milkAnalysisReminderFollowup";
import { chatStore } from "@/lib/chatStore";

describe("appendAgentHubAnalysisMessage", () => {
  afterEach(() => {
    localStorage.clear();
    chatStore.setMessages([]);
  });

  it("appends a plain message when no analysis card is provided", () => {
    const id = appendAgentHubAnalysisMessage("嗨，我注意到你近期奶量偏低，可以和你聊聊吗？", {
      kind: "milk_analysis",
      id: "milk-reminder-1",
    });

    expect(id).toBe("milk-reminder-1");
    expect(chatStore.get().messages).toHaveLength(1);
    expect(chatStore.get().messages[0]).toMatchObject({
      id: "milk-reminder-1",
      role: "mai",
      content: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      chatStreamContext: "main",
    });
    expect(chatStore.get().messages[0].cardType).toBeUndefined();
    expect(chatStore.get().messages[0].cardData).toBeUndefined();
  });

  it("keeps report metadata when an analysis card is provided", () => {
    const analysisCard: AgentAnalysisCard = {
      kind: "daily_summary",
      title: "每日奶量总结",
      sections: [],
    };

    appendAgentHubAnalysisMessage("今日总结", {
      kind: "daily_summary",
      id: "daily-summary-1",
      analysisCard,
    });

    expect(chatStore.get().messages[0]).toMatchObject({
      id: "daily-summary-1",
      cardType: "report",
      cardData: {
        kind: "daily_summary",
        analysisCard,
      },
    });
    expect(chatStore.get().messages[0].chatStreamContext).toBeUndefined();
  });
});

describe("milk analysis reminder followup", () => {
  afterEach(() => {
    localStorage.clear();
  });

  it("queues one hidden followup trigger for a milk analysis reminder", () => {
    const analysisContext: AgentAnalysisCard = {
      kind: "milk_analysis",
      title: "奶量分析",
      status: "attention",
      status_label: "偏低但可追",
      sections: [
        {
          title: "数据统计",
          metrics: [{ label: "近7天总量", value: "3600 ml", detail: "低于参考" }],
        },
      ],
    };

    queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-1",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      analysisContext,
    });

    const pending = consumeMilkAnalysisReminderFollowup();
    expect(pending?.chatMessageId).toBe("analysis-milk_analysis-1");
    expect(pending?.analysisContext?.status_label).toBe("偏低但可追");

    const prompt = buildMilkAnalysisReminderFollowupPrompt(pending!);
    expect(prompt).toContain("后台奶量分析提醒后的自动接续");
    expect(prompt).toContain("近7天总量=3600 ml");
    expect(prompt).toContain("不要重复说");

    expect(consumeMilkAnalysisReminderFollowup()).toBeNull();
    expect(
      queueMilkAnalysisReminderFollowup({
        chatMessageId: "analysis-milk_analysis-1",
        message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      }),
    ).toBeNull();
  });
});
