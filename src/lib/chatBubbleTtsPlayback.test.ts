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

  it("removes media file names and resource paths", () => {
    expect(
      sanitizeTextForVoice("请看 pump_step_3.png 和 /skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4。"),
    ).toBe("请看 和 。");
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

  it("skips markdown image alt text split across streaming deltas", () => {
    const filter = createVoiceTextStreamFilter();

    expect(filter.push("先看这张图：!")).toBe("先看这张图：");
    expect(filter.push("[Air1 核心部件](")).toBe("");
    expect(filter.push("/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png")).toBe("");
    expect(filter.push(")，然后继续。")).toBe(" ，然后继续。");
    expect(filter.flush()).toBe("");
  });

  it("speaks explicit media narration when markdown image url matches", () => {
    const filter = createVoiceTextStreamFilter({
      mediaNarrationResolver: ({ url }) =>
        url === "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png"
          ? "我放了一张当前步骤的对照图，你可以边看图边完成这一步。"
          : undefined,
    });

    expect(filter.push("先看这张图：!")).toBe("先看这张图：");
    expect(filter.push("[Air1 核心部件](")).toBe("");
    expect(filter.push("/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png")).toBe("");
    expect(filter.push(")，然后继续。")).toBe(" 我放了一张当前步骤的对照图，你可以边看图边完成这一步。 ，然后继续。");
    expect(filter.flush()).toBe("");
  });

  it("speaks explicit media narration for markdown links to images", () => {
    const filter = createVoiceTextStreamFilter({
      mediaNarrationResolver: ({ url }) =>
        url === "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png"
          ? "我放了一张当前步骤的对照图，你可以边看图边完成这一步。"
          : undefined,
    });

    expect(filter.push("先看 [查看图片](/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png)，然后继续。")).toBe(
      "先看  我放了一张当前步骤的对照图，你可以边看图边完成这一步。 ，然后继续。",
    );
    expect(filter.flush()).toBe("");
  });

  it("speaks explicit media narration for bare media paths", () => {
    const filter = createVoiceTextStreamFilter({
      mediaNarrationResolver: ({ url }) =>
        url === "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png"
          ? "我放了一张当前步骤的对照图，你可以边看图边完成这一步。"
          : undefined,
    });

    expect(filter.push("先看 /skill-assets/device-guidance/air1/images/air1_guide_parts_components.png，然后继续。")).toBe(
      "先看 我放了一张当前步骤的对照图，你可以边看图边完成这一步。 ，然后继续。",
    );
    expect(filter.flush()).toBe("");
  });

  it("speaks explicit media narration for bare absolute media urls", () => {
    const filter = createVoiceTextStreamFilter({
      mediaNarrationResolver: ({ url }) =>
        url === "http://127.0.0.1:17769/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png"
          ? "我放了一张当前步骤的对照图，你可以边看图边完成这一步。"
          : undefined,
    });

    expect(filter.push("先看 http://127.0.0.1:17769/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png，然后继续。")).toBe(
      "先看 我放了一张当前步骤的对照图，你可以边看图边完成这一步。 ，然后继续。",
    );
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

  it("speaks explicit media narration labels but not silent media", () => {
    const msg: ChatMessage = {
      id: "m2",
      role: "mai",
      content: "我放了一张步骤图。",
      timestamp: "",
      richText: {
        title: "",
        content: "",
        button: [],
        card: [],
        action: [],
        voice: [
          {
            mediaId: "step-image",
            kind: "image",
            voicePolicy: "announce",
            spokenLabel: "我放了一张阀门安装方向图，你可以对照检查。",
          },
          {
            mediaId: "product-image",
            kind: "image",
            voicePolicy: "silent",
            spokenLabel: "Momcozy M9 产品图。",
          },
        ],
      },
    };

    expect(buildSpeakableTextForVoice(msg)).toBe("我放了一张步骤图。 我放了一张阀门安装方向图，你可以对照检查。");
  });

  it("deduplicates media narration mirrored in stream render items", () => {
    const voice = [
      {
        mediaId: "step-image",
        kind: "image",
        voicePolicy: "announce" as const,
        spokenLabel: "我放了一张阀门安装方向图，你可以对照检查。",
      },
    ];
    const msg: ChatMessage = {
      id: "m3",
      role: "mai",
      content: "",
      timestamp: "",
      richText: { title: "", content: "", button: [], card: [], action: [], voice },
      streamRenderItems: [{ kind: "rich", payload: { title: "", content: "", button: [], card: [], action: [], voice } }],
    };

    expect(buildSpeakableTextForVoice(msg)).toBe("我放了一张阀门安装方向图，你可以对照检查。");
  });
});
