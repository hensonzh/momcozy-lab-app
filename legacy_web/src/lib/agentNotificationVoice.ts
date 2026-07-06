import type { ChatMessage } from "@/types/chat";

export const AGENT_NOTIFICATION_VOICE_EVENT = "mmc-agent-notification-voice";
export const AGENT_NOTIFICATION_VOICE_IDLE_EVENT =
  "mmc-agent-notification-voice-idle";

let notificationVoiceBusy = false;

export function isAgentNotificationVoicePlaying(): boolean {
  return notificationVoiceBusy;
}

export function setAgentNotificationVoicePlaying(value: boolean): void {
  notificationVoiceBusy = value;
}

export function dispatchAgentNotificationVoiceMessage(
  message: ChatMessage,
): void {
  if (typeof window === "undefined") return;
  if (!message.autoVoiceOnAppend || message.role !== "mai") return;
  window.dispatchEvent(
    new CustomEvent<ChatMessage>(AGENT_NOTIFICATION_VOICE_EVENT, {
      detail: message,
    }),
  );
}

export function dispatchAgentNotificationVoiceIdle(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(AGENT_NOTIFICATION_VOICE_IDLE_EVENT));
}
