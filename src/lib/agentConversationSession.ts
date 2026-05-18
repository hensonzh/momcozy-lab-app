/**
 * 主对话 chat-messages 的 conversation_id：
 * - App 启动时从 localStorage 恢复（模块首次加载即读入内存）；
 * - 尚无记录时请求体使用空字符串 ""；
 * - SSE 中收到服务端下发的 conversation_id 后写入内存并持久化到 localStorage。
 * 与吸乳页 Mai 助手共用 {@link AGENT_CONVERSATION_ID_STORAGE_KEY}，保证会话连续。
 */

/** 与历史 PumpSession sessionStorage 键名一致，便于迁移 */
export const AGENT_CONVERSATION_ID_STORAGE_KEY = "mai_agent_conversation_id";
/** ag-ui 协议线程 id：后端以 threadId 识别上下文会话 */
export const AG_UI_THREAD_ID_STORAGE_KEY = "momcozy_conversation_id";

let agentConversationIdMemory = "";
let agUiThreadIdMemory = "";

function readStoredConversationId(): string {
  try {
    const fromLocal = localStorage.getItem(AGENT_CONVERSATION_ID_STORAGE_KEY)?.trim();
    if (fromLocal) return fromLocal;
    const fromSession = sessionStorage.getItem(AGENT_CONVERSATION_ID_STORAGE_KEY)?.trim();
    if (fromSession) {
      localStorage.setItem(AGENT_CONVERSATION_ID_STORAGE_KEY, fromSession);
      sessionStorage.removeItem(AGENT_CONVERSATION_ID_STORAGE_KEY);
      return fromSession;
    }
  } catch {
    /* 忽略存储不可用 */
  }
  return "";
}

agentConversationIdMemory = readStoredConversationId();
agUiThreadIdMemory = (() => {
  try {
    return localStorage.getItem(AG_UI_THREAD_ID_STORAGE_KEY)?.trim() ?? "";
  } catch {
    return "";
  }
})();

function writeStoredConversationId(id: string): void {
  try {
    const t = id.trim();
    if (!t) {
      localStorage.removeItem(AGENT_CONVERSATION_ID_STORAGE_KEY);
      return;
    }
    localStorage.setItem(AGENT_CONVERSATION_ID_STORAGE_KEY, t);
  } catch {
    /* 忽略 */
  }
}

function writeStoredAgUiThreadId(id: string): void {
  try {
    const t = id.trim();
    if (!t) {
      localStorage.removeItem(AG_UI_THREAD_ID_STORAGE_KEY);
      return;
    }
    localStorage.setItem(AG_UI_THREAD_ID_STORAGE_KEY, t);
  } catch {
    /* ignore */
  }
}

/**
 * 仅清理曾放在 sessionStorage 的同键副本（迁移后一般为空）；不删 localStorage 中的主对话 id。
 */
export function clearLegacyAgentConversationIdStorage(): void {
  try {
    sessionStorage.removeItem(AGENT_CONVERSATION_ID_STORAGE_KEY);
  } catch {
    /* 忽略 */
  }
}

/**
 * 读取当前会话 id，用于 chat-messages 请求体的 conversation_id。
 * @returns 本地或 SSE 已写入的 id；从未获得则为 ""
 */
export function getAgentConversationIdForRequest(): string {
  return agentConversationIdMemory;
}

function createAgUiThreadId(): string {
  return `thread_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

/** 读取 ag-ui threadId；不存在时前端生成并持久化。 */
export function getAgUiThreadIdForRequest(): string {
  const current = agUiThreadIdMemory.trim();
  if (current) return current;
  const created = createAgUiThreadId();
  agUiThreadIdMemory = created;
  writeStoredAgUiThreadId(created);
  return created;
}

/** 由 RUN_STARTED / RUN_FINISHED 等事件回写 thread_id。 */
export function persistAgUiThreadId(threadId: unknown): void {
  if (typeof threadId !== "string") return;
  const next = threadId.trim();
  if (!next) return;
  agUiThreadIdMemory = next;
  writeStoredAgUiThreadId(next);
}

/**
 * 从 chat-messages SSE 单条 JSON 中解析 conversation_id，写入内存并持久化到 localStorage。
 * @param data SSE onMessage 收到的解析结果（对象才可能含 conversation_id）
 */
export function persistAgentConversationIdFromSse(data: string | object): void {
  if (typeof data !== "object" || data == null) return;
  const id = (data as { conversation_id?: unknown }).conversation_id;
  if (typeof id !== "string" || !id.trim()) return;
  const next = id.trim();
  agentConversationIdMemory = next;
  writeStoredConversationId(next);
}

/**
 * 清空内存与 localStorage 中的主对话会话 id（例如用户「新会话」；当前产品未接线则保留导出供扩展）。
 */
export function clearPersistedAgentConversationId(): void {
  agentConversationIdMemory = "";
  try {
    localStorage.removeItem(AGENT_CONVERSATION_ID_STORAGE_KEY);
  } catch {
    /* 忽略 */
  }
}

/** 清空 ag-ui thread id（预留给新会话入口）。 */
export function clearPersistedAgUiThreadId(): void {
  agUiThreadIdMemory = "";
  try {
    localStorage.removeItem(AG_UI_THREAD_ID_STORAGE_KEY);
  } catch {
    /* ignore */
  }
}
