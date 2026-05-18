/**
 * 专注模式 TTS：拉取服务端音频后以 HTMLAudioElement 播放，便于按 currentTime/duration 同步字幕；
 * 与 chatBubbleTtsPlayback（NativeAudio 单例）分离，避免与气泡播报互相抢占时无法细粒度打断。
 */
import { fetchTtsAudio } from "@/lib/agentApi";
import { sanitizeTextForTts } from "@/lib/chatBubbleTtsPlayback";

let activeAudio: HTMLAudioElement | null = null;
let activeObjectUrl: string | null = null;

/** 句读类切分点，用于首段尽量落在完整短句末尾 */
const HEAD_SEGMENT_SENTENCE_END = /[。！？…；.!?]/;

/**
 * 将已净化的可读 TTS 文本切成「首段 + 剩余」，首段不超过 maxChars，优先在句读处截断。
 * @param text sanitize 后的单行化文本
 * @param maxChars 首段最大字符数（建议 80～160）
 * @returns head 首段、tail 剩余（可能为空）
 */
export function splitSpeakableTextForHeadSegment(text: string, maxChars: number): { head: string; tail: string } {
  const t = text.trim();
  if (!t || maxChars < 1) return { head: t, tail: "" };
  if (t.length <= maxChars) return { head: t, tail: "" };
  const window = t.slice(0, maxChars + 1);
  let cut = -1;
  const minBack = Math.min(24, Math.floor(maxChars * 0.35));
  for (let i = maxChars; i >= minBack; i--) {
    const ch = window[i - 1] ?? "";
    if (HEAD_SEGMENT_SENTENCE_END.test(ch)) {
      cut = i;
      break;
    }
  }
  if (cut < 0) {
    const sp = window.lastIndexOf(" ", maxChars);
    if (sp > Math.floor(maxChars * 0.4)) cut = sp + 1;
    else cut = maxChars;
  }
  let head = t.slice(0, cut).trimEnd();
  let tail = t.slice(cut).trimStart();
  if (!head) {
    head = t.slice(0, maxChars);
    tail = t.slice(maxChars).trimStart();
  }
  if (!tail) return { head: t, tail: "" };
  return { head, tail };
}

/**
 * 停止专注模式当前音频：暂停、卸载并回收 Blob URL。
 * @returns Promise<void>
 */
export async function stopFocusVoicePlayback(): Promise<void> {
  if (activeAudio) {
    try {
      activeAudio.pause();
    } catch {
      /* noop */
    }
    activeAudio.src = "";
    activeAudio = null;
  }
  if (activeObjectUrl) {
    URL.revokeObjectURL(activeObjectUrl);
    activeObjectUrl = null;
  }
}

export type PlayFocusPlainTextTtsParams = {
  /** 与 chat API 一致的 user_id */
  userId: string;
  /** 待合成全文 */
  text: string;
  /** 取消或打断时中止拉流 */
  signal?: AbortSignal;
  /**
   * 按播放进度回调当前应展示的字幕前缀（与音频同步）。
   * @param revealed 已「露出」的字符子串
   */
  onSubtitle: (revealed: string) => void;
  /**
   * 为 true（默认）时按播放进度驱动 onSubtitle 并挂 RAF；为 false 时不驱动字幕（Hub 并行播报等场景）。
   */
  syncSubtitle?: boolean;
  /**
   * 大于 0 时启用「首段 + 剩余」两次请求：首段先播以降低首响延迟，剩余段与首段拉流并行请求、顺序播放。
   * 专注模式可不传，保持单次全文合成。
   */
  firstSegmentMaxChars?: number;
};

/** 分段播放时：字幕按全文累计，本段从 revealOffset 起算时长比例 */
type TtsSubtitleCumulative = { fullSpeakable: string; revealOffset: number };

/**
 * 播放单段 TTS Blob（内部复用）：卸载上一段、绑定字幕与 ended。
 * @param blob 服务端返回的音频
 * @param speakText 本段字幕文本（与音频等长，用于 syncSubtitle 比例）
 * @param params 信号与字幕选项
 * @param cumulative 可选；多段连续播时按全文露出，避免第二段字幕从尾段开头重置
 * @returns Promise<void> 自然播完 resolve；abort 抛 AbortError
 */
