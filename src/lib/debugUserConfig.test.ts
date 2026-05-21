import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  clearRuntimeUserInfo,
  getRuntimeMomStage,
  getRuntimeUserConfig,
  getRuntimeUserIds,
  getRuntimeUserId,
  RUNTIME_USER_ID_STORAGE_KEY,
  RUNTIME_USER_STAGE_STORAGE_KEY,
  saveRuntimeUserConfig,
  switchRuntimeUserConfig,
} from "./debugUserConfig";
import { AGENT_CONVERSATION_ID_STORAGE_KEY, AG_UI_THREAD_ID_STORAGE_KEY } from "./agentConversationSession";
import { CHAT_MESSAGES_STORAGE_KEY } from "./chatMessagesLocalPersistence";
import { deviceStore } from "./deviceStore";
import { disconnect as bleDisconnect, resetBleProtocolStateForDevice } from "./ble";

vi.mock("./ble", () => ({
  disconnect: vi.fn(() => Promise.resolve()),
  resetBleProtocolStateForDevice: vi.fn(),
}));

const connectedLeftDevice = {
  deviceId: "left-device",
  deviceName: "Left Pump",
  connected: true,
  battery: 88,
  flangeSize: 24,
  sealSize: "M",
  model: "Air One",
  firmware: "1.0.0",
  serialNumber: "SN-L",
  pumpWorkState: 1,
  pumpScene: 1 as const,
};

