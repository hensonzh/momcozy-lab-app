import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { buildMilkAnalysisContextText } from "@/lib/analysisContextEvents";

export const MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT = "mmc-milk-analysis-reminder-followup";

const PENDING_KEY = "mmc_milk_analysis_reminder_followup_pending";
const CONSUMED_KEY = "mmc_milk_analysis_reminder_followup_consumed";
const PENDING_TTL_MS = 30 * 60 * 1000;
const MAX_CONSUMED_IDS = 30;

export interface MilkAnalysisReminderFollowup {
  chatMessageId: string;
  message: string;
  analysisContext?: AgentAnalysisCard;
  createdAt: number;
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

function readConsumedIds(): string[] {
  try {
    const parsed = JSON.parse(storageGet(CONSUMED_KEY)) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.map(compactText).filter(Boolean).slice(-MAX_CONSUMED_IDS);
  } catch {
    return [];
  }
}

function hasConsumed(chatMessageId: string): boolean {
  return readConsumedIds().includes(chatMessageId);
}

function markConsumed(chatMessageId: string): void {
  const ids = readConsumedIds().filter((id) => id !== chatMessageId);
  ids.push(chatMessageId);
  storageSet(CONSUMED_KEY, JSON.stringify(ids.slice(-MAX_CONSUMED_IDS)));
}

export function queueMilkAnalysisReminderFollowup(params: {
  chatMessageId?: string;
  message?: string;
  analysisContext?: AgentAnalysisCard;
}): MilkAnalysisReminderFollowup | null {
  const chatMessageId = compactText(params.chatMessageId);
  const message = compactText(params.message);
  if (!chatMessageId || !message || hasConsumed(chatMessageId)) return null;

  const pending: MilkAnalysisReminderFollowup = {
    chatMessageId,
    message,
    analysisContext: params.analysisContext,
    createdAt: Date.now(),
  };
  storageSet(PENDING_KEY, JSON.stringify(pending));
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent(MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT, { detail: pending }));
  }
  return pending;
}

export function consumeMilkAnalysisReminderFollowup(): MilkAnalysisReminderFollowup | null {
  try {
    const parsed = JSON.parse(storageGet(PENDING_KEY)) as Partial<MilkAnalysisReminderFollowup> | null;
    const chatMessageId = compactText(parsed?.chatMessageId);
    const message = compactText(parsed?.message);
    const createdAt = Number(parsed?.createdAt || 0);
    if (!chatMessageId || !message || !createdAt || Date.now() - createdAt > PENDING_TTL_MS || hasConsumed(chatMessageId)) {
      storageRemove(PENDING_KEY);
      return null;
    }
    storageRemove(PENDING_KEY);
    markConsumed(chatMessageId);
    return {
      chatMessageId,
      message,
      analysisContext: parsed?.analysisContext,
      createdAt,
    };
  } catch {
    storageRemove(PENDING_KEY);
    return null;
  }
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
    "重点说明：最近数据怎么看、可能是否有漏记、下一步最需要用户确认什么。",
    "不要生成卡片、表单或清单，不要诊断或开药。",
    "",
    `已展示提醒：${pending.message}`,
    `奶量分析上下文：${contextText}`,
  ].join("\n");
}
