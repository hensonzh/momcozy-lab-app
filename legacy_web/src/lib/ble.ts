import { Capacitor, registerPlugin, type PluginListenerHandle } from "@capacitor/core";
import {
  buildAck,
  buildF1SetUserParams,
  getCidFromReqPacket,
  parseFrame,
  parseBFEndRunResponse,
  parseD0OperationRecord,
  parseD1PowerOff,
  parseD4OfflineData,
  parseD5Letdown,
  parseD6Battery,
  parse80RealtimeMilk,
  CT_ACK,
  CT_NACK,
  CT_NOTIFY,
  CT_DEVICE,
} from "./bleProtocol";
import { deviceStore, type DeviceSide } from "./deviceStore";
import { mergeE1PumpGearCalibWireIntoCalibrationLocalStorage, logCalibrationE1MergeSkippedFromConfigurePump } from "./calibrationLocalStorage";
import { markPumpAgentUploadDeviceSourceByPacket } from "./pumpAgentUpload";
import {
  reportDeviceInfoAfterPhysicalDisconnect,
  reportDeviceInfoAfterProtocolConfigured,
} from "./deviceInfoReport";
import { warn as loggerWarn, createScopedConsole } from "./logger";

const console = createScopedConsole("ble");

// ─── 主机 BLE UUIDs ───
/** 主机服务 UUID */
export const PUMP_SERVICE_UUID = "0000af00-0000-1000-8000-00805f9b34fb";
/** 主机写通道（writeWithoutResponse）UUID */
export const PUMP_CMD_CHAR_UUID = "0000af01-0000-1000-8000-00805f9b34fb";
/** 主机通知通道（notify）UUID */
export const PUMP_NOTIFY_CHAR_UUID = "0000af02-0000-1000-8000-00805f9b34fb";

/** True only on Android; BLE is implemented by the app's native Android plugin. */
export function isBleSupported(): boolean {
  const platform = Capacitor.getPlatform();
  return platform === "android";
}

/** Minimal scan result shape for the UI; plugin types are used only inside this module. */
export interface BleScanResult {
  device: { deviceId: string; name?: string };
  localName?: string;
  rssi?: number;
}

interface MmcBlePlugin {
  initialize(options?: InitializeBleOptions): Promise<void>;
  requestLEScan(options?: { allowDuplicates?: boolean }): Promise<void>;
  stopLEScan(): Promise<void>;
  getConnectedDevices(options?: { services?: string[] }): Promise<{ devices: Array<{ deviceId: string; name?: string }> }>;
  connect(options: { deviceId: string }): Promise<void>;
  disconnect(options: { deviceId: string }): Promise<void>;
  read(options: { deviceId: string; serviceUUID: string; characteristicUUID: string }): Promise<{ value: number[] }>;
  write(options: { deviceId: string; serviceUUID: string; characteristicUUID: string; value: number[] }): Promise<void>;
  writeWithoutResponse(options: { deviceId: string; serviceUUID: string; characteristicUUID: string; value: number[] }): Promise<void>;
  startNotifications(options: { deviceId: string; serviceUUID: string; characteristicUUID: string }): Promise<void>;
  stopNotifications(options: { deviceId: string; serviceUUID: string; characteristicUUID: string }): Promise<void>;
  openBluetoothSettings(): Promise<void>;
  openAppSettings(): Promise<void>;
  nativeSetPumpParams(options: { deviceId: string; startStop: 0 | 1; mode: 0 | 1 | 2; gear: number; scene: 0 | 1 }): Promise<NativeProtocolReqResult>;
  nativePowerOff(options: { deviceId: string; reboot?: 0 | 1 }): Promise<NativeProtocolReqResult>;
  nativeEndRun(options: { deviceId: string }): Promise<NativeProtocolReqResult>;
  nativeGetDeviceInfo(options: { deviceId: string }): Promise<NativeProtocolReqResult>;
  nativeSetRtc(options: { deviceId: string; utcSeconds: number }): Promise<NativeProtocolReqResult>;
  nativeQueryDeviceStatus(options: { deviceId: string }): Promise<NativeProtocolReqResult>;
  nativeAdjustGearForSide(options: { side: DeviceSide; delta: number }): Promise<NativeProtocolReqResult>;
  nativeSetModeForSide(options: { side: DeviceSide; mode: 0 | 1 | 2 }): Promise<NativeProtocolReqResult>;
  nativeSetSceneForSide(options: { side: DeviceSide; scene: 0 | 1 }): Promise<NativeProtocolReqResult>;
  nativeSetStartStopForSide(options: { side: DeviceSide; startStop: 0 | 1 }): Promise<NativeProtocolReqResult>;
  addListener(
    eventName: "scanResult",
    listenerFunc: (event: BleScanResult) => void
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: "notification",
    listenerFunc: (event: { deviceId: string; serviceUUID: string; characteristicUUID: string; value: number[] }) => void
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: "disconnected",
    listenerFunc: (event: { deviceId: string }) => void
  ): Promise<PluginListenerHandle>;
}

const MmcBle = registerPlugin<MmcBlePlugin>("MmcBle");
let nativeScanListener: PluginListenerHandle | null = null;
let nativeScanActive = false;
let nativeScanStartPromise: Promise<void> | null = null;
let nativeScanStopRequested = false;
const nativeNotifyListeners = new Map<string, PluginListenerHandle>();
const nativeDisconnectListeners = new Map<string, PluginListenerHandle>();

