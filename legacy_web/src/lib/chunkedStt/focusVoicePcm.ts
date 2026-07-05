/** 专注模式录音目标：16kHz、16bit、小端 PCM（与 ffmpeg pcm_s16le 一致） */
export const FOCUS_PCM_SAMPLE_RATE = 16_000;
const PCM_S16LE_SPEECH_MIN_DURATION_MS = 350;
const PCM_S16LE_SPEECH_MIN_RMS = 0.003;
const PCM_S16LE_SPEECH_MIN_PEAK = 0.012;

export interface PcmS16leSignalStats {
  sampleCount: number;
  durationMs: number;
  rms: number;
  peak: number;
}

/**
 * 将 float32 样本（约 -1..1）量化为 s16le 整数。
 * @param f32 单声道浮点缓冲
 * @returns 与 f32 等长的 Int16Array（小端字节序由 TypedArray 保证）
 */
export function floatToS16le(f32: Float32Array): Int16Array {
  const out = new Int16Array(f32.length);
  for (let i = 0; i < f32.length; i++) {
    const s = Math.max(-1, Math.min(1, f32[i] ?? 0));
    out[i] = s < 0 ? Math.round(s * 0x8000) : Math.round(s * 0x7fff);
  }
  return out;
}

/**
 * 线性重采样（浮点域），用于将麦克风实际采样率对齐到 {@link FOCUS_PCM_SAMPLE_RATE}。
 * @param input 输入样本
 * @param fromRate 输入采样率（如 AudioContext.sampleRate）
 * @param toRate 输出采样率
 * @returns 重采样后的 float32
 */
export function resampleFloat32Linear(input: Float32Array, fromRate: number, toRate: number): Float32Array {
  if (fromRate === toRate || input.length === 0) {
    return input.length === 0 ? new Float32Array(0) : new Float32Array(input);
  }
  const ratio = fromRate / toRate;
  const outLen = Math.max(1, Math.floor(input.length / ratio));
  const out = new Float32Array(outLen);
  for (let i = 0; i < outLen; i++) {
    const x = i * ratio;
    const j = Math.floor(x);
    const f = x - j;
    const s0 = input[j] ?? 0;
    const s1 = input[j + 1] ?? s0;
    out[i] = s0 * (1 - f) + s1 * f;
  }
  return out;
}

export function pcmS16leSignalStats(pcmS16le: ArrayBuffer, sampleRate: number = FOCUS_PCM_SAMPLE_RATE): PcmS16leSignalStats {
  const byteLength = pcmS16le.byteLength - (pcmS16le.byteLength % 2);
  if (byteLength <= 0 || sampleRate <= 0) {
    return { sampleCount: 0, durationMs: 0, rms: 0, peak: 0 };
  }

  const view = new DataView(pcmS16le, 0, byteLength);
  let sumSquares = 0;
  let peak = 0;
  const sampleCount = byteLength / 2;
  for (let offset = 0; offset < byteLength; offset += 2) {
    const normalized = view.getInt16(offset, true) / 32768;
    const abs = Math.abs(normalized);
    sumSquares += normalized * normalized;
    if (abs > peak) peak = abs;
  }

  return {
    sampleCount,
    durationMs: (sampleCount / sampleRate) * 1000,
    rms: Math.sqrt(sumSquares / sampleCount),
    peak,
  };
}

export function isPcmS16leLikelySpeech(pcmS16le: ArrayBuffer, sampleRate: number = FOCUS_PCM_SAMPLE_RATE): boolean {
  const stats = pcmS16leSignalStats(pcmS16le, sampleRate);
  return (
    stats.durationMs >= PCM_S16LE_SPEECH_MIN_DURATION_MS &&
    stats.rms >= PCM_S16LE_SPEECH_MIN_RMS &&
    stats.peak >= PCM_S16LE_SPEECH_MIN_PEAK
  );
}

/**
 * 将裸 pcm_s16le 单声道数据封装为标准 WAV（供 HTTP 上传；磁盘存储仍用裸 PCM）。
 * @param pcmS16le 小端 16bit PCM 裸数据
 * @param sampleRate 采样率，默认 16000
 * @returns 含 44 字节头的 WAV Blob
 */
export function pcmS16leMonoToWavBlob(pcmS16le: ArrayBuffer, sampleRate: number = FOCUS_PCM_SAMPLE_RATE): Blob {
  const numChannels = 1;
  const bitsPerSample = 16;
  const blockAlign = (numChannels * bitsPerSample) / 8;
  const byteRate = sampleRate * blockAlign;
  const dataSize = pcmS16le.byteLength;
  const header = new ArrayBuffer(44);
  const view = new DataView(header);
  const writeStr = (offset: number, s: string) => {
    for (let i = 0; i < s.length; i++) {
      view.setUint8(offset + i, s.charCodeAt(i));
    }
  };
  writeStr(0, "RIFF");
  view.setUint32(4, 36 + dataSize, true);
  writeStr(8, "WAVE");
  writeStr(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);
  writeStr(36, "data");
  view.setUint32(40, dataSize, true);
  return new Blob([header, pcmS16le], { type: "audio/wav" });
}
