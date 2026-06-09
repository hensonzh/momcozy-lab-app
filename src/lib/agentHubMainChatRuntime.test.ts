import { beforeEach, describe, expect, it, vi } from "vitest";
import { agentHubMainChatRuntime } from "@/lib/agentHubMainChatRuntime";

describe("agentHubMainChatRuntime", () => {
  beforeEach(() => {
    agentHubMainChatRuntime.cancel();
  });

  it("publishes the active reply while a main chat stream is running", () => {
    const listener = vi.fn();
    const unsubscribe = agentHubMainChatRuntime.subscribe(listener);

    agentHubMainChatRuntime.start("reply-1", vi.fn());

    expect(agentHubMainChatRuntime.getSnapshot()).toEqual({
      replyId: "reply-1",
      running: true,
    });
    expect(listener).toHaveBeenCalledTimes(1);

    agentHubMainChatRuntime.finish("reply-1");

    expect(agentHubMainChatRuntime.getSnapshot()).toEqual({
      replyId: null,
      running: false,
    });
    expect(listener).toHaveBeenCalledTimes(2);
    unsubscribe();
  });

  it("cancels the active stream only when cancellation is explicit", () => {
    const cancel = vi.fn();
    agentHubMainChatRuntime.start("reply-1", cancel);

    expect(agentHubMainChatRuntime.cancel()).toBe(true);
    expect(cancel).toHaveBeenCalledTimes(1);
    expect(agentHubMainChatRuntime.getSnapshot().running).toBe(false);

    expect(agentHubMainChatRuntime.cancel()).toBe(false);
    expect(cancel).toHaveBeenCalledTimes(1);
  });
});