function characteristicKey(deviceId: string, serviceUUID: string, characteristicUUID: string): string {
  const normalizeUuid = (uuid: string) =>
    uuid.length === 4 ? `0000${uuid.toLowerCase()}-0000-1000-8000-00805f9b34fb` : uuid.toLowerCase();
  return `${deviceId}|${normalizeUuid(serviceUUID)}|${normalizeUuid(characteristicUUID)}`;
}

function dataViewToByteArray(value: DataView): number[] {
  const out: number[] = [];
  for (let i = 0; i < value.byteLength; i++) out.push(value.getUint8(i));
  return out;
}

function byteArrayToDataView(value: number[] | Uint8Array): DataView {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value.map((b) => b & 0xff));
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return new DataView(copy.buffer);
}

export interface InitializeBleOptions {
  androidNeverForLocation?: boolean;
}

/**
 * Initialize BLE. Call once before scanning. On Android may request location permission.
 * @throws Error with message if BLE is unavailable or user denies permission.
 */
export async function initializeBle(options?: InitializeBleOptions): Promise<void> {
  await MmcBle.initialize(options ?? {});
}

/**
 * Start BLE scan. Call stopLEScan when done. Callback may be invoked multiple times per device (allowDuplicates).
 */
export async function startLEScan(
  callback: (result: BleScanResult) => void
): Promise<void> {
  nativeScanStopRequested = false;
  await nativeScanListener?.remove();
  nativeScanListener = await MmcBle.addListener("scanResult", (result) => {
    callback({
      device: result.device,
      localName: result.localName,
      rssi: result.rssi,
    });
  });

  if (nativeScanActive) return;
  if (nativeScanStartPromise) {
    await nativeScanStartPromise;
    return;
  }

  nativeScanStartPromise = MmcBle.requestLEScan({ allowDuplicates: false })
    .then(() => {
      nativeScanActive = true;
      if (nativeScanStopRequested) {
        void stopLEScan();
      }
    })
    .catch(async (error) => {
      await nativeScanListener?.remove();
      nativeScanListener = null;
      throw error;
    })
    .finally(() => {
      nativeScanStartPromise = null;
    });
  await nativeScanStartPromise;
}

/** Stop an ongoing BLE scan. */
export async function stopLEScan(): Promise<void> {
  nativeScanStopRequested = true;
  if (nativeScanStartPromise) {
    try {
      await nativeScanStartPromise;
    } catch {
      // The start path already cleared the listener; keep stop idempotent.
    }
  }
  if (nativeScanActive) {
    await MmcBle.stopLEScan();
    nativeScanActive = false;
  }
  await nativeScanListener?.remove();
  nativeScanListener = null;
}

/**
 * Query BLE devices that are already connected at the native GATT layer.
 * This is used when the WebView/JS runtime was recreated while the native BLE
 * connection survived: scanning may not discover the device again, but notify
 * and protocol state still need to be rebound to the new JS process.
 */
export async function getConnectedPumpDevices(): Promise<BleScanResult[]> {
  const { devices } = await MmcBle.getConnectedDevices({ services: [PUMP_SERVICE_UUID] });
  return devices.map((device) => ({
    device: {
      deviceId: device.deviceId,
      name: device.name,
    },
    localName: device.name,
  }));
}

// ─── 协议层：REQ 等待 ACK/NACK、Device 解析与 ACK 回包 ───────────────────────
const REQ_TIMEOUT_MS = 3000;
const REQ_MAX_ATTEMPTS = 3;

type PendingEntry = {
  resolve: (value: { ct: number; cid: number; cab: Uint8Array }) => void;
  reject: (reason: Error) => void;
  timeoutId: ReturnType<typeof setTimeout> | null;
};

type PendingFrameEntry = {
  cid: number;
  acceptCts: number[];
  resolve: (frame: Uint8Array) => void;
  reject: (reason: Error) => void;
  timeoutId: ReturnType<typeof setTimeout> | null;
};

const pendingReqs = new Map<string, Map<number, PendingEntry>>();
const pendingFrames = new Map<string, PendingFrameEntry[]>();

function toUtcIsoFromDeviceSeconds(seconds?: number): string | null {
  if (typeof seconds !== "number" || !Number.isFinite(seconds) || seconds <= 0) return null;
  return new Date(seconds * 1000).toISOString();
}

function touchDevicePacketTimestamp(
  deviceId: string,
  timestampSeconds: number | undefined,
  kind: "workstate" | "process",
): void {
  const ts = toUtcIsoFromDeviceSeconds(timestampSeconds);
  if (!ts) return;
  const store = deviceStore.get();
  const patch = kind === "workstate"
    ? { lastDeviceWorkstateTs: ts }
    : { lastDeviceProcessTs: ts };
  if (store.L?.deviceId === deviceId) {
    deviceStore.setDevice("L", { ...store.L, ...patch });
  }
  if (store.R?.deviceId === deviceId) {
    deviceStore.setDevice("R", { ...store.R, ...patch });
  }
}

interface ProtocolChannel {
  onParsed: ((cid: number, data: unknown) => void) | null;
  notifyStarted: boolean;
  unsubscribe: (() => void) | null;
}

const protocolChannels = new Map<string, ProtocolChannel>();

function getOrCreateChannel(deviceId: string): ProtocolChannel {
  let ch = protocolChannels.get(deviceId);
  if (!ch) {
    ch = { onParsed: null, notifyStarted: false, unsubscribe: null };
    protocolChannels.set(deviceId, ch);
  }
  return ch;
}

