/**
 * 将助手/用户正文按与后端约定的分隔符拆成多段，用于多气泡展示。
 * 分隔符为单独一行、大小写不敏感的 `data`（前后可为空白，两侧为换行）。
 */

const DATA_LINE_DELIMITER = /\r?\n\s*data\s*\r?\n/i;

/**
 * 以单独一行的 `data` 为分隔符拆分对话正文，去掉空段。
 * @param text 原始正文（可含 Markdown）
 * @returns 非空段落数组；无内容时返回 []
 */
export function splitChatContentByDataDelimiter(text: string): string[] {
  const trimmed = text.trim();
  if (!trimmed) return [];
  const parts = trimmed.split(DATA_LINE_DELIMITER);
  return parts.map((p) => p.trim()).filter((p) => p.length > 0);
}
