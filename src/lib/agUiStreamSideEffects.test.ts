import { describe, expect, it } from "vitest";
import type { SetStateAction } from "react";
import { applyAgUiStreamSideEffects } from "@/lib/agUiStreamSideEffects";
import type { ChatMessage } from "@/types/chat";

function applyEvents(events: Array<Record<string, unknown>>): ChatMessage {
  let messages: ChatMessage[] = [
    {
      id: "reply",
      role: "mai",
      content: "",
      timestamp: "",
    },
  ];
  const setMessages = (updater: SetStateAction<ChatMessage[]>) => {
    messages = typeof updater === "function" ? updater(messages) : updater;
  };
  for (const event of events) {
    applyAgUiStreamSideEffects("reply", event, setMessages);
  }
  return messages[0];
}

function applyEventSequence(
  steps: Array<Record<string, unknown> | ((message: ChatMessage) => ChatMessage)>,
): ChatMessage {
  let messages: ChatMessage[] = [
    {
      id: "reply",
      role: "mai",
      content: "",
      timestamp: "",
    },
  ];
  const setMessages = (updater: SetStateAction<ChatMessage[]>) => {
    messages = typeof updater === "function" ? updater(messages) : updater;
  };
  for (const step of steps) {
    if (typeof step === "function") {
      messages = messages.map((message) => (message.id === "reply" ? step(message) : message));
      continue;
    }
    applyAgUiStreamSideEffects("reply", step, setMessages);
  }
  return messages[0];
}

describe("applyAgUiStreamSideEffects", () => {
  it("keeps generic run and processing statuses hidden from the user-facing status line", () => {
    const msg = applyEvents([
      {
        type: "RUN_STARTED",
        metadata: { status: "Agent loop started." },
      },
      {
        type: "CUSTOM",
        name: "momcozy.agent.status",
        value: "Running a processing step.",
      },
      {
        type: "CUSTOM",
        name: "momcozy.agent.status",
        value: "Requesting model response with tool outputs.",
      },
    ]);

    expect(msg.agentStatusLine).toBe("");
  });

  it("maps tool work to generic user-facing work panel text", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_1",
        tool_call_name: "milk_records_query",
      },
      {
        type: "TOOL_CALL_ARGS",
        tool_call_id: "call_1",
        tool_call_name: "milk_records_query",
      },
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_1",
        tool_call_name: "milk_records_query",
        content: JSON.stringify({ ok: true, tool_name: "milk_records_query", records: [] }),
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "milk_records_query",
      title: "相关信息已读取",
      state: "completed",
    });
    expect(msg.agentToolCalls?.[0].title).not.toContain("milk_records_query");
    expect(msg.agentToolCalls?.[0].title).not.toMatch(/Milk|Tool|records/i);
  });

  it("renders structured UI only from ARTIFACT_CREATED in the main loop", () => {
    const toolResultOnly = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_form",
        tool_call_name: "ui_form_create",
        content: JSON.stringify({
          ok: true,
          tool_name: "ui_form_create",
          form: { id: "form_1", title: "确认信息", fields: [] },
        }),
      },
    ]);
    expect(toolResultOnly.richText).toBeUndefined();

    const withArtifact = applyEvents([
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "form_1",
        artifact_type: "form",
        tool_call_id: "call_form",
        tool_call_name: "ui_form_create",
        artifact: { id: "form_1", title: "确认信息", fields: [] },
      },
    ]);
    expect(withArtifact.richText?.action).toHaveLength(1);
    expect(withArtifact.richText?.action[0]).toMatchObject({
      kind: "ag_ui_artifact",
      artifact_type: "form",
      form: { id: "form_1" },
    });
    expect(withArtifact.streamRenderItems?.[0]).toMatchObject({ kind: "rich" });
  });

  it("replaces repeated artifact updates instead of appending duplicate cards", () => {
    const msg = applyEvents([
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "ticket_1",
        artifact_type: "support_ticket_draft",
        tool_call_id: "call_ticket",
        tool_call_name: "support_ticket_draft_create",
        artifact: {
          issue_type: "usage_help",
          issue_summary: "用户需要首次使用指导。",
          product_model: "Air1",
          urgency: "normal",
        },
      },
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "ticket_1",
        artifact_type: "support_ticket_draft",
        tool_call_id: "call_ticket",
        tool_call_name: "support_ticket_draft_create",
        artifact: {
          issue_type: "usage_help",
          issue_summary: "用户需要首次使用吸奶器指导。",
          product_model: "Momcozy Air1",
          urgency: "normal",
        },
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.richText?.action[0]).toMatchObject({
      kind: "ag_ui_artifact",
      artifact_type: "support_ticket_draft",
      artifact_id: "ticket_1",
      ticket: {
        issue_summary: "用户需要首次使用吸奶器指导。",
        product_model: "Momcozy Air1",
      },
    });
    expect(msg.streamRenderItems?.[0]).toMatchObject({
      kind: "rich",
      payload: {
        action: [
          {
            artifact_id: "ticket_1",
            ticket: {
              issue_summary: "用户需要首次使用吸奶器指导。",
            },
          },
        ],
      },
    });
  });

  it("adds a generic confirmation step without exposing the tool name", () => {
    const msg = applyEvents([
      {
        type: "CONFIRMATION_REQUIRED",
        confirmation_id: "confirm_1",
        tool_call_id: "call_plan",
        tool_call_name: "milk_plan_preview",
        artifact_id: "draft_1",
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      title: "请确认后继续",
      argsDigest: "相关内容已准备好，等待你确认。",
      state: "completed",
    });
    expect(msg.agentToolCalls?.[0].title).not.toContain("milk_plan_preview");
  });

  it("moves intermediate text into the work panel even after tool work already started", () => {
    const msg = applyEventSequence([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_skill",
        tool_call_name: "load_skill",
        content: JSON.stringify({ ok: true, tool_name: "load_skill" }),
      },
      (message) => ({
        ...message,
        content: "我先帮你做成一张更贴合你情况的待产包卡片",
        streamRenderItems: [
          {
            kind: "text",
            text: "我先帮你做成一张更贴合你情况的待产包卡片",
          },
        ],
      }),
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "card_1",
        artifact_type: "hospital_bag_card",
        tool_call_id: "call_card",
        tool_call_name: "ui_card_create",
        artifact: { id: "card_1", card_type: "hospital_bag_card", card_json: { title: "待产包" } },
      },
    ]);

    expect(msg.content).toBe("");
    expect(msg.streamRenderItems?.some((item) => item.kind === "text")).toBe(false);
    expect(msg.agentToolCalls?.some((item) => item.kind === "narration" && item.content?.includes("待产包卡片"))).toBe(true);
    expect(msg.richText?.action).toHaveLength(1);
  });
});
