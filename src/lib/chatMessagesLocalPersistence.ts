import type { ChatMessage } from "@/types/chat";
import { log } from "@/lib/logger";

/**
 * Agent Hub 写入本地持久化的对话条数上限（仅保留时间上最新的若干条）。
 * 修改此处即可调整存储规模。
 */
export const CHAT_MESSAGES_LOCAL_MAX_COUNT = 50;

export const CHAT_MESSAGES_STORAGE_KEY = "mai_agent_hub_chat_messages_v1";

function takeLatestMessages(messages: ChatMessage[], max: number): ChatMessage[] {
  if (messages.length <= max) return messages;
  return messages.slice(-max);
}

export function stripEphemeralChatMessageUi(messages: ChatMessage[]): ChatMessage[] {
  return messages.map((message) => {
    if (!message.quickReplies) return message;
    const { quickReplies: _quickReplies, ...rest } = message;
    return rest;
  });
}

export function isTransientAgentHubFailureMessage(message: ChatMessage): boolean {
  if (message.role !== "mai") return false;
  if (message.chatStreamContext && message.chatStreamContext !== "main") return false;
  const content = message.content.trim();
  if (!content.startsWith("请求失败：")) return false;
  return /ag-ui websocket|websocket|upstream returned status|request timed out|timed out|timeout|无法连接后端|failed to fetch|networkerror|load failed|VITE_API_BASE_URL|VITE_API_TOKEN/i.test(
    content,
  );
}

function hasRenderableAssistantContent(message: ChatMessage): boolean {
  if (message.content.trim()) return true;
  if (message.richText) return true;
  if ((message.streamRenderItems ?? []).length > 0) return true;
  if ((message.agentToolCalls ?? []).length > 0) return true;
  if (message.cardType && message.cardType !== "encourage") return true;
  return false;
}

function isStaleMainStreamPlaceholder(message: ChatMessage): boolean {
  if (message.role !== "mai") return false;
  if (message.chatStreamContext && message.chatStreamContext !== "main") return false;
  if (message.agentStatusDone || message.agentWorkFinishedAtMs) return false;
  return !hasRenderableAssistantContent(message);
}

function isUploadedImageStagingMessage(message: ChatMessage): boolean {
  return message.role === "user" && String(message.cardData?.kind ?? "") === "uploaded-image";
}

function removeUnansweredUserRuns(messages: ChatMessage[]): ChatMessage[] {
  const remove = new Set<number>();
  let index = 0;
  while (index < messages.length) {
    if (messages[index]?.role !== "user") {
      index += 1;
      continue;
    }

    const plainUserIndexes: number[] = [];
    while (index < messages.length && messages[index]?.role === "user") {
      if (!isUploadedImageStagingMessage(messages[index])) plainUserIndexes.push(index);
      index += 1;
    }

    const followedByAssistant = messages[index]?.role === "mai";
    if (!followedByAssistant) {
      plainUserIndexes.forEach((i) => remove.add(i));
      continue;
    }
    plainUserIndexes.slice(0, -1).forEach((i) => remove.add(i));
  }

  if (remove.size === 0) return messages;
  return messages.filter((_, index) => !remove.has(index));
}

export function stripTransientAgentHubFailureMessages(
  messages: ChatMessage[],
  opts?: { stripEphemeralUi?: boolean },
): ChatMessage[] {
  const remove = new Set<number>();
  messages.forEach((message, index) => {
    if (!isTransientAgentHubFailureMessage(message) && !isStaleMainStreamPlaceholder(message)) return;
    remove.add(index);
    for (let prev = index - 1; prev >= 0; prev -= 1) {
      if (remove.has(prev)) continue;
      if (messages[prev]?.role === "user") remove.add(prev);
      break;
    }
  });

  const remaining = messages.filter((_, index) => !remove.has(index));
  const cleaned = removeUnansweredUserRuns(opts?.stripEphemeralUi ? stripEphemeralChatMessageUi(remaining) : remaining);
  while (cleaned.length > 0) {
    const last = cleaned.at(-1);
    if (last?.role !== "user") break;
    if (isUploadedImageStagingMessage(last)) break;
    cleaned.pop();
  }
  return cleaned;
}

/**
 * 从 localStorage 读取已保存的对话列表；解析失败或无数据时返回 []。
 */
export function loadPersistedChatMessages(): ChatMessage[] {
  try {
    const raw = localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY);
    if (!raw?.trim()) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    const original = parsed as ChatMessage[];
    const sanitized = stripTransientAgentHubFailureMessages(original, { stripEphemeralUi: true });
    if (sanitized.length !== original.length || JSON.stringify(sanitized) !== JSON.stringify(original)) {
      localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, JSON.stringify(takeLatestMessages(sanitized, CHAT_MESSAGES_LOCAL_MAX_COUNT)));
    }
    return sanitized;
  } catch (e) {
    log("[chat-persist] 读取本地对话失败", e);
    return [];
  }
}

/**
 * 持久化对话列表，仅写入末尾 {@link CHAT_MESSAGES_LOCAL_MAX_COUNT} 条。
 */
export function savePersistedChatMessages(messages: ChatMessage[]): void {
  try {
    const slice = takeLatestMessages(
      stripTransientAgentHubFailureMessages(messages, { stripEphemeralUi: true }),
      CHAT_MESSAGES_LOCAL_MAX_COUNT,
    );
    localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, JSON.stringify(slice));
  } catch (e) {
    log("[chat-persist] 写入本地对话失败", e);
  }
}

export function clearPersistedChatMessages(): void {
  try {
    localStorage.removeItem(CHAT_MESSAGES_STORAGE_KEY);
  } catch (e) {
    log("[chat-persist] 清空本地对话失败", e);
  }
}
