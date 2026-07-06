import { describe, expect, it } from "vitest";
import {
  buildSpeakableTextForMediaVoice,
  fallbackMediaVoiceNarration,
  mediaVoiceLookupKeys,
  normalizeMediaVoiceNarrationItems,
} from "@/lib/mediaVoiceNarration";

describe("mediaVoiceLookupKeys", () => {
  it("matches relative and absolute skill asset urls by pathname", () => {
    const relative = "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png";
    const absolute = "http://127.0.0.1:17769/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png";

    expect(mediaVoiceLookupKeys(relative)).toContain(relative);
    expect(mediaVoiceLookupKeys(absolute)).toContain(relative);
  });

  it("adds queryless keys for media urls with query or hash", () => {
    const path = "/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png";
    const keys = mediaVoiceLookupKeys(`${path}?v=demo#step`);

    expect(keys).toContain(`${path}?v=demo`);
    expect(keys).toContain(path);
  });
});

describe("media voice narration payloads", () => {
  it("normalizes snake case payloads and only speaks announce/read_text items", () => {
    const items = normalizeMediaVoiceNarrationItems([
      {
        media_id: "step-image",
        voice_policy: "announce",
        spoken_label: "我放了一张当前步骤的对照图。",
      },
      {
        media_id: "decorative-image",
        voice_policy: "silent",
        spoken_label: "这句不应该播。",
      },
    ]);

    expect(items[0]).toMatchObject({
      mediaId: "step-image",
      voicePolicy: "announce",
      spokenLabel: "我放了一张当前步骤的对照图。",
    });
    expect(buildSpeakableTextForMediaVoice(items)).toBe("我放了一张当前步骤的对照图。");
  });
});

describe("fallbackMediaVoiceNarration", () => {
  it("speaks device guidance step images without reading their filenames", () => {
    expect(
      fallbackMediaVoiceNarration(
        "http://127.0.0.1:17769/skill-assets/device-guidance/air1/images/air1_guide_charging_status.png",
      ),
    ).toBe("我放了一张当前步骤的对照图，你可以边看图边完成这一步。");
  });

  it("does not speak non-image device resources", () => {
    expect(fallbackMediaVoiceNarration("/skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4")).toBeUndefined();
    expect(
      fallbackMediaVoiceNarration("/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf"),
    ).toBeUndefined();
  });
});
