export type MomStage = "prenatal" | "postpartum";

export type HubPillAction =
  | "maternityBag"
  | "birthPlan"
  | "unboxGuide"
  | "startPump"
  | "increaseMilkPlan"
  | "returnWorkPlan"
  | "recentPumpAnalysis";

export interface HubPillDefinition {
  action: HubPillAction;
  label: string;
  disabled?: boolean;
  active?: boolean;
}

export type HubPillClickIntent =
  | { type: "fillInput"; text: string }
  | { type: "triggerStartPump" };

interface GetHubPillDefinitionsInput {
  momStage: MomStage;
  startPumpBusy?: boolean;
  pumpSessionActive?: boolean;
}

export function normalizeMomStage(raw: string | undefined): MomStage {
  return raw?.trim().toLowerCase() === "prenatal" ? "prenatal" : "postpartum";
}

export function getHubPillDefinitions({
  momStage,
  startPumpBusy = false,
  pumpSessionActive = false,
}: GetHubPillDefinitionsInput): HubPillDefinition[] {
  if (momStage === "prenatal") {
    return [
      { action: "birthPlan", label: "生成分娩计划" },
      { action: "maternityBag", label: "生成待产包" },
    ];
  }

  return [
    { action: "unboxGuide", label: "开箱指导" },
    {
      action: "startPump",
      label: startPumpBusy ? "检查中…" : pumpSessionActive ? "吸奶中" : "开始吸奶",
      disabled: startPumpBusy,
      active: !startPumpBusy && pumpSessionActive,
    },
    { action: "increaseMilkPlan", label: "生成追奶计划" },
    { action: "returnWorkPlan", label: "生成返工计划" },
    { action: "recentPumpAnalysis", label: "分析最近吸奶情况" },
  ];
}

export function getHubPillClickIntent(action: HubPillAction): HubPillClickIntent {
  switch (action) {
    case "startPump":
      return { type: "triggerStartPump" };
    case "maternityBag":
      return { type: "fillInput", text: "帮我生成待产包清单" };
    case "birthPlan":
      return { type: "fillInput", text: "帮我生成分娩计划" };
    case "unboxGuide":
      return { type: "fillInput", text: "开箱指导" };
    case "increaseMilkPlan":
      return { type: "fillInput", text: "帮我生成追奶计划" };
    case "returnWorkPlan":
      return { type: "fillInput", text: "帮我生成返工计划" };
    case "recentPumpAnalysis":
      return { type: "fillInput", text: "分析最近吸奶情况" };
  }
}
