import { act, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { runFocusVoiceSttSession } from "@/lib/chunkedStt/runFocusVoiceSttSession";
import { useAgentHubSpeechInput } from "./useAgentHubSpeechInput";

vi.mock("@/lib/chunkedStt/runFocusVoiceSttSession", () => ({
  runFocusVoiceSttSession: vi.fn(),
}));

vi.mock("sonner", () => ({
  toast: {
    error: vi.fn(),
  },
}));

vi.mock("@/lib/logger", () => ({
  log: vi.fn(),
}));

describe("useAgentHubSpeechInput", () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it("waits for and returns final STT text when speech is finished", async () => {
    let finishSignal: AbortSignal | undefined;
    vi.mocked(runFocusVoiceSttSession).mockImplementation(async ({ finishSignal: signal }) => {
      finishSignal = signal;
      await new Promise<void>((resolve) => {
        signal?.addEventListener("abort", () => resolve(), { once: true });
      });
      return "最终转录文本";
    });
    const updates: string[] = [];
    const { result } = renderHook(() =>
      useAgentHubSpeechInput((value) => updates.push(value), { userId: "demo-user" }),
    );

    await act(async () => {
      await result.current.startSpeech();
    });
    await waitFor(() => expect(finishSignal).toBeDefined());
    expect(result.current.speechPhase).toBe("listening");

    let stopPromise!: Promise<string>;
    act(() => {
      stopPromise = result.current.stopSpeech();
    });
    await waitFor(() => expect(result.current.speechPhase).toBe("transcribing"));
    let finalText = "";
    await act(async () => {
      finalText = await stopPromise;
    });

    expect(finishSignal?.aborted).toBe(true);
    expect(finalText).toBe("最终转录文本");
    expect(updates.at(-1)).toBe("最终转录文本");
    expect(result.current.speechPhase).toBe("idle");
  });

  it("returns empty text and suppresses final writes when speech is discarded", async () => {
    let cancelSignal: AbortSignal | undefined;
    vi.mocked(runFocusVoiceSttSession).mockImplementation(async ({ signal }) => {
      cancelSignal = signal;
      await new Promise<void>((resolve) => {
        signal.addEventListener("abort", () => resolve(), { once: true });
      });
      return "不应写入";
    });
    const updates: string[] = [];
    const { result } = renderHook(() =>
      useAgentHubSpeechInput((value) => updates.push(value), { userId: "demo-user" }),
    );

    await act(async () => {
      await result.current.startSpeech();
    });
    await waitFor(() => expect(cancelSignal).toBeDefined());
    expect(result.current.speechPhase).toBe("listening");

    let finalText = "placeholder";
    await act(async () => {
      finalText = await result.current.stopSpeech({ discardSttResult: true });
    });

    expect(cancelSignal?.aborted).toBe(true);
    expect(finalText).toBe("");
    expect(updates).not.toContain("不应写入");
    expect(result.current.speechPhase).toBe("idle");
  });
});
