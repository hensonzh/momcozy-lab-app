import { afterEach, describe, expect, it, vi } from "vitest";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";
import { chatStore } from "@/lib/chatStore";
import { postPumpSessionSummaryWebSocket } from "@/lib/agentApi";
import { pushPumpMilkUploadForPumpSessionEnd, pushPumpStopAgentSummaryToChat } from "@/lib/pumpAutoEndSession";
import { uploadPumpMilkRecord } from "@/lib/momPumpTwinAgentApi";

vi.mock("@capacitor/core", () => ({
  Capacitor: {
    getPlatform: vi.fn(() => "web"),
    isNativePlatform: vi.fn(() => false),
  },
  registerPlugin: vi.fn(() => ({})),
}));

vi.mock("@/lib/agentApi", () => ({
  parseChatRichTextFromSseData: vi.fn(() => null),
  postAgUiWebSocketStream: vi.fn(),
  postPumpSessionSummaryWebSocket: vi.fn(),
}));

vi.mock("@/lib/momPumpTwinAgentApi", () => ({
  uploadPumpMilkRecord: vi.fn(),
}));

vi.mock("@/lib/agentConversationSession", () => ({
  getAgentConversationIdForRequest: vi.fn(() => "conversation-1"),
  getAgUiThreadIdForRequest: vi.fn(() => "thread-1"),
  persistAgentConversationIdFromSse: vi.fn(),
  persistAgUiThreadId: vi.fn(),
}));

vi.mock("@/lib/pumpAgentUpload", () => ({
  getPumpAgentUploadProcessProgress: vi.fn(() => ({
    processL: 70,
    processR: 80,
    processAll: 75,
  })),
  markPumpAgentUploadProcessStepStop: vi.fn(),
  resetPumpAgentUploadProcessProgress: vi.fn(),
  setPumpAgentUploadOperationSource: vi.fn(),
}));

function storedDevice(side: "L" | "R", patch: Partial<StoredDeviceInfo>): StoredDeviceInfo {
  return {
    deviceId: `${side}-device`,
    deviceName: side,
    connected: true,
    battery: 90,
    flangeSize: 24,
    sealSize: "",
    model: "pump",
    firmware: "1.0",
    serialNumber: `${side}-sn`,
    pumpMode: side === "L" ? 0 : 1,
    gear: side === "L" ? 3 : 4,
    pumpWorkState: 0,
    pumpScene: 1,
    duration: side === "L" ? 321 : 300,
    milkMl: side === "L" ? 12.3 : 8.2,
    finalMilkMl: side === "L" ? 12.8 : 8.5,
    milkFlag: 1,
    moFlag: side === "L" ? 1 : 0,
    ...patch,
  };
}

describe("pushPumpStopAgentSummaryToChat", () => {
  afterEach(() => {
    deviceStore.setDevice("L", null);
    deviceStore.setDevice("R", null);
    chatStore.setMessages([]);
    vi.clearAllMocks();
  });

  it("uploads the same milk values and elapsed time shown in the pump session UI", async () => {
    deviceStore.setDevice("L", storedDevice("L", { duration: 60 }));
    deviceStore.setDevice("R", storedDevice("R", { duration: 60 }));
    vi.mocked(postPumpSessionSummaryWebSocket).mockResolvedValue({
      status: 200,
      data: {
        error: 0,
        chat_message: {
          id: "summary-id",
          content: "本次吸乳小结",
          timestamp: "12:30",
          cardType: "report",
        },
      },
    });

    const summary = await pushPumpStopAgentSummaryToChat(
      { reason: "user-confirm", at: 1234 },
      { displayedDurationSeconds: 45 },
    );

    expect(summary?.content).toBe("本次吸乳小结");
    expect(chatStore.get().messages.at(-1)?.content).toBe("本次吸乳小结");
    expect(postPumpSessionSummaryWebSocket).toHaveBeenCalledWith(
      expect.objectContaining({
        conversation_id: "conversation-1",
        process_all: 75,
        total_milk_ml: 20,
        duration_seconds: 45,
        left: expect.objectContaining({
          milk_ml: 12,
          process: 70,
          duration_seconds: 45,
          has_letdown: true,
        }),
        right: expect.objectContaining({
          milk_ml: 8,
          process: 80,
          duration_seconds: 45,
          has_letdown: false,
        }),
      }),
      expect.objectContaining({ timeoutMs: 15000 }),
    );
  });

  it("uploads a pump-milk record using the displayed milk snapshot", async () => {
    const endedAt = new Date(2026, 4, 22, 8, 9, 30).getTime();
    deviceStore.setDevice("L", storedDevice("L", { milkMl: 12.3, finalMilkMl: 12.9 }));
    deviceStore.setDevice("R", storedDevice("R", { milkMl: 8.2, finalMilkMl: 8.9 }));
    vi.mocked(uploadPumpMilkRecord).mockResolvedValue({ error: 0, pump_id: 123 });

    await pushPumpMilkUploadForPumpSessionEnd({ reason: "user-confirm", at: endedAt });

    expect(uploadPumpMilkRecord).toHaveBeenCalledWith({
      user_id: expect.any(String),
      pump_type: 0,
      pump_source: 0,
      pump_time: "08:09",
      pump_milk_volum: 20,
    });
  });
});
