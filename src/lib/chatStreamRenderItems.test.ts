import { describe, expect, it } from "vitest";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";
import type { ChatStreamRenderItem } from "@/types/chat";
import {
  appendTextRenderItem,
  appendTextRenderItemBeforeAgUiArtifacts,
  richTextPayloadHasAgUiArtifact,
} from "@/lib/chatStreamRenderItems";

function agUiArtifactPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "card",
        artifact_id: "birth_journey_1",
        card: { card_type: "birth_journey_plan_card" },
      },
    ],
  };
}

function plainRichPayload(): ChatRichTextPayload {
  return {
    title: "提示",
    content: "普通富文本",
    button: [],
    card: [],
    action: [],
  };
}

describe("chat stream render item ordering", () => {
  it("detects ag-ui artifact payloads", () => {
    expect(richTextPayloadHasAgUiArtifact(agUiArtifactPayload())).toBe(true);
    expect(richTextPayloadHasAgUiArtifact(plainRichPayload())).toBe(false);
  });

  it("appends text to the last text item when there is no artifact", () => {
    expect(appendTextRenderItem([{ kind: "text", text: "孕期" }], "计划")).toEqual([
      { kind: "text", text: "孕期计划" },
    ]);
  });

  it("keeps later final text before an already rendered artifact", () => {
    const artifact: ChatStreamRenderItem = { kind: "rich", payload: agUiArtifactPayload() };
    const items: ChatStreamRenderItem[] = [
      { kind: "text", text: "孕期" },
      artifact,
    ];

    expect(appendTextRenderItemBeforeAgUiArtifacts(items, "计划我整理好了。")).toEqual([
      { kind: "text", text: "孕期计划我整理好了。" },
      artifact,
    ]);
  });

  it("inserts final text before the first artifact when no text precedes it", () => {
    const artifact: ChatStreamRenderItem = { kind: "rich", payload: agUiArtifactPayload() };

    expect(appendTextRenderItemBeforeAgUiArtifacts([artifact], "我整理好了。")).toEqual([
      { kind: "text", text: "我整理好了。" },
      artifact,
    ]);
  });
});
