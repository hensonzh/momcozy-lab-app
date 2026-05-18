/**
 * Agent Hub 对话泡 TTS：拉取服务端语音二进制，使用 @capgo/native-audio 在原生端播放；
 * Web 开发环境同样走 NativeAudio（blob URL），与真机行为一致。
 */
import { Capacitor, type PluginListenerHandle } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { NativeAudio } from "@capgo/native-audio";
import { fetchTtsAudio } from "@/lib/agentApi";
import { splitChatContentByDataDelimiter } from "@/lib/chatContentSegments";
import type { ChatMessage } from "@/types/chat";

const TTS_SUBDIR = "tts_bubble_cache";
/** 气泡与手动 TTS 可朗读正文最大字符数（与后端能力对齐） */
export const CHAT_BUBBLE_TTS_MAX_CHARS = 8000;

/** 是否已对 Native Audio 做过一次性配置（仅原生） */
let nativeAudioConfigured = false;

let activeAssetId: string | null = null;
let activeObjectUrl: string | null = null;
let activeNativeRelativePath: string | null = null;
let activeListener: PluginListenerHandle | null = null;

/**
 * ArrayBuffer 转 base64（写入 Filesystem）。
 * @param buffer 二进制缓冲
 * @returns base64 字符串
 */
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

/**
 * 根据服务端文件名或 Blob MIME 猜测音频扩展名。
 * @param fileName Content-Disposition 文件名（可选）
 * @param mime Blob.type（可选）
 * @returns 不含点的扩展名，默认 mp3
 */
function guessAudioExtension(fileName: string | undefined, mime: string): string {
  if (fileName) {
    const m = /\.([a-z0-9]+)$/i.exec(fileName.trim());
    if (m) return m[1].toLowerCase();
  }
  const mt = mime.split(";")[0]?.trim().toLowerCase() || "";
  if (mt.includes("mpeg") || mt.includes("mp3")) return "mp3";
  if (mt.includes("wav")) return "wav";
  if (mt.includes("aac")) return "aac";
  if (mt.includes("ogg")) return "ogg";
  return "mp3";
}

/**
 * 净化为适合语音合成的纯文本：去掉 HTML、图片、链接中的 URL、代码块等；富文本里的按键文案在 buildSpeakableTextForTts 中单独排除。
 * @param s 原始文本
 * @returns 净化后的单行化近似纯文本
 */
