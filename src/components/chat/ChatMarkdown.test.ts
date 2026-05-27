import { describe, expect, it } from "vitest";
import { linkifyBareSkillAssetUrlsForMarkdown } from "@/components/chat/ChatMarkdown";

describe("linkifyBareSkillAssetUrlsForMarkdown", () => {
  it("turns bare skill asset paths into readable markdown links", () => {
    const input =
      "Air1 Quick Start Guide： /skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf\n" +
      "Air1 中文操作视频： /skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4";

    expect(linkifyBareSkillAssetUrlsForMarkdown(input)).toBe(
      "Air1 Quick Start Guide： [打开 PDF](/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf)\n" +
        "Air1 中文操作视频： [打开视频](/skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4)",
    );
  });

  it("does not rewrite paths that are already markdown links or fenced code", () => {
    const input =
      "[快速指南](/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf)\n" +
      "```\n/skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4\n```";

    expect(linkifyBareSkillAssetUrlsForMarkdown(input)).toBe(input);
  });
});
