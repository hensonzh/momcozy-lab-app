import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { buildMilkAnalysisContextText } from "@/lib/analysisContextEvents";

export const MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT = "mmc-milk-analysis-reminder-followup";

const PENDING_KEY = "mmc_milk_analysis_reminder_followup_pending";
const PENDING_TTL_MS = 30 * 60 * 1000;
const MAX_ATTEMPTS = 3;
const ATTEMPT_COOLDOWN_MS = 3000;
const RUNNING_STALE_MS = 2 * 60 * 1000;

type MilkAnalysisReminderFollowupStatus = "pending" | "running";

export interface MilkAnalysisReminderFollowup {
  taskId: string;
  chatMessageId: string;
  message: string;
  analysisContext?: AgentAnalysisCard;
  createdAt: number;
  status?: MilkAnalysisReminderFollowupStatus;
  attempts?: number;
  lastAttemptAt?: number;
}

function compactText(value: unknown): string {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function storageGet(key: string): string {
  if (typeof localStorage === "undefined") return "";
  try {
    return localStorage.getItem(key) || "";
  } catch {
    return "";
  }
}

function storageSet(key: string, value: string): void {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(key, value);
  } catch {
    /* best effort */
  }
}

function storageRemove(key: string): void {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.removeItem(key);
  } catch {
    /* best effort */
  }
}

function isSamePending(
  pending: MilkAnalysisReminderFollowup | null,
  chatMessageId: string,
  message: string,
): boolean {
  return (
    Boolean(pending) &&
    pending?.chatMessageId === chatMessageId &&
    pending?.message === message
  );
}

function createTaskId(chatMessageId: string): string {
  const randomPart = Math.random().toString(36).slice(2, 8);
  return `${chatMessageId}-${Date.now()}-${randomPart}`;
}

function dispatchFollowupTask(task: MilkAnalysisReminderFollowup): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(
    new CustomEvent(MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT, {
      detail: task,
    }),
  );
}

export function queueMilkAnalysisReminderFollowup(params: {
  chatMessageId?: string;
  message?: string;
  analysisContext?: AgentAnalysisCard;
}): MilkAnalysisReminderFollowup | null {
  const chatMessageId = compactText(params.chatMessageId);
  const message = compactText(params.message);
  if (!chatMessageId || !message) return null;

  const currentPending = readPendingMilkAnalysisReminderFollowup();
  if (isSamePending(currentPending, chatMessageId, message)) {
    dispatchFollowupTask(currentPending);
    return currentPending;
  }

  const pending: MilkAnalysisReminderFollowup = {
    taskId: createTaskId(chatMessageId),
    chatMessageId,
    message,
    analysisContext: params.analysisContext,
    createdAt: Date.now(),
    status: "pending",
    attempts: 0,
  };
  storageSet(PENDING_KEY, JSON.stringify(pending));
  dispatchFollowupTask(pending);
  return pending;
}

function readPendingMilkAnalysisReminderFollowup(): MilkAnalysisReminderFollowup | null {
  try {
    const parsed = JSON.parse(storageGet(PENDING_KEY)) as Partial<MilkAnalysisReminderFollowup> | null;
    const taskId = compactText(parsed?.taskId);
    const chatMessageId = compactText(parsed?.chatMessageId);
    const message = compactText(parsed?.message);
    const createdAt = Number(parsed?.createdAt || 0);
    if (!taskId || !chatMessageId || !message || !createdAt || Date.now() - createdAt > PENDING_TTL_MS) {
      storageRemove(PENDING_KEY);
      return null;
    }
    const attempts = Number(parsed?.attempts || 0);
    const lastAttemptAt = Number(parsed?.lastAttemptAt || 0);
    const parsedStatus = parsed?.status === "running" ? "running" : "pending";
    const status =
      parsedStatus === "running" &&
      (!lastAttemptAt || Date.now() - lastAttemptAt > RUNNING_STALE_MS)
        ? "pending"
        : parsedStatus;

    return {
      taskId,
      chatMessageId,
      message,
      analysisContext: parsed?.analysisContext,
      createdAt,
      status,
      attempts,
      lastAttemptAt,
    };
  } catch {
    storageRemove(PENDING_KEY);
    return null;
  }
}

