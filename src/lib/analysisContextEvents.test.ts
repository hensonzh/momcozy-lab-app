import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";

const mocks = vi.hoisted(() => ({
  apiRequestRaw: vi.fn(),
}));

vi.mock("@/lib/http", () => ({
  apiRequestRaw: mocks.apiRequestRaw,
}));

vi.mock("@/lib/agentConversationSession", () => ({
  getAgUiThreadIdForRequest: () => "thread-analysis-context",
}));

vi.mock("@/pages/agentHub/agentHubConstants", () => ({
  DEFAULT_CHAT_USER_ID: "demo-user",
}));

import {
  buildMilkAnalysisContextText,
  recordMilkAnalysisContextEvent,
} from "@/lib/analysisContextEvents";

describe("buildMilkAnalysisContextText", () => {
  beforeEach(() => {
    mocks.apiRequestRaw.mockReset();
  });

  it("keeps milk analysis process details with the preset result", () => {
    const card: AgentAnalysisCard & { headline?: string } = {
      kind: "milk_analysis",
      title: "奶量分析",
      subtitle: "2026-05-27 至 2026-06-02",
      status: "attention",
      status_label: "低于参考区间",
      headline: "最近整体偏低。建议先确认记录完整性。",
      sections: [
        {
          id: "milk",
          title: "数据统计",
          metrics: [
            { label: "实测吸奶", value: "510 ml/天", detail: "近 7 天共 3570 ml" },
            { label: "参考区间", value: "620-820 ml/天", detail: "同阶段常见范围" },
          ],
          items: ["连续 3 天低于参考下沿"],
        },
        {
          id: "daily_records",
          title: "近7天记录",
          items: [
            "6/15：估算510 ml，吸奶420 ml/5次，亲喂2次，参考620-820 ml/天，状态偏低",
          ],
        },
      ],
    };

    const text = buildMilkAnalysisContextText({
      message: "最近整体偏低。",
      analysisCard: card,
      chatMessageId: "analysis-milk_analysis-1",
    });

    expect(text).toContain("消息提醒提前生成");
    expect(text).toContain(
      "服务链：/v1/analysis/create(type=milk_analysis) -> evaluate_milk_status",
    );
    expect(text).toContain("等价分析口径：milk_analysis_evaluate");
    expect(text).toContain("window_days=7");
    expect(text).toContain("include_today=false");
    expect(text).toContain("不包含当天未完整记录");
    expect(text).toContain("低于参考区间");
    expect(text).toContain("实测吸奶=510 ml/天");
    expect(text).toContain("6/15：估算510 ml");
    expect(text).toContain("chat_message_id：analysis-milk_analysis-1");
    expect(text.length).toBeLessThanOrEqual(1200);
  });

  it("records the milk analysis context into the current user thread", async () => {
    const card: AgentAnalysisCard = {
      kind: "milk_analysis",
      title: "奶量分析",
      status: "attention",
      status_label: "奶量偏低",
      sections: [
        {
          title: "数据统计",
          metrics: [{ label: "近7天总量", value: "3600 ml" }],
        },
      ],
    };

    await recordMilkAnalysisContextEvent({
      message: "嗨，我注意到你近期奶量偏低，可以和你聊聊吗？",
      analysisCard: card,
      chatMessageId: "analysis-milk_analysis-2",
    });

    expect(mocks.apiRequestRaw).toHaveBeenCalledTimes(1);
    expect(mocks.apiRequestRaw).toHaveBeenCalledWith(
      "/api/client-event",
      expect.objectContaining({
        method: "POST",
        body: expect.objectContaining({
          thread_id: "thread-analysis-context",
          user_id: "demo-user",
          event_type: "milk_analysis_generated",
          label: "已生成奶量分析",
          metadata: expect.objectContaining({
            source: "device_reminder",
            reminder_type: "milk_analysis_reminder",
            analysis_type: "milk_analysis",
            equivalent_tool_name: "milk_analysis_evaluate",
            service_handler: "evaluate_milk_status",
            window_days: 7,
            include_today: false,
            chat_message_id: "analysis-milk_analysis-2",
            status_label: "奶量偏低",
          }),
        }),
      }),
    );
    const body = mocks.apiRequestRaw.mock.calls[0][1].body;
    expect(body.metadata.context_text).toContain("奶量偏低");
    expect(body.metadata.context_text).toContain("近7天总量=3600 ml");
  });
});
