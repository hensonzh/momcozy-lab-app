import type { AgUiToolCallRow } from "@/types/chat";

export type WorkProgressTone = "running" | "waiting" | "done" | "error";
export type WorkProgressSummary = { title: string; tone: WorkProgressTone };

const COMPLETED_TOOL_SUMMARY_TITLES: Record<string, string> = {
  birth_plan_form_create: "我已经准备好确认内容啦",
  hospital_bag_form_create: "我已经准备好确认内容啦",
  ui_form_create: "我已经准备好确认内容啦",
  labor_communication_card_create: "我已经帮你整理好分娩沟通单啦",
  birth_journey_plan_card_create: "我已经帮你整理好孕期计划啦",
  birth_journey_plan_delete: "我已经删除孕期计划啦",
  birth_journey_plan_todo_update: "我已经同步计划完成状态啦",
  hospital_bag_card_create: "我已经帮你生成好待产包清单啦",
  ibclc_consult_card_create: "我已经准备好 IBCLC 咨询入口啦",
  hospital_bag_pump_recommend: "我已经帮你整理好吸奶器推荐啦",
  hospital_bag_cart_update: "我已经帮你更新好待产包购物车啦",
  support_ticket_draft_create: "请确认售后信息",
};

const GENERIC_DONE_TITLES = new Set([
  "我处理好了",
  "我处理完了",
  "我已经处理好了",
  "我处理完这一步了",
  "我已经处理完这一步了",
  "我已经准备好结果了",
  "我已经生成结果卡片了",
  "我处理好啦",
  "这一步处理好啦",
  "我准备好结果啦",
  "我已经整理好结果啦",
]);

const GENERIC_ERROR_TITLES = new Set([
  "这一步暂时没处理好",
]);

function normalizeToolName(toolName: string): string {
  const token = String(toolName ?? "").trim();
  if (!token) return "";
  const parts = token.split(".");
  return (parts[parts.length - 1] || "").replace(/^milk_management__/, "");
}

function isRunStartedWorkRow(tool: AgUiToolCallRow): boolean {
  return tool.id === "run:started-work" || normalizeToolName(tool.name) === "run_started";
}

export function workItemTitle(tool: AgUiToolCallRow): string {
  if (tool.kind === "narration") return "";
  const title = tool.title?.trim();
  if (title && !GENERIC_ERROR_TITLES.has(title)) return title;
  if (tool.state === "running") return "我按当前场景继续处理～";
  if (tool.state === "error") return "我继续处理一下～";
  return "这一步处理好啦";
}

function workItemNeedsConfirmation(tool: AgUiToolCallRow): boolean {
  if (tool.kind === "narration") return false;
  const text = `${tool.title ?? ""} ${tool.argsDigest ?? ""}`;
  return text.includes("确认") || text.includes("等你确认");
}

function completedToolSummaryTitle(tool: AgUiToolCallRow): string {
  const title = workItemTitle(tool);
  if (normalizeToolName(tool.name) === "ibclc_consult_card_create" && title.includes("确认")) return title;
  const mapped = COMPLETED_TOOL_SUMMARY_TITLES[normalizeToolName(tool.name)];
  if (mapped) return mapped;
  return title && !GENERIC_DONE_TITLES.has(title) ? title : "";
}

export function workProgressSummary(
  tools: AgUiToolCallRow[],
  isWorkFinished: boolean,
): WorkProgressSummary | null {
  const actionRows = tools.filter((tool) => tool.kind !== "narration" && !(isWorkFinished && isRunStartedWorkRow(tool)));
  const running = [...actionRows].reverse().find((tool) => tool.state === "running");
  if (running) return { title: workItemTitle(running), tone: "running" };
  const needsConfirmation = actionRows.some(workItemNeedsConfirmation);
  if (needsConfirmation && !isWorkFinished) return { title: "等你确认", tone: "waiting" };
  if (isWorkFinished) {
    if (actionRows.length === 0) return null;
    const completed = [...actionRows].reverse().find((tool) => tool.state === "completed" && completedToolSummaryTitle(tool));
    return { title: completed ? completedToolSummaryTitle(completed) : "我处理好啦", tone: "done" };
  }
  const lastAction = actionRows.at(-1);
  if (lastAction) {
    return {
      title: workItemTitle(lastAction),
      tone: lastAction.state === "completed" ? "done" : lastAction.state === "error" ? "running" : lastAction.state,
    };
  }
  return { title: "我先处理一下～", tone: "running" };
}
