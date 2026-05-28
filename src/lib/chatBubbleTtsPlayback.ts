/**
 * Agent Hub 对话泡可播报文本构造。
 * 实际播放统一由火山实时语音流处理，当前文件不再包含第三方语音服务调用。
 */
import { splitChatContentByDataDelimiter } from "@/lib/chatContentSegments";
import type { ChatMessage } from "@/types/chat";

/** 气泡与手动语音播报可朗读正文最大字符数。 */
export const CHAT_BUBBLE_VOICE_MAX_CHARS = 4096;

const VOICE_BARE_URL_PATTERN =
  /\b(?:(?:https?|ftp):\/\/|www\.)[^\s<>"'，。！？；、]+/gi;
const VOICE_APP_RELATIVE_URL_PATTERN =
  /(^|[\s(（\[])\/[A-Za-z][^\s<>"'，。！？；、)]*/g;
const VOICE_HASH_OR_QUERY_URL_PATTERN =
  /(^|[\s(（\[])[?#][A-Za-z0-9_=&%./:%+-][^\s<>"'，。！？；、)]*/g;
const VOICE_BARE_DOMAIN_URL_LIKE_PATTERN =
  /\b(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、]*)?$/i;
const VOICE_BARE_DOMAIN_URL_PATTERN =
  /\b(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、]*)?/gi;
const VOICE_STREAM_TRAILING_URL_LIKE_PATTERN =
  /(^|[\s(（\[])(((?:https?|ftp):\/\/|www\.)[^\s<>"'，。！？；、)]*|\/[A-Za-z][^\s<>"'，。！？；、)]*|(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、)]*)?)$/i;

function isVoiceUrlLike(value: string): boolean {
  const text = value.trim();
  if (!text) return false;
  return /^(?:(?:https?|ftp):\/\/|www\.)/i.test(text) || VOICE_BARE_DOMAIN_URL_LIKE_PATTERN.test(text);
}

function markdownVoiceLinkLabelReplacement(_m: string, label: string): string {
  const L = (label || "").trim();
  if (!L || isVoiceUrlLike(L)) return " ";
  return ` ${L} `;
}

function stripLinksForVoiceText(s: string): string {
  let t = s;
  // Markdown 图片：行内式与参考式
  t = t.replace(/!\[[^\]]*]\([^)]*\)/g, " ");
  t = t.replace(/!\[[^\]]*]\s*\[[^\]]*]/g, " ");
  // Markdown 链接：仅保留可见文案；空文案或文案为 URL 则不读
  t = t.replace(/\[([^\]]*)\]\([^)]*\)/g, markdownVoiceLinkLabelReplacement);
  // 流式输出中 Markdown 链接可能先到达 `[文案](`，此时保留文案，后续 URL 由流式过滤器跳过。
  t = t.replace(/\[([^\]]+)\]\(\s*$/g, markdownVoiceLinkLabelReplacement);
  // 尖括号自动链接 <https://...>
  t = t.replace(/<(?:https?|ftp):\/\/[^>\s]+>/gi, " ");
  // 裸 URL 与站内路由：不朗读地址本身。
  t = t.replace(VOICE_BARE_URL_PATTERN, " ");
  t = t.replace(VOICE_APP_RELATIVE_URL_PATTERN, "$1 ");
  t = t.replace(VOICE_HASH_OR_QUERY_URL_PATTERN, "$1 ");
  t = t.replace(VOICE_BARE_DOMAIN_URL_PATTERN, " ");
  // 流式 Markdown 链接拆分后可能只剩目的地址右括号，清掉孤立闭合符号。
  t = t.replace(/(^|[\s(（\[])[)\]](?=($|[\s，。！？；、,.!?;:]))/g, "$1 ");
  return t;
}

function normalizeSlashForVoiceText(s: string): string {
  let t = s;
  // 常见日期：5/28 -> 5月28日
  t = t.replace(/(^|[^\d])(\d{1,2})\s*\/\s*(\d{1,2})(?=$|[^\d])/g, "$1$2月$3日");
  // 常见母婴/健康单位：ml/次、次/天 -> ml 每次、次 每天
  t = t.replace(
    /((?:\d+(?:\.\d+)?\s*)?(?:ml|mL|ML|g|kg|oz|cm|mm|分钟|小时|天|周|月|次|侧|边|度|℃))\s*\/\s*(次|天|日|周|月|侧|边|小时|分钟|min|h)/g,
    "$1 每$2",
  );
  t = t.replace(/(次|顿|餐|片|粒|袋|瓶)\s*\/\s*(天|日|周|月|次)/g, "$1 每$2");
  return t.replace(/\s*\/\s*/g, " ");
}

function stripVoiceMarkupAndSymbols(s: string): string {
  let t = s;
  // Markdown 删除线、粗体、斜体：保留内部文字。
  t = t.replace(/~~([^~]+)~~/g, "$1");
  t = t.replace(/\*{1,2}([^*\n]+)\*{1,2}/g, "$1");
  t = t.replace(/_{1,2}([^_\n]+)_{1,2}/g, "$1");
  // 数字范围：6-8 次、6~8 次 -> 6到8 次。
  t = t.replace(/(\d)\s*[-~～]\s*(\d)/g, "$1到$2");
  // 流式切段可能留下未闭合 Markdown 标记，直接去掉符号本身。
  t = t.replace(/[*_~`]+/g, " ");
  // 装饰/结构符号不适合朗读，保留符号两侧文字。
  t = t.replace(/[\\|#>{}\[\]<>]/g, " ");
  t = t.replace(/[()（）【】「」『』“”"'‘’]/g, " ");
  t = t.replace(/={2,}|-{2,}|—{2,}|_{2,}/g, " ");
  return t;
}

function findIncompleteMarkdownVoiceLinkHoldStart(text: string): number {
  const openLabel = text.lastIndexOf("[");
  if (openLabel < 0) return -1;
  const closeLabel = text.indexOf("]", openLabel + 1);
  if (closeLabel < 0) return openLabel;
  if (closeLabel === text.length - 1) return openLabel;
  if (text[closeLabel + 1] !== "(") return -1;
  const destinationStart = closeLabel + 2;
  const closeDestination = text.indexOf(")", destinationStart);
  if (closeDestination >= 0) return -1;
  return destinationStart;
}

function findTrailingVoiceUrlLikeHoldStart(text: string): number {
  const match = text.match(VOICE_STREAM_TRAILING_URL_LIKE_PATTERN);
  if (!match || match.index == null) return -1;
  return match.index + (match[1]?.length ?? 0);
}

function findVoiceStreamHoldStart(text: string): number {
  const starts = [
    findIncompleteMarkdownVoiceLinkHoldStart(text),
    findTrailingVoiceUrlLikeHoldStart(text),
  ].filter((start) => start >= 0);
  return starts.length > 0 ? Math.min(...starts) : -1;
}

export type VoiceTextStreamFilter = {
  push: (delta: string) => string;
  flush: () => string;
};

/**
 * 为流式语音播报准备文本：保留普通文本和 Markdown 链接文案，跳过链接地址。
 * 只暂存未完成的链接 token，避免 URL 被拆成多轮 delta 后漏进 TTS。
 */
export function createVoiceTextStreamFilter(): VoiceTextStreamFilter {
  let pending = "";

  const drain = (force: boolean): string => {
    if (!pending) return "";
    if (force) {
      const ready = pending;
      pending = "";
      return stripLinksForVoiceText(ready);
    }

    const holdStart = findVoiceStreamHoldStart(pending);
    if (holdStart < 0) {
      const ready = pending;
      pending = "";
      return stripLinksForVoiceText(ready);
    }
    if (holdStart === 0) return "";

    const ready = pending.slice(0, holdStart);
    pending = pending.slice(holdStart);
    return stripLinksForVoiceText(ready);
  };

  return {
    push(delta: string) {
      if (!delta) return "";
      pending += delta;
      return drain(false);
    },
    flush() {
      return drain(true);
    },
  };
}

/**
 * 净化为适合语音合成的纯文本：去掉 HTML、图片、链接中的 URL、代码块等；富文本里的按键文案在 buildSpeakableTextForVoice 中单独排除。
 * @param s 原始文本
 * @returns 净化后的单行化近似纯文本
 */
export function sanitizeTextForVoice(s: string): string {
  if (!s) return "";
  let t = s;
  t = t.replace(/&nbsp;|&#160;/gi, " ");
  t = t.replace(/&amp;/gi, "和");
  t = t.replace(/&(lt|gt|quot|apos);/gi, " ");
  // HTML 标签（按钮、图片、卡片容器等）
  t = t.replace(/<[^>]+>/g, " ");
  // HTML 注释
  t = t.replace(/<!--[\s\S]*?-->/g, " ");
  t = stripLinksForVoiceText(t);
  t = normalizeSlashForVoiceText(t);
  // 行内代码与围栏代码
  t = t.replace(/```[\s\S]*?```/g, " ");
  t = t.replace(/`{1,3}[^`]*`{1,3}/g, " ");
  // 标题、引用、列表标记弱化
  t = t.replace(/^#{1,6}\s+/gm, "");
  t = t.replace(/^>\s?/gm, "");
  t = t.replace(/^\s*[-*+]\s+/gm, "");
  t = t.replace(/^\s*[•·]\s+/gm, "");
  t = t.replace(/^\s*\d+[.)、]\s+/gm, "");
  t = stripVoiceMarkupAndSymbols(t);
  t = t.replace(/\r?\n+/g, " ");
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

/**
 * 从一条对话消息构造可送语音合成的纯文本（多段合并 + 富文本标题/说明；不含按键文案与图片类噪声）。
 * @param msg Hub 消息
 * @returns 非空则可用于合成；否则空串
 */
export function buildSpeakableTextForVoice(msg: ChatMessage): string {
  const parts = splitChatContentByDataDelimiter(msg.content);
  const bodyRaw = parts.length > 0 ? parts.join(" ") : msg.content.trim();
  const chunks: string[] = [bodyRaw];
  if (msg.richText) {
    const rt = msg.richText;
    // 仅朗读标题与说明正文，不朗读 rich_text 中的按钮
    if (rt.title) chunks.push(rt.title);
    if (rt.content) chunks.push(rt.content);
  }
  return sanitizeTextForVoice(chunks.filter(Boolean).join(" "));
}

/**
 * 旧气泡音频文件播放器已移除。保留该 no-op 便于统一清理调用点。
 * @returns Promise<void>
 */
export async function stopChatBubblePlayback(): Promise<void> {
  return;
}
