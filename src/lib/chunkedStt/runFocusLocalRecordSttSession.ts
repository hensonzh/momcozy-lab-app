import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { toast } from "sonner";
import { transcribeSpeechAudioChunk } from "@/lib/agentApi";
import { startFocusModePcmCapture } from "@/lib/chunkedStt/focusModeMicPcm";
import { log } from "@/lib/logger";
import {
  FOCUS_PCM_SAMPLE_RATE,
  isPcmS16leLikelySpeech,
  pcmS16leMonoToWavBlob,
} from "@/lib/chunkedStt/focusVoicePcm";

/** 向在线接口上传累计录音的间隔（毫秒） */
const POLL_MS = 2000;
/** 单轮最长录音时间 */
const MAX_SESSION_MS = 60_000;
/** 原生端 pcm_s16le 文件目录 */
const FOCUS_STT_SUBDIR = "focus_stt_recordings";

/**
 * ArrayBuffer 转 base64（写入 Filesystem）。
 * @param buffer 二进制缓冲
 * @returns base64 字符串
 */
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
}

/**
 * 将当前累计 pcm_s16le 裸数据写入原生 Cache（Web 端不写盘）。
 * @param relativePath 相对路径，扩展名建议 .pcm
 * @param pcmBuffer 16kHz / mono / s16le 裸 PCM
 */
async function persistPcmToCacheFile(relativePath: string, pcmBuffer: ArrayBuffer): Promise<void> {
  if (!Capacitor.isNativePlatform()) return;
  try {
    await Filesystem.writeFile({
      path: relativePath,
      directory: Directory.Cache,
      data: arrayBufferToBase64(pcmBuffer),
      recursive: true,
    });
  } catch (e: unknown) {
    log("[Focus STT] 写入 PCM 文件失败", e instanceof Error ? e.message : e);
  }
}

/**
 * 专注模式听写：本机以 16kHz / 16bit / pcm_s16le 形式累计录音并落盘；
 * 每 2s 将当前累计 PCM 封装为 WAV 上传在线转写；连续两次转写结果一致则结束。
 *
 * @param params.userId 业务 user_id
 * @param params.signal 外部取消，直接丢弃本轮结果
 * @param params.finishSignal 外部结束，停止录音并补一次最终转写
 * @param params.setInterimText 实时转写预览
 * @returns 最终用户文本
 */
