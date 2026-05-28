import { describe, expect, it } from "vitest";
import { buildSpeakableTextForVoice, createVoiceTextStreamFilter, sanitizeTextForVoice } from "@/lib/chatBubbleTtsPlayback";
import type { ChatMessage } from "@/types/chat";

describe("sanitizeTextForVoice", () => {
  it("keeps readable markdown link labels and removes their urls", () => {
    expect(sanitizeTextForVoice("请看 [查看报告](https://example.com/report?id=1)。")).toBe("请看 查看报告 。");
  });

  it("removes bare urls without speaking the address", () => {
    expect(sanitizeTextForVoice("详情见 https://example.com/a?x=1 或 www.example.com/path。")).toBe("详情见 或 。");
  });

  it("does not speak markdown link labels that are urls", () => {
    expect(sanitizeTextForVoice("[https://example.com](https://example.com) 已生成")).toBe("已生成");
  });

  it("keeps readable markdown labels for app routes and removes route urls", () => {
    expect(sanitizeTextForVoice("请看 [待产包清单](/hospital-bag-cart?tab=ready)。")).toBe("请看 待产包清单 。");
    expect(sanitizeTextForVoice("请打开 /hospital-bag-cart?tab=ready 查看。")).toBe("请打开 查看。");
  });

  it("removes markdown and decorative symbols that should not be spoken", () => {
    expect(sanitizeTextForVoice("## **重点**\n- 每天 6-8 次，80ml/次\n> 详情：`code` | A/B")).toBe(
      "重点 每天 6到8 次，80ml 每次 详情： A B",
    );
  });

  it("removes unfinished markdown markers left by streaming cuts", () => {
    expect(sanitizeTextForVoice("**重点：每天 80ml/次。")).toBe("重点：每天 80ml 每次。");
  });

  it("normalizes tilde ranges before removing markup symbols", () => {
    expect(sanitizeTextForVoice("建议每天 6~8 次。")).toBe("建议每天 6到8 次。");
  });
});

describe("createVoiceTextStreamFilter", () => {
  it("skips a markdown link href split across streaming deltas", () => {
    const filter = createVoiceTextStreamFilter();

    expect(filter.push("请看 [待产包清单](")).toBe("请看  待产包清单 ");
    expect(filter.push("/hospital-bag-cart?tab=ready")).toBe("");
    expect(filter.push(")，然后继续。")).toBe("  ，然后继续。");
    expect(filter.flush()).toBe("");
  });

  it("skips a bare url split across streaming deltas", () => {
    const filter = createVoiceTextStreamFilter();

    expect(filter.push("详情见 https://exa")).toBe("详情见 ");
    expect(filter.push("mple.com/report?id=1")).toBe("");
    expect(filter.push(" 再继续。")).toBe("  再继续。");
    expect(filter.flush()).toBe("");
  });
});

describe("buildSpeakableTextForVoice", () => {
  it("includes rich text title and content when message body is empty", () => {
    const msg: ChatMessage = {
      id: "m1",
      role: "mai",
      content: "",
      timestamp: "",
      richText: {
        title: "待产包清单",
        content: "我已经帮你整理好了。",
        button: [{ label: "查看", action: "navigate", value: "/hospital-bag-cart" }],
      },
    };

    expect(buildSpeakableTextForVoice(msg)).toBe("待产包清单 我已经帮你整理好了。");
  });
});
