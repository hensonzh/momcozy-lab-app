import { describe, expect, it } from "vitest";
import type { SetStateAction } from "react";
import { applyAgUiStreamSideEffects, semanticForAgUiEvent } from "@/lib/agUiStreamSideEffects";
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
  it("applies quick replies only to the current assistant message", () => {
    let messages: ChatMessage[] = [
      {
        id: "old",
        role: "mai",
        content: "上一轮",
        timestamp: "",
        quickReplies: [
          { text: "旧提示1", sendText: "旧提示1" },
          { text: "旧提示2", sendText: "旧提示2" },
          { text: "旧提示3", sendText: "旧提示3" },
        ],
      },
      {
        id: "reply",
        role: "mai",
        content: "当前轮",
        timestamp: "",
      },
    ];
    const setMessages = (updater: SetStateAction<ChatMessage[]>) => {
      messages = typeof updater === "function" ? updater(messages) : updater;
    };

    applyAgUiStreamSideEffects(
      "reply",
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "继续下一步", send_text: "继续下一步" },
          { text: "换个方案", send_text: "我想换个方案" },
          { text: "先帮我总结", send_text: "先帮我总结" },
        ],
      },
      setMessages,
    );

    expect(messages[0].quickReplies).toBeUndefined();
    expect(messages[1].quickReplies).toEqual([
      { text: "继续下一步", sendText: "继续下一步" },
      { text: "换个方案", sendText: "我想换个方案" },
      { text: "先帮我总结", sendText: "先帮我总结" },
    ]);
  });

  it("does not attach quick replies to an older assistant message", () => {
    let messages: ChatMessage[] = [
      {
        id: "reply",
        role: "mai",
        content: "上一轮助手回复",
        timestamp: "",
      },
      {
        id: "next-user",
        role: "user",
        content: "我又问了一句",
        timestamp: "",
      },
    ];
    const setMessages = (updater: SetStateAction<ChatMessage[]>) => {
      messages = typeof updater === "function" ? updater(messages) : updater;
    };

    applyAgUiStreamSideEffects(
      "reply",
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "继续下一步", send_text: "继续下一步" },
          { text: "换个方案", send_text: "我想换个方案" },
          { text: "先帮我总结", send_text: "先帮我总结" },
        ],
      },
      setMessages,
    );

    expect(messages[0].quickReplies).toBeUndefined();
    expect(messages[1].quickReplies).toBeUndefined();
  });

  it("does not apply quick replies to a message that already contains a form artifact", () => {
    const msg = applyEvents([
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "birth_plan_card_intake",
        artifact_type: "form",
        tool_call_id: "call-form",
        tool_call_name: "birth_plan_form_create",
        artifact: {
          id: "birth_plan_card_intake",
          title: "信息采集",
          fields: [],
        },
      },
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "我来填写", send_text: "我来填写" },
          { text: "先解释一下", send_text: "先解释一下" },
          { text: "晚点再说", send_text: "晚点再说" },
        ],
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.quickReplies).toBeUndefined();
  });

  it("does not apply quick replies to a message that already contains a card artifact", () => {
    const msg = applyEvents([
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "birth_journey_1",
        artifact_type: "birth_journey_plan_card",
        tool_call_id: "call-card",
        tool_call_name: "birth_journey_plan_card_create",
        artifact: {
          card_type: "birth_journey_plan_card",
          card_json: { title: "生产全过程计划" },
        },
      },
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "确认医院流程", send_text: "确认医院流程" },
          { text: "整理待产包", send_text: "整理待产包" },
          { text: "做沟通单", send_text: "做分娩沟通单" },
        ],
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.quickReplies).toBeUndefined();
  });

  it("attaches web search citations to the assistant message", () => {
    const msg = applyEvents([
      {
        type: "CUSTOM",
        name: "momcozy.web_search.citations",
        value: {
          citations: [
            {
              index: 1,
              title: "Academy of Breastfeeding Medicine Protocols",
              url: "https://www.bfmed.org/protocols",
            },
            {
              index: 2,
              title: "Duplicate",
              url: "https://www.bfmed.org/protocols",
            },
          ],
        },
      },
    ]);

    expect(msg.citations).toEqual([
      {
        index: 1,
        title: "Academy of Breastfeeding Medicine Protocols",
        url: "https://www.bfmed.org/protocols",
      },
    ]);
  });

  it("removes existing quick replies when a support ticket form artifact arrives", () => {
    const msg = applyEvents([
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "继续下一步", send_text: "继续下一步" },
          { text: "换个方案", send_text: "换个方案" },
          { text: "先帮我总结", send_text: "先帮我总结" },
        ],
      },
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "ticket-1",
        artifact_type: "support_ticket",
        tool_call_id: "call-ticket",
        tool_call_name: "support_ticket_draft_create",
        artifact: {
          draft_id: "ticket-1",
          issue_type: "malfunction",
          issue_summary: "吸奶器无法启动",
        },
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.quickReplies).toBeUndefined();
  });

  it("can defer artifact rendering to the caller", () => {
    let messages: ChatMessage[] = [
      {
        id: "reply",
        role: "mai",
        content: "",
        timestamp: "",
        quickReplies: [
          { text: "继续下一步", sendText: "继续下一步" },
          { text: "换个方案", sendText: "换个方案" },
          { text: "先总结", sendText: "先总结" },
        ],
      },
    ];
    const deferred: unknown[] = [];
    const setMessages = (updater: SetStateAction<ChatMessage[]>) => {
      messages = typeof updater === "function" ? updater(messages) : updater;
    };

    const result = applyAgUiStreamSideEffects(
      "reply",
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "birth_plan_card_intake",
        artifact_type: "form",
        tool_call_id: "call-form",
        tool_call_name: "birth_plan_form_create",
        artifact: {
          id: "birth_plan_card_intake",
          title: "信息采集",
          fields: [],
        },
      },
      setMessages,
      {
        deferAgUiArtifacts: true,
        onAgUiArtifactRichText: (payload) => deferred.push(payload),
      },
    );

    expect(result.didUpdate).toBe(true);
    expect(messages[0].richText).toBeUndefined();
    expect(messages[0].streamRenderItems).toBeUndefined();
    expect(messages[0].quickReplies).toHaveLength(3);
    expect(deferred).toHaveLength(1);
  });

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

  it("uses the short thinking status copy for model response requests", () => {
    const semantic = semanticForAgUiEvent({
      type: "CUSTOM",
      name: "momcozy.agent.status",
      value: "Requesting model response.",
    });

    expect(semantic.label).toBe("我想一下");
  });

  it("shows an optimistic work panel row as soon as a run starts", () => {
    const msg = applyEvents([
      {
        type: "RUN_STARTED",
        metadata: { status: "Agent loop started." },
        semantic: {
          phase: "thinking",
          label: "我在接收你的消息～",
          visibility: "status",
          merge_key: "run:run_1",
          priority: 10,
        },
      },
    ]);

    expect(msg.agentStatusLine).toBe("");
    expect(typeof msg.agentWorkStartedAtMs).toBe("number");
    expect(msg.agentWorkFinishedAtMs).toBeUndefined();
    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      id: "run:started-work",
      name: "run_started",
      title: "我已经收到你的消息啦～",
      state: "running",
    });
  });

  it("replaces the optimistic run row when real tool work starts", () => {
    const msg = applyEvents([
      {
        type: "RUN_STARTED",
        metadata: { status: "Agent loop started." },
      },
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_1",
        tool_call_name: "milk_records_query",
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      id: "tool:call_1",
      name: "milk_records_query",
      title: "我先看看吸奶和喂养记录～",
      state: "running",
    });
    expect(msg.agentToolCalls?.some((row) => row.name === "run_started")).toBe(false);
  });

  it("completes the optimistic run row for direct text replies without tool work", () => {
    const msg = applyEvents([
      {
        type: "RUN_STARTED",
        metadata: { status: "Agent loop started." },
      },
      {
        type: "TEXT_MESSAGE_CONTENT",
        message_id: "reply",
        delta: "好的。",
      },
      {
        type: "RUN_FINISHED",
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      id: "run:started-work",
      state: "completed",
    });
    expect(typeof msg.agentWorkFinishedAtMs).toBe("number");
  });

  it("maps tool work to specific user-facing work panel text", () => {
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
      title: "我把吸奶和喂养记录整理好啦",
      state: "completed",
    });
    expect(msg.agentToolCalls?.[0].title).not.toContain("milk_records_query");
    expect(msg.agentToolCalls?.[0].title).not.toMatch(/Milk|Tool|records/i);
  });

  it("maps web search process events to one user-facing work row", () => {
    const msg = applyEvents([
      {
        type: "RUN_STARTED",
        semantic: {
          phase: "thinking",
          label: "我已经收到你的消息啦～",
          visibility: "status",
          merge_key: "run:run_1",
          priority: 10,
        },
      },
      {
        type: "CUSTOM",
        name: "momcozy.agent.web_search",
        value: {
          type: "agent.web_search",
          status: "searching",
          label: "我在查专业资料～",
        },
        semantic: {
          phase: "reading",
          label: "我在查专业资料～",
          visibility: "work_item",
          merge_key: "web_search:current",
          priority: 55,
        },
      },
      {
        type: "CUSTOM",
        name: "momcozy.agent.web_search",
        value: {
          type: "agent.web_search",
          status: "completed",
          label: "我查好专业资料啦",
        },
        semantic: {
          phase: "done",
          label: "我查好专业资料啦",
          visibility: "work_item",
          merge_key: "web_search:current",
          priority: 55,
        },
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      id: "web_search:current",
      name: "web_search",
      title: "我查好专业资料啦",
      state: "completed",
    });
    expect(msg.agentToolCalls?.some((row) => row.name === "run_started")).toBe(false);
  });

  it("prefers backend semantic labels over frontend fallback labels", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_1",
        tool_call_name: "milk_records_query",
        semantic: {
          phase: "reading",
          label: "我正在看最近 7 天奶量记录",
          visibility: "work_item",
          merge_key: "tool:call_1",
          priority: 50,
        },
      },
    ]);

    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "milk_records_query",
      title: "我正在看最近 7 天奶量记录",
      state: "running",
    });
  });

  it("keeps every AG-UI event mappable to a semantic object", () => {
    expect(
      semanticForAgUiEvent({
        type: "ARTIFACT_CREATED",
        artifact_id: "milk-plan-1",
        artifact_type: "milk_plan_card",
      }),
    ).toMatchObject({
      phase: "done",
      label: "我已经整理好奶量计划啦",
      visibility: "artifact",
      mergeKey: "artifact:milk-plan-1",
    });
    expect(
      semanticForAgUiEvent({
        type: "RUN_ERROR",
        code: "RuntimeError",
      }),
    ).toMatchObject({
      phase: "error",
      label: "这轮暂时没处理好",
      visibility: "status",
    });
  });

  it("uses explicit user-facing labels for pump recommendation work", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_pump",
        tool_call_name: "hospital_bag_pump_recommend",
      },
      {
        type: "TOOL_CALL_END",
        tool_call_id: "call_pump",
        tool_call_name: "hospital_bag_pump_recommend",
      },
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_pump",
        tool_call_name: "hospital_bag_pump_recommend",
        content: JSON.stringify({
          status: "pump_recommended",
          tool_name: "hospital_bag_pump_recommend",
          recommended_product: { model: "S12 Pro Quick" },
        }),
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "hospital_bag_pump_recommend",
      title: "我已经帮你整理好吸奶器推荐啦",
      state: "completed",
    });
  });

  it("uses explicit user-facing labels for hospital bag cart updates", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_cart",
        tool_call_name: "hospital_bag_cart_update",
      },
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_cart",
        tool_call_name: "hospital_bag_cart_update",
        content: JSON.stringify({
          status: "cart_updated",
          tool_name: "hospital_bag_cart_update",
          cart_update: { action: "replace_pump_model", groups: [] },
        }),
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "hospital_bag_cart_update",
      title: "我已经帮你更新好待产包购物车啦",
      state: "completed",
    });
  });

  it("uses explicit user-facing labels for generated hospital bag lists", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_bag",
        tool_call_name: "hospital_bag_card_create",
      },
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_bag",
        tool_call_name: "hospital_bag_card_create",
        content: JSON.stringify({
          ok: true,
          status: "card_created",
          tool_name: "hospital_bag_card_create",
          card: { card_type: "hospital_bag_card" },
        }),
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "hospital_bag_card_create",
      title: "我已经帮你生成好待产包清单啦",
      state: "completed",
    });
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

  it("updates the existing milk plan card when the plan is confirmed", () => {
    let messages: ChatMessage[] = [
      {
        id: "previous",
        role: "mai",
        content: "",
        timestamp: "",
        richText: {
          title: "",
          content: "",
          button: [],
          card: [],
          action: [
            {
              kind: "ag_ui_artifact",
              artifact_type: "card",
              artifact_id: "milk-plan-increase_milk-7",
              card: {
                id: "milk-plan-increase_milk-7",
                card_type: "milk_plan_card",
                schema_version: "1.0",
                card_json: {
                  title: "追奶计划",
                  status_label: "待确认",
                },
              },
            },
          ],
        },
        streamRenderItems: [
          {
            kind: "rich",
            payload: {
              title: "",
              content: "",
              button: [],
              card: [],
              action: [
                {
                  kind: "ag_ui_artifact",
                  artifact_type: "card",
                  artifact_id: "milk-plan-increase_milk-7",
                  card: {
                    id: "milk-plan-increase_milk-7",
                    card_type: "milk_plan_card",
                    schema_version: "1.0",
                    card_json: {
                      title: "追奶计划",
                      status_label: "待确认",
                    },
                  },
                },
              ],
            },
          },
        ],
      },
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

    applyAgUiStreamSideEffects(
      "reply",
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_save",
        tool_call_name: "milk_plan_mutate",
        content: JSON.stringify({
          ok: true,
          tool_name: "milk_plan_mutate",
          status: "plan_created",
          card: {
            id: "milk-plan-increase_milk-7",
            card_type: "milk_plan_card",
            schema_version: "1.0",
            card_json: {
              title: "追奶计划",
              status_label: "已确认",
              status: "confirmed",
            },
          },
        }),
      },
      setMessages,
    );

    const action = messages[0].richText?.action[0] as Record<string, unknown>;
    const card = action.card as Record<string, unknown>;
    expect((card.card_json as Record<string, unknown>).status_label).toBe("已确认");
    const streamAction = messages[0].streamRenderItems?.[0].kind === "rich"
      ? (messages[0].streamRenderItems[0].payload.action[0] as Record<string, unknown>)
      : null;
    expect(((streamAction?.card as Record<string, unknown>).card_json as Record<string, unknown>).status_label).toBe("已确认");
    expect(messages[1].richText).toBeUndefined();
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
      title: "我需要你确认一下，再继续处理",
      argsDigest: "我已经准备好相关内容，等你确认。",
      state: "completed",
    });
    expect(msg.agentToolCalls?.[0].title).not.toContain("milk_plan_preview");
  });

  it("keeps intermediate text in the assistant bubble when an artifact arrives", () => {
    const msg = applyEventSequence([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_skill",
        tool_call_name: "load_skill",
        content: JSON.stringify({ ok: true, tool_name: "load_skill" }),
      },
      (message) => ({
        ...message,
        content: "我先帮你整理成一份更贴合你情况的待产包清单",
        streamRenderItems: [
          {
            kind: "text",
            text: "我先帮你整理成一份更贴合你情况的待产包清单",
          },
        ],
      }),
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "card_1",
        artifact_type: "hospital_bag_card",
        tool_call_id: "call_card",
        tool_call_name: "hospital_bag_card_create",
        artifact: { id: "card_1", card_type: "hospital_bag_card", card_json: { title: "待产包" } },
      },
    ]);

    expect(msg.content).toBe("我先帮你整理成一份更贴合你情况的待产包清单");
    expect(msg.streamRenderItems?.[0]).toMatchObject({
      kind: "text",
      text: "我先帮你整理成一份更贴合你情况的待产包清单",
    });
    expect(msg.streamRenderItems?.[1]).toMatchObject({ kind: "rich" });
    expect(msg.agentToolCalls?.some((item) => item.kind === "narration")).toBe(false);
    expect(msg.richText?.action).toHaveLength(1);
  });
});
