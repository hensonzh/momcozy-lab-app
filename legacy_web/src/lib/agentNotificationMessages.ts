import { queryUserProfile } from "@/lib/agentApi";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

export type AgentNotificationKind = "milk_analysis" | "health_issue";

export function buildNotificationMessageFlags(kind: AgentNotificationKind) {
  return {
    messageTone: "notification" as const,
    notificationKind: kind,
    autoVoiceOnAppend: true,
  };
}

export function buildPersonalizedNotificationText(
  text: string,
  displayName?: string | null,
): string {
  const trimmedText = text.trim();
  const name = displayName?.trim();
  if (!trimmedText || !name) return trimmedText;
  if (/^嗨[，,\s]/.test(trimmedText) && trimmedText.includes(`嗨，${name}`))
    return trimmedText;
  if (!trimmedText.startsWith("嗨")) return trimmedText;

  const rest = trimmedText
    .slice("嗨".length)
    .replace(/^[，,\s]+/, "")
    .trimStart();
  return rest ? `嗨，${name}，${rest}` : `嗨，${name}`;
}

export async function loadNotificationDisplayName(
  userId = DEFAULT_CHAT_USER_ID,
): Promise<string> {
  try {
    const profile = await queryUserProfile({ user_id: userId });
    return profile.display_name?.trim() || "";
  } catch {
    return "";
  }
}

export async function personalizeNotificationText(
  text: string,
  userId = DEFAULT_CHAT_USER_ID,
): Promise<string> {
  const displayName = await loadNotificationDisplayName(userId);
  return buildPersonalizedNotificationText(text, displayName);
}
