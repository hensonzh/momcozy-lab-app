import { describe, expect, it } from "vitest";
import { resolveAgentResponseLightRailMode } from "@/lib/agentResponseLightRail";
import type { AgentHubMainChatRuntimeSnapshot } from "@/lib/agentHubMainChatRuntime";
import type { ChatMessage } from "@/types/chat";

function runtime(
  partial: Partial<AgentHubMainChatRuntimeSnapshot> = {},
): AgentHubMainChatRuntimeSnapshot {
  return {
    replyId: partial.replyId ?? "reply-1",
    running: partial.running ?? true,
  };
}

function message(partial: Partial<ChatMessage> = {}): ChatMessage {
  return {
    id: partial.id ?? "reply-1",
    role: partial.role ?? "mai",
    content: partial.content ?? "",
    timestamp: partial.timestamp ?? "",
    ...partial,
  };
}

describe("resolveAgentResponseLightRailMode", () => {
  it("hides the rail when no main chat run is active", () => {
    expect(
      resolveAgentResponseLightRailMode(runtime({ running: false }), [
        message({ content: "Done" }),
      ]),
    ).toBe("idle");
  });

  it("uses fast loop mode while thinking or tool work is active", () => {
    expect(
      resolveAgentResponseLightRailMode(runtime(), [
        message({ agentThinkingTitle: "我想一下" }),
      ]),
    ).toBe("loop");

    expect(
      resolveAgentResponseLightRailMode(runtime(), [
        message({
          content: "先给你一个方向",
          agentToolCalls: [
            {
              id: "tool:search",
              name: "search",
              argsDigest: "",
              state: "running",
            },
          ],
        }),
      ]),
    ).toBe("loop");
  });

  it("uses slower replying mode once final text is streaming", () => {
    expect(
      resolveAgentResponseLightRailMode(runtime(), [
        message({ content: "我整理好了，先看这个方案。" }),
      ]),
    ).toBe("replying");
  });
});
