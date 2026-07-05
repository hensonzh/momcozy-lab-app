import { describe, expect, it } from "vitest";
import {
  chatScrollDistanceFromTail,
  isChatScrollNearTail,
  shouldAutoScrollChatTail,
} from "./chatAutoScroll";

describe("chatAutoScroll", () => {
  it("calculates the remaining distance to the latest content", () => {
    expect(chatScrollDistanceFromTail({ scrollHeight: 1200, scrollTop: 700, clientHeight: 400 })).toBe(100);
  });

  it("clamps overscrolled layouts to zero distance", () => {
    expect(chatScrollDistanceFromTail({ scrollHeight: 1000, scrollTop: 700, clientHeight: 400 })).toBe(0);
  });

  it("treats content within the tail threshold as near the latest content", () => {
    expect(isChatScrollNearTail({ scrollHeight: 1000, scrollTop: 531, clientHeight: 400 })).toBe(true);
    expect(isChatScrollNearTail({ scrollHeight: 1000, scrollTop: 520, clientHeight: 400 })).toBe(false);
  });

  it("keeps following the tail when a card makes the current bubble much taller", () => {
    expect(
      shouldAutoScrollChatTail({
        isNewBubble: false,
        forceTailAfterSend: false,
        wasPinnedToTail: true,
        isNearTailAfterUpdate: false,
      }),
    ).toBe(true);
  });

  it("does not pull the user away from history for a new bubble when they are not pinned", () => {
    expect(
      shouldAutoScrollChatTail({
        isNewBubble: true,
        forceTailAfterSend: false,
        wasPinnedToTail: false,
        isNearTailAfterUpdate: false,
      }),
    ).toBe(false);
  });

  it("still follows small streaming updates while near the tail", () => {
    expect(
      shouldAutoScrollChatTail({
        isNewBubble: false,
        forceTailAfterSend: false,
        wasPinnedToTail: false,
        isNearTailAfterUpdate: true,
      }),
    ).toBe(true);
  });

  it("forces tail scroll immediately after the user sends from the bottom bar", () => {
    expect(
      shouldAutoScrollChatTail({
        isNewBubble: true,
        forceTailAfterSend: true,
        wasPinnedToTail: false,
        isNearTailAfterUpdate: false,
      }),
    ).toBe(true);
  });
});