/**
 * 清除指定设备在内存中的协议状态（待响应 REQ、Notify 订阅标记）。
 * 在 BLE 物理断开或重新发起 connect 前应调用，否则重连后会误判「已订阅 Notify」而跳过 startNotifications，与首次连接行为不一致。
 * @param deviceId 主机 deviceId
 */
export function resetBleProtocolStateForDevice(deviceId: string): void {
  const pending = pendingReqs.get(deviceId);
  if (pending) {
    for (const [, entry] of pending) {
      if (entry.timeoutId != null) clearTimeout(entry.timeoutId);
      entry.reject(new Error("BLE connection reset"));
    }
    pendingReqs.delete(deviceId);
  }
  const framePending = pendingFrames.get(deviceId);
  if (framePending) {
    for (const entry of framePending) {
      if (entry.timeoutId != null) clearTimeout(entry.timeoutId);
      entry.reject(new Error("BLE connection reset"));
    }
    pendingFrames.delete(deviceId);
  }
  const ch = protocolChannels.get(deviceId);
  if (!ch) return;
  ch.onParsed = null;
  if (ch.unsubscribe) {
    ch.unsubscribe();
  } else if (ch.notifyStarted) {
    ch.notifyStarted = false;
    stopNotifications(deviceId, PUMP_SERVICE_UUID, PUMP_NOTIFY_CHAR_UUID).catch(() => {});
  }
  protocolChannels.delete(deviceId);
  // 清除通知通道缓存，确保重连后重新建立通知订阅
  notifyChannels.delete(deviceId);
  console.log(`[BLE协议状态重置] 清除设备 ${deviceId} 的通知通道缓存`);
}

function settlePendingFrame(deviceId: string, rawFrame: Uint8Array, ct: number, cid: number): void {
  const entries = pendingFrames.get(deviceId);
  if (!entries?.length) return;
  const idx = entries.findIndex((entry) => entry.cid === cid && entry.acceptCts.includes(ct));
  if (idx < 0) return;
  const [entry] = entries.splice(idx, 1);
  if (entry.timeoutId != null) clearTimeout(entry.timeoutId);
  entry.resolve(rawFrame);
  if (entries.length === 0) pendingFrames.delete(deviceId);
}

function dispatchNotifyPayload(deviceId: string, buf: Uint8Array): void {
  const frame = parseFrame(buf);
  if (!frame) return;
  settlePendingFrame(deviceId, buf, frame.ct, frame.cid);
  
  // 打印接收到的设备响应数据
  const dataHex = Array.from(buf)
    .map(b => b.toString(16).padStart(2, '0'))
    .join(' ');
  console.log(`[BLE接收响应] 设备: ${deviceId}, CT: ${frame.ct}, CID: 0x${frame.cid.toString(16)}, 数据: ${dataHex}`);

  if (frame.ct === CT_ACK || frame.ct === CT_NACK) {
    const byDevice = pendingReqs.get(deviceId);
    if (byDevice) {
      const entry = byDevice.get(frame.cid);
      if (entry) {
        if (entry.timeoutId != null) clearTimeout(entry.timeoutId);
        byDevice.delete(frame.cid);
        console.log(`[BLE响应处理] 设备: ${deviceId}, 处理 ACK/NACK 响应, CID: 0x${frame.cid.toString(16)}`);
        entry.resolve({ ct: frame.ct, cid: frame.cid, cab: frame.cab });
      } else {
        console.log(`[BLE响应处理] 设备: ${deviceId}, 未找到对应请求, CID: 0x${frame.cid.toString(16)}`);
      }
    } else {
      console.log(`[BLE响应处理] 设备: ${deviceId}, 无 pending 请求, CID: 0x${frame.cid.toString(16)}`);
    }
    return;
  }

  if (frame.ct === CT_DEVICE || frame.ct === CT_NOTIFY) {
    // 仅 CT_DEVICE 需要回 ACK；CT_NOTIFY（0x03）不回 ACK
    if (frame.ct === CT_DEVICE) {
    const ack = buildAck(frame.cid);
    const view = new DataView(ack.buffer, ack.byteOffset, ack.byteLength);
    writeCharacteristicWithoutResponse(
      deviceId,
      PUMP_SERVICE_UUID,
      PUMP_CMD_CHAR_UUID,
      view
    ).catch(() => {});
    }

    const ch = protocolChannels.get(deviceId);
    if (!ch?.onParsed) return;

    let parsed: unknown = null;
    let packetTs: number | undefined;
    switch (frame.cid) {
      case 0xd0:
        parsed = parseD0OperationRecord(frame.cab);
        packetTs = (parsed as ReturnType<typeof parseD0OperationRecord> | null)?.timestamp;
        break;
      case 0xd1:
        parsed = parseD1PowerOff(frame.cab);
        packetTs = (parsed as ReturnType<typeof parseD1PowerOff> | null)?.timestamp;
        break;
      case 0xd4:
        parsed = parseD4OfflineData(frame.cab);
        packetTs = (parsed as ReturnType<typeof parseD4OfflineData> | null)?.timestamp;
        break;
      case 0xd5:
        parsed = parseD5Letdown(frame.cab);
        packetTs = (parsed as ReturnType<typeof parseD5Letdown> | null)?.timestamp;
        break;
      case 0xd6:
        parsed = parseD6Battery(frame.cab);
        packetTs = (parsed as ReturnType<typeof parseD6Battery> | null)?.timestamp;
        break;
      case 0x80:
        parsed = parse80RealtimeMilk(frame.cab);
        packetTs = (parsed as ReturnType<typeof parse80RealtimeMilk> | null)?.timestamp;
        break;
      case 0xbf:
        parsed = parseBFEndRunResponse(frame.cab);
        break;
      default:
        break;
    }
    markPumpAgentUploadDeviceSourceByPacket(frame.cid, deviceId);
    if (frame.cid === 0x80) touchDevicePacketTimestamp(deviceId, packetTs, "process");
    else if (frame.cid === 0xe1 || frame.cid === 0xd0 || frame.cid === 0xd1 || frame.cid === 0xd4 || frame.cid === 0xd5 || frame.cid === 0xd6) {
      touchDevicePacketTimestamp(deviceId, packetTs, "workstate");
    }
    if (parsed != null) ch.onParsed(frame.cid, parsed);
  }
}