export function peekMilkAnalysisReminderFollowup(): MilkAnalysisReminderFollowup | null {
  const pending = readPendingMilkAnalysisReminderFollowup();
  if (!pending || pending.status !== "pending" || Number(pending.attempts || 0) >= MAX_ATTEMPTS) return null;
  const lastAttemptAt = Number(pending.lastAttemptAt || 0);
  if (lastAttemptAt > 0 && Date.now() - lastAttemptAt < ATTEMPT_COOLDOWN_MS) return null;
  return pending;
}

export function markMilkAnalysisReminderFollowupAttempt(
  taskId: string,
): MilkAnalysisReminderFollowup | null {
  const pending = readPendingMilkAnalysisReminderFollowup();
  if (!pending || pending.taskId !== compactText(taskId)) return null;
  const next: MilkAnalysisReminderFollowup = {
    ...pending,
    status: "running",
    attempts: Number(pending.attempts || 0) + 1,
    lastAttemptAt: Date.now(),
  };
  storageSet(PENDING_KEY, JSON.stringify(next));
  return next;
}

export function completeMilkAnalysisReminderFollowup(taskId: string): void {
  const pending = readPendingMilkAnalysisReminderFollowup();
  if (!pending || pending.taskId !== compactText(taskId)) return;
  storageRemove(PENDING_KEY);
}

export function retryMilkAnalysisReminderFollowupLater(taskId: string, delayMs = 3000): void {
  const pending = readPendingMilkAnalysisReminderFollowup();
  if (!pending || pending.taskId !== compactText(taskId)) return;
  const next: MilkAnalysisReminderFollowup = {
    ...pending,
    status: "pending",
  };
  storageSet(PENDING_KEY, JSON.stringify(next));
  if (typeof window !== "undefined") {
    window.setTimeout(() => {
      const stillPending = readPendingMilkAnalysisReminderFollowup();
      if (!stillPending || stillPending.taskId !== compactText(taskId)) return;
      dispatchFollowupTask(stillPending);
    }, delayMs);
  }
}

export function consumeMilkAnalysisReminderFollowup(): MilkAnalysisReminderFollowup | null {
  const pending = readPendingMilkAnalysisReminderFollowup();
  if (!pending) return null;
  storageRemove(PENDING_KEY);
  return pending;
}

export function buildMilkAnalysisReminderFollowupPrompt(pending: MilkAnalysisReminderFollowup): string {
  const contextText = buildMilkAnalysisContextText({
    message: pending.message,
    analysisCard: pending.analysisContext,
    chatMessageId: pending.chatMessageId,
  });
  return [
    "这是后台奶量分析提醒后的自动接续，不是用户新输入的问题。",
    "前端已经展示过提醒语，请不要重复说“嗨，我注意到你近期奶量偏低，可以和你聊聊吗？”。",
    "请基于下面的奶量分析上下文，用自然简短的话继续解释近期奶量偏低的具体情况。",
    "这段上下文只能作为提醒线索，不要把它当作完整实时评估结论。",
    "本轮最终只能追问一个问题：先确认近 7 天奶量记录是否完整、有没有漏记吸奶量或瓶喂量。",
    "不要在同一轮追问宝宝尿布、精神、吃奶、体重、妈妈红旗症状或乳房舒适度；这些必须等用户回答记录完整性后，再由新版奶量管理状态机逐轮追问。",
    "如果用户继续追问奶量分析、追奶、稳奶、减奶或计划制定，必须按新版奶量管理流程核对必要信息，并通过奶量管理工具推进。",
    "不要生成卡片、表单或清单，不要诊断或开药。",
    "",
    `已展示提醒：${pending.message}`,
    `奶量分析上下文：${contextText}`,
  ].join("\n");
}
