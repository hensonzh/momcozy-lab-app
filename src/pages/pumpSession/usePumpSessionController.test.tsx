import { act, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { resetPumpAgentUploadProcessProgress } from "@/lib/pumpAgentUpload";
import { pushPumpMilkUploadForPumpSessionEnd } from "@/lib/pumpAutoEndSession";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import { usePumpAgentRuntime } from "./usePumpAgentRuntime";
import { usePumpDeviceControlRuntime } from "./usePumpDeviceControlRuntime";
import { usePumpSessionController } from "./usePumpSessionController";

vi.mock("@/lib/pumpSessionLifecycle", () => ({
  pumpSessionLifecycle: {
    getSessionState: vi.fn(() => "running"),
    markSessionEnded: vi.fn(),
    getLastEndedEvent: vi.fn(() => ({ reason: "user-confirm", at: 1234 })),
  },
}));

vi.mock("@/lib/pumpAgentUpload", () => ({
  resetPumpAgentUploadProcessProgress: vi.fn(),
}));

vi.mock("@/lib/pumpAutoEndSession", () => ({
  pushPumpMilkUploadForPumpSessionEnd: vi.fn(() => Promise.resolve()),
}));

vi.mock("./usePumpMaiRuntime", () => ({
  usePumpMaiRuntime: vi.fn(() => ({})),
}));

vi.mock("./usePumpAgentRuntime", () => ({
  usePumpAgentRuntime: vi.fn(),
}));

vi.mock("./usePumpDeviceControlRuntime", () => ({
  usePumpDeviceControlRuntime: vi.fn(),
}));

function deferred<T = void>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

function renderController(params?: {
  elapsed?: number;
  pushStopPumpAgentSummary?: (...args: unknown[]) => Promise<void>;
  stopPumpWithBle?: () => Promise<void>;
  navigateHome?: () => void;
}) {
  const pushStopPumpAgentSummary = params?.pushStopPumpAgentSummary ?? vi.fn(() => Promise.resolve());
  const stopPumpWithBle = params?.stopPumpWithBle ?? vi.fn(() => Promise.resolve());
  const navigateHome = params?.navigateHome ?? vi.fn();

  vi.mocked(usePumpAgentRuntime).mockReturnValue({
    pushStopPumpAgentSummary,
    sendAgentQuery: vi.fn(),
    maiAssistantContent: "",
    maiAssistantLoading: false,
    maiAssistantError: "",
    maiAssistantRichText: null,
  });
  vi.mocked(usePumpDeviceControlRuntime).mockReturnValue({
    stopPumpWithBle,
    pauseResume: vi.fn(),
    setModeBoth: vi.fn(),
    setModeL: vi.fn(),
    setModeR: vi.fn(),
    handleAiModeRequest: vi.fn(),
    adjustGearL: vi.fn(),
    adjustGearR: vi.fn(),
  });

  return {
    pushStopPumpAgentSummary,
    stopPumpWithBle,
    navigateHome,
    ...renderHook(() =>
      usePumpSessionController({
        left: { gear: 1, mode: "stimulate", flow: 0 },
        right: { gear: 1, mode: "stimulate", flow: 0 },
        aiMode: true,
        sessionState: "running",
        processAll: 80,
        elapsed: params?.elapsed ?? 45,
        setElapsed: vi.fn(),
        setAiMode: vi.fn(),
        setSessionState: vi.fn(),
        setLeft: vi.fn(),
        setRight: vi.fn(),
        setDevicePowerOffOpen: vi.fn(),
        setManualConfirmOpen: vi.fn(),
        setFinishConfirmOpen: vi.fn(),
        navigateHome,
      }),
    ),
  };
}

describe("usePumpSessionController finish flow", () => {
  let consoleErrorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleErrorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    vi.mocked(pumpSessionLifecycle.getSessionState).mockReturnValue("running");
    vi.mocked(pumpSessionLifecycle.getLastEndedEvent).mockReturnValue({ reason: "user-confirm", at: 1234 });
    vi.mocked(pushPumpMilkUploadForPumpSessionEnd).mockResolvedValue(undefined);
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  it("waits for BLE stop before uploading the summary, then navigates home", async () => {
    const order: string[] = [];
    const stop = deferred();
    const summary = deferred();
    const { result, navigateHome, pushStopPumpAgentSummary, stopPumpWithBle } = renderController({
      stopPumpWithBle: vi.fn(() => {
        order.push("stop");
        return stop.promise;
      }),
      pushStopPumpAgentSummary: vi.fn(() => {
        order.push("summary");
        return summary.promise;
      }),
      navigateHome: vi.fn(() => order.push("navigate")),
    });

    let finishPromise!: Promise<void>;
    act(() => {
      finishPromise = result.current.confirmFinish();
    });

    expect(order).toEqual(["stop"]);
    expect(navigateHome).not.toHaveBeenCalled();

    await act(async () => {
      stop.resolve();
      await stop.promise;
    });

    expect(order).toEqual(["stop", "summary"]);
    expect(vi.mocked(pushPumpMilkUploadForPumpSessionEnd).mock.invocationCallOrder[0]).toBeGreaterThan(
      vi.mocked(stopPumpWithBle).mock.invocationCallOrder[0],
    );
    expect(vi.mocked(pushPumpMilkUploadForPumpSessionEnd).mock.invocationCallOrder[0]).toBeLessThan(
      vi.mocked(pushStopPumpAgentSummary).mock.invocationCallOrder[0],
    );
    expect(navigateHome).not.toHaveBeenCalled();

    await act(async () => {
      summary.resolve();
      await finishPromise;
    });

    expect(order).toEqual(["stop", "summary", "navigate"]);
    expect(resetPumpAgentUploadProcessProgress).toHaveBeenCalledTimes(1);
    expect(vi.mocked(resetPumpAgentUploadProcessProgress).mock.invocationCallOrder[0]).toBeGreaterThan(
      vi.mocked(pushStopPumpAgentSummary).mock.invocationCallOrder[0],
    );
    expect(vi.mocked(resetPumpAgentUploadProcessProgress).mock.invocationCallOrder[0]).toBeLessThan(
      vi.mocked(navigateHome).mock.invocationCallOrder[0],
    );
  });

  it("allows retry when summary upload fails", async () => {
    const pushStopPumpAgentSummary = vi
      .fn()
      .mockRejectedValueOnce(new Error("summary failed"))
      .mockResolvedValueOnce(undefined);
    const { result } = renderController({
      pushStopPumpAgentSummary,
      stopPumpWithBle: vi.fn(() => Promise.resolve()),
    });

    await act(async () => {
      await result.current.confirmFinish();
    });
    await act(async () => {
      await result.current.confirmFinish();
    });

    expect(pushStopPumpAgentSummary).toHaveBeenCalledTimes(2);
    expect(pushPumpMilkUploadForPumpSessionEnd).toHaveBeenCalledTimes(1);
  });

  it("passes the displayed elapsed seconds to the summary upload", async () => {
    const pushStopPumpAgentSummary = vi.fn(() => Promise.resolve());
    const { result } = renderController({
      elapsed: 45,
      pushStopPumpAgentSummary,
      stopPumpWithBle: vi.fn(() => Promise.resolve()),
    });

    await act(async () => {
      await result.current.confirmFinish();
    });

    expect(pushStopPumpAgentSummary).toHaveBeenCalledWith(
      expect.objectContaining({ reason: "user-confirm", at: 1234 }),
      { displayedDurationSeconds: 45 },
    );
  });
});
