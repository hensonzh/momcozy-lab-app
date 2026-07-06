import { beforeEach, describe, expect, it, vi } from "vitest";
import { agentHubVoicePlaybackRuntime } from "@/lib/agentHubVoicePlaybackRuntime";

describe("agentHubVoicePlaybackRuntime", () => {
  beforeEach(() => {
    agentHubVoicePlaybackRuntime.cancelAutoVoice();
  });

  it("publishes the reply currently owned by automatic voice playback", () => {
    const listener = vi.fn();
    const unsubscribe = agentHubVoicePlaybackRuntime.subscribe(listener);

    const handle = agentHubVoicePlaybackRuntime.startAutoVoice("reply-1");

    expect(agentHubVoicePlaybackRuntime.getSnapshot()).toEqual({
      autoVoicePlayingId: "reply-1",
      running: true,
    });
    expect(listener).toHaveBeenCalledTimes(1);

    agentHubVoicePlaybackRuntime.finishAutoVoice(handle);

    expect(agentHubVoicePlaybackRuntime.getSnapshot()).toEqual({
      autoVoicePlayingId: null,
      running: false,
    });
    expect(listener).toHaveBeenCalledTimes(2);
    unsubscribe();
  });

  it("cancels the active automatic voice playback when requested globally", () => {
    const cancel = vi.fn();
    agentHubVoicePlaybackRuntime.startAutoVoice("reply-1", cancel);

    expect(agentHubVoicePlaybackRuntime.cancelAutoVoice()).toBe(true);

    expect(cancel).toHaveBeenCalledTimes(1);
    expect(agentHubVoicePlaybackRuntime.getSnapshot()).toEqual({
      autoVoicePlayingId: null,
      running: false,
    });
    expect(agentHubVoicePlaybackRuntime.cancelAutoVoice()).toBe(false);
  });

  it("ignores stale finishes from a replaced playback for the same reply", () => {
    const first = agentHubVoicePlaybackRuntime.startAutoVoice("reply-1");
    const second = agentHubVoicePlaybackRuntime.startAutoVoice("reply-1");

    agentHubVoicePlaybackRuntime.finishAutoVoice(first);

    expect(agentHubVoicePlaybackRuntime.getSnapshot()).toEqual({
      autoVoicePlayingId: "reply-1",
      running: true,
    });

    agentHubVoicePlaybackRuntime.finishAutoVoice(second);

    expect(agentHubVoicePlaybackRuntime.getSnapshot().running).toBe(false);
  });

  it("ignores stale cancels from a replaced playback", () => {
    const firstCancel = vi.fn();
    const secondCancel = vi.fn();
    const first = agentHubVoicePlaybackRuntime.startAutoVoice(
      "reply-1",
      firstCancel,
    );
    agentHubVoicePlaybackRuntime.startAutoVoice("reply-1", secondCancel);

    expect(agentHubVoicePlaybackRuntime.cancelAutoVoice(first)).toBe(false);

    expect(firstCancel).not.toHaveBeenCalled();
    expect(secondCancel).not.toHaveBeenCalled();
    expect(agentHubVoicePlaybackRuntime.getSnapshot()).toEqual({
      autoVoicePlayingId: "reply-1",
      running: true,
    });

    expect(agentHubVoicePlaybackRuntime.cancelAutoVoice()).toBe(true);
    expect(secondCancel).toHaveBeenCalledTimes(1);
  });
});
