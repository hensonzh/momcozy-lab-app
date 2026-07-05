import {
  clearLegacyAgentConversationIdStorage,
  clearPersistedAgentConversationId,
  clearPersistedAgUiThreadId,
} from "@/lib/agentConversationSession";
import { clearPersistedChatMessages } from "@/lib/chatMessagesLocalPersistence";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";

export type RuntimeMomStage = "prenatal" | "postpartum";

export interface RuntimeUserConfig {
  userId: string;
  momStage: RuntimeMomStage;
  source: "runtime" | "env";
}

export const RUNTIME_USER_ID_STORAGE_KEY = "mai_debug_user_id";
export const RUNTIME_USER_STAGE_STORAGE_KEY = "mai_debug_user_stage";
export const RUNTIME_USER_IDS_STORAGE_KEY = "mai_debug_user_ids";
export const ANONYMOUS_RUNTIME_USER_ID_STORAGE_KEY = "mai_anonymous_user_id";
const RUNTIME_USER_DATA_STORAGE_PREFIX = "mai_debug_user_data:";

const ANONYMOUS_USER_ID_PREFIX = "demo-user";

const USER_RUNTIME_LOCAL_STORAGE_KEYS = [
  RUNTIME_USER_ID_STORAGE_KEY,
  RUNTIME_USER_STAGE_STORAGE_KEY,
] as const;

const USER_CONFIG_LOCAL_STORAGE_KEYS = [
  "mai_agent_hub_chat_messages_v1",
  "mai_agent_conversation_id",
  "momcozy_conversation_id",
  "calibration",
  "calibrationInProgress",
  "calibration_prompt_disabled",
  "calibration_decline_count",
  "chaseMilkTasks",
  "activePlanIds",
  "currentLactationGoal",
  "device_store",
  "momcozy_user_id",
  "momcozy_ibclc_consult_completed",
  "momcozy_ibclc_consult_completions",
  "momcozy_ibclc_return_to",
  "momcozy_ibclc_return_viewport",
] as const;

const ACTIVE_USER_LOCAL_STORAGE_KEYS = [
  ...USER_RUNTIME_LOCAL_STORAGE_KEYS,
  ...USER_CONFIG_LOCAL_STORAGE_KEYS,
] as const;

interface RuntimeUserSnapshot {
  momStage: RuntimeMomStage;
  values: Record<string, string>;
}

export function normalizeRuntimeMomStage(raw: string | undefined | null): RuntimeMomStage {
  return raw?.trim().toLowerCase() === "prenatal" ? "prenatal" : "postpartum";
}

function isRuntimeMomStage(raw: string): boolean {
  const value = raw.trim().toLowerCase();
  return value === "prenatal" || value === "postpartum";
}

function readLocalStorageValue(key: string): string {
  try {
    return localStorage.getItem(key)?.trim() ?? "";
  } catch {
    return "";
  }
}

function removeLocalStorageValue(key: string): void {
  try {
    localStorage.removeItem(key);
  } catch {
    /* ignore */
  }
}

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    if (!raw?.trim()) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function writeJson(key: string, value: unknown): void {
  localStorage.setItem(key, JSON.stringify(value));
}

function userDataStorageKey(userId: string): string {
  return `${RUNTIME_USER_DATA_STORAGE_PREFIX}${encodeURIComponent(userId)}`;
}

function normalizeUserIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  raw.forEach((item) => {
    if (typeof item !== "string") return;
    const userId = item.trim();
    if (!userId || seen.has(userId)) return;
    seen.add(userId);
    result.push(userId);
  });
  return result;
}

export function getRuntimeUserIds(): string[] {
  return normalizeUserIds(readJson<unknown>(RUNTIME_USER_IDS_STORAGE_KEY, []));
}

export function getRuntimeMomStageForUser(userId: string, defaultMomStage?: string): RuntimeMomStage {
  const trimmed = userId.trim();
  if (!trimmed) return normalizeRuntimeMomStage(defaultMomStage);
  if (trimmed === readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY)) {
    return getRuntimeMomStage(defaultMomStage);
  }
  return readSnapshotForUser(trimmed)?.momStage ?? normalizeRuntimeMomStage(defaultMomStage);
}