// 缓存已建立通知通道的设备ID
const notifyChannels = new Set<string>();

export async function ensureProtocolNotify(deviceId: string): Promise<void> {
  // 检查是否已经建立过通知通道
  if (notifyChannels.has(deviceId)) {
    console.log(`[BLE通知订阅] 设备 ${deviceId} 通知通道已存在，跳过建立`);
    return;
  }

  console.log(`[BLE通知订阅] 开始为设备 ${deviceId} 建立通知订阅`);
  
  try {
    await startNotifications(
      deviceId,
      PUMP_SERVICE_UUID,
      PUMP_NOTIFY_CHAR_UUID,
      (value: DataView) => {
        const len = value.byteLength;
        const buf = new Uint8Array(len);
        for (let i = 0; i < len; i++) buf[i] = value.getUint8(i);
        dispatchNotifyPayload(deviceId, buf);
      }
    );
    
    console.log(`[BLE通知订阅] 设备 ${deviceId} 通知订阅建立成功`);
    
    // 添加到缓存中
    notifyChannels.add(deviceId);
  } catch (e) {
    console.warn(`[BLE通知订阅] 设备 ${deviceId} 建立通知订阅失败:`, e);
    throw e;
  }
}

/**
 * 发送协议包（不等待响应），用于 ACK 回包等。
 */
export async function sendProtocolPacket(
  deviceId: string,
  packet: Uint8Array
): Promise<void> {
  const view = new DataView(
    packet.buffer,
    packet.byteOffset,
    packet.byteLength
  );
  await writeCharacteristicWithoutResponse(
    deviceId,
    PUMP_SERVICE_UUID,
    PUMP_CMD_CHAR_UUID,
    view
  );
}

export interface SendProtocolReqResult {
  ct: number;
  cid: number;
  cab: Uint8Array;
}

interface NativeProtocolReqResult {
  ct: number;
  cid: number;
  value?: number[];
  snapshotJson?: string;
}

function nativeProtocolResultToSendResult(result: NativeProtocolReqResult | undefined): SendProtocolReqResult | undefined {
  if (!result) return undefined;
  applyNativeSnapshotJson(result.snapshotJson);
  return {
    ct: result.ct,
    cid: result.cid,
    cab: new Uint8Array(result.value ?? []),
  };
}

function applyNativeSnapshotJson(snapshotJson?: string): void {
  if (!snapshotJson) return;
  try {
    deviceStore.replaceSnapshot(JSON.parse(snapshotJson));
  } catch (error) {
    console.error("[BLE原生状态] apply snapshot failed:", error);
  }
}

export interface SendProtocolFrameOptions {
  acceptCts: number[];
  timeoutMs?: number;
  maxAttempts?: number;
}

/**
 * 发送 REQ 并等待 ACK/NACK；超时 3s 重发，最多重发 2 次（共 3 次）；失败打日志并 reject。
 */