export function sanitizeTextForTts(s: string): string {
  if (!s) return "";
  let t = s;
  // HTML 标签（按钮、图片、卡片容器等）
  t = t.replace(/<[^>]+>/g, " ");
  // HTML 注释
  t = t.replace(/<!--[\s\S]*?-->/g, " ");
  // Markdown 图片：行内式与参考式
  t = t.replace(/!\[[^\]]*]\([^)]*\)/g, " ");
  t = t.replace(/!\[[^\]]*]\s*\[[^\]]*]/g, " ");
  // Markdown 链接：仅保留可见文案；空文案或文案为 URL 则不读
  t = t.replace(/\[([^\]]*)\]\([^)]*\)/g, (_m, label: string) => {
    const L = (label || "").trim();
    if (!L || /^https?:\/\//i.test(L)) return " ";
    return L;
  });
  // 尖括号自动链接 <https://...>
  t = t.replace(/<https?:\/\/[^>\s]+>/gi, " ");
  // 行内代码与围栏代码
  t = t.replace(/`{1,3}[^`]*`{1,3}/g, " ");
  // 粗体、斜体（保留内部文字）
  t = t.replace(/\*{1,2}([^*]+)\*{1,2}/g, "$1");
  t = t.replace(/_{1,2}([^_]+)_{1,2}/g, "$1");
  // 标题、引用、列表标记弱化
  t = t.replace(/^#{1,6}\s+/gm, "");
  t = t.replace(/^>\s?/gm, "");
  t = t.replace(/^\s*[-*+]\s+/gm, "");
  t = t.replace(/^\s*\d+\.\s+/gm, "");
  // 表格竖线
  t = t.replace(/\|/g, " ");
  t = t.replace(/\r?\n+/g, " ");
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

/**
 * 从一条对话消息构造可送 TTS 的纯文本（多段合并 + 富文本标题/说明；不含按键文案与图片类噪声）。
 * @param msg Hub 消息
 * @returns 非空则可用于合成；否则空串
 */
export function buildSpeakableTextForTts(msg: ChatMessage): string {
  const parts = splitChatContentByDataDelimiter(msg.content);
  const bodyRaw = parts.length > 0 ? parts.join(" ") : msg.content.trim();
  const chunks: string[] = [bodyRaw];
  if (msg.richText) {
    const rt = msg.richText;
    // 仅朗读标题与说明正文，不朗读 rich_text 中的按钮
    if (rt.title) chunks.push(rt.title);
    if (rt.content) chunks.push(rt.content);
  }
  return sanitizeTextForTts(chunks.filter(Boolean).join(" "));
}

/**
 * 将 TTS Blob 写入 Cache 子目录并返回 Filesystem URI（供 NativeAudio 使用）。
 * @param blob 音频二进制
 * @param ext 扩展名（无点）
 * @returns uri 与相对路径（用于播放后删除）
 */
async function writeBlobToTtsCache(
  blob: Blob,
  ext: string,
): Promise<{ uri: string; relativePath: string }> {
  const buf = await blob.arrayBuffer();
  const name = `tts_${Date.now()}_${Math.random().toString(36).slice(2, 10)}.${ext}`;
  const relativePath = `${TTS_SUBDIR}/${name}`;
  await Filesystem.writeFile({
    path: relativePath,
    directory: Directory.Cache,
    data: arrayBufferToBase64(buf),
    recursive: true,
  });
  const { uri } = await Filesystem.getUri({
    path: relativePath,
    directory: Directory.Cache,
  });
  return { uri, relativePath };
}

/**
 * 删除单次 TTS 缓存文件。
 * @param relativePath writeBlobToTtsCache 返回的 relativePath
 */
async function deleteTtsCacheFile(relativePath: string): Promise<void> {
  try {
    await Filesystem.deleteFile({
      path: relativePath,
      directory: Directory.Cache,
    });
  } catch {
    /* 已删或不存在 */
  }
}

/**
 * 原生端一次性配置：语音对话泡不抢占系统「正在播放」通知，仅请求音频焦点便于听清。
 * @returns Promise<void>
 */
async function ensureNativeAudioConfigured(): Promise<void> {
  if (!Capacitor.isNativePlatform() || nativeAudioConfigured) return;
  await NativeAudio.configure({
    focus: true,
    showNotification: false,
  });
  nativeAudioConfigured = true;
}

/**
 * 停止当前对话泡 TTS（切换气泡、重复点击或组件卸载时调用）。
 * @returns Promise<void>
 */
export async function stopChatBubblePlayback(): Promise<void> {
  if (activeListener) {
    try {
      await activeListener.remove();
    } catch {
      /* noop */
    }
    activeListener = null;
  }
  if (activeAssetId) {
    try {
      await NativeAudio.stop({ assetId: activeAssetId });
    } catch {
      /* noop */
    }
    try {
      await NativeAudio.unload({ assetId: activeAssetId });
    } catch {
      /* noop */
    }
    activeAssetId = null;
  }
  if (activeNativeRelativePath) {
    await deleteTtsCacheFile(activeNativeRelativePath);
    activeNativeRelativePath = null;
  }
  if (activeObjectUrl) {
    URL.revokeObjectURL(activeObjectUrl);
    activeObjectUrl = null;
  }
}

/**
 * 拉取 TTS 并使用 Native Audio 播放，播完 resolve；失败 reject。
 * @param params.message 当前气泡消息
 * @param params.userId 与 chat API 一致的 user_id
 * @param params.signal 取消拉流或打断时 AbortSignal
 * @returns Promise<void> 自然播放结束时 fulfilled
 */
export async function playChatBubbleTts(params: {
  message: ChatMessage;
  userId: string;
  signal?: AbortSignal;
}): Promise<void> {
  await stopChatBubblePlayback();
  if (params.signal?.aborted) {
    throw new DOMException("aborted", "AbortError");
  }

  const text = buildSpeakableTextForTts(params.message).slice(0, CHAT_BUBBLE_TTS_MAX_CHARS);
  if (!text) {
    throw new Error("暂无可播报的文字");
  }

  await ensureNativeAudioConfigured();

  // 调用 TTS API 获取音频二进制
  const { blob, fileName } = await fetchTtsAudio(params.userId, text, { signal: params.signal });

  let assetPath: string;
  // 如果是原生平台，则将音频二进制写入缓存
  // 否则创建 Blob URL
  const isUrl = true;
  if (Capacitor.isNativePlatform()) {
    const ext = guessAudioExtension(fileName, blob.type);
    const { uri, relativePath } = await writeBlobToTtsCache(blob, ext);
    assetPath = uri;
    activeNativeRelativePath = relativePath;
  } else {
    activeObjectUrl = URL.createObjectURL(blob);
    assetPath = activeObjectUrl;
  }

  const assetId = `mai_bubble_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;

  await NativeAudio.preload({
    assetId,
    assetPath,
    isUrl,
    audioChannelNum: 1,
    volume: 1,
  });
  activeAssetId = assetId;

  return new Promise((resolve, reject) => {
    const onAbort = () => {
      void stopChatBubblePlayback().then(() => {
        reject(new DOMException("aborted", "AbortError"));
      });
    };
    params.signal?.addEventListener("abort", onAbort);

    void (async () => {
      try {
        let listenerHandle: PluginListenerHandle | undefined;
        listenerHandle = await NativeAudio.addListener("complete", async (ev) => {
          if (ev.assetId !== assetId) return;
          params.signal?.removeEventListener("abort", onAbort);
          try {
            await listenerHandle?.remove();
          } catch {
            /* noop */
          }
          activeListener = null;
          try {
            await NativeAudio.unload({ assetId });
          } catch {
            /* noop */
          }
          activeAssetId = null;
          if (activeNativeRelativePath) {
            await deleteTtsCacheFile(activeNativeRelativePath);
            activeNativeRelativePath = null;
          }
          if (activeObjectUrl) {
            URL.revokeObjectURL(activeObjectUrl);
            activeObjectUrl = null;
          }
          resolve();
        });
        activeListener = listenerHandle;
        await NativeAudio.play({ assetId });
      } catch (e: unknown) {
        params.signal?.removeEventListener("abort", onAbort);
        await stopChatBubblePlayback();
        reject(e instanceof Error ? e : new Error(String(e)));
      }
    })();
  });
}
