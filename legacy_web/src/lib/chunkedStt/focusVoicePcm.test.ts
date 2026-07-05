import { describe, expect, it } from "vitest";
import { FOCUS_PCM_SAMPLE_RATE, isPcmS16leLikelySpeech, pcmS16leSignalStats } from "./focusVoicePcm";

function pcmFromSamples(samples: Int16Array): ArrayBuffer {
  const copy = new ArrayBuffer(samples.byteLength);
  new Int16Array(copy).set(samples);
  return copy;
}

describe("focusVoicePcm voice activity helpers", () => {
  it("rejects silence-like pcm before uploading to STT", () => {
    const samples = new Int16Array(FOCUS_PCM_SAMPLE_RATE);
    const pcm = pcmFromSamples(samples);

    expect(isPcmS16leLikelySpeech(pcm)).toBe(false);
    expect(pcmS16leSignalStats(pcm).rms).toBe(0);
  });

  it("accepts pcm with enough duration and signal level", () => {
    const samples = new Int16Array(FOCUS_PCM_SAMPLE_RATE);
    for (let i = 0; i < samples.length; i++) {
      samples[i] = i % 2 === 0 ? 2800 : -2800;
    }

    const pcm = pcmFromSamples(samples);

    expect(isPcmS16leLikelySpeech(pcm)).toBe(true);
    expect(pcmS16leSignalStats(pcm).peak).toBeGreaterThan(0.08);
  });

  it("rejects very short pcm even when it has signal", () => {
    const samples = new Int16Array(Math.floor(FOCUS_PCM_SAMPLE_RATE * 0.1));
    samples.fill(2800);

    expect(isPcmS16leLikelySpeech(pcmFromSamples(samples))).toBe(false);
  });
});