export function sendProtocolReq(
  deviceId: string,
  packet: Uint8Array
): Promise<SendProtocolReqResult> {
  const cid = getCidFromReqPacket(packet);
  if (cid < 0) {
    return Promise.reject(new Error("invalid REQ packet"));
  }

  let byDevice = pendingReqs.get(deviceId);
  if (!byDevice) {
    byDevice = new Map();
    pendingReqs.set(deviceId, byDevice);
  }
  if (byDevice.has(cid)) {
    return Promise.reject(new Error(`duplicate pending REQ cid=0x${cid.toString(16)}`));
  }

  return new Promise<SendProtocolReqResult>((resolve, reject) => {
    const entry: PendingEntry = { resolve, reject, timeoutId: null };
    byDevice!.set(cid, entry);

    const sendOne = (): Promise<void> => {
      const v = new DataView(
        packet.buffer,
        packet.byteOffset,
        packet.byteLength
      );
      // 打印发送的指令数据
      const dataHex = Array.from(new Uint8Array(packet.buffer, packet.byteOffset, packet.byteLength))
        .map(b => b.toString(16).padStart(2, '0'))
        .join(' ');
      console.log(`[BLE发送指令] 设备: ${deviceId}, CID: 0x${cid.toString(16)}, 数据: ${dataHex}`);
      return writeCharacteristicWithoutResponse(
        deviceId,
        PUMP_SERVICE_UUID,
        PUMP_CMD_CHAR_UUID,
        v
      );
    };

    let attempts = 0;

    const clearTimeoutAndReject = (msg: unknown) => {
      if (entry.timeoutId != null) {
        clearTimeout(entry.timeoutId);
        entry.timeoutId = null;
      }
      byDevice!.delete(cid);
      const errorMessage = typeof msg === 'string' ? msg : (msg as Error)?.message ?? "send failed";
      loggerWarn("[BLE协议]", "指令发送失败", { cid: cid.toString(16), deviceId, attempts, msg: errorMessage });
      reject(new Error(errorMessage));
    };

    const run = () => {
      console.log(`[BLE发送指令] 设备: ${deviceId}, 开始发送指令, CID: 0x${cid.toString(16)}, 尝试次数: ${attempts + 1}/${REQ_MAX_ATTEMPTS}`);
      sendOne()
        .then(() => {
          attempts++;
          console.log(`[BLE发送指令] 设备: ${deviceId}, 指令发送成功, CID: 0x${cid.toString(16)}, 尝试次数: ${attempts}`);
          entry.timeoutId = setTimeout(() => {
            entry.timeoutId = null;
            if (attempts >= REQ_MAX_ATTEMPTS) {
              console.log(`[BLE发送指令] 设备: ${deviceId}, 指令发送超时, CID: 0x${cid.toString(16)}, 尝试次数: ${attempts}`);
              clearTimeoutAndReject("no ACK/NACK after 3 attempts");
              return;
            }
            console.log(`[BLE发送指令] 设备: ${deviceId}, 等待响应超时, 开始重发, CID: 0x${cid.toString(16)}, 尝试次数: ${attempts + 1}/${REQ_MAX_ATTEMPTS}`);
            run();
          }, REQ_TIMEOUT_MS);
        })
        .catch((err) => {
          console.log(`[BLE发送指令] 设备: ${deviceId}, 指令发送失败, CID: 0x${cid.toString(16)}, 错误:`, err);
          clearTimeoutAndReject(err?.message ?? "send failed");
        });
    };

    // 确保通知通道建立后再发送指令
    console.log(`[BLE通知订阅] 设备 ${deviceId} 开始建立通知订阅`);
    ensureProtocolNotify(deviceId).catch((e) => {
      console.warn(`[BLE通知订阅] 设备 ${deviceId} 建立通知订阅失败:`, e);
      // 通知订阅失败不影响指令发送，只是可能收不到响应
    }).finally(() => {
      console.log(`[BLE通知订阅] 设备 ${deviceId} 通知订阅建立完成`);
      // 通知通道建立后发送指令
      run();
    });
  });
}

/**
 * 订阅协议 notify：收到 Device 上报时解析并回调 onParsed(cid, parsedObject)；ACK 由内部自动回包。
 * 返回取消订阅函数。
 */
export function sendProtocolFrame(
  deviceId: string,
  packet: Uint8Array,
  options: SendProtocolFrameOptions
): Promise<Uint8Array> {
  const cid = getCidFromReqPacket(packet);
  if (cid < 0) {
    return Promise.reject(new Error("invalid REQ packet"));
  }

  const acceptCts = options.acceptCts.length > 0 ? options.acceptCts : [CT_ACK];
  const timeoutMs = options.timeoutMs ?? REQ_TIMEOUT_MS;
  const maxAttempts = options.maxAttempts ?? REQ_MAX_ATTEMPTS;

  let byDevice = pendingFrames.get(deviceId);
  if (!byDevice) {
    byDevice = [];
    pendingFrames.set(deviceId, byDevice);
  }
  if (byDevice.some((entry) => entry.cid === cid)) {
    return Promise.reject(new Error(`duplicate pending frame cid=0x${cid.toString(16)}`));
  }

  return new Promise<Uint8Array>((resolve, reject) => {
    const entry: PendingFrameEntry = {
      cid,
      acceptCts,
      resolve,
      reject,
      timeoutId: null,
    };
    byDevice!.push(entry);

    const sendOne = (): Promise<void> => {
      const v = new DataView(packet.buffer, packet.byteOffset, packet.byteLength);
      return writeCharacteristicWithoutResponse(
        deviceId,
        PUMP_SERVICE_UUID,
        PUMP_CMD_CHAR_UUID,
        v
      );
    };

    let attempts = 0;

    const cleanup = () => {
      if (entry.timeoutId != null) {
        clearTimeout(entry.timeoutId);
        entry.timeoutId = null;
      }
      const pending = pendingFrames.get(deviceId);
      if (!pending) return;
      const idx = pending.indexOf(entry);
      if (idx >= 0) pending.splice(idx, 1);
      if (pending.length === 0) pendingFrames.delete(deviceId);
    };

    const rejectWith = (msg: unknown) => {
      cleanup();
      const errorMessage = typeof msg === "string" ? msg : (msg as Error)?.message ?? "send failed";
      reject(new Error(errorMessage));
    };

    const run = () => {
      sendOne()
        .then(() => {
          attempts += 1;
          entry.timeoutId = setTimeout(() => {
            entry.timeoutId = null;
            if (attempts >= maxAttempts) {
              rejectWith(`no response after ${maxAttempts} attempts`);
              return;
            }
            run();
          }, timeoutMs);
        })
        .catch((err) => {
          rejectWith(err?.message ?? "send failed");
        });
    };

    ensureProtocolNotify(deviceId).catch(() => {}).finally(run);
  });
}

