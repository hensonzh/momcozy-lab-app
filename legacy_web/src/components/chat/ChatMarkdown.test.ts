import { describe, expect, it } from "vitest";
import {
  linkifyBareSkillAssetUrlsForMarkdown,
  resolveChatMarkdownImageSrc,
  resolveChatMarkdownMediaViewerKind,
  stripHospitalBagCartPreviewLinks,
} from "@/components/chat/ChatMarkdown";

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

  it("resolves skill asset markdown images through the API asset route", () => {
    expect(resolveChatMarkdownImageSrc("/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png")).toBe(
      "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png",
    );
  });

  it("routes pdf and video markdown links to the media viewer", () => {
    expect(resolveChatMarkdownMediaViewerKind("/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf")).toBe("pdf");
    expect(resolveChatMarkdownMediaViewerKind("/skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4")).toBe("video");
  });

  it("removes the hospital bag cart text link while keeping surrounding copy", () => {
    const input =
      "你的待产包已经设计好了哦～我顺手把清单里适合直接购买的妈妈/宝宝用品整理到了购物车。\n\n" +
      "**[打开待产包一键打包下单页](/hospital-bag-cart)**";

    expect(stripHospitalBagCartPreviewLinks(input)).toBe(
      "你的待产包已经设计好了哦～我顺手把清单里适合直接购买的妈妈/宝宝用品整理到了购物车。",
    );
  });

  it("removes bare hospital bag cart links from preview-only text", () => {
    expect(stripHospitalBagCartPreviewLinks("/hospital-bag-cart?tab=ready")).toBe("");
  });
});
