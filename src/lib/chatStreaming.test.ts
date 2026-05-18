import { describe, expect, it } from "vitest";
import { extractChatAnswerChunk, mergeStreamingAnswer, mergeStreamingAnswerDelta } from "./chatStreaming";

describe("mergeStreamingAnswer", () => {
  it("增量拼接", () => {
    expect(mergeStreamingAnswer("你好", "世界")).toBe("你好世界");
  });

  it("累计全文覆盖（新文本以旧正文为前缀）", () => {
    expect(mergeStreamingAnswer("你好", "你好世界")).toBe("你好世界");
  });

  it("首轮仅片段", () => {
    expect(mergeStreamingAnswer("", "第一段")).toBe("第一段");
  });
});

describe("mergeStreamingAnswerDelta", () => {
  it("累计全文时 delta 仅为新增后缀", () => {
    expect(mergeStreamingAnswerDelta("你好", "你好世界")).toEqual({ merged: "你好世界", delta: "世界" });
  });

  it("纯增量时 delta 为整段 chunk", () => {
    expect(mergeStreamingAnswerDelta("你好", "世界")).toEqual({ merged: "你好世界", delta: "世界" });
  });

  it("首轮 delta 等于 merged", () => {
    expect(mergeStreamingAnswerDelta("", "首包")).toEqual({ merged: "首包", delta: "首包" });
  });
});

describe("extractChatAnswerChunk", () => {
  it("从 answer 取值", () => {
    expect(extractChatAnswerChunk({ answer: "x" })).toBe("x");
  });

  it("优先顺序中第一个非空字段", () => {
    expect(extractChatAnswerChunk({ answer: "", delta: "d" })).toBe("d");
  });

  it("JSON 字符串", () => {
    expect(extractChatAnswerChunk('{"text":"hi"}')).toBe("hi");
  });

  it("非 JSON 字符串原样为片段", () => {
    expect(extractChatAnswerChunk("plain")).toBe("plain");
  });
});
