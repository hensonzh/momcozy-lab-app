export function normalizeChatHistoryPageSize(pageSize: number): number {
  if (!Number.isFinite(pageSize)) return 1;
  return Math.max(1, Math.floor(pageSize));
}

export function clampChatHistoryStart(messageCount: number, pageSize: number, startIndex: number): number {
  const count = Math.max(0, Math.floor(Number.isFinite(messageCount) ? messageCount : 0));
  const size = normalizeChatHistoryPageSize(pageSize);
  const upper = Math.max(0, count - size);
  const start = Math.floor(Number.isFinite(startIndex) ? startIndex : 0);
  return Math.min(Math.max(0, start), upper);
}

export function previousChatHistoryStart(startIndex: number, pageSize: number): number {
  const start = Math.floor(Number.isFinite(startIndex) ? startIndex : 0);
  return Math.max(0, start - normalizeChatHistoryPageSize(pageSize));
}

export function scrollTopForPreservedAnchor(
  currentScrollTop: number,
  anchorTopBefore: number,
  anchorTopAfter: number,
): number {
  const top = Number.isFinite(currentScrollTop) ? currentScrollTop : 0;
  const before = Number.isFinite(anchorTopBefore) ? anchorTopBefore : 0;
  const after = Number.isFinite(anchorTopAfter) ? anchorTopAfter : before;
  return Math.max(0, top + (after - before));
}