export async function runFocusLocalRecordSttSession(params: {
  userId: string;
  signal: AbortSignal;
  finishSignal?: AbortSignal;
  setInterimText: (text: string) => void;
}): Promise<string> {
  if (typeof navigator !== "undefined" && navigator.onLine === false) {
    toast.error("当前无网络，无法使用在线语音转写");
    return "";
  }

  let settled = false;
  /** 累计 pcm_s16le 裸字节（16k mono） */
  let pcmAccumulator = new Uint8Array(0);
  /** 上一次接口返回的 trim 后全文 */
  let lastNorm: string | null = null;
  let bestText = "";
  let hadNonEmptyResult = false;
  let maxTimer: ReturnType<typeof setTimeout> | null = null;
  let pollTimer: ReturnType<typeof setTimeout> | null = null;
  let sessionFilePath: string | null = null;
  let micClose: (() => Promise<void>) | null = null;

  const appendPcmS16le = (i16: Int16Array) => {
    const chunk = new Uint8Array(i16.buffer, i16.byteOffset, i16.byteLength);
    const next = new Uint8Array(pcmAccumulator.length + chunk.length);
    if (pcmAccumulator.length) next.set(pcmAccumulator);
    next.set(chunk, pcmAccumulator.length);
    pcmAccumulator = next;
  };

  const getPcmSnapshot = (): ArrayBuffer => {
    const copy = new ArrayBuffer(pcmAccumulator.byteLength);
    new Uint8Array(copy).set(pcmAccumulator);
    return copy;
  };

  const cleanupTimers = () => {
    if (maxTimer != null) {
      clearTimeout(maxTimer);
      maxTimer = null;
    }
    if (pollTimer != null) {
      clearTimeout(pollTimer);
      pollTimer = null;
    }
  };

  const teardownMic = async () => {
    if (micClose) {
      try {
        await micClose();
      } catch {
        /* noop */
      }
      micClose = null;
    }
  };

  return new Promise<string>((resolve) => {
    let finishing = false;

    const finish = async (out: string) => {
      if (settled) return;
      settled = true;
      params.signal.removeEventListener("abort", onAbort);
      params.finishSignal?.removeEventListener("abort", onFinishRequest);
      cleanupTimers();
      await teardownMic();
      resolve(out.trim());
    };

    const transcribePcmSnapshot = async (pcm: ArrayBuffer): Promise<string> => {
      if (pcm.byteLength === 0 || params.signal.aborted || settled) return "";
      if (!isPcmS16leLikelySpeech(pcm, FOCUS_PCM_SAMPLE_RATE)) return "";

      if (sessionFilePath) {
        void persistPcmToCacheFile(sessionFilePath, pcm);
      }

      try {
        const wavBlob = pcmS16leMonoToWavBlob(pcm, FOCUS_PCM_SAMPLE_RATE);
        const text = await transcribeSpeechAudioChunk(params.userId, wavBlob, {
          signal: params.signal,
          fileName: `speech-chunk-${Date.now()}.wav`,
          mimeType: "audio/wav",
        });
        return text ?? "";
      } catch (err: unknown) {
        if (params.signal.aborted) return "";
        log("[Focus STT] 分片转写失败（已忽略单次错误）", err instanceof Error ? err.message : err);
        return "";
      }
    };

    const finishWithCurrentAudio = async () => {
      if (settled || finishing) return;
      finishing = true;
      cleanupTimers();
      await teardownMic();
      const text = await transcribePcmSnapshot(getPcmSnapshot());
      if (!params.signal.aborted && text.trim().length > 0) {
        handleApiResult(text);
      }
      await finish(hadNonEmptyResult ? bestText : "");
    };

    const onAbort = () => void finish("");
    const onFinishRequest = () => void finishWithCurrentAudio();
    params.signal.addEventListener("abort", onAbort, { once: true });
    params.finishSignal?.addEventListener("abort", onFinishRequest, { once: true });
    if (params.signal.aborted) {
      void finish("");
      return;
    }
    if (params.finishSignal?.aborted) {
      void finishWithCurrentAudio();
    }

    const handleApiResult = (raw: string | null) => {
      if (settled || params.signal.aborted) return;
      const norm = (raw ?? "").trim();
      const display = norm.length > 0 ? norm : bestText;
      params.setInterimText(display);

      if (!finishing && lastNorm !== null && norm === lastNorm) {
        if (norm.length > 0) {
          void finish(norm);
          return;
        }
        if (hadNonEmptyResult && bestText.length > 0) {
          void finish(bestText);
          return;
        }
      }

      if (norm.length > 0) {
        hadNonEmptyResult = true;
        bestText = norm;
      }
      lastNorm = norm;
    };

    const runOnePoll = async () => {
      if (settled || params.signal.aborted) return;
      const pcm = getPcmSnapshot();
      if (pcm.byteLength === 0) return;

      const text = await transcribePcmSnapshot(pcm);
      if (params.signal.aborted || settled) return;
      handleApiResult(text);
    };

    const scheduleNextPoll = () => {
      if (settled || params.signal.aborted) return;
      pollTimer = window.setTimeout(() => {
        pollTimer = null;
        void (async () => {
          await runOnePoll();
          scheduleNextPoll();
        })();
      }, POLL_MS);
    };

    void (async () => {
      if (Capacitor.isNativePlatform()) {
        sessionFilePath = `${FOCUS_STT_SUBDIR}/focus_rec_${Date.now()}.pcm`;
      }

      try {
        const { close } = await startFocusModePcmCapture({
          signal: params.signal,
          isActive: () => !settled && !params.signal.aborted,
          onPcmS16le: appendPcmS16le,
        });
        if (settled) {
          await close().catch(() => undefined);
          return;
        }
        micClose = close;
      } catch {
        void finish("");
        return;
      }

      if (params.signal.aborted) {
        void finish("");
        return;
      }

      maxTimer = setTimeout(() => {
        maxTimer = null;
        void finish(hadNonEmptyResult ? bestText : "");
      }, MAX_SESSION_MS);

      scheduleNextPoll();
    })();
  });
}