function playTtsBlobOnce(
  blob: Blob,
  speakText: string,
  params: Pick<PlayFocusPlainTextTtsParams, "signal" | "onSubtitle" | "syncSubtitle">,
  cumulative?: TtsSubtitleCumulative,
): Promise<void> {
  if (params.signal?.aborted) {
    return Promise.reject(new DOMException("aborted", "AbortError"));
  }

  return stopFocusVoicePlayback().then(() => {
    if (params.signal?.aborted) {
      throw new DOMException("aborted", "AbortError");
    }
    const url = URL.createObjectURL(blob);
    activeObjectUrl = url;

    const audio = new Audio();
    audio.src = url;
    audio.preload = "auto";
    activeAudio = audio;

    const full = speakText;
    let rafId: number | null = null;
    const syncSubtitle = params.syncSubtitle !== false;

    const tickSubtitle = () => {
      const d = audio.duration;
      if (!Number.isFinite(d) || d <= 0) {
        if (cumulative) {
          const end = Math.min(cumulative.fullSpeakable.length, cumulative.revealOffset + full.length);
          params.onSubtitle(cumulative.fullSpeakable.slice(0, end));
        } else {
          params.onSubtitle(full);
        }
        return;
      }
      const t = Math.min(Math.max(audio.currentTime, 0), d);
      const ratio = t / d;
      const segN = Math.min(full.length, Math.ceil(full.length * ratio));
      if (cumulative) {
        const total = Math.min(cumulative.fullSpeakable.length, cumulative.revealOffset + segN);
        params.onSubtitle(cumulative.fullSpeakable.slice(0, total));
      } else {
        params.onSubtitle(full.slice(0, segN));
      }
    };

    const rafLoop = () => {
      tickSubtitle();
      if (!audio.paused && !audio.ended) {
        rafId = requestAnimationFrame(rafLoop);
      }
    };

    const stopRaf = () => {
      if (rafId != null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
    };

    return new Promise<void>((resolve, reject) => {
      const onAbort = () => {
        stopRaf();
        void stopFocusVoicePlayback().then(() => {
          reject(new DOMException("aborted", "AbortError"));
        });
      };
      params.signal?.addEventListener("abort", onAbort);

      const cleanup = () => {
        stopRaf();
        params.signal?.removeEventListener("abort", onAbort);
        if (syncSubtitle) {
          audio.removeEventListener("timeupdate", tickSubtitle);
        }
        audio.removeEventListener("pause", onPause);
        audio.removeEventListener("ended", onEnded);
        audio.removeEventListener("error", onError);
      };

      const onPause = () => {
        stopRaf();
        if (syncSubtitle) tickSubtitle();
      };

      const onEnded = () => {
        if (cumulative) {
          const end = Math.min(cumulative.fullSpeakable.length, cumulative.revealOffset + full.length);
          params.onSubtitle(cumulative.fullSpeakable.slice(0, end));
        } else {
          params.onSubtitle(full);
        }
        cleanup();
        void stopFocusVoicePlayback().then(() => resolve());
      };

      const onError = () => {
        cleanup();
        void stopFocusVoicePlayback().then(() => {
          reject(new Error("音频播放失败"));
        });
      };

      if (syncSubtitle) {
        audio.addEventListener("timeupdate", tickSubtitle);
      }
      audio.addEventListener("pause", onPause);
      audio.addEventListener("ended", onEnded);
      audio.addEventListener("error", onError);

      void audio
        .play()
        .then(() => {
          if (!syncSubtitle) return;
          tickSubtitle();
          if (!audio.paused) {
            stopRaf();
            rafId = requestAnimationFrame(rafLoop);
          }
        })
        .catch((e: unknown) => {
          cleanup();
          void stopFocusVoicePlayback();
          reject(e instanceof Error ? e : new Error(String(e)));
        });
    });
  });
}

/**
 * 拉取 TTS 音频并以 HTMLAudio 播放；通过 timeupdate 按时长比例 Reveal 全文（可由 syncSubtitle 关闭）。
 * 若 `firstSegmentMaxChars > 0` 且正文超过该长度：先请求并播放首段，**在开始播首段的同时**再请求尾段，尾段下载与首段播放重叠。
 * 自然播完 resolve；abort 或 stopFocusVoicePlayback 抛 AbortError。
 * @param params 用户、文案、AbortSignal、字幕与可选分段
 * @returns Promise<void>
 */
export async function playFocusPlainTextTts(params: PlayFocusPlainTextTtsParams): Promise<void> {
  await stopFocusVoicePlayback();
  if (params.signal?.aborted) {
    throw new DOMException("aborted", "AbortError");
  }

  const speakText = sanitizeTextForTts(params.text);
  if (!speakText) {
    throw new Error("暂无可播报的文字");
  }

  const maxFirst = params.firstSegmentMaxChars ?? 0;
  if (maxFirst > 0 && speakText.length > maxFirst) {
    const { head, tail } = splitSpeakableTextForHeadSegment(speakText, maxFirst);
    if (tail) {
      const { blob: headBlob } = await fetchTtsAudio(params.userId, head, { signal: params.signal });
      const tailFetchPromise = fetchTtsAudio(params.userId, tail, { signal: params.signal });
      const cumHead =
        params.syncSubtitle !== false ? { fullSpeakable: speakText, revealOffset: 0 } : undefined;
      await playTtsBlobOnce(headBlob, head, params, cumHead);
      if (params.signal?.aborted) {
        throw new DOMException("aborted", "AbortError");
      }
      const { blob: tailBlob } = await tailFetchPromise;
      const tailStart = tail.length > 0 ? speakText.indexOf(tail) : -1;
      const tailRevealOffset = tailStart >= 0 ? tailStart : head.length;
      const cumTail =
        params.syncSubtitle !== false
          ? { fullSpeakable: speakText, revealOffset: tailRevealOffset }
          : undefined;
      await playTtsBlobOnce(tailBlob, tail, params, cumTail);
      return;
    }
  }

  const { blob } = await fetchTtsAudio(params.userId, speakText, { signal: params.signal });
  await playTtsBlobOnce(blob, speakText, params);
}
