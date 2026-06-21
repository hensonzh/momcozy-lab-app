import { describe, expect, it } from "vitest";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { buildMilkAnalysisContextText } from "@/lib/analysisContextEvents";

describe("buildMilkAnalysisContextText", () => {
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
      ],
    };

    const text = buildMilkAnalysisContextText({
      message: "最近整体偏低。",
      analysisCard: card,
      chatMessageId: "analysis-milk_analysis-1",
    });

    expect(text).toContain("消息提醒提前生成");
    expect(text).toContain("服务链：/v1/analysis/create(type=milk_analysis) -> evaluate_milk_status");
    expect(text).toContain("等价分析口径：milk_analysis_evaluate");
    expect(text).toContain("window_days=7");
    expect(text).toContain("include_today=false");
    expect(text).toContain("不包含当天未完整记录");
    expect(text).toContain("低于参考区间");
    expect(text).toContain("实测吸奶=510 ml/天");
    expect(text).toContain("chat_message_id：analysis-milk_analysis-1");
    expect(text.length).toBeLessThanOrEqual(640);
  });
});