export function subscribeProtocolNotifications(
  deviceId: string,
  onParsed: (cid: number, data: unknown) => void
): () => void {
  const ch = getOrCreateChannel(deviceId);
  const originalOnParsed = ch.onParsed;
  
  ch.onParsed = (cid: number, data: unknown) => {
    // 调用原始的回调函数
    if (originalOnParsed) {
      originalOnParsed(cid, data);
    }
    
    // 调用传入的回调函数
    onParsed(cid, data);
    
    // D0/D6/80/BF/FE 状态写入由 Android 原生 DeviceNativeStateStore 处理；
    // JS 这里只保留 onParsed 分发，供调试抽屉等非状态写入场景使用。
  };
  
  ensureProtocolNotify(deviceId).catch(() => {});

  return () => {
    ch.onParsed = originalOnParsed;
    const pending = pendingReqs.get(deviceId);
    if (!pending?.size && ch.unsubscribe) {
      ch.unsubscribe();
      protocolChannels.delete(deviceId);
    }
  };
}

/**
 * 获取设备信息（F0），连接后 10 秒内发送；带 3s 超时重发，最多 3 次。
 */
export async function sendDeviceInfoQuery(deviceId: string): Promise<SendProtocolReqResult | undefined> {
  try {
    await ensureProtocolNotify(deviceId);
    const native = await MmcBle.nativeGetDeviceInfo({ deviceId });
    return nativeProtocolResultToSendResult(native);
  } catch (error) {
    console.error("[BLE原生F0] nativeGetDeviceInfo failed:", error);
    return undefined;
  }
}

/**
 * 设置 RTC 时间（F2），每次连接都应执行；用于在查询 E1 前同步主机时间。
 */
export async function sendSetRtc(deviceId: string): Promise<SendProtocolReqResult | undefined> {
  try {
    await ensureProtocolNotify(deviceId);
    const native = await MmcBle.nativeSetRtc({ deviceId, utcSeconds: Math.floor(Date.now() / 1000) });
    return nativeProtocolResultToSendResult(native);
  } catch (error) {
    console.error("[BLE原生F2] nativeSetRtc failed:", error);
    return undefined;
  }
}

/**
 * 查询设备状态（E1），返回 ACK 含电量等；带 3s 超时重发。
 */
export async function sendDeviceStatusQuery(deviceId: string): Promise<SendProtocolReqResult | undefined> {
  try {
    await ensureProtocolNotify(deviceId);
    const native = await MmcBle.nativeQueryDeviceStatus({ deviceId });
    return nativeProtocolResultToSendResult(native);
  } catch (error) {
    console.error("[BLE原生E1] nativeQueryDeviceStatus failed:", error);
    return undefined;
  }
}

/**
 * 先发 F2 同步 RTC，再发 E1 查电量，并将电量写入 deviceStore；卡片通过 subscribe 自动刷新。
 */
export async function queryBatteryAndUpdateStore(deviceId: string, side: DeviceSide): Promise<void> {
  await sendSetRtc(deviceId);
  await queryDeviceStatusAndUpdateStore(deviceId, side);
}

/**
 * 发送E1指令查询设备状态，并将结果更新到deviceStore
 */
export async function queryDeviceStatusAndUpdateStore(deviceId: string, side: DeviceSide): Promise<void> {
  const res = await sendDeviceStatusQuery(deviceId);
  if (res === undefined || res === null) return;
  if (res.cid !== 0xe1 || res.ct !== CT_ACK) return;
  markPumpAgentUploadDeviceSourceByPacket(0xe1, deviceId);
  const current = deviceStore.get()[side];
  if (current?.deviceId !== deviceId) return;
  console.log(`[E1原生状态] 已由 Android 原生更新${side}侧设备状态: workState=${current.pumpWorkState ?? "null"}, scene=${current.pumpScene ?? "null"}, mode=${current.pumpMode ?? "null"}, gear=${current.gear ?? "null"}, duration=${current.duration ?? "null"}`);
}

/**
 * 发送 F1 指令设置用户个性化参数
 * @param deviceId 设备 ID
 * @param stimulateGear 刺激挡位
 * @param lactateGear 吸乳挡位
 * @param persist 有效性 0|1
 */
export async function sendF1SetUserParams(deviceId: string, stimulateGear: number, lactateGear: number, persist: 0 | 1): Promise<boolean> {
  const req = buildF1SetUserParams(stimulateGear, lactateGear, persist);
  const res = await sendProtocolReq(deviceId, req);
  return res?.ct === CT_ACK;
}

/**
 * BLE 建立连接后的协议配置流程（与扫描页首次连接一致）：F0 拉型号/版本 → 成功则 F2 校时 + E1 查状态并写回 deviceStore。
 * @param deviceId 当前已连接的 deviceId
 * @param side 左或右，用于写入 store
 */
