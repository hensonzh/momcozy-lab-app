import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  beginAgentVoicePlayback,
  cancelAgentVoicePlayback,
  getActiveAgentVoicePlaybackSource,
  requestAgentVoicePlayback,
  subscribeAgentVoicePlaybackIdle,
} from "@/lib/agentVoicePlaybackCoordinator";
import { agentHubVoicePlaybackRuntime } from "@/lib/agentHubVoicePlaybackRuntime";

describe("agentVoicePlaybackCoordinator", () => {
  beforeEach(() => {
    cancelAgentVoicePlayback();
    agentHubVoicePlaybackRuntime.cancelAutoVoice();
  });

  it("keeps notification voice from being interrupted by auto reply voice", () => {
    const notificationCancel = vi.fn();
    const autoCancel = vi.fn();

    const notification = beginAgentVoicePlayback({
      id: "notification-1",
      source: "notification",
      cancel: notificationCancel,
    });
    const auto = beginAgentVoicePlayback({
      id: "reply-1",
      source: "auto-reply",
      cancel: autoCancel,
    });

    expect(notification).not.toBeNull();
    expect(auto).toBeNull();
    expect(notificationCancel).not.toHaveBeenCalled();
    expect(autoCancel).not.toHaveBeenCalled();
    expect(getActiveAgentVoicePlaybackSource()).toBe("notification");
    expect(agentHubVoicePlaybackRuntime.getSnapshot()).toEqual({
      autoVoicePlayingId: "notification-1",
      running: true,
    });

    notification?.finish();
    expect(getActiveAgentVoicePlaybackSource()).toBeNull();
  });

  it("reports blocked playback and notifies when the active voice becomes idle", () => {
    const notificationCancel = vi.fn();
    const autoCancel = vi.fn();
    const onIdle = vi.fn();
    const unsubscribe = subscribeAgentVoicePlaybackIdle(onIdle);

    const notification = requestAgentVoicePlayback({
      id: "notification-1",
      source: "notification",
      cancel: notificationCancel,
    });
    const auto = requestAgentVoicePlayback({
      id: "reply-1",
      source: "auto-reply",
      cancel: autoCancel,
    });

    expect(notification.status).toBe("started");
    expect(auto).toEqual({
      status: "blocked",
      activeId: "notification-1",
      activeSource: "notification",
    });
    expect(notificationCancel).not.toHaveBeenCalled();
    expect(autoCancel).not.toHaveBeenCalled();
    expect(onIdle).not.toHaveBeenCalled();

    if (notification.status === "started") notification.handle.finish();

    expect(onIdle).toHaveBeenCalledTimes(1);
    expect(getActiveAgentVoicePlaybackSource()).toBeNull();
    unsubscribe();
  });

  it("lets manual bubble playback interrupt notification voice", () => {
    const notificationCancel = vi.fn();
    const manualCancel = vi.fn();

    beginAgentVoicePlayback({
      id: "notification-1",
      source: "notification",
      cancel: notificationCancel,
    });
    const manual = beginAgentVoicePlayback({
      id: "message-1",
      source: "manual-bubble",
      cancel: manualCancel,
      visual: false,
    });

    expect(manual).not.toBeNull();
    expect(notificationCancel).toHaveBeenCalledTimes(1);
    expect(manualCancel).not.toHaveBeenCalled();
    expect(getActiveAgentVoicePlaybackSource()).toBe("manual-bubble");

    manual?.cancel();
    expect(manualCancel).toHaveBeenCalledTimes(1);
    expect(getActiveAgentVoicePlaybackSource()).toBeNull();
  });

  it("does not emit idle while a higher priority voice is taking over", () => {
    const onIdle = vi.fn();
    const unsubscribe = subscribeAgentVoicePlaybackIdle(onIdle);

    beginAgentVoicePlayback({
      id: "notification-1",
      source: "notification",
    });
    const manual = beginAgentVoicePlayback({
      id: "message-1",
      source: "manual-bubble",
      visual: false,
    });

    expect(manual).not.toBeNull();
    expect(onIdle).not.toHaveBeenCalled();

    manual?.finish();
    expect(onIdle).toHaveBeenCalledTimes(1);
    unsubscribe();
  });

  it("preserves notification voice when requested by hidden followup work", () => {
    const notificationCancel = vi.fn();
    beginAgentVoicePlayback({
      id: "notification-1",
      source: "notification",
      cancel: notificationCancel,
    });

    expect(
      cancelAgentVoicePlayback({ preserveSources: ["notification"] }),
    ).toBe(false);
    expect(notificationCancel).not.toHaveBeenCalled();
    expect(getActiveAgentVoicePlaybackSource()).toBe("notification");
  });
});
