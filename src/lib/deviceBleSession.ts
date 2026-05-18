const DEBUG_SERVICE_UUID = "0000af00-0000-1000-8000-00805f9b34fb";
const DEBUG_WRITE_CHAR_UUID = "0000af01-0000-1000-8000-00805f9b34fb";
const DEBUG_NOTIFY_CHAR_UUID = "0000af02-0000-1000-8000-00805f9b34fb";

const FRAME_HEADER_A = 0xaa;
const FRAME_HEADER_B = 0x55;

const DEFAULT_TIMEOUT_MS = 4000;

type PendingFrameRequest = {
  cid: number;
  resolve: (frame: Uint8Array) => void;
  reject: (error: Error) => void;
  timeoutId: ReturnType<typeof setTimeout>;
};

export interface DeviceBleSession {
  id: string;
  name: string;
  device: BluetoothDevice;
  server: BluetoothRemoteGATTServer;
  service: BluetoothRemoteGATTService;
  writeCharacteristic: BluetoothRemoteGATTCharacteristic;
  notifyCharacteristic: BluetoothRemoteGATTCharacteristic;
  frameBuffer: number[];
  pending: PendingFrameRequest[];
}

const sessions = new Map<string, DeviceBleSession>();

function normalizeFrame(data: DataView | ArrayBuffer | Uint8Array): Uint8Array {
  if (data instanceof Uint8Array) return data;
  if (data instanceof DataView) return new Uint8Array(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
  return new Uint8Array(data);
}

function readCid(frame: Uint8Array): number {
  return frame[3] ?? -1;
}

function readPayloadLength(frame: Uint8Array): number {
  return frame[4] ?? 0;
}

function frameLengthFromHeader(frameBuffer: number[]): number | null {
  if (frameBuffer.length < 5) return null;
  if (frameBuffer[0] !== FRAME_HEADER_A || frameBuffer[1] !== FRAME_HEADER_B) return null;
  return 2 + 1 + 1 + 1 + frameBuffer[4] + 1;
}

function checksum8(bytes: Uint8Array): number {
  let sum = 0;
  for (const b of bytes) sum += b;
  return (~(sum & 0xff)) & 0xff;
}

function validateFrame(frame: Uint8Array): boolean {
  if (frame.length < 6) return false;
  if (frame[0] !== FRAME_HEADER_A || frame[1] !== FRAME_HEADER_B) return false;
  const payloadLength = readPayloadLength(frame);
  if (frame.length !== 6 + payloadLength) return false;
  return checksum8(frame.subarray(0, frame.length - 1)) === frame[frame.length - 1];
}

function settlePending(session: DeviceBleSession, frame: Uint8Array): void {
  const cid = readCid(frame);
  const idx = session.pending.findIndex((request) => request.cid === cid);
  if (idx < 0) return;
  const [request] = session.pending.splice(idx, 1);
  clearTimeout(request.timeoutId);
  request.resolve(frame);
}

function rejectAllPending(session: DeviceBleSession, error: Error): void {
  const pending = session.pending.splice(0, session.pending.length);
  pending.forEach((request) => {
    clearTimeout(request.timeoutId);
    request.reject(error);
  });
}

function handleNotifyEvent(session: DeviceBleSession, event: Event): void {
  const target = event.target as BluetoothRemoteGATTCharacteristic | null;
  const value = target?.value;
  if (!value) return;

  const chunk = normalizeFrame(value);
  session.frameBuffer.push(...chunk);

  while (session.frameBuffer.length > 0) {
    if (session.frameBuffer[0] !== FRAME_HEADER_A || session.frameBuffer[1] !== FRAME_HEADER_B) {
      session.frameBuffer.shift();
      continue;
    }

    const expectedLength = frameLengthFromHeader(session.frameBuffer);
    if (!expectedLength) {
      session.frameBuffer.shift();
      continue;
    }

    if (session.frameBuffer.length < expectedLength) {
      return;
    }

    const frame = new Uint8Array(session.frameBuffer.splice(0, expectedLength));
    if (!validateFrame(frame)) {
      continue;
    }
    settlePending(session, frame);
  }
}

function assertBluetoothAvailable(): void {
  if (typeof navigator === "undefined" || !("bluetooth" in navigator)) {
    throw new Error("当前环境不支持 Web Bluetooth");
  }
  if (!window.isSecureContext) {
    throw new Error("蓝牙连接需要在 HTTPS 或 localhost 环境下使用");
  }
}

export function isWebBluetoothSupported(): boolean {
  return typeof navigator !== "undefined" && "bluetooth" in navigator && window.isSecureContext;
}

export async function requestAndConnectDevice(side: "L" | "R"): Promise<{ id: string; name: string }> {
  assertBluetoothAvailable();

  const bluetooth = navigator.bluetooth;
  const device = await bluetooth.requestDevice({
    acceptAllDevices: true,
    optionalServices: [DEBUG_SERVICE_UUID],
  });

  if (!device.gatt) {
    throw new Error("当前设备不支持 GATT 连接");
  }

  const server = await device.gatt.connect();
  const service = await server.getPrimaryService(DEBUG_SERVICE_UUID);
  const writeCharacteristic = await service.getCharacteristic(DEBUG_WRITE_CHAR_UUID);
  const notifyCharacteristic = await service.getCharacteristic(DEBUG_NOTIFY_CHAR_UUID);

  const session: DeviceBleSession = {
    id: device.id,
    name: device.name || `${side === "L" ? "左侧" : "右侧"}设备`,
    device,
    server,
    service,
    writeCharacteristic,
    notifyCharacteristic,
    frameBuffer: [],
    pending: [],
  };

  device.addEventListener("gattserverdisconnected", () => {
    sessions.delete(device.id);
    rejectAllPending(session, new Error("蓝牙连接已断开"));
  });

  await notifyCharacteristic.startNotifications();
  notifyCharacteristic.addEventListener("characteristicvaluechanged", (event) => handleNotifyEvent(session, event));
  sessions.set(device.id, session);

  return { id: device.id, name: session.name };
}

export function hasDeviceSession(deviceId: string): boolean {
  return sessions.has(deviceId);
}

export async function disconnectDeviceSession(deviceId: string): Promise<void> {
  const session = sessions.get(deviceId);
  if (!session) return;
  rejectAllPending(session, new Error("蓝牙连接已关闭"));
  session.device.gatt?.disconnect();
  sessions.delete(deviceId);
}

export async function sendDeviceDebugRequest(
  deviceId: string,
  packet: Uint8Array,
  expectedCid: number,
  timeoutMs = DEFAULT_TIMEOUT_MS,
): Promise<Uint8Array> {
  const session = sessions.get(deviceId);
  if (!session) {
    throw new Error("当前设备还没有建立蓝牙连接");
  }

  if (!session.device.gatt?.connected) {
    throw new Error("蓝牙连接已断开，请重新连接设备");
  }

  const framePromise = new Promise<Uint8Array>((resolve, reject) => {
    const timeoutId = setTimeout(() => {
      const idx = session.pending.findIndex((request) => request.resolve === resolve);
      if (idx >= 0) session.pending.splice(idx, 1);
      reject(new Error("等待设备回复超时"));
    }, timeoutMs);

    session.pending.push({
      cid: expectedCid,
      resolve,
      reject,
      timeoutId,
    });
  });

  try {
    await session.writeCharacteristic.writeValue(packet);
  } catch (error) {
    rejectAllPending(session, error instanceof Error ? error : new Error("蓝牙写入失败"));
    throw error;
  }

  return framePromise;
}

