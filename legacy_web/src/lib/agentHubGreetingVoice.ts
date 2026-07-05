import type { ChatMessage } from "@/types/chat";

export function isAgentHubGreetingMessage(message: ChatMessage): boolean {
  return (
    message.role === "mai" &&
    String(message.id || "").startsWith("mai-greeting-")
  );
}

export function isPendingGreetingVoiceStale(
  messages: ChatMessage[],
  greetingId: string,
): boolean {
  const normalizedGreetingId = String(greetingId || "").trim();
  if (!normalizedGreetingId) return true;
  const greetingIndex = messages.findIndex(
    (message) =>
      message.id === normalizedGreetingId && isAgentHubGreetingMessage(message),
  );
  if (greetingIndex < 0) return true;
  return messages
    .slice(greetingIndex + 1)
    .some((message) => !isAgentHubGreetingMessage(message));
}
