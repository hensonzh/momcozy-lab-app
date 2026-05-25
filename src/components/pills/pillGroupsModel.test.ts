import { describe, expect, it } from "vitest";
import { getHubPillClickIntent, getHubPillDefinitions, normalizeMomStage } from "./pillGroupsModel";

describe("pillGroupsModel", () => {
  it("normalizes mom stage from env values", () => {
    expect(normalizeMomStage("prenatal")).toBe("prenatal");
    expect(normalizeMomStage("postpartum")).toBe("postpartum");
    expect(normalizeMomStage(" POSTPARTUM ")).toBe("postpartum");
    expect(normalizeMomStage("unknown")).toBe("postpartum");
    expect(normalizeMomStage(undefined)).toBe("postpartum");
  });

  it("shows prenatal pills for prenatal users", () => {
    expect(getHubPillDefinitions({ momStage: "prenatal" }).map((pill) => pill.label)).toEqual([
      "生成分娩沟通",
      "生成待产包",
    ]);
  });

  it("hides the return work plan pill for postpartum users", () => {
    expect(getHubPillDefinitions({ momStage: "postpartum" }).map((pill) => pill.action)).toEqual([
      "unboxGuide",
      "startPump",
      "increaseMilkPlan",
      "recentPumpAnalysis",
    ]);
  });

  it("keeps pump pill state labels for postpartum users", () => {
    expect(getHubPillDefinitions({ momStage: "postpartum", startPumpBusy: true })[1]).toMatchObject({
      action: "startPump",
      label: "检查中…",
      disabled: true,
    });
    expect(getHubPillDefinitions({ momStage: "postpartum", pumpSessionActive: true })[1]).toMatchObject({
      action: "startPump",
      label: "吸奶中",
      disabled: false,
      active: true,
    });
  });

  it("only start pump triggers a direct event and other pills fill the input", () => {
    expect(getHubPillClickIntent("startPump")).toEqual({ type: "triggerStartPump" });

    expect(getHubPillClickIntent("unboxGuide")).toEqual({ type: "fillInput", text: "开箱指导" });
    expect(getHubPillClickIntent("maternityBag")).toEqual({ type: "fillInput", text: "帮我生成待产包清单" });
    expect(getHubPillClickIntent("birthPlan")).toEqual({ type: "fillInput", text: "帮我生成分娩沟通" });
    expect(getHubPillClickIntent("increaseMilkPlan")).toEqual({ type: "fillInput", text: "帮我生成追奶计划" });
    expect(getHubPillClickIntent("returnWorkPlan")).toEqual({ type: "fillInput", text: "帮我生成返工计划" });
    expect(getHubPillClickIntent("recentPumpAnalysis")).toEqual({ type: "fillInput", text: "分析最近吸奶情况" });
  });
});
