import type { AgentHubMainChatRuntimeSnapshot } from "@/lib/agentHubMainChatRuntime";
import type { ChatMessage } from "@/types/chat";

export type AgentResponseLightRailMode = "idle" | "loop" | "replying";

function messageHasReplyText(message: ChatMessage): boolean {
  if (message.content.trim()) return true;
  return Boolean(
    message.streamRenderItems?.some(
      (item) => item.kind === "text" && item.text.trim(),
    ),
  );
}

function messageHasActiveLoopWork(message: ChatMessage): boolean {
  if (message.agentThinkingTitle?.trim()) return true;
  if (message.thinkingStatus === "thinking") return true;
  return Boolean(
    message.agentToolCalls?.some((row) => row.state === "running"),
  );
}

export function resolveAgentResponseLightRailMode(
  runtime: AgentHubMainChatRuntimeSnapshot,
  messages: ChatMessage[],
): AgentResponseLightRailMode {
  if (!runtime.running || !runtime.replyId) return "idle";
  const activeMessage = messages.find((message) => message.id === runtime.replyId);
  if (!activeMessage) return "loop";
  if (messageHasActiveLoopWork(activeMessage)) return "loop";
  return messageHasReplyText(activeMessage) ? "replying" : "loop";
}
