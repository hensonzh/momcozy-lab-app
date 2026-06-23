import { describe, expect, it } from "vitest";
import { workProgressSummary } from "@/lib/agUiWorkProgress";
import type { AgUiToolCallRow } from "@/types/chat";

function row(partial: Partial<AgUiToolCallRow>): AgUiToolCallRow {
  return {
    id: partial.id ?? `tool:${partial.name ?? "tool"}`,
    name: partial.name ?? "tool",
    title: partial.title,
    argsDigest: partial.argsDigest ?? "",
    state: partial.state ?? "completed",
    kind: partial.kind,
    resultSummary: partial.resultSummary,
  };
}

describe("workProgressSummary", () => {
  it("keeps the generated hospital bag summary after the run finishes", () => {
    const summary = workProgressSummary(
      [
        row({ name: "load_skill", title: "我已经准备好继续处理了" }),
        row({ name: "hospital_bag_card_create", title: "我已经整理好待产包清单了" }),
      ],
      true,
    );

    expect(summary).toEqual({
      title: "我已经帮你生成好待产包清单啦",
      tone: "done",
    });
  });

  it("falls back to a generic done title only without a semantic completed row", () => {
    const summary = workProgressSummary(
      [
        row({ name: "run_approved_skill_script", title: "我处理完这一步了" }),
      ],
      true,
    );

    expect(summary).toEqual({
      title: "我处理好啦",
      tone: "done",
    });
  });

  it("keeps the blocked IBCLC confirmation title instead of the default consult-ready title", () => {
    const summary = workProgressSummary(
      [
        row({ name: "ibclc_consult_card_create", title: "还需要你确认 IBCLC 咨询入口" }),
      ],
      true,
    );

    expect(summary).toEqual({
      title: "还需要你确认 IBCLC 咨询入口",
      tone: "done",
    });
  });

  it("hides the optimistic run-start row after a text-only reply finishes", () => {
    const summary = workProgressSummary(
      [
        row({
          id: "run:started-work",
          name: "run_started",
          title: "我在接收你的消息～",
          state: "running",
        }),
      ],
      true,
    );

    expect(summary).toBeNull();
  });
});
