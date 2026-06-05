import {
  clampChatHistoryStart,
  latestChatHistoryStart,
  previousChatHistoryStart,
  scrollTopForPreservedAnchor,
} from "./chatHistoryWindow";

describe("chatHistoryWindow", () => {
  it("clamps the visible start to the latest page upper bound", () => {
    expect(clampChatHistoryStart(25, 10, 99)).toBe(15);
    expect(clampChatHistoryStart(25, 10, -5)).toBe(0);
  });

  it("keeps short histories anchored at the beginning", () => {
    expect(clampChatHistoryStart(6, 10, 3)).toBe(0);
  });

  it("returns the latest visible page start", () => {
    expect(latestChatHistoryStart(25, 10)).toBe(15);
    expect(latestChatHistoryStart(6, 10)).toBe(0);
  });

  it("moves to the previous history page without crossing the first message", () => {
    expect(previousChatHistoryStart(15, 10)).toBe(5);
    expect(previousChatHistoryStart(5, 10)).toBe(0);
  });

  it("calculates scrollTop needed to keep the same message anchor in place", () => {
    expect(scrollTopForPreservedAnchor(120, 40, 240)).toBe(320);
    expect(scrollTopForPreservedAnchor(120, 240, 40)).toBe(0);
  });
});
