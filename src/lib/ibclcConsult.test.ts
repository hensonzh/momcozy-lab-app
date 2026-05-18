import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  buildIbclcChatUrl,
  isIbclcCompletionForCard,
  publishIbclcConsultCompleted,
  readStoredIbclcConsultCompletion,
  stableIbclcConsultId,
} from "@/lib/ibclcConsult";

describe("ibclcConsult", () => {
  beforeEach(() => {
    localStorage.clear();
    vi.unstubAllEnvs();
    vi.stubEnv("VITE_CHAT_IMAGE_PROXY_TARGET", "");
  });

  it("builds the IBCLC chat url with thread and consult ids", () => {
    expect(buildIbclcChatUrl("/ibclc-chat.html", "ibclc_1", "thread_1")).toBe(
      "/ibclc-chat.html?thread_id=thread_1&consult_id=ibclc_1",
    );
  });

  it("adds an explicit return target to the IBCLC chat url", () => {
    expect(buildIbclcChatUrl("/ibclc-chat.html", "ibclc_1", "thread_1", "/?tab=agent#latest")).toBe(
      "/ibclc-chat.html?thread_id=thread_1&consult_id=ibclc_1&return_to=%2F%3Ftab%3Dagent%23latest",
    );
  });

  it("prefixes relative IBCLC chat urls with the configured proxy target", () => {
    vi.stubEnv("VITE_CHAT_IMAGE_PROXY_TARGET", "http://192.168.24.182:8900");

    expect(buildIbclcChatUrl("/ibclc-chat.html", "ibclc_1", "thread_1")).toBe(
      "http://192.168.24.182:8900/ibclc-chat.html?thread_id=thread_1&consult_id=ibclc_1",
    );
  });

  it("matches completion events to the same card only", () => {
    const payload = {
      type: "momcozy.ibclc_consult_completed" as const,
      conversation_id: "thread_1",
      consult_id: "ibclc_1",
    };

    expect(isIbclcCompletionForCard(payload, "thread_1", "ibclc_1")).toBe(true);
    expect(isIbclcCompletionForCard(payload, "thread_1", "ibclc_2")).toBe(false);
    expect(isIbclcCompletionForCard(payload, "thread_2", "ibclc_1")).toBe(false);
  });

  it("publishes and stores the completion payload", () => {
    publishIbclcConsultCompleted(
      { conversation_id: "thread_1", consult_id: "ibclc_1", event: "done" },
      { conversationId: "thread_fallback", consultId: "ibclc_fallback" },
    );

    expect(readStoredIbclcConsultCompletion()).toMatchObject({
      type: "momcozy.ibclc_consult_completed",
      conversation_id: "thread_1",
      consult_id: "ibclc_1",
      event: "done",
    });
  });

  it("creates deterministic consult ids from the same seed", () => {
    expect(stableIbclcConsultId("message:0")).toBe(stableIbclcConsultId("message:0"));
    expect(stableIbclcConsultId("message:0")).not.toBe(stableIbclcConsultId("message:1"));
  });
});