export async function configurePumpAfterBleConnect(
  deviceId: string,
  side: DeviceSide
): Promise<void> {
  const res = await sendDeviceInfoQuery(deviceId);
  if (res === undefined || res === null) return;
  if (res.cid !== 0xf0 || res.ct !== CT_ACK) return;
  await queryBatteryAndUpdateStore(deviceId, side);

  /**
   * E1 → localStorage `calibration`（仅在本函数内、且 F0 已成功之后）：
   * 1. `queryBatteryAndUpdateStore` = F2 校时 + E1；`queryDeviceStatusAndUpdateStore` 把 CAB 里滴定两字节写入 `deviceStore[side].pumpGearCalib`。
   * 2. 从 store 再读同一 `deviceId` 的 `pumpGearCalib.stimulate/deep`（须已为 number），避免与 setDevice 时序竞态。
   * 3. `mergeE1PumpGearCalibWireIntoCalibrationLocalStorage`：按侧合并线值→`calibration` JSON（0～14→UI+1，0xFF→占位 255；对侧仅宽松 JSON 或镜像本侧，见该函数注释）。
   * 4. 不再次发送 E1；与 `subscribeProtocolNotifications`、上报无先后硬依赖。
   */
  const afterE1 = deviceStore.get()[side];
  if (
    afterE1?.deviceId === deviceId &&
    afterE1.pumpGearCalib &&
    typeof afterE1.pumpGearCalib.stimulate === "number" &&
    typeof afterE1.pumpGearCalib.deep === "number"
  ) {
    mergeE1PumpGearCalibWireIntoCalibrationLocalStorage(
      side,
      afterE1.pumpGearCalib.stimulate,
      afterE1.pumpGearCalib.deep,
    );
  } else {
    logCalibrationE1MergeSkippedFromConfigurePump({
      side,
      expectedDeviceId: deviceId,
      afterDeviceId: afterE1?.deviceId,
      hasPumpGearCalib: Boolean(afterE1?.pumpGearCalib),
      stimulateType: typeof afterE1?.pumpGearCalib?.stimulate,
      deepType: typeof afterE1?.pumpGearCalib?.deep,
    });
  }

  // 订阅设备通知，确保设备状态变化能够及时同步到deviceStore
  subscribeProtocolNotifications(deviceId, () => {});

  // F0 + E1 等已写入 deviceStore 后再次上报，包含固件、电量等完整字段
  reportDeviceInfoAfterProtocolConfigured("protocol_f0_e1_ready");
}

/**
 * 设置吸乳参数 B1：四字节 CAB（启停、模式、挡位、场景）；带 3s 超时重发。
 * @param scene 0 手动，1 自动（默认 1，与协议「自动场景」一致）
 */
export async function sendB1SetPumpParams(
  deviceId: string,
  startStop: 0 | 1,
  mode: 0 | 1 | 2,
  gear: number,
  scene: 0 | 1 = 1
): Promise<SendProtocolReqResult | undefined> {
  try {
    await ensureProtocolNotify(deviceId);
    const native = await MmcBle.nativeSetPumpParams({ deviceId, startStop, mode, gear, scene });
    return nativeProtocolResultToSendResult(native);
  } catch (error) {
    console.error("[BLE原生B1] nativeSetPumpParams failed:", error);
    return undefined;
  }
}

/**
 * 发送结束运行 BF 指令，带 3s 超时重发。
 */
export async function sendBFEndRun(
  deviceId: string
): Promise<SendProtocolReqResult | undefined> {
  try {
    await ensureProtocolNotify(deviceId);
    const native = await MmcBle.nativeEndRun({ deviceId });
    return nativeProtocolResultToSendResult(native);
  } catch (error) {
    console.error("[BLE原生BF] nativeEndRun failed:", error);
    return undefined;
  }
}

/**
 * 发送控制设备关机 FE 指令，默认不重启；带 3s 超时重发。
 */
export async function sendFEPowerOff(
  deviceId: string,
  reboot: 0 | 1 = 0
): Promise<SendProtocolReqResult | undefined> {
  try {
    await ensureProtocolNotify(deviceId);
    const native = await MmcBle.nativePowerOff({ deviceId, reboot });
    return nativeProtocolResultToSendResult(native);
  } catch (error) {
    console.error("[BLE原生FE] nativePowerOff failed:", error);
    return undefined;
  }
}

export async function nativeAdjustGearForSide(side: DeviceSide, delta: number): Promise<boolean> {
  try {
    const native = await MmcBle.nativeAdjustGearForSide({ side, delta });
    nativeProtocolResultToSendResult(native);
    return native?.ct === CT_ACK;
  } catch (error) {
    console.error(`[BLE原生调档] side=${side} failed:`, error);
    return false;
  }
}

export async function nativeSetModeForSide(side: DeviceSide, mode: 0 | 1 | 2): Promise<boolean> {
  try {
    const native = await MmcBle.nativeSetModeForSide({ side, mode });
    nativeProtocolResultToSendResult(native);
    return native?.ct === CT_ACK;
  } catch (error) {
    console.error(`[BLE原生模式] side=${side} failed:`, error);
    return false;
  }
}

export async function nativeSetSceneForSide(side: DeviceSide, scene: 0 | 1): Promise<boolean> {
  try {
    const native = await MmcBle.nativeSetSceneForSide({ side, scene });
    nativeProtocolResultToSendResult(native);
    return native?.ct === CT_ACK;
  } catch (error) {
    console.error(`[BLE原生场景] side=${side} failed:`, error);
    return false;
  }
}

export async function nativeSetStartStopForSide(side: DeviceSide, startStop: 0 | 1): Promise<boolean> {
  try {
    const native = await MmcBle.nativeSetStartStopForSide({ side, startStop });
    nativeProtocolResultToSendResult(native);
    return native?.ct === CT_ACK;
  } catch (error) {
    console.error(`[BLE原生启停] side=${side} failed:`, error);
    return false;
  }
}

/**
 * 发送控制设备关机 FE 指令。设备状态更新由 Android 原生快照回推。
 */
export async function powerOffDeviceAndUpdateStore(deviceId: string, side: DeviceSide): Promise<void> {
  const res = await sendFEPowerOff(deviceId, 0);
  if (res === undefined || res === null) return;
  if (res.ct !== CT_ACK || res.cid !== 0xfe) return;
  console.log(`[FE原生指令] 已下发关机指令 side=${side}, device=${deviceId}`);
}

/**
 * Connect to a BLE device by ID (from scan result).
 * @param deviceId Device ID from BleScanResult.device.deviceId
 * @param onDisconnect Optional callback when device disconnects
 */