function writeRuntimeUserIds(userIds: string[]): void {
  const normalized = normalizeUserIds(userIds);
  if (normalized.length === 0) {
    removeLocalStorageValue(RUNTIME_USER_IDS_STORAGE_KEY);
    return;
  }
  writeJson(RUNTIME_USER_IDS_STORAGE_KEY, normalized);
}

function addRuntimeUserId(userId: string): void {
  const ids = getRuntimeUserIds();
  if (ids.includes(userId)) return;
  writeRuntimeUserIds([...ids, userId]);
}

function removeRuntimeUserId(userId: string): void {
  writeRuntimeUserIds(getRuntimeUserIds().filter((id) => id !== userId));
}

function clearActiveUserLocalData(): void {
  deviceStore.setDevice("L", null);
  deviceStore.setDevice("R", null);
  ACTIVE_USER_LOCAL_STORAGE_KEYS.forEach(removeLocalStorageValue);
  clearLegacyAgentConversationIdStorage();
}

async function disconnectActiveBleDevicesForUserSwitch(): Promise<void> {
  const snapshot = deviceStore.get();
  const ble = await import("./ble");
  const sides: DeviceSide[] = ["L", "R"];
  for (const side of sides) {
    const device = snapshot[side];
    if (!device?.connected || !device.deviceId) continue;
    try {
      await ble.disconnect(device.deviceId);
    } catch {
      /* keep switching users even if the physical link already dropped */
    } finally {
      ble.resetBleProtocolStateForDevice(device.deviceId);
      deviceStore.setConnected(side, false);
    }
  }
}

function hasActiveConnectedBleDevice(): boolean {
  const snapshot = deviceStore.get();
  return Boolean(snapshot.L?.connected && snapshot.L.deviceId) || Boolean(snapshot.R?.connected && snapshot.R.deviceId);
}

function readCurrentActiveSnapshot(momStage: RuntimeMomStage): RuntimeUserSnapshot {
  const values: Record<string, string> = {};
  USER_CONFIG_LOCAL_STORAGE_KEYS.forEach((key) => {
    try {
      const value = localStorage.getItem(key);
      if (value != null) values[key] = value;
    } catch {
      /* ignore */
    }
  });
  return { momStage, values };
}

function saveActiveSnapshotForUser(userId: string): void {
  const trimmed = userId.trim();
  if (!trimmed) return;
  const snapshot = readCurrentActiveSnapshot(getRuntimeMomStage());
  writeJson(userDataStorageKey(trimmed), snapshot);
}

function readSnapshotForUser(userId: string): RuntimeUserSnapshot | null {
  const raw = readJson<Partial<RuntimeUserSnapshot> | null>(userDataStorageKey(userId), null);
  if (!raw || typeof raw !== "object") return null;
  return {
    momStage: normalizeRuntimeMomStage(raw.momStage),
    values: raw.values && typeof raw.values === "object" ? raw.values : {},
  };
}

function restoreSnapshotForUser(userId: string, fallbackMomStage: RuntimeMomStage): RuntimeMomStage {
  const snapshot = readSnapshotForUser(userId);
  const momStage = snapshot?.momStage ?? fallbackMomStage;
  if (snapshot) {
    Object.entries(snapshot.values).forEach(([key, value]) => {
      if (typeof value !== "string") return;
      localStorage.setItem(key, value);
    });
  }
  return momStage;
}

export function getRuntimeUserId(defaultUserId?: string): string {
  return readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY) || defaultUserId?.trim() || getAnonymousRuntimeUserId();
}

function getAnonymousRuntimeUserId(): string {
  const stored = readLocalStorageValue(ANONYMOUS_RUNTIME_USER_ID_STORAGE_KEY);
  if (stored) return stored;
  const created = createAnonymousRuntimeUserId();
  try {
    localStorage.setItem(ANONYMOUS_RUNTIME_USER_ID_STORAGE_KEY, created);
  } catch {
    /* keep the generated id for this call even if storage is unavailable */
  }
  return created;
}

