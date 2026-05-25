export type ChatScrollMetrics = {
  scrollHeight: number;
  scrollTop: number;
  clientHeight: number;
};

export const DEFAULT_CHAT_TAIL_THRESHOLD_PX = 80;

export function chatScrollDistanceFromTail(metrics: ChatScrollMetrics): number {
  return Math.max(0, metrics.scrollHeight - (metrics.scrollTop + metrics.clientHeight));
}

export function isChatScrollNearTail(
  metrics: ChatScrollMetrics,
  thresholdPx = DEFAULT_CHAT_TAIL_THRESHOLD_PX,
): boolean {
  return chatScrollDistanceFromTail(metrics) < thresholdPx;
}

export function shouldAutoScrollChatTail(input: {
  isNewBubble: boolean;
  forceTailAfterSend: boolean;
  wasPinnedToTail: boolean;
  isNearTailAfterUpdate: boolean;
}): boolean {
  if (input.forceTailAfterSend) return true;
  if (input.wasPinnedToTail) return true;
  if (!input.isNewBubble && input.isNearTailAfterUpdate) return true;
  return false;
}
