import { describe, expect, it } from "vitest";
import type { ChatMessage } from "@/types/chat";
import {
  isAgentHubGreetingMessage,
  isPendingGreetingVoiceStale,
} from "@/lib/agentHubGreetingVoice";

function message(
  id: string,
  role: ChatMessage["role"],
  content = "hello",
): ChatMessage {
  return {
    id,
    role,
    content,
    timestamp: "09:00",
  };
}

describe("agentHubGreetingVoice", () => {
  it("recognizes Agent Hub greeting messages by id and role", () => {
    expect(
      isAgentHubGreetingMessage(message("mai-greeting-1", "mai")),
    ).toBe(true);
    expect(
      isAgentHubGreetingMessage(message("mai-greeting-1", "user")),
    ).toBe(false);
    expect(isAgentHubGreetingMessage(message("reply-1", "mai"))).toBe(false);
  });

  it("keeps a pending greeting fresh while it is still the latest message", () => {
    const greeting = message("mai-greeting-1", "mai");

    expect(isPendingGreetingVoiceStale([greeting], greeting.id)).toBe(false);
  });

  it("marks a pending greeting stale once conversation content follows it", () => {
    const greeting = message("mai-greeting-1", "mai");

    expect(
      isPendingGreetingVoiceStale(
        [
          greeting,
          {
            ...message("analysis-milk_analysis-1", "mai"),
            messageTone: "notification",
            notificationKind: "milk_analysis",
          },
        ],
        greeting.id,
      ),
    ).toBe(true);
    expect(
      isPendingGreetingVoiceStale(
        [greeting, message("user-1", "user", "我想分析奶量")],
        greeting.id,
      ),
    ).toBe(true);
  });

  it("treats missing pending greeting ids as stale", () => {
    expect(
      isPendingGreetingVoiceStale(
        [message("mai-greeting-current", "mai")],
        "mai-greeting-old",
      ),
    ).toBe(true);
  });
});
