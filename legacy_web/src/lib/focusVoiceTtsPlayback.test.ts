import { describe, expect, it } from "vitest";
import { splitRealtimeVoiceReadySegments } from "@/lib/focusVoiceTtsPlayback";

describe("splitRealtimeVoiceReadySegments", () => {
  it("emits a ready Chinese sentence and keeps the unfinished tail", () => {
    const result = splitRealtimeVoiceReadySegments("好的，我会先帮你看一下。接下来继续", {
      maxChars: 90,
      minChars: 24,
    });

    expect(result.segments).toEqual(["好的，我会先帮你看一下。"]);
    expect(result.rest).toBe("接下来继续");
  });

  it("cuts long text at a soft break before the max segment length", () => {
    const result = splitRealtimeVoiceReadySegments("这是一段比较长的说明内容，需要先在逗号处切开，然后继续等待后面的文字", {
      maxChars: 24,
      minChars: 8,
    });

    expect(result.segments).toEqual(["这是一段比较长的说明内容，", "需要先在逗号处切开，"]);
    expect(result.rest).toBe("然后继续等待后面的文字");
  });

  it("flushes remaining text when forced", () => {
    const result = splitRealtimeVoiceReadySegments("最后还有半句没有句号", {
      force: true,
      maxChars: 90,
      minChars: 24,
    });

    expect(result.segments).toEqual(["最后还有半句没有句号"]);
    expect(result.rest).toBe("");
  });

  it("can eagerly emit a short first segment before punctuation", () => {
    const result = splitRealtimeVoiceReadySegments("这是一段前面没有标点的长句子后面才会继续", {
      eager: true,
      maxChars: 64,
      minChars: 12,
    });

    expect(result.segments).toEqual(["这是一段前面没有标点的长"]);
    expect(result.rest).toBe("句子后面才会继续");
  });

  it("does not emit an unfinished trailing url while streaming", () => {
    const result = splitRealtimeVoiceReadySegments("这里可以查看 https://exa", {
      eager: true,
      maxChars: 64,
      minChars: 6,
    });

    expect(result.segments).toEqual(["这里可以查看"]);
    expect(result.rest).toBe("https://exa");
  });

  it("removes complete urls from emitted segments", () => {
    const result = splitRealtimeVoiceReadySegments("更多信息见 https://example.com/docs。下一步继续", {
      maxChars: 64,
      minChars: 6,
    });

    expect(result.segments).toEqual(["更多信息见"]);
    expect(result.rest).toBe("下一步继续");
  });

  it("keeps media narration when splitting a complete media path", () => {
    const result = splitRealtimeVoiceReadySegments(
      "先看 /skill-assets/device-guidance/air1/images/air1_guide_parts_components.png。下一步继续",
      {
        maxChars: 120,
        minChars: 6,
        mediaNarrationResolver: ({ url }) =>
          url === "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png"
            ? "我放了一张当前步骤的对照图，你可以边看图边完成这一步。"
            : undefined,
      },
    );

    expect(result.segments).toEqual(["先看 我放了一张当前步骤的对照图，你可以边看图边完成这一步。 。"]);
    expect(result.rest).toBe("下一步继续");
  });

  it("does not emit an unfinished trailing app route while streaming", () => {
    const result = splitRealtimeVoiceReadySegments("这里可以查看 /hospital-bag", {
      eager: true,
      maxChars: 64,
      minChars: 6,
    });

    expect(result.segments).toEqual(["这里可以查看"]);
    expect(result.rest).toBe("/hospital-bag");
  });

  it("removes complete app route links from emitted segments", () => {
    const result = splitRealtimeVoiceReadySegments("打开 /hospital-bag-cart?tab=ready。下一步继续", {
      maxChars: 64,
      minChars: 6,
    });

    expect(result.segments).toEqual(["打开 。"]);
    expect(result.rest).toBe("下一步继续");
  });

  it("removes markdown markers and normalizes slash units in emitted segments", () => {
    const result = splitRealtimeVoiceReadySegments("**重点**：每天 80ml/次。下一步继续", {
      maxChars: 64,
      minChars: 6,
    });

    expect(result.segments).toEqual(["重点：", "每天 80ml 每次。"]);
    expect(result.rest).toBe("下一步继续");
  });
});
