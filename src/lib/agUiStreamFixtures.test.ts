import fs from "node:fs";
import { describe, expect, it } from "vitest";
import {
  parseChatRichTextFromSseData,
} from "@/lib/agentApi";
import {
  resolveAgUiEventType,
  semanticForAgUiEvent,
} from "@/lib/agUiStreamSideEffects";

type JsonRecord = Record<string, unknown>;

type WebSocketFrameFixture = {
  frame: string;
};

const fixturePath = (filename: string): string =>
  `${process.cwd()}/test/fixtures/ag_ui/${filename}`;

const readText = (filename: string): string =>
  fs.readFileSync(fixturePath(filename), "utf8");

const readJson = <T,>(filename: string): T =>
  JSON.parse(readText(filename)) as T;

const readJsonl = <T,>(filename: string): T[] =>
  readText(filename)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line) as T);

const parseEventStream = (raw: string): JsonRecord[] =>
  raw
    .split(/\r?\n\r?\n/)
    .flatMap((block) => {
      const data = block
        .split(/\r?\n/)
        .filter((line) => line.startsWith("data:"))
        .map((line) => line.slice(5).trim())
        .join("\n")
        .trim();
      return data ? [JSON.parse(data) as JsonRecord] : [];
    });

const parseWebSocketFrame = (frame: string): JsonRecord[] => {
  if (frame.includes("data:")) return parseEventStream(frame);
  const parsed = JSON.parse(frame) as unknown;
  return parsed && typeof parsed === "object" && !Array.isArray(parsed)
    ? [parsed as JsonRecord]
    : [];
};

const collectAllStreamEvents = (): JsonRecord[] => [
  readJson<JsonRecord>("run_started.json"),
  ...readJsonl<JsonRecord>("text_stream_basic.jsonl"),
  ...readJsonl<JsonRecord>("tool_call_lifecycle.jsonl"),
  readJson<JsonRecord>("activity_snapshot.json"),
  readJson<JsonRecord>("rich_text_artifact.json"),
  readJson<JsonRecord>("run_error.json"),
];

describe("AG-UI stream fixtures", () => {
  it("keeps text stream fixtures transport-agnostic across JSONL, SSE, and WebSocket frames", () => {
    const logicalEvents = readJsonl<JsonRecord>("text_stream_basic.jsonl");
    const sseEvents = parseEventStream(readText("text_stream_basic.eventstream"));
    const wsEvents = readJsonl<WebSocketFrameFixture>("text_stream_basic.websocket.jsonl")
      .flatMap((entry) => parseWebSocketFrame(entry.frame));

    expect(sseEvents).toEqual(logicalEvents);
    expect(wsEvents).toEqual(logicalEvents);
  });

  it("covers the required AG-UI event types for Flutter parser parity", () => {
    const eventTypes = new Set(collectAllStreamEvents().map((event) => resolveAgUiEventType(event)));

    for (const type of [
      "RUN_STARTED",
      "CUSTOM",
      "ACTIVITY_SNAPSHOT",
      "TOOL_CALL_START",
      "TOOL_CALL_ARGS",
      "TOOL_CALL_END",
      "TOOL_CALL_RESULT",
      "TEXT_MESSAGE_START",
      "TEXT_MESSAGE_CONTENT",
      "TEXT_MESSAGE_END",
      "RUN_FINISHED",
      "RUN_ERROR",
    ]) {
      expect(eventTypes.has(type), type).toBe(true);
    }
  });

  it("maps every stream event fixture to a semantic UI object", () => {
    for (const event of collectAllStreamEvents()) {
      const semantic = semanticForAgUiEvent(event, resolveAgUiEventType(event));
      expect(semantic.phase, JSON.stringify(event)).toBeTruthy();
      expect(semantic.visibility, JSON.stringify(event)).toBeTruthy();
      expect(semantic.mergeKey, JSON.stringify(event)).toBeTruthy();
    }
  });

  it("keeps tool lifecycle events merged by one stable tool_call_id without exposing raw args", () => {
    const toolEvents = readJsonl<JsonRecord>("tool_call_lifecycle.jsonl")
      .filter((event) => resolveAgUiEventType(event).startsWith("TOOL_CALL"));
    const toolCallIds = new Set(toolEvents.map((event) => event.tool_call_id));
    const argsEvent = toolEvents.find((event) => resolveAgUiEventType(event) === "TOOL_CALL_ARGS");

    expect(toolCallIds).toEqual(new Set(["call_pump_summary_001"]));
    expect(argsEvent).toMatchObject({
      args_summary: {
        date: "2026-06-29",
        side: "both",
      },
    });
    expect(argsEvent).not.toHaveProperty("args");
  });

  it("keeps artifact and outbound image payload fixtures safe and parseable", () => {
    const artifact = readJson<JsonRecord>("rich_text_artifact.json");
    const imagePayload = readJson<JsonRecord>("image_upload_message.json");
    const semantic = semanticForAgUiEvent(artifact, resolveAgUiEventType(artifact));

    expect(semantic).toMatchObject({
      visibility: "artifact",
      mergeKey: "artifact:milk-plan-001",
    });
    expect(parseChatRichTextFromSseData(artifact)).toMatchObject({
      title: "Milk supply plan",
    });
    expect(JSON.stringify(imagePayload)).not.toContain("token");
    expect(imagePayload).toMatchObject({
      messages: [
        {
          role: "user",
        },
      ],
    });
  });
});