export async function connect(
  deviceId: string,
  onDisconnect: () => void
): Promise<void> {
  await stopLEScan();
  await nativeDisconnectListeners.get(deviceId)?.remove();
  const handle = await MmcBle.addListener("disconnected", (event) => {
    if (event.deviceId !== deviceId) return;
    nativeDisconnectListeners.delete(deviceId);
    void handle.remove();
    onDisconnect();
    reportDeviceInfoAfterPhysicalDisconnect();
  });
  nativeDisconnectListeners.set(deviceId, handle);
  try {
    await MmcBle.connect({ deviceId });
  } catch (error) {
    nativeDisconnectListeners.delete(deviceId);
    await handle.remove();
    throw error;
  }
}

/** Disconnect a BLE device by ID. */
export async function disconnect(deviceId: string): Promise<void> {
  await MmcBle.disconnect({ deviceId });
  await nativeDisconnectListeners.get(deviceId)?.remove();
  nativeDisconnectListeners.delete(deviceId);
}

/** Open system Bluetooth settings (Android). No-op on iOS/web. */
export async function openBluetoothSettings(): Promise<void> {
  await MmcBle.openBluetoothSettings();
}

/** Open app settings (e.g. to grant Bluetooth permission after user denied). */
export async function openAppSettings(): Promise<void> {
  await MmcBle.openAppSettings();
}

/**
 * Read a BLE characteristic value.
 * @returns DataView with the current value
 */
export async function readCharacteristic(
  deviceId: string,
  serviceUUID: string,
  characteristicUUID: string
): Promise<DataView> {
  const { value } = await MmcBle.read({ deviceId, serviceUUID, characteristicUUID });
  return byteArrayToDataView(value);
}

/**
 * Write a value to a BLE characteristic (with response; waits for device acknowledgment).
 */
export async function writeCharacteristic(
  deviceId: string,
  serviceUUID: string,
  characteristicUUID: string,
  value: DataView
): Promise<void> {
  await MmcBle.write({ deviceId, serviceUUID, characteristicUUID, value: dataViewToByteArray(value) });
}

/**
 * Write a value to a BLE characteristic without waiting for response (lower latency).
 */
export async function writeCharacteristicWithoutResponse(
  deviceId: string,
  serviceUUID: string,
  characteristicUUID: string,
  value: DataView
): Promise<void> {
  await MmcBle.writeWithoutResponse({ deviceId, serviceUUID, characteristicUUID, value: dataViewToByteArray(value) });
}

/**
 * Subscribe to characteristic notifications; callback is invoked when the device pushes data.
 * Call stopNotifications when done to avoid leaks.
 */
export async function startNotifications(
  deviceId: string,
  serviceUUID: string,
  characteristicUUID: string,
  callback: (value: DataView) => void
): Promise<void> {
  const key = characteristicKey(deviceId, serviceUUID, characteristicUUID);
  await nativeNotifyListeners.get(key)?.remove();
  const handle = await MmcBle.addListener("notification", (event) => {
    if (characteristicKey(event.deviceId, event.serviceUUID, event.characteristicUUID) !== key) return;
    callback(byteArrayToDataView(event.value));
  });
  nativeNotifyListeners.set(key, handle);
  try {
    await MmcBle.startNotifications({ deviceId, serviceUUID, characteristicUUID });
  } catch (error) {
    nativeNotifyListeners.delete(key);
    await handle.remove();
    throw error;
  }
}

/** Stop listening to characteristic notifications. */
export async function stopNotifications(
  deviceId: string,
  serviceUUID: string,
  characteristicUUID: string
): Promise<void> {
  await MmcBle.stopNotifications({ deviceId, serviceUUID, characteristicUUID });
  const key = characteristicKey(deviceId, serviceUUID, characteristicUUID);
  await nativeNotifyListeners.get(key)?.remove();
  nativeNotifyListeners.delete(key);
}

export interface SubscribeCharacteristicOptions {
  /** Poll interval in ms when useNotify is false. Ignored when useNotify is true. */
  intervalMs?: number;
  /** If true, use startNotifications; otherwise poll with readCharacteristic. */
  useNotify?: boolean;
}

/**
 * Unified subscribe API: receive characteristic data via callback, either by Notify or polling.
 * Returns an unsubscribe function. Call it on unmount or when switching device/side.
 */
export function subscribeCharacteristic(
  deviceId: string,
  serviceUUID: string,
  characteristicUUID: string,
  options: SubscribeCharacteristicOptions,
  callback: (value: DataView) => void
): () => void {
  const { intervalMs = 1000, useNotify = true } = options ?? {};
  let cancelled = false;
  let notifyStarted = false;

  if (useNotify) {
    startNotifications(deviceId, serviceUUID, characteristicUUID, (value) => {
      if (!cancelled) callback(value);
    }).then(() => { notifyStarted = true; }).catch(() => {});

    return () => {
      cancelled = true;
      if (notifyStarted) {
        stopNotifications(deviceId, serviceUUID, characteristicUUID).catch(() => {});
      }
    };
  }

  const intervalId = setInterval(async () => {
    if (cancelled) return;
    try {
      const value = await readCharacteristic(deviceId, serviceUUID, characteristicUUID);
      if (!cancelled) callback(value);
    } catch {
      // ignore read errors (e.g. disconnected)
    }
  }, intervalMs);

  return () => {
    cancelled = true;
    clearInterval(intervalId);
  };
}
