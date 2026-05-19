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

export function isTransientAgentHubFailureMessage(message: ChatMessage): boolean {
  if (message.role !== "mai") return false;
  if (message.chatStreamContext && message.chatStreamContext !== "main") return false;
  const content = message.content.trim();
  if (!content.startsWith("请求失败：")) return false;
  return /ag-ui websocket|websocket|upstream returned status|无法连接后端|failed to fetch|networkerror|load failed|VITE_API_BASE_URL|VITE_API_TOKEN/i.test(
    content,
  );
}

export function stripTransientAgentHubFailureMessages(messages: ChatMessage[]): ChatMessage[] {
  const remove = new Set<number>();
  messages.forEach((message, index) => {
    if (!isTransientAgentHubFailureMessage(message)) return;
    remove.add(index);
    for (let prev = index - 1; prev >= 0; prev -= 1) {
      if (remove.has(prev)) continue;
      if (messages[prev]?.role === "user") remove.add(prev);
      break;
    }
  });

  const cleaned = messages.filter((_, index) => !remove.has(index));
  while (cleaned.length > 0) {
    const last = cleaned.at(-1);
    if (last?.role !== "user") break;
    if (String(last.cardData?.kind ?? "") === "uploaded-image") break;
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
    const messages = parsed as ChatMessage[];
    const sanitized = stripTransientAgentHubFailureMessages(messages);
    if (sanitized.length !== messages.length) {
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
    const slice = takeLatestMessages(stripTransientAgentHubFailureMessages(messages), CHAT_MESSAGES_LOCAL_MAX_COUNT);
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
