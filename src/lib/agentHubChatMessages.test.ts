import { afterEach, describe, expect, it, vi } from "vitest";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import {
  appendAgentHubAnalysisMessage,
  appendAgentHubNotificationMessage,
} from "@/lib/agentHubChatMessages";
import { buildPersonalizedNotificationText } from "@/lib/agentNotificationMessages";
import { AGENT_NOTIFICATION_VOICE_EVENT } from "@/lib/agentNotificationVoice";
import {
  buildMilkAnalysisReminderFollowupPrompt,
  completeMilkAnalysisReminderFollowup,
  consumeMilkAnalysisReminderFollowup,
  markMilkAnalysisReminderFollowupAttempt,
  peekMilkAnalysisReminderFollowup,
  queueMilkAnalysisReminderFollowup,
} from "@/lib/milkAnalysisReminderFollowup";
import { chatStore } from "@/lib/chatStore";

describe("appendAgentHubAnalysisMessage", () => {
  afterEach(() => {
    localStorage.clear();
    chatStore.setMessages([]);
  });

  it("appends a plain message when no analysis card is provided", () => {
    const id = appendAgentHubAnalysisMessage(
      "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      {
        kind: "milk_analysis",
        id: "milk-reminder-1",
        notification: true,
      },
    );

    expect(id).toBe("milk-reminder-1");
    expect(chatStore.get().messages).toHaveLength(1);
    expect(chatStore.get().messages[0]).toMatchObject({
      id: "milk-reminder-1",
      role: "mai",
      content: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      chatStreamContext: "main",
      messageTone: "notification",
      notificationKind: "milk_analysis",
      autoVoiceOnAppend: true,
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
    const id = appendAgentHubNotificationMessage(
      "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗",
      {
        kind: "health_issue",
        id: "notification-health_issue-1",
      },
    );

    expect(id).toBe("notification-health_issue-1");
    expect(chatStore.get().messages[0]).toMatchObject({
      id: "notification-health_issue-1",
      role: "mai",
      content: "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗",
      chatStreamContext: "main",
      messageTone: "notification",
      notificationKind: "health_issue",
      autoVoiceOnAppend: true,
    });
    expect(chatStore.get().messages[0].cardType).toBeUndefined();
    expect(chatStore.get().messages[0].cardData).toBeUndefined();
  });

  it("dispatches a global voice event when appending notification messages", () => {
    let eventDetailId = "";
    const handler = (event: Event) => {
      eventDetailId = (event as CustomEvent<{ id?: string }>).detail?.id || "";
    };
    window.addEventListener(AGENT_NOTIFICATION_VOICE_EVENT, handler);

    try {
      appendAgentHubNotificationMessage(
        "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗",
        {
          kind: "health_issue",
          id: "notification-health_issue-voice",
        },
      );
    } finally {
      window.removeEventListener(AGENT_NOTIFICATION_VOICE_EVENT, handler);
    }

    expect(eventDetailId).toBe("notification-health_issue-voice");
  });
});

describe("buildPersonalizedNotificationText", () => {
  it("inserts the display name after leading hi", () => {
    expect(
      buildPersonalizedNotificationText(
        "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗",
        "小雨",
      ),
    ).toBe("嗨，小雨，我发现你的乳汁电导率有点异常，可以和你聊聊吗");
  });

  it("keeps messages unchanged without a leading hi or name", () => {
    expect(
      buildPersonalizedNotificationText(
        "我发现你的乳汁电导率有点异常，可以和你聊聊吗",
        "小雨",
      ),
    ).toBe("我发现你的乳汁电导率有点异常，可以和你聊聊吗");
    expect(
      buildPersonalizedNotificationText(
        "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗",
        "",
      ),
    ).toBe("嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗");
  });
});

describe("milk analysis reminder followup", () => {
  afterEach(() => {
    vi.useRealTimers();
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
          metrics: [
            { label: "近7天总量", value: "3600 ml", detail: "低于参考" },
          ],
        },
      ],
    };

    queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-1",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      analysisContext,
    });

    const pending = consumeMilkAnalysisReminderFollowup();
    expect(pending?.taskId).toContain("analysis-milk_analysis-1");
    expect(pending?.chatMessageId).toBe("analysis-milk_analysis-1");
    expect(pending?.analysisContext?.status_label).toBe("偏低但可追");

    const prompt = buildMilkAnalysisReminderFollowupPrompt(pending!);
    expect(prompt).toContain("后台奶量分析提醒后的自动接续");
    expect(prompt).toContain("近7天总量=3600 ml");
    expect(prompt).toContain("不要重复说");

    expect(consumeMilkAnalysisReminderFollowup()).toBeNull();
    const next = queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-1",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
    });
    expect(next?.chatMessageId).toBe("analysis-milk_analysis-1");
    expect(next?.taskId).not.toBe(pending?.taskId);
  });

  it("keeps pending followup until the hidden agent run finishes", () => {
    queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-retry",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
    });

    expect(peekMilkAnalysisReminderFollowup()?.chatMessageId).toBe(
      "analysis-milk_analysis-retry",
    );

    const taskId = peekMilkAnalysisReminderFollowup()?.taskId || "";
    const attempt = markMilkAnalysisReminderFollowupAttempt(taskId);
    expect(attempt?.attempts).toBe(1);
    expect(attempt?.status).toBe("running");
    expect(peekMilkAnalysisReminderFollowup()).toBeNull();

    completeMilkAnalysisReminderFollowup(taskId);
    expect(consumeMilkAnalysisReminderFollowup()).toBeNull();
    const next = queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-retry",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
    });
    expect(next?.chatMessageId).toBe("analysis-milk_analysis-retry");
    expect(next?.taskId).not.toBe(taskId);
  });

  it("does not duplicate an identical pending hidden followup", () => {
    const first = queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-pending",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
    });
    const second = queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-pending",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
    });

    expect(second?.chatMessageId).toBe(first?.chatMessageId);
    expect(second?.taskId).toBe(first?.taskId);
    expect(second?.message).toBe(first?.message);
    expect(second?.createdAt).toBe(first?.createdAt);
  });

  it("recovers a stale running hidden followup task", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-15T00:00:00.000Z"));

    const queued = queueMilkAnalysisReminderFollowup({
      chatMessageId: "analysis-milk_analysis-stale",
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
    });
    const attempt = markMilkAnalysisReminderFollowupAttempt(
      queued?.taskId || "",
    );

    expect(attempt?.status).toBe("running");
    expect(peekMilkAnalysisReminderFollowup()).toBeNull();

    vi.setSystemTime(new Date("2026-06-15T00:03:00.000Z"));

    expect(peekMilkAnalysisReminderFollowup()?.taskId).toBe(queued?.taskId);
  });
});
