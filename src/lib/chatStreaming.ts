/**
 * 对话 SSE 流式正文：合并策略与从 data 载荷中取文本（供 Agent Hub 等共用）。
 */

const ANSWER_KEYS = ["answer", "delta", "text", "content", "message"] as const;

/**
 * 合并流式片段：若新文本以旧正文为前缀则视为服务端「累计全文」模式并直接覆盖；否则视为增量拼接。
 * @param previous 当前已展示的完整正文
 * @param chunk 本轮 SSE 解析出的片段（可能为累计全文或增量）
 * @returns 合并后的完整正文
 */
export function mergeStreamingAnswer(previous: string, chunk: string): string {
  if (!chunk) return previous;
  if (!previous) return chunk;
  if (chunk.startsWith(previous)) return chunk;
  return previous + chunk;
}

/**
 * 在 `mergeStreamingAnswer` 语义下，计算本轮相对「已合并正文」的新增片段，供打字机按字符入队。
 * @param previous 当前已合并的完整正文（与 SSE 协议一致，非 UI 已打出字数）
 * @param chunk 本轮 SSE 解析出的片段（可能为累计全文或增量）
 * @returns `merged` 新的完整正文、`delta` 本轮应追加到打字机队列的文本
 */
export function mergeStreamingAnswerDelta(
  previous: string,
  chunk: string,
): { merged: string; delta: string } {
  const merged = mergeStreamingAnswer(previous, chunk);
  if (!chunk) return { merged, delta: "" };
  if (!previous) return { merged, delta: merged };
  // 累计全文：新正文为 chunk，增量为去掉旧前缀后的后缀
  if (chunk.startsWith(previous)) return { merged, delta: merged.slice(previous.length) };
  // 纯增量拼接：delta 即本轮 chunk
  return { merged, delta: chunk };
}

/**
 * 从 SSE 单条 data（JSON 对象或原始字符串）中取出可拼接到气泡的文本。
 * 兼容常见字段名；非 JSON 字符串则视为整段正文增量。
 * @param data streamSSE 传入的解析结果
 * @returns 本轮文本；无则返回 ""
 */
export function extractChatAnswerChunk(data: string | object): string {
  if (typeof data === "string") {
    const t = data.trim();
    if (!t) return "";
    try {
      const o = JSON.parse(t) as Record<string, unknown>;
      return extractFromObject(o);
    } catch {
      return t;
    }
  }
  if (typeof data === "object" && data != null) {
    return extractFromObject(data as Record<string, unknown>);
  }
  return "";
}

/**
 * 从扁平 JSON 对象中取第一个非空字符串字段。
 * @param d 解析后的对象
 * @returns 文本或 ""
 */
function extractFromObject(d: Record<string, unknown>): string {
  for (const k of ANSWER_KEYS) {
    const v = d[k];
    if (typeof v === "string" && v.length > 0) return v;
  }
  return "";
}
