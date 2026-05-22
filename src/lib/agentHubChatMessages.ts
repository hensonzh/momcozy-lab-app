import type { ChatMessage } from "@/types/chat";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import { chatStore } from "@/lib/chatStore";
import { loadPersistedChatMessages, savePersistedChatMessages } from "@/lib/chatMessagesLocalPersistence";

export const AGENT_HUB_SYNC_CHAT_EVENT = "mmc-agent-hub-sync-chat";

type AnalysisMessageKind = "daily_summary" | "mom_baby";

function nowTimestamp(): string {
  return new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
}

function createMessageId(kind: AnalysisMessageKind): string {
  return `analysis-${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function mergeMessagesPreserveOrder(base: ChatMessage[], incoming: ChatMessage[]): ChatMessage[] {
  if (base.length === 0) return incoming;
  if (incoming.length === 0) return base;
  const merged = [...base];
  const ids = new Set(base.map((m) => m.id));
  for (const message of incoming) {
    if (ids.has(message.id)) continue;
    merged.push(message);
    ids.add(message.id);
  }
  return merged;
}

function syncAgentHubMessages(messages: ChatMessage[]): void {
  chatStore.setMessages(messages);
  savePersistedChatMessages(messages);
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent(AGENT_HUB_SYNC_CHAT_EVENT));
  }
}

export function appendMessageToAgentHubStore(message: ChatMessage): ChatMessage[] {
  const base = mergeMessagesPreserveOrder(loadPersistedChatMessages(), chatStore.get().messages);
  if (base.some((m) => m.id === message.id)) {
    syncAgentHubMessages(base);
    return base;
  }

  const next = [...base, message];
  syncAgentHubMessages(next);
  return next;
}

export function appendAgentHubAnalysisMessage(
  content: string,
  opts: {
    kind: AnalysisMessageKind;
    id?: string;
    analysisCard?: AgentAnalysisCard;
  },
): string | null {
  const trimmed = content.trim();
  if (!trimmed && !opts.analysisCard) return null;

  const id = opts.id?.trim() || createMessageId(opts.kind);
  appendMessageToAgentHubStore({
    id,
    role: "mai",
    content: trimmed,
    timestamp: nowTimestamp(),
    cardType: "report",
    cardData: { kind: opts.kind, analysisCard: opts.analysisCard },
  });
  return id;
}
