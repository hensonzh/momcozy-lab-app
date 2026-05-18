import { beforeEach, describe, expect, it } from "vitest";
import {
  buildIbclcChatUrl,
  clearStoredIbclcReturnViewport,
  isIbclcCompletionForCard,
  publishIbclcConsultCompleted,
  readStoredIbclcReturnViewport,
  readStoredIbclcReturnTo,
  readStoredIbclcConsultCompletions,
  readStoredIbclcConsultCompletion,
  rememberIbclcReturnViewport,
  rememberIbclcReturnTo,
  stableIbclcConsultId,
} from "@/lib/ibclcConsult";

describe("ibclcConsult", () => {
  beforeEach(() => {
    localStorage.clear();
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

  it("matches completion events by consult id", () => {
    const payload = {
      type: "momcozy.ibclc_consult_completed" as const,
      conversation_id: "thread_1",
      consult_id: "ibclc_1",
    };

    expect(isIbclcCompletionForCard(payload, "thread_1", "ibclc_1")).toBe(true);
    expect(isIbclcCompletionForCard(payload, "thread_1", "ibclc_2")).toBe(false);
    expect(isIbclcCompletionForCard(payload, "thread_2", "ibclc_1")).toBe(true);
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
    expect(readStoredIbclcConsultCompletions()).toHaveLength(1);
  });

  it("keeps completion status for multiple consultation cards", () => {
    publishIbclcConsultCompleted(
      { conversation_id: "thread_1", consult_id: "ibclc_1", event: "done" },
      { conversationId: "thread_fallback", consultId: "ibclc_fallback" },
    );
    publishIbclcConsultCompleted(
      { conversation_id: "thread_2", consult_id: "ibclc_2", event: "done" },
      { conversationId: "thread_fallback", consultId: "ibclc_fallback" },
    );

    const completions = readStoredIbclcConsultCompletions();
    expect(completions.map((payload) => payload.consult_id)).toEqual(["ibclc_1", "ibclc_2"]);
    expect(completions.some((payload) => isIbclcCompletionForCard(payload, "thread_1", "ibclc_1"))).toBe(true);
    expect(completions.some((payload) => isIbclcCompletionForCard(payload, "thread_2", "ibclc_2"))).toBe(true);
    expect(readStoredIbclcConsultCompletion()).toMatchObject({ consult_id: "ibclc_2" });
  });

  it("stores the last IBCLC return target for route recovery", () => {
    rememberIbclcReturnTo("/?tab=agent#latest");

    expect(readStoredIbclcReturnTo()).toBe("/?tab=agent#latest");
  });

  it("stores and reads the IBCLC return viewport for the matching route only", () => {
    rememberIbclcReturnViewport({
      returnTo: "/?tab=agent#latest",
      consultId: "ibclc_1",
      scrollTop: 320.4,
      scrollHeight: 1200,
    });

    expect(readStoredIbclcReturnViewport("/other")).toBeNull();
    expect(readStoredIbclcReturnViewport("/?tab=agent#latest")).toMatchObject({
      return_to: "/?tab=agent#latest",
      consult_id: "ibclc_1",
      scroll_top: 320,
      scroll_height: 1200,
    });

    clearStoredIbclcReturnViewport();
    expect(readStoredIbclcReturnViewport("/?tab=agent#latest")).toBeNull();
  });

  it("creates deterministic consult ids from the same seed", () => {
    expect(stableIbclcConsultId("message:0")).toBe(stableIbclcConsultId("message:0"));
    expect(stableIbclcConsultId("message:0")).not.toBe(stableIbclcConsultId("message:1"));
  });
});