function createAnonymousRuntimeUserId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${ANONYMOUS_USER_ID_PREFIX}-${crypto.randomUUID()}`;
  }
  return `${ANONYMOUS_USER_ID_PREFIX}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

export function getRuntimeMomStage(defaultMomStage?: string): RuntimeMomStage {
  const stored = readLocalStorageValue(RUNTIME_USER_STAGE_STORAGE_KEY);
  if (stored) return normalizeRuntimeMomStage(stored);
  return normalizeRuntimeMomStage(defaultMomStage);
}

export function getRuntimeUserConfig(defaults?: {
  defaultUserId?: string;
  defaultMomStage?: string;
}): RuntimeUserConfig {
  const storedUserId = readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY);
  const storedStage = readLocalStorageValue(RUNTIME_USER_STAGE_STORAGE_KEY);
  const hasRuntimeOverride = Boolean(storedUserId || (storedStage && isRuntimeMomStage(storedStage)));
  return {
    userId: getRuntimeUserId(defaults?.defaultUserId),
    momStage: getRuntimeMomStage(defaults?.defaultMomStage),
    source: hasRuntimeOverride ? "runtime" : "env",
  };
}

export function saveRuntimeUserConfig(input: { userId: string; momStage: RuntimeMomStage }): RuntimeUserConfig {
  const userId = input.userId.trim();
  if (!userId) {
    throw new Error("userId is required");
  }
  const momStage = normalizeRuntimeMomStage(input.momStage);
  const currentUserId = readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY);
  if (currentUserId && currentUserId !== userId) {
    saveActiveSnapshotForUser(currentUserId);
    clearActiveUserLocalData();
  }
  addRuntimeUserId(userId);
  const restoredMomStage = currentUserId && currentUserId !== userId
    ? restoreSnapshotForUser(userId, momStage)
    : momStage;
  localStorage.setItem(RUNTIME_USER_ID_STORAGE_KEY, userId);
  localStorage.setItem(RUNTIME_USER_STAGE_STORAGE_KEY, restoredMomStage);
  return { userId, momStage: restoredMomStage, source: "runtime" };
}

export function switchRuntimeUserConfig(
  input: { userId: string; momStage: RuntimeMomStage },
): RuntimeUserConfig | Promise<RuntimeUserConfig> {
  const nextUserId = input.userId.trim();
  const currentUserId = readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY);
  if (currentUserId && currentUserId !== nextUserId && hasActiveConnectedBleDevice()) {
    return switchRuntimeUserConfigAsync(input);
  }
  return saveRuntimeUserConfig(input);
}

export async function switchRuntimeUserConfigAsync(input: {
  userId: string;
  momStage: RuntimeMomStage;
}): Promise<RuntimeUserConfig> {
  const nextUserId = input.userId.trim();
  const currentUserId = readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY);
  if (currentUserId && currentUserId !== nextUserId) {
    await disconnectActiveBleDevicesForUserSwitch();
  }
  return saveRuntimeUserConfig(input);
}

export function clearRuntimeUserInfo(): void | Promise<void> {
  const currentUserId = readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY);
  if (currentUserId && hasActiveConnectedBleDevice()) {
    return clearRuntimeUserInfoAsync();
  }
  if (currentUserId) {
    removeRuntimeUserId(currentUserId);
    removeLocalStorageValue(userDataStorageKey(currentUserId));
  }
  clearActiveUserLocalData();
  clearPersistedChatMessages();
  clearPersistedAgentConversationId();
  clearPersistedAgUiThreadId();
}

export async function clearRuntimeUserInfoAsync(): Promise<void> {
  const currentUserId = readLocalStorageValue(RUNTIME_USER_ID_STORAGE_KEY);
  if (currentUserId) {
    await disconnectActiveBleDevicesForUserSwitch();
    removeRuntimeUserId(currentUserId);
    removeLocalStorageValue(userDataStorageKey(currentUserId));
  }
  clearActiveUserLocalData();
  clearPersistedChatMessages();
  clearPersistedAgentConversationId();
  clearPersistedAgUiThreadId();
}
