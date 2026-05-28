/**
 * 专注/Hub 语音播放：统一使用火山实时语音 PCM 流边收边播。
 */
import { fetchRealtimeVoicePcmStream, resolveRealtimeVoiceSessionWebSocketUrl } from "@/lib/agentApi";
import { createVoiceTextStreamFilter, sanitizeTextForVoice } from "@/lib/chatBubbleTtsPlayback";

let activeRealtimeAudioContext: AudioContext | null = null;
let activeRealtimeGain: GainNode | null = null;
let realtimeNextStartAt = 0;
let realtimeLastEndAt = 0;
const activeRealtimeSources = new Set<AudioBufferSourceNode>();

const REALTIME_VOICE_STRONG_END = /[。！？；!?]/;
const REALTIME_VOICE_SOFT_BREAK = /[，,、：:\s]/;
const REALTIME_VOICE_URL_TOKEN = /(^|[\s(（\[])(((?:https?|ftp):\/\/|www\.)[^\s<>"'，。！？；、)]*|\/[A-Za-z][^\s<>"'，。！？；、)]*|(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、)]*)?)/gi;
const REALTIME_VOICE_TRAILING_URL = /(^|[\s(（\[])(((?:https?|ftp):\/\/|www\.)[^\s<>"'，。！？；、)]*|\/[A-Za-z][^\s<>"'，。！？；、)]*|(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、)]*)?)$/i;
const REALTIME_VOICE_URL_TERMINATOR = /[，。！？；、,!?)]$/;
const REALTIME_VOICE_DEFAULT_MAX_CHARS = 64;
const REALTIME_VOICE_DEFAULT_MIN_CHARS = 12;
const REALTIME_VOICE_DEFAULT_SAMPLE_RATE = 24000;

type RealtimeVoiceSplitOptions = {
  force?: boolean;
  maxChars?: number;
  minChars?: number;
  eager?: boolean;
};

export function splitRealtimeVoiceReadySegments(
  input: string,
  opts?: RealtimeVoiceSplitOptions,
): { segments: string[]; rest: string } {
  let rest = input;
  const segments: string[] = [];
  const maxChars = Math.max(24, opts?.maxChars ?? REALTIME_VOICE_DEFAULT_MAX_CHARS);
  const minChars = Math.max(6, Math.min(opts?.minChars ?? REALTIME_VOICE_DEFAULT_MIN_CHARS, maxChars));
  const force = opts?.force ?? false;
  const eager = opts?.eager ?? false;

  while (rest.trim()) {
    rest = rest.trimStart();
    const protectedTailStart = findTrailingRealtimeVoiceUrlStart(rest);
    const candidate = protectedTailStart >= 0 ? rest.slice(0, protectedTailStart).trimEnd() : rest;
    if (!candidate.trim()) break;
    const urlRanges = findRealtimeVoiceUrlRanges(candidate);
    const cut = findRealtimeVoiceCut(candidate, maxChars, minChars, force, eager, urlRanges);
    if (cut <= 0) break;
    const segment = sanitizeTextForVoice(candidate.slice(0, cut));
    rest = rest.slice(cut).trimStart();
    if (segment && hasRealtimeVoiceSpeakableText(segment)) segments.push(segment);
  }

  return { segments, rest };
}

function findRealtimeVoiceCut(
  text: string,
  maxChars: number,
  minChars: number,
  force: boolean,
  eager: boolean,
  urlRanges: Array<{ start: number; end: number }>,
): number {
  if (!text) return 0;
  const scanLimit = Math.min(text.length, maxChars);
  for (let i = 0; i < scanLimit; i += 1) {
    const ch = text[i] ?? "";
    const cut = i + 1;
    if (isIndexInsideRealtimeVoiceUrl(i, urlRanges)) continue;
    if (REALTIME_VOICE_STRONG_END.test(ch) || ch === "…") {
      return cut;
    }
    if (ch === "." && cut >= minChars) {
      return cut;
    }
    if (cut >= minChars && REALTIME_VOICE_SOFT_BREAK.test(ch)) {
      return cut;
    }
  }

  if (text.length >= maxChars) {
    const softCut = findRealtimeVoiceSoftCut(text, maxChars, minChars, urlRanges);
    if (softCut <= 0) {
      const rangeAtMax = urlRanges.find((range) => maxChars > range.start && maxChars < range.end);
      if (rangeAtMax) return rangeAtMax.start >= minChars ? rangeAtMax.start : 0;
    }
    return softCut > 0 ? softCut : maxChars;
  }

  if (eager && text.length >= minChars) {
    return minChars;
  }

  return force ? text.length : 0;
}

function findRealtimeVoiceSoftCut(
  text: string,
  maxChars: number,
  minChars: number,
  urlRanges: Array<{ start: number; end: number }>,
): number {
  const end = Math.min(text.length, maxChars);
  for (let i = minChars; i <= end; i += 1) {
    const ch = text[i - 1] ?? "";
    if (isIndexInsideRealtimeVoiceUrl(i - 1, urlRanges)) continue;
    if (REALTIME_VOICE_SOFT_BREAK.test(ch)) return i;
  }
  return -1;
}

function findRealtimeVoiceUrlRanges(text: string): Array<{ start: number; end: number }> {
  return Array.from(text.matchAll(REALTIME_VOICE_URL_TOKEN))
    .map((match) => ({
      start: (match.index ?? -1) + (match[1]?.length ?? 0),
      end: (match.index ?? -1) + (match[0]?.length ?? 0),
    }))
    .filter((range) => range.start >= 0 && range.end > range.start);
}

function isIndexInsideRealtimeVoiceUrl(index: number, ranges: Array<{ start: number; end: number }>): boolean {
  return ranges.some((range) => index >= range.start && index < range.end);
}

function findTrailingRealtimeVoiceUrlStart(text: string): number {
  const match = text.match(REALTIME_VOICE_TRAILING_URL);
  if (!match || match.index == null) return -1;
  const token = match[2] ?? "";
  if (!token || REALTIME_VOICE_URL_TERMINATOR.test(token)) return -1;
  return match.index + (match[1]?.length ?? 0);
}

function hasRealtimeVoiceSpeakableText(text: string): boolean {
  return /[0-9A-Za-z\u3400-\u9fff]/.test(text);
}

/**
 * 停止专注模式当前音频：停止已排队的 WebAudio source。
 * @param opts.closeAudioContext 是否关闭 WebAudio 上下文；默认保留已由用户手势解锁的上下文
 * @returns Promise<void>
 */
export async function stopFocusVoicePlayback(opts?: { closeAudioContext?: boolean }): Promise<void> {
  for (const source of activeRealtimeSources) {
    try {
      source.stop();
    } catch {
      /* noop */
    }
    try {
      source.disconnect();
    } catch {
      /* noop */
    }
  }
  activeRealtimeSources.clear();
  realtimeNextStartAt = 0;
  realtimeLastEndAt = 0;
  if (!opts?.closeAudioContext) return;

  if (activeRealtimeGain) {
    try {
      activeRealtimeGain.disconnect();
    } catch {
      /* noop */
    }
    activeRealtimeGain = null;
  }
  if (activeRealtimeAudioContext) {
    const ctx = activeRealtimeAudioContext;
    activeRealtimeAudioContext = null;
    try {
      if (ctx.state !== "closed") await ctx.close();
    } catch {
      /* noop */
    }
  }
}

export type PlayFocusPlainTextVoiceParams = {
  /** 与 chat API 一致的 user_id */
  userId: string;
  /** 待播报全文 */
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
};

export type FocusRealtimePlainTextVoiceSession = {
  append: (delta: string) => void;
  flush: () => void;
  finish: () => void;
  cancel: () => void;
  done: Promise<void>;
};

export type StartFocusRealtimePlainTextVoiceParams = {
  userId: string;
  signal?: AbortSignal;
  maxSegmentChars?: number;
  minSegmentChars?: number;
  eagerSegmenting?: boolean;
  resetPlaybackOnStart?: boolean;
  onAudioFrame?: (byteLength: number) => void;
  onSubtitle?: (revealed: string) => void;
  syncSubtitle?: boolean;
};

/**
 * 拉取火山实时语音 PCM 流并播放。
 * @param params 用户、文案、AbortSignal 与字幕选项
 * @returns Promise<void>
 */
export async function playFocusPlainTextVoice(params: PlayFocusPlainTextVoiceParams): Promise<void> {
  await stopFocusVoicePlayback();
  if (params.signal?.aborted) {
    throw new DOMException("aborted", "AbortError");
  }
  await primeFocusVoicePlayback();

  const speakText = sanitizeTextForVoice(params.text);
  if (!speakText) {
    throw new Error("暂无可播报的文字");
  }

  const response = await fetchRealtimeVoicePcmStream(params.userId, speakText, { signal: params.signal });
  await playRealtimeVoicePcmStream(response, speakText, params);
}

export async function primeFocusVoicePlayback(): Promise<void> {
  const ctx = await getRealtimeAudioContext();
  if (ctx.state === "suspended") {
    await ctx.resume();
  }

  const gain = activeRealtimeGain;
  if (!gain || ctx.state === "closed") return;
  const buffer = ctx.createBuffer(1, 1, ctx.sampleRate);
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  source.connect(gain);
  source.start();
  source.onended = () => {
    try {
      source.disconnect();
    } catch {
      /* noop */
    }
  };
}

async function getRealtimeAudioContext(): Promise<AudioContext> {
  if (typeof window === "undefined") {
    throw new Error("当前环境不支持实时语音播放");
  }
  const webkitAudioContext = (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  const AudioContextCtor = window.AudioContext || webkitAudioContext;
  if (!AudioContextCtor) {
    throw new Error("当前浏览器不支持实时语音播放");
  }
  if (activeRealtimeAudioContext && activeRealtimeAudioContext.state !== "closed") {
    if (activeRealtimeAudioContext.state === "suspended") {
      await activeRealtimeAudioContext.resume();
    }
    return activeRealtimeAudioContext;
  }

  const ctx = new AudioContextCtor();
  const gain = ctx.createGain();
  gain.gain.value = 1;
  gain.connect(ctx.destination);
  activeRealtimeAudioContext = ctx;
  activeRealtimeGain = gain;
  realtimeNextStartAt = ctx.currentTime + 0.03;
  realtimeLastEndAt = realtimeNextStartAt;
  if (ctx.state === "suspended") {
    await ctx.resume();
  }
  return ctx;
}

function readRealtimeVoiceSampleRate(response: Response): number {
  const raw = response.headers.get("X-Mai-Audio-Sample-Rate") || response.headers.get("x-mai-audio-sample-rate") || "";
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : REALTIME_VOICE_DEFAULT_SAMPLE_RATE;
}

function concatBytes(left: Uint8Array, right: Uint8Array): Uint8Array {
  const out = new Uint8Array(left.byteLength + right.byteLength);
  out.set(left, 0);
  out.set(right, left.byteLength);
  return out;
}

function scheduleRealtimePcm16Chunk(bytes: Uint8Array, sampleRate: number): void {
  const ctx = activeRealtimeAudioContext;
  const gain = activeRealtimeGain;
  if (!ctx || !gain || ctx.state === "closed") {
    throw new Error("实时语音播放器未初始化");
  }
  if (ctx.state === "suspended") {
    void ctx.resume().catch(() => {
      /* browser may require the next user gesture */
    });
  }

  const frameCount = Math.floor(bytes.byteLength / 2);
  if (frameCount <= 0) return;
  const audioBuffer = ctx.createBuffer(1, frameCount, sampleRate);
  const channel = audioBuffer.getChannelData(0);
  const view = new DataView(bytes.buffer, bytes.byteOffset, frameCount * 2);
  for (let i = 0; i < frameCount; i += 1) {
    const sample = view.getInt16(i * 2, true);
    channel[i] = sample < 0 ? sample / 32768 : sample / 32767;
  }

  const source = ctx.createBufferSource();
  source.buffer = audioBuffer;
  source.connect(gain);
  activeRealtimeSources.add(source);
  source.onended = () => {
    activeRealtimeSources.delete(source);
  };

  const startAt = Math.max(realtimeNextStartAt, ctx.currentTime + 0.02);
  source.start(startAt);
  realtimeNextStartAt = startAt + audioBuffer.duration;
  realtimeLastEndAt = realtimeNextStartAt;
}

function waitForRealtimeAudioTail(signal?: AbortSignal): Promise<void> {
  const ctx = activeRealtimeAudioContext;
  if (!ctx || ctx.state === "closed") return Promise.resolve();
  const waitMs = Math.max(0, (realtimeLastEndAt - ctx.currentTime) * 1000 + 80);
  if (waitMs <= 0) return Promise.resolve();

  return new Promise<void>((resolve, reject) => {
    let timer: ReturnType<typeof setTimeout> | null = null;
    const cleanup = () => {
      if (timer != null) {
        clearTimeout(timer);
        timer = null;
      }
      signal?.removeEventListener("abort", onAbort);
    };
    const onAbort = () => {
      cleanup();
      reject(new DOMException("aborted", "AbortError"));
    };
    signal?.addEventListener("abort", onAbort);
    timer = setTimeout(() => {
      cleanup();
      resolve();
    }, waitMs);
  });
}

async function playRealtimeVoicePcmStream(
  response: Response,
  speakText: string,
  params: Pick<StartFocusRealtimePlainTextVoiceParams, "signal" | "onSubtitle" | "syncSubtitle">,
): Promise<void> {
  if (params.signal?.aborted) {
    throw new DOMException("aborted", "AbortError");
  }
  const reader = response.body?.getReader();
  if (!reader) {
    throw new Error("当前环境不支持实时语音流播放");
  }

  const sampleRate = readRealtimeVoiceSampleRate(response);
  const syncSubtitle = params.syncSubtitle !== false;
  let pending = new Uint8Array(0);
  let subtitleShown = false;

  try {
    await getRealtimeAudioContext();
    while (true) {
      if (params.signal?.aborted) {
        throw new DOMException("aborted", "AbortError");
      }
      const { value, done } = await reader.read();
      if (done) break;
      if (!value?.byteLength) continue;

      const bytes = pending.byteLength ? concatBytes(pending, value) : value;
      const playableLength = bytes.byteLength - (bytes.byteLength % 2);
      if (playableLength > 0) {
        scheduleRealtimePcm16Chunk(bytes.subarray(0, playableLength), sampleRate);
        if (syncSubtitle && !subtitleShown) {
          params.onSubtitle?.(speakText);
          subtitleShown = true;
        }
      }
      pending = playableLength < bytes.byteLength ? bytes.slice(playableLength) : new Uint8Array(0);
    }
    if (syncSubtitle) {
      params.onSubtitle?.(speakText);
    }
    await waitForRealtimeAudioTail(params.signal);
  } catch (e) {
    try {
      await reader.cancel();
    } catch {
      /* noop */
    }
    throw e;
  } finally {
    try {
      reader.releaseLock();
    } catch {
      /* noop */
    }
  }
}

export function startFocusRealtimePlainTextVoice(
  params: StartFocusRealtimePlainTextVoiceParams,
): FocusRealtimePlainTextVoiceSession {
  const ac = new AbortController();
  let ws: WebSocket | null = null;
  const pendingSegments: string[] = [];
  const voiceTextFilter = createVoiceTextStreamFilter();
  let buffer = "";
  let finished = false;
  let cancelled = false;
  let finishSent = false;
  let serverDone = false;
  let sampleRate = REALTIME_VOICE_DEFAULT_SAMPLE_RATE;
  let doneSettled = false;
  let settleDoneReject: ((error: Error) => void) | null = null;

  const onSubtitle = params.onSubtitle ?? (() => {});
  const maxSegmentChars = Math.max(24, params.maxSegmentChars ?? REALTIME_VOICE_DEFAULT_MAX_CHARS);
  const minSegmentChars = Math.max(6, Math.min(params.minSegmentChars ?? REALTIME_VOICE_DEFAULT_MIN_CHARS, maxSegmentChars));

  const sendJson = (payload: Record<string, unknown>) => {
    if (ws?.readyState !== WebSocket.OPEN) return false;
    ws.send(JSON.stringify(payload));
    return true;
  };

  const flushPendingSegments = () => {
    while (!cancelled && pendingSegments.length > 0 && sendJson({ type: "append", text: pendingSegments[0] })) {
      pendingSegments.shift();
    }
    if (finished && pendingSegments.length === 0 && !finishSent && sendJson({ type: "finish" })) {
      finishSent = true;
    }
  };

  const enqueueSegment = (segment: string) => {
    if (cancelled || ac.signal.aborted) return;
    const text = segment.trim();
    if (!text) return;
    pendingSegments.push(text);
    flushPendingSegments();
  };

  const drainBuffer = (force: boolean) => {
    if (cancelled) return;
    const split = splitRealtimeVoiceReadySegments(buffer, {
      force,
      maxChars: maxSegmentChars,
      minChars: minSegmentChars,
      eager: params.eagerSegmenting ?? false,
    });
    buffer = split.rest;
    split.segments.forEach(enqueueSegment);
  };

  const appendSpeakableText = (text: string, force: boolean) => {
    if (!text) return;
    buffer += text;
    drainBuffer(force);
  };

  const parseControlFrame = (raw: string) => {
    let payload: unknown;
    try {
      payload = JSON.parse(raw);
    } catch {
      return;
    }
    if (!payload || typeof payload !== "object") return;
    const rec = payload as Record<string, unknown>;
    const type = String(rec.type ?? "");
    if (type === "ready") {
      const nextSampleRate = Number(rec.sample_rate ?? rec.sampleRate ?? 0);
      if (Number.isFinite(nextSampleRate) && nextSampleRate > 0) sampleRate = nextSampleRate;
      flushPendingSegments();
      return;
    }
    if (type === "done") {
      serverDone = true;
      return;
    }
    if (type === "error") {
      const message = typeof rec.message === "string" && rec.message.trim() ? rec.message.trim() : "实时语音播报失败";
      throw new Error(message);
    }
  };

  const readBinaryFrame = async (data: unknown): Promise<Uint8Array | null> => {
    if (data instanceof ArrayBuffer) return new Uint8Array(data);
    if (ArrayBuffer.isView(data)) {
      return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
    }
    if (typeof Blob !== "undefined" && data instanceof Blob) {
      return new Uint8Array(await data.arrayBuffer());
    }
    return null;
  };

  const cancelInternal = () => {
    if (cancelled) return;
    cancelled = true;
    finished = true;
    buffer = "";
    pendingSegments.length = 0;
    ac.abort();
    try {
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "cancel" }));
      }
    } catch {
      /* noop */
    }
    try {
      ws?.close();
    } catch {
      /* noop */
    }
    params.signal?.removeEventListener("abort", onParentAbort);
    void stopFocusVoicePlayback();
    if (!doneSettled) {
      doneSettled = true;
      settleDoneReject?.(new DOMException("aborted", "AbortError"));
    }
  };

  const onParentAbort = () => cancelInternal();
  params.signal?.addEventListener("abort", onParentAbort);

  const done = new Promise<void>((resolve, reject) => {
    settleDoneReject = reject;

    const fail = (error: unknown) => {
      if (doneSettled) return;
      doneSettled = true;
      if (!ac.signal.aborted) ac.abort();
      params.signal?.removeEventListener("abort", onParentAbort);
      try {
        ws?.close();
      } catch {
        /* noop */
      }
      reject(error instanceof Error ? error : new Error(String(error)));
    };

    const finishDone = () => {
      if (doneSettled) return;
      params.signal?.removeEventListener("abort", onParentAbort);
      void waitForRealtimeAudioTail(ac.signal)
        .then(() => {
          if (doneSettled) return;
          doneSettled = true;
          resolve();
        })
        .catch(fail);
    };

    const preparePlayback =
      params.resetPlaybackOnStart === false ? Promise.resolve() : stopFocusVoicePlayback();

    void preparePlayback
      .then(() => getRealtimeAudioContext())
      .then(() => {
        if (ac.signal.aborted || params.signal?.aborted) {
          throw new DOMException("aborted", "AbortError");
        }
        ws = new WebSocket(resolveRealtimeVoiceSessionWebSocketUrl(params.userId));
        ws.binaryType = "arraybuffer";

        ws.onopen = () => {
          flushPendingSegments();
        };
        ws.onmessage = (ev: MessageEvent) => {
          if (cancelled || ac.signal.aborted) return;
          void (async () => {
            if (typeof ev.data === "string") {
              parseControlFrame(ev.data);
              if (serverDone) finishDone();
              return;
            }
            const bytes = await readBinaryFrame(ev.data);
            if (bytes?.byteLength) {
              params.onAudioFrame?.(bytes.byteLength);
              scheduleRealtimePcm16Chunk(bytes, sampleRate);
              if (params.syncSubtitle !== false) onSubtitle("");
            }
          })().catch(fail);
        };
        ws.onerror = () => {
          fail(new Error("实时语音连接失败"));
        };
        ws.onclose = (ev: CloseEvent) => {
          if (cancelled || ac.signal.aborted) return;
          if (serverDone || finishSent) {
            finishDone();
            return;
          }
          fail(new Error(`实时语音连接已关闭: ${ev.code}`));
        };

        if (params.signal?.aborted) cancelInternal();
      })
      .catch(fail);
  });

  return {
    append(delta: string) {
      if (cancelled || finished || !delta) return;
      appendSpeakableText(voiceTextFilter.push(delta), false);
    },
    flush() {
      if (cancelled || finished) return;
      appendSpeakableText(voiceTextFilter.flush(), false);
      drainBuffer(true);
      flushPendingSegments();
    },
    finish() {
      if (cancelled || finished) return;
      appendSpeakableText(voiceTextFilter.flush(), false);
      drainBuffer(true);
      finished = true;
      flushPendingSegments();
    },
    cancel: cancelInternal,
    done,
  };
}
