/** 刺激/深度 分档记忆（B1 线 0–14），与 pumpGearMemory 一致 */
export interface PumpGearMemoryPair {
  stimulate?: number;
  deep?: number;
}

/** Per-side BLE device info stored after connection (shared across pages). */
export interface StoredDeviceInfo {
  deviceId: string;
  deviceName: string;
  connected: boolean;
  battery: number;
  /** 最近一次扫描到的 RSSI（dBm），用于信号强度展示 */
  rssi?: number;
  flangeSize: number;
  sealSize: string;
  model: string;
  firmware: string;
  serialNumber: string;
  /** E1 吸乳模式 0刺激 1吸乳 2混合（协议值，用于同步到 PumpSession） */
  pumpMode?: number;
  /** E1 挡位 0-14（协议值，用于同步到 PumpSession） */
  gear?: number;
  /** 泵启停状态：0x00 暂停，0x01 工作（E1/D0/B1 成功后同步，会话页恢复用） */
  pumpWorkState?: number;
  /** B1 场景字节：0 手动，1 自动（与吸乳页 AI/手动 对应，用于恢复与下发一致） */
  pumpScene?: 0 | 1;
  /** E1 吸乳时长，单位秒 */
  duration?: number;
  /** 最终奶量，单位为ml */
  finalMilkMl?: number;
  /** Mai（自动）场景下：刺激/深度 各自记忆的 B1 档位（0–14），由 D0/B1 更新 */
  pumpGearMemoryAi?: PumpGearMemoryPair;
  /** 手动场景下：刺激/深度 各自记忆的 B1 档位 */
  pumpGearMemoryManual?: PumpGearMemoryPair;
  /** 滴定挡位：刺激/深度 各自B1 档位 */
  pumpGearCalib?: PumpGearMemoryPair;
  /** 实时奶阵/流量（收到 0x80 包后更新；初始可能为空） */
  flowFloat?: number;
  /** 实时奶量（收到 0x80 包后更新；单位 ml） */
  milkMl?: number;
  /** 有无奶标志位（收到 0x80 包后更新） */
  milkFlag?: number;
  /** 奶阵标志位（收到 0x80 包后更新） */
  moFlag?: number;
  /** 乳流强度（收到 0x80 包后更新） */
  bandpower?: number;
  /** 姿态俯仰角（收到 0x80 包后更新） */
  pitch?: number;
  /** 姿态横滚角（收到 0x80 包后更新） */
  roll?: number;
  /** 通道1负压（收到 0x80 包后更新） */
  pressureCh1?: number;
  /** 通道2负压（收到 0x80 包后更新） */
  pressureCh2?: number;
  /** 设备状态类数据包（E1/D0/D1/D4/D5/D6）最新时间戳，UTC 字符串 */
  lastDeviceWorkstateTs?: string;
  /** 吸乳进程类数据包（当前为 0x80）最新时间戳，UTC 字符串 */
  lastDeviceProcessTs?: string;
}

export type DeviceSide = "L" | "R";

interface DeviceStoreState {
  L: StoredDeviceInfo | null;
  R: StoredDeviceInfo | null;
}

const STORAGE_KEY = "device_store";

const state: DeviceStoreState = {
  L: null,
  R: null,
};

function ensureConnectedFalse<T extends { connected?: boolean }>(obj: T): T {
  return { ...obj, connected: false };
}

function resetRealtimeProcessFields(info: StoredDeviceInfo): StoredDeviceInfo {
  return {
    ...info,
    flowFloat: 0,
    milkMl: 0,
    milkFlag: 0,
    moFlag: 0,
    bandpower: 0,
    pitch: 0,
    roll: 0,
    pressureCh1: 0,
    pressureCh2: 0,
    // 持久化恢复必须把 pumpWorkState 清零：上次进程残留的 0x01（运行中）会与新会话首次 E1 应答到达前的
    // touchDevicePacketTimestamp 写入产生「脏 workState + 新 ts」中间态，被 pumpSessionLifecycle 误判为 running。
    pumpWorkState: 0,
    // 同理 pumpScene 也清零，避免 idle/paused 阶段冷启动时被旧场景值误导。
    pumpScene: 0,
    lastDeviceWorkstateTs: "",
    lastDeviceProcessTs: "",
  };
}

function sanitizeRestoredDevice(info: StoredDeviceInfo): StoredDeviceInfo {
  return resetRealtimeProcessFields(ensureConnectedFalse(info));
}

function readPersistedSync(): void {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw) as DeviceStoreState;
    if (parsed.L) state.L = sanitizeRestoredDevice(parsed.L);
    if (parsed.R) state.R = sanitizeRestoredDevice(parsed.R);
    writePersisted();
  } catch {
    // ignore invalid or missing data
  }
}

function writePersisted(): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ L: state.L, R: state.R }));
  } catch {
    // ignore quota / private mode
  }
  // When on native and @capacitor/preferences available, also persist there (fire-and-forget)
  import("@capacitor/core").then(({ Capacitor }) => {
    if (Capacitor.isNativePlatform()) {
      return import("@capacitor/preferences").then(({ Preferences }) =>
        Preferences.set({
          key: STORAGE_KEY,
          value: JSON.stringify({ L: state.L, R: state.R }),
        })
      );
    }
  }).catch(() => {});
}

// Restore from localStorage on module load so first get() has data
readPersistedSync();

// Optional: on native, overwrite with Capacitor Preferences when available
(async () => {
  try {
    const { Capacitor } = await import("@capacitor/core");
    if (!Capacitor.isNativePlatform()) return;
    const { Preferences } = await import("@capacitor/preferences");
    const { value } = await Preferences.get({ key: STORAGE_KEY });
    if (value) {
      const parsed = JSON.parse(value) as DeviceStoreState;
      if (parsed.L) state.L = sanitizeRestoredDevice(parsed.L);
      if (parsed.R) state.R = sanitizeRestoredDevice(parsed.R);
      writePersisted();
    }
  } catch {
    // use existing state from localStorage
  }
})();

const listeners = new Set<() => void>();

function notifyListeners(): void {
  listeners.forEach((cb) => cb());
}

export const deviceStore = {
  get(): DeviceStoreState {
    return { ...state };
  },

  /** 订阅 store 变更（如 setDevice / setConnected），返回取消订阅函数。设备离线时 UI 可据此刷新卡片。 */
  subscribe(listener: () => void): () => void {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },

  setDevice(side: DeviceSide, info: StoredDeviceInfo | null): void {
    state[side] = info;
    writePersisted();
    notifyListeners();
  },

  setConnected(side: DeviceSide, connected: boolean): void {
    if (state[side]) {
      if (connected) {
        state[side] = { ...state[side]!, connected: true };
      } else {
        // 断联同步清除 workstate 相关残留：避免后续重连后 setConnected(true) 先于 E1 应答到达，
        // 让 lifecycle 看到「在线 + 旧 pumpWorkState=0x01 + 旧 ts」而误判为 running。
        state[side] = {
          ...state[side]!,
          connected: false,
          pumpWorkState: 0,
          lastDeviceWorkstateTs: "",
        };
      }
      writePersisted();
      notifyListeners();
    }
  },
};