describe("debugUserConfig", () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    deviceStore.setDevice("L", null);
    deviceStore.setDevice("R", null);
    vi.clearAllMocks();
  });

  it("uses local runtime user config before env defaults", () => {
    saveRuntimeUserConfig({ userId: "debug-user-001", momStage: "prenatal" });

    expect(getRuntimeUserId("env-user")).toBe("debug-user-001");
    expect(getRuntimeMomStage("postpartum")).toBe("prenatal");
    expect(getRuntimeUserConfig({ defaultUserId: "env-user", defaultMomStage: "postpartum" })).toEqual({
      userId: "debug-user-001",
      momStage: "prenatal",
      source: "runtime",
    });
  });

  it("falls back to env defaults and normalizes invalid stages", () => {
    localStorage.setItem(RUNTIME_USER_STAGE_STORAGE_KEY, "unknown");

    expect(getRuntimeUserId("env-user")).toBe("env-user");
    expect(getRuntimeMomStage("unknown")).toBe("postpartum");
    expect(getRuntimeUserConfig({ defaultUserId: "env-user", defaultMomStage: "prenatal" })).toEqual({
      userId: "env-user",
      momStage: "postpartum",
      source: "env",
    });
  });

  it("deletes current user info, chat history, conversations, local user configs, and removes it from user list", () => {
    saveRuntimeUserConfig({ userId: "debug-user-001", momStage: "prenatal" });
    localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, "[]");
    localStorage.setItem(AGENT_CONVERSATION_ID_STORAGE_KEY, "conv-1");
    localStorage.setItem(AG_UI_THREAD_ID_STORAGE_KEY, "thread-1");
    localStorage.setItem("calibration", "{}");
    localStorage.setItem("calibrationInProgress", "true");
    localStorage.setItem("calibration_prompt_disabled", "true");
    localStorage.setItem("calibration_decline_count", "2");
    localStorage.setItem("chaseMilkTasks", "[]");
    localStorage.setItem("activePlanIds", "[]");
    localStorage.setItem("currentLactationGoal", "{}");
    localStorage.setItem("mai_agent_hub_chat_messages_v1", "[]");
    sessionStorage.setItem(AGENT_CONVERSATION_ID_STORAGE_KEY, "conv-session");

    clearRuntimeUserInfo();

    expect(getRuntimeUserIds()).toEqual([]);
    expect(localStorage.getItem(RUNTIME_USER_ID_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem(RUNTIME_USER_STAGE_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem(AGENT_CONVERSATION_ID_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem(AG_UI_THREAD_ID_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem("calibration")).toBeNull();
    expect(localStorage.getItem("calibrationInProgress")).toBeNull();
    expect(localStorage.getItem("calibration_prompt_disabled")).toBeNull();
    expect(localStorage.getItem("calibration_decline_count")).toBeNull();
    expect(localStorage.getItem("chaseMilkTasks")).toBeNull();
    expect(localStorage.getItem("activePlanIds")).toBeNull();
    expect(localStorage.getItem("currentLactationGoal")).toBeNull();
    expect(sessionStorage.getItem(AGENT_CONVERSATION_ID_STORAGE_KEY)).toBeNull();
  });

  it("saves previous user data and restores selected existing user data when switching users", () => {
    saveRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });
    localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, JSON.stringify([{ id: "old-chat" }]));
    localStorage.setItem(AGENT_CONVERSATION_ID_STORAGE_KEY, "conv-1");
    localStorage.setItem(AG_UI_THREAD_ID_STORAGE_KEY, "thread-1");
    localStorage.setItem("calibration", '{"user":"old"}');
    localStorage.setItem("chaseMilkTasks", '["old-task"]');

    saveRuntimeUserConfig({ userId: "new-user", momStage: "prenatal" });
    localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, JSON.stringify([{ id: "new-chat" }]));
    localStorage.setItem(AGENT_CONVERSATION_ID_STORAGE_KEY, "conv-2");
    localStorage.setItem(AG_UI_THREAD_ID_STORAGE_KEY, "thread-2");
    localStorage.setItem("calibration", '{"user":"new"}');

    saveRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });

    expect(getRuntimeUserConfig({ defaultUserId: "env-user", defaultMomStage: "postpartum" })).toEqual({
      userId: "old-user",
      momStage: "postpartum",
      source: "runtime",
    });
    expect(getRuntimeUserIds()).toEqual(["old-user", "new-user"]);
    expect(localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY)).toBe(JSON.stringify([{ id: "old-chat" }]));
    expect(localStorage.getItem(AGENT_CONVERSATION_ID_STORAGE_KEY)).toBe("conv-1");
    expect(localStorage.getItem(AG_UI_THREAD_ID_STORAGE_KEY)).toBe("thread-1");
    expect(localStorage.getItem("calibration")).toBe('{"user":"old"}');
    expect(localStorage.getItem("chaseMilkTasks")).toBe('["old-task"]');
  });

  it("creates a new user and resets active data without deleting previous user snapshot", () => {
    saveRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });
    localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, JSON.stringify([{ id: "old-chat" }]));
    localStorage.setItem("calibration", '{"user":"old"}');

    saveRuntimeUserConfig({ userId: "brand-new-user", momStage: "prenatal" });

    expect(getRuntimeUserIds()).toEqual(["old-user", "brand-new-user"]);
    expect(getRuntimeUserConfig({ defaultUserId: "env-user", defaultMomStage: "postpartum" })).toEqual({
      userId: "brand-new-user",
      momStage: "prenatal",
      source: "runtime",
    });
    expect(localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem("calibration")).toBeNull();

    saveRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });
    expect(localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY)).toBe(JSON.stringify([{ id: "old-chat" }]));
    expect(localStorage.getItem("calibration")).toBe('{"user":"old"}');
  });

  it("switches users by clearing only active displayed data while preserving the previous user's snapshot", () => {
    saveRuntimeUserConfig({ userId: "display-user", momStage: "postpartum" });
    localStorage.setItem(CHAT_MESSAGES_STORAGE_KEY, JSON.stringify([{ id: "display-chat" }]));
    localStorage.setItem("calibration", '{"display":true}');

    switchRuntimeUserConfig({ userId: "empty-user", momStage: "prenatal" });

    expect(getRuntimeUserIds()).toEqual(["display-user", "empty-user"]);
    expect(localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY)).toBeNull();
    expect(localStorage.getItem("calibration")).toBeNull();

    switchRuntimeUserConfig({ userId: "display-user", momStage: "postpartum" });
    expect(localStorage.getItem(CHAT_MESSAGES_STORAGE_KEY)).toBe(JSON.stringify([{ id: "display-chat" }]));
    expect(localStorage.getItem("calibration")).toBe('{"display":true}');
  });

  it("disconnects active BLE devices before saving the previous user's device snapshot", async () => {
    saveRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });
    deviceStore.setDevice("L", connectedLeftDevice);

    await switchRuntimeUserConfig({ userId: "new-user", momStage: "prenatal" });

    expect(bleDisconnect).toHaveBeenCalledWith("left-device");
    expect(resetBleProtocolStateForDevice).toHaveBeenCalledWith("left-device");
    expect(localStorage.getItem("device_store")).toBeNull();

    await switchRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });

    const restored = JSON.parse(localStorage.getItem("device_store") ?? "{}");
    expect(restored.L).toMatchObject({
      deviceId: "left-device",
      connected: false,
      pumpWorkState: 0,
    });
  });

  it("keeps device snapshots isolated so a new user does not inherit the previous user's devices", async () => {
    saveRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });
    deviceStore.setDevice("L", connectedLeftDevice);

    await switchRuntimeUserConfig({ userId: "brand-new-user", momStage: "prenatal" });

    expect(localStorage.getItem("device_store")).toBeNull();

    await switchRuntimeUserConfig({ userId: "old-user", momStage: "postpartum" });

    const restored = JSON.parse(localStorage.getItem("device_store") ?? "{}");
    expect(restored.L.deviceId).toBe("left-device");
    expect(restored.L.connected).toBe(false);
  });
});
