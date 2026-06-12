import { afterEach, describe, expect, it } from "vitest";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { appendAgentHubAnalysisMessage, appendAgentHubNotificationMessage } from "@/lib/agentHubChatMessages";
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

  it("renders health issue notifications as main assistant text bubbles", () => {
    const id = appendAgentHubNotificationMessage("嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗", {
      kind: "health_issue",
      id: "notification-health_issue-1",
    });

    expect(id).toBe("notification-health_issue-1");
    expect(chatStore.get().messages[0]).toMatchObject({
      id: "notification-health_issue-1",
      role: "mai",
      content: "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗",
      chatStreamContext: "main",
    });
    expect(chatStore.get().messages[0].cardType).toBeUndefined();
    expect(chatStore.get().messages[0].cardData).toBeUndefined();
  });
});
