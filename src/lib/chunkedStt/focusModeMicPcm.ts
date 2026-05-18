import { toast } from "sonner";
import { log } from "@/lib/logger";
import {
  FOCUS_PCM_SAMPLE_RATE,
  floatToS16le,
  resampleFloat32Linear,
} from "@/lib/chunkedStt/focusVoicePcm";

/** ScriptProcessor 缓冲长度（样本帧），与专注模式 STT 其它实现保持一致 */
const SCRIPT_PROCESSOR_BUFFER_SIZE = 4096;

type AudioContextWithLegacy = AudioContext & {
  createScriptProcessor?: (
    bufferSize: number,
    numberOfInputChannels: number,
    numberOfOutputChannels: number,
  ) => ScriptProcessorNode;
};

/**
 * 启动专注模式麦克风链路：单声道采集 → 重采样至 16kHz → s16le PCM 分块回调。
 * @param params.signal 中止后 onPcmS16le 不再被调用（与 isActive 共同约束）
 * @param params.isActive 返回 false 时跳过处理（如会话已结算）
 * @param params.onPcmS16le 每一音频处理块输出 Int16Array（小端语义与 pcm_s16le 一致）
 * @returns close 关闭麦与 AudioContext，可重复调用且幂等
 */
export async function startFocusModePcmCapture(params: {
  signal: AbortSignal;
  isActive: () => boolean;
  onPcmS16le: (chunk: Int16Array) => void;
}): Promise<{ close: () => Promise<void> }> {
  let stream: MediaStream | null = null;
  let audioContext: AudioContext | null = null;
  let processor: ScriptProcessorNode | null = null;
  let source: MediaStreamAudioSourceNode | null = null;
  let silentGain: GainNode | null = null;

  const stopTracks = () => {
    stream?.getTracks().forEach((t) => {
      try {
        t.stop();
      } catch {
        /* noop */
      }
    });
    stream = null;
  };

  const close = async () => {
    try {
      if (processor) {
        processor.onaudioprocess = null;
        processor.disconnect();
      }
    } catch {
      /* noop */
    }
    processor = null;
    try {
      source?.disconnect();
    } catch {
      /* noop */
    }
    source = null;
    try {
      silentGain?.disconnect();
    } catch {
      /* noop */
    }
    silentGain = null;
    if (audioContext && audioContext.state !== "closed") {
      try {
        await audioContext.close();
      } catch {
        /* noop */
      }
    }
    audioContext = null;
    stopTracks();
  };

  try {
    stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
      },
    });
  } catch (e: unknown) {
    log("[Focus Mic] getUserMedia 失败", e instanceof Error ? e.message : e);
    toast.error("无法使用麦克风");
    throw e;
  }

  const AC = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AC) {
    toast.error("当前环境不支持 Web Audio");
    stopTracks();
    throw new Error("No AudioContext");
  }

  try {
    audioContext = new AC();
    await audioContext.resume().catch(() => undefined);
  } catch (e: unknown) {
    log("[Focus Mic] AudioContext 失败", e instanceof Error ? e.message : e);
    toast.error("无法初始化音频");
    stopTracks();
    throw e;
  }

  const ctx = audioContext as AudioContextWithLegacy;
  if (typeof ctx.createScriptProcessor !== "function") {
    toast.error("当前环境不支持 PCM 采集（缺少 ScriptProcessor）");
    await close();
    throw new Error("No ScriptProcessor");
  }

  try {
    source = audioContext.createMediaStreamSource(stream);
    processor = ctx.createScriptProcessor!(SCRIPT_PROCESSOR_BUFFER_SIZE, 1, 1);
    silentGain = audioContext.createGain();
    silentGain.gain.value = 0;

    processor.onaudioprocess = (ev: AudioProcessingEvent) => {
      if (params.signal.aborted || !params.isActive()) return;
      const input = ev.inputBuffer.getChannelData(0);
      const copy = new Float32Array(input.length);
      copy.set(input);
      const resampled = resampleFloat32Linear(copy, audioContext!.sampleRate, FOCUS_PCM_SAMPLE_RATE);
      params.onPcmS16le(floatToS16le(resampled));
    };

    source.connect(processor);
    processor.connect(silentGain);
    silentGain.connect(audioContext.destination);
  } catch (e: unknown) {
    log("[Focus Mic] 音频图连接失败", e instanceof Error ? e.message : e);
    toast.error("无法启动录音");
    await close();
    throw e;
  }

  return { close };
}
