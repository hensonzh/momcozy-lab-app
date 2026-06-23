import { beforeEach, describe, expect, it } from "vitest";
import type { SetStateAction } from "react";
import { applyAgUiStreamSideEffects, semanticForAgUiEvent } from "@/lib/agUiStreamSideEffects";
import { BIRTH_JOURNEY_PLAN_DELETED_EVENT, BIRTH_JOURNEY_PLAN_UPDATED_EVENT } from "@/lib/birthJourneyPlanNotification";
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
  beforeEach(() => {
    localStorage.clear();
  });

  it("emits media voice metadata from tool results even without tool call keys", () => {
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
    const received: unknown[] = [];

    applyAgUiStreamSideEffects(
      "reply",
      {
        type: "TOOL_CALL_RESULT",
        content: JSON.stringify({
          ok: true,
          tool_name: "device_manual_search",
          media_voice: [
            {
              media_id: "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png",
              kind: "image",
              voice_policy: "announce",
              spoken_label: "我放了一张当前步骤的对照图，你可以边看图边完成这一步。",
            },
          ],
        }),
      },
      setMessages,
      {
        onMediaVoice: (items) => {
          received.push(...items);
        },
      },
    );

    expect(received).toHaveLength(1);
    expect(received[0]).toMatchObject({
      mediaId: "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png",
      voicePolicy: "announce",
      spokenLabel: "我放了一张当前步骤的对照图，你可以边看图边完成这一步。",
    });
  });

  it("applies quick replies only to the current assistant message", () => {
    let messages: ChatMessage[] = [
      {
        id: "old",
        role: "mai",
        content: "上一轮",
        timestamp: "",
        quickReplies: [
          { text: "旧提示1" },
          { text: "旧提示2" },
          { text: "旧提示3" },
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
          { text: "继续下一步" },
          { text: "换个方案" },
          { text: "先帮我总结" },
        ],
      },
      setMessages,
    );

    expect(messages[0].quickReplies).toBeUndefined();
    expect(messages[1].quickReplies).toEqual([
      { text: "继续下一步" },
      { text: "换个方案" },
      { text: "先帮我总结" },
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
          { text: "继续下一步" },
          { text: "换个方案" },
          { text: "先帮我总结" },
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
          { text: "我来填写" },
          { text: "先解释一下" },
          { text: "晚点再说" },
        ],
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.quickReplies).toBeUndefined();
  });

  it("applies quick replies to a message that contains a non-form card artifact", () => {
    const msg = applyEvents([
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "birth_journey_1",
        artifact_type: "birth_journey_plan_card",
        tool_call_id: "call-card",
        tool_call_name: "birth_journey_plan_card_create",
        artifact: {
          card_type: "birth_journey_plan_card",
          card_json: { title: "孕期计划" },
        },
      },
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "确认医院流程" },
          { text: "整理待产包" },
          { text: "做沟通单" },
        ],
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.quickReplies).toEqual([
      { text: "确认医院流程" },
      { text: "整理待产包" },
      { text: "做沟通单" },
    ]);
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
            {
              index: 3,
              title: "www.ncbi.nlm.nih.gov",
              url: "https://www.ncbi.nlm.nih.gov/books/NBK148970/",
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
        displayText: "ABM 哺乳医学临床指南：bfmed.org/protocols",
      },
      {
        index: 2,
        title: "www.ncbi.nlm.nih.gov",
        url: "https://www.ncbi.nlm.nih.gov/books/NBK148970/",
        displayText: "NCBI 医学资料：ncbi.nlm.nih.gov/books/...",
      },
    ]);
  });

  it("removes existing quick replies when a support ticket form artifact arrives", () => {
    const msg = applyEvents([
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "继续下一步" },
          { text: "换个方案" },
          { text: "先帮我总结" },
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

  it("keeps existing quick replies when a non-form card artifact arrives", () => {
    const msg = applyEvents([
      {
        type: "QUICK_REPLIES",
        message_id: "reply",
        replies: [
          { text: "确认医院流程" },
          { text: "整理待产包" },
          { text: "做沟通单" },
        ],
      },
      {
        type: "ARTIFACT_CREATED",
        artifact_id: "birth_journey_1",
        artifact_type: "birth_journey_plan_card",
        tool_call_id: "call-card",
        tool_call_name: "birth_journey_plan_card_create",
        artifact: {
          card_type: "birth_journey_plan_card",
          card_json: { title: "孕期计划" },
        },
      },
    ]);

    expect(msg.richText?.action).toHaveLength(1);
    expect(msg.quickReplies).toEqual([
      { text: "确认医院流程" },
      { text: "整理待产包" },
      { text: "做沟通单" },
    ]);
  });

  it("can defer artifact rendering to the caller", () => {
    let messages: ChatMessage[] = [
      {
        id: "reply",
        role: "mai",
        content: "",
        timestamp: "",
        quickReplies: [
          { text: "继续下一步" },
          { text: "换个方案" },
          { text: "先总结" },
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

  it("shows waiting-for-next-model-turn status while keeping generic processing hidden", () => {
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

    expect(msg.agentStatusLine).toBe("我接着处理下一步");
  });

  it("uses the short thinking status copy for model response requests", () => {
    const semantic = semanticForAgUiEvent({
      type: "CUSTOM",
      name: "momcozy.agent.status",
      value: "Requesting model response.",
    });

    expect(semantic.label).toBe("我想一下");
  });

  it("keeps custom thinking events out of the main status line", () => {
    const semantic = semanticForAgUiEvent({
      type: "CUSTOM",
      name: "momcozy.agent.thinking",
      value: { status: "started" },
      semantic: {
        phase: "thinking",
        label: "我想一下",
        visibility: "status",
        merge_key: "thinking:current",
        priority: 40,
      },
    });

    expect(semantic.label).toBe("我想一下");
    expect(semantic.visibility).toBe("hidden");

    const msg = applyEvents([
      {
        type: "RUN_STARTED",
        metadata: { status: "Agent loop started." },
      },
      {
        type: "CUSTOM",
        name: "momcozy.agent.thinking",
        value: { status: "started" },
        semantic: {
          phase: "thinking",
          label: "我想一下",
          visibility: "status",
          merge_key: "thinking:current",
          priority: 40,
        },
      },
    ]);

    expect(msg.agentStatusLine).toBe("我已经收到你的消息啦～");
  });

  it("uses confirmation-oriented copy for support ticket artifact semantics", () => {
    const semantic = semanticForAgUiEvent({
      type: "ARTIFACT_CREATED",
      artifact_id: "ticket-1",
      artifact_type: "support_ticket",
      tool_call_name: "support_ticket_draft_create",
    });

    expect(semantic.label).toBe("请确认售后信息");
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

    expect(msg.agentStatusLine).toBe("我在接收你的消息～");
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

  it("hides the status line when final text starts while preserving work rows", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_1",
        tool_call_name: "web_search",
      },
      {
        type: "CUSTOM",
        name: "momcozy.agent.status",
        value: "Searching professional sources.",
      },
      {
        type: "TEXT_MESSAGE_CONTENT",
        message_id: "reply",
        delta: "我",
      },
    ]);

    expect(msg.agentStatusDone).toBe(true);
    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      id: "tool:call_1",
      state: "running",
    });
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

  it("uses specific fallback labels for tool start events without backend semantics", () => {
    const cases = [
      ["profile_update", "我先帮你记一下基础信息～"],
      ["milk_analysis_intake_manage", "我先把关键信息核对齐全～"],
      ["milk_analysis_evaluate", "我来综合评估一下奶量问题～"],
      ["milk_plan_preview_create", "我先帮你拟一版奶量计划～"],
      ["birth_journey_intake_manage", "我先整理孕期计划信息～"],
      ["handoff_summary_generate", "我先整理转接摘要～"],
      ["run_approved_skill_script", "我按场景说明处理这一步～"],
    ] as const;

    for (const [toolName, expectedTitle] of cases) {
      const msg = applyEvents([
        {
          type: "TOOL_CALL_START",
          tool_call_id: `call_${toolName}`,
          tool_call_name: toolName,
        },
      ]);

      expect(msg.agentToolCalls?.[0]).toMatchObject({
        name: toolName,
        title: expectedTitle,
        state: "running",
      });
      expect(msg.agentToolCalls?.[0].title).not.toBe("我先处理这一步～");
    }
  });

  it("shows status semantic tool events as status text without adding work rows", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
        tool_call_id: "call_quick",
        tool_call_name: "ui_quick_replies_create",
        semantic: {
          phase: "planning",
          label: "我在帮你准备下一轮的快捷输入～",
          visibility: "status",
          merge_key: "quick_replies:call_quick",
          priority: 60,
        },
      },
    ]);

    expect(msg.agentStatusLine).toBe("我在帮你准备下一轮的快捷输入～");
    expect(msg.agentStatusDone).toBe(false);
    expect(msg.agentToolCalls ?? []).toHaveLength(0);
  });

  it("maps quick replies tool events to status semantics without backend metadata", () => {
    expect(
      semanticForAgUiEvent({
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_quick",
        tool_call_name: "ui_quick_replies_create",
      }),
    ).toMatchObject({
      phase: "done",
      label: "我帮你准备好下一轮的快捷输入啦",
      visibility: "status",
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

    expect(msg.agentStatusLine).toBe("我已经帮你整理好吸奶器推荐啦");
    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "hospital_bag_pump_recommend",
      title: "我已经帮你整理好吸奶器推荐啦",
      state: "completed",
    });
  });

  it("lets the latest visible semantic immediately replace the previous status text", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_START",
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
      {
        type: "CUSTOM",
        name: "momcozy.agent.status",
        value: "Requesting model response with tool outputs.",
      },
    ]);

    expect(msg.agentStatusLine).toBe("我接着处理下一步");
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

  it("does not render a blocked IBCLC tool result as a consult artifact", () => {
    const msg = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_ibclc",
        tool_call_name: "ibclc_consult_card_create",
        content: JSON.stringify({
          ok: true,
          tool_name: "ibclc_consult_card_create",
          status: "ibclc_consult_blocked",
          reason: "missing_explicit_ibclc_request",
          requires_user_confirmation: true,
          confirmation_question: "要我帮你打开 IBCLC 在线咨询入口吗？",
        }),
      },
    ]);

    expect(msg.richText).toBeUndefined();
    expect(msg.streamRenderItems).toBeUndefined();
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
        tool_call_name: "milk_plan_preview_create",
        artifact_id: "draft_1",
      },
    ]);

    expect(msg.agentToolCalls).toHaveLength(1);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      title: "我需要你确认一下，再继续处理",
      argsDigest: "我已经准备好相关内容，等你确认。",
      state: "completed",
    });
    expect(msg.agentToolCalls?.[0].title).not.toContain("milk_plan_preview_create");
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

  it("emits birth journey plan deleted event from the delete tool result", () => {
    const events: string[] = [];
    window.addEventListener(BIRTH_JOURNEY_PLAN_DELETED_EVENT, () => {
      events.push("deleted");
    }, { once: true });

    const msg = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_delete_birth_journey",
        tool_call_name: "birth_journey_plan_delete",
        content: JSON.stringify({
          ok: true,
          tool_name: "birth_journey_plan_delete",
          status: "plan_deleted",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(events).toEqual(["deleted"]);
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "birth_journey_plan_delete",
      title: "我已经删除孕期计划啦",
      state: "completed",
    });
  });

  it("emits birth journey plan updated event from todo completion tool result", () => {
    const events: string[] = [];
    window.addEventListener(BIRTH_JOURNEY_PLAN_UPDATED_EVENT, () => {
      events.push("updated");
    }, { once: true });

    const msg = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_birth_journey_todo",
        tool_call_name: "birth_journey_plan_todo_update",
        content: JSON.stringify({
          ok: true,
          tool_name: "birth_journey_plan_todo_update",
          status: "todo_completion_updated",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(events).toEqual(["updated"]);
    expect(localStorage.getItem("mmc_birth_journey_plan_nav_pending")).toContain('"reason":"updated"');
    expect(msg.agentToolCalls?.[0]).toMatchObject({
      name: "birth_journey_plan_todo_update",
      title: "我已经同步计划完成状态啦",
      state: "completed",
    });
  });

  it("marks pregnancy diary created and updated tool results as status notifications", () => {
    const created = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_create_diary",
        tool_call_name: "pregnancy_diary_manage",
        content: JSON.stringify({
          ok: true,
          tool_name: "pregnancy_diary_manage",
          status: "diary_entry_written",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBe("1");
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
    expect(created.agentToolCalls?.[0]).toMatchObject({
      name: "pregnancy_diary_manage",
      title: "我已经记录好孕期日记啦",
      state: "completed",
    });

    localStorage.clear();

    const legacyCreated = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_legacy_create_diary",
        tool_call_name: "pregnancy_diary_manage",
        content: JSON.stringify({
          ok: true,
          tool_name: "pregnancy_diary_manage",
          status: "diary_entry_created",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBe("1");
    expect(legacyCreated.agentToolCalls?.[0]).toMatchObject({
      name: "pregnancy_diary_manage",
      title: "我已经记录好孕期日记啦",
      state: "completed",
    });

    localStorage.clear();

    const updated = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_update_diary",
        tool_call_name: "pregnancy_diary_manage",
        content: JSON.stringify({
          ok: true,
          tool_name: "pregnancy_diary_manage",
          status: "diary_entry_updated",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBe("1");
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
    expect(updated.agentToolCalls?.[0]).toMatchObject({
      name: "pregnancy_diary_manage",
      title: "我已经修改好孕期日记啦",
      state: "completed",
    });

    localStorage.clear();

    const healthUpdated = applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_update_health_diary",
        tool_call_name: "pregnancy_diary_manage",
        content: JSON.stringify({
          ok: true,
          tool_name: "pregnancy_diary_manage",
          status: "health_consultation_updated",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBe("1");
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
    expect(healthUpdated.agentToolCalls?.[0]).toMatchObject({
      name: "pregnancy_diary_manage",
      title: "我已经记录到孕期日记啦",
      state: "completed",
    });
  });

  it("clears pregnancy diary notifications when the diary is deleted through the agent", () => {
    localStorage.setItem("mmc_pregnancy_diary_nav_pending", "1");
    localStorage.setItem("mmc_pregnancy_diary_card_label", "记录更新");

    applyEvents([
      {
        type: "TOOL_CALL_RESULT",
        tool_call_id: "call_delete_diary",
        tool_call_name: "pregnancy_diary_manage",
        content: JSON.stringify({
          ok: true,
          tool_name: "pregnancy_diary_manage",
          status: "diary_entry_deleted",
          side_effect_performed: true,
        }),
      },
    ]);

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
  });
});
