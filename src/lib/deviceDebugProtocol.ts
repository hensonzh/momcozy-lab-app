import { sendProtocolFrame } from "@/lib/ble";

export const SOP = 0xaa;
export const FCF = 0x55;
export const CT_REQ = 0x00;
export const CT_ACK = 0x01;
export const CID_B4 = 0xb4;
export const CID_B5 = 0xb5;
export const CID_B6 = 0xb6;
export const CID_E4 = 0xe4;
export const CID_E5 = 0xe5;
export const CID_E6 = 0xe6;

export interface GoldenRhythmStep {
  index?: number;
  mode: number;
  gearDisplay: number;
  frequency: number;
  durationSec: number;
  milkBurstEnabled: 0 | 1;
  flexibleEnabled: 0 | 1;
  reserved1: number;
  reserved2: number;
}

export interface GoldenRhythmConfig {
  bootTimeUtc: number;
  customModeId: number;
  steps: GoldenRhythmStep[];
}

export interface SoftTransitionConfig {
  bootTimeUtc?: number;
  enabled: 0 | 1;
  stepKpa: number;
  stepCount: number;
  transitionGear: number;
}

export interface SmartForceLineConfig {
  bootTimeUtc?: number;
  workMode: 0 | 1;
  gearDisplay: number;
  maxPressureKpa: number;
  frequencyPcm: number;
  holdTimeMs: number;
  // 新增字段用于前端联动计算
  buildTimeA?: number;      // 建压时间a(ms)
  releaseTimeC?: number;    // 泄压时间c(ms)
  restTimeD?: number;       // 休息时间d(ms)
  cycleT?: number;          // 周期T(ms)
  dutyCycle?: number;       // 占空比(%)
  ratio?: string;           // 比值(a+b):(c+d)
}

function checksum8(bytes: Uint8Array): number {
  let sum = 0;
  for (const b of bytes) sum += b;
  return (~(sum & 0xff)) & 0xff;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function buildReq(cid: number, cab: Uint8Array): Uint8Array {
  const out = new Uint8Array(5 + cab.length + 1);
  out[0] = SOP;
  out[1] = FCF;
  out[2] = CT_REQ;
  out[3] = cid & 0xff;
  out[4] = cab.length & 0xff;
  out.set(cab, 5);
  out[out.length - 1] = checksum8(out.subarray(0, out.length - 1));
  return out;
}

function assertFrameBasics(frame: Uint8Array, cid: number): void {
  if (frame.length < 6) {
    throw new Error("设备回帧长度异常");
  }
  if (frame[0] !== SOP || frame[1] !== FCF) {
    throw new Error("设备回帧帧头异常");
  }
  if (frame[3] !== cid) {
    throw new Error("设备回帧命令号不匹配");
  }
}

function assertAck(frame: Uint8Array, cid: number): void {
  assertFrameBasics(frame, cid);
  if (frame[2] !== CT_ACK) {
    throw new Error("设备未返回 ACK");
  }
  
  // B4黄金韵律：参数长度为0x00，无错误码
  if (cid === CID_B4) {
    if (frame[4] !== 0x00) {
      throw new Error("ACK 参数长度异常");
    }
  } 
  // B5柔性过渡和B6智能力线：参数长度为0x02，包含2字节错误码
  else if (cid === CID_B5 || cid === CID_B6) {
    if (frame[4] !== 0x02) {
      throw new Error("ACK 参数长度异常");
    }
    // 检查错误码（小端模式）
    const errorCode = new DataView(frame.buffer, frame.byteOffset).getUint16(5, true);
    if (errorCode !== 0) {
      throw new Error(`设备返回错误码: ${errorCode}`);
    }
  }
}

function ensureResponsePayloadLength(frame: Uint8Array, minLength: number, cid: number): void {
  assertFrameBasics(frame, cid);
  if (frame[4] < minLength) {
    throw new Error("设备回帧参数长度不足");
  }
}

function stepToPacket(step: GoldenRhythmStep, index: number, view: DataView, cab: Uint8Array, offset: number): void {
  cab[offset] = clamp(step.index ?? index, 0, 9);
  cab[offset + 1] = step.mode & 0xff;
  cab[offset + 2] = clamp(step.gearDisplay - 1, 0, 14);
  cab[offset + 3] = clamp(step.frequency, 0, 2);
  view.setUint16(offset + 4, clamp(step.durationSec, 0, 1800), true);
  cab[offset + 6] = step.milkBurstEnabled;
  cab[offset + 7] = step.flexibleEnabled;
  cab[offset + 8] = step.reserved1 & 0xff;
  cab[offset + 9] = step.reserved2 & 0xff;
}

function parseGoldenStep(view: DataView, offset: number): GoldenRhythmStep {
  return {
    index: view.getUint8(offset),
    mode: view.getUint8(offset + 1),
    gearDisplay: view.getUint8(offset + 2) + 1,
    frequency: view.getUint8(offset + 3),
    durationSec: view.getUint16(offset + 4, true),
    milkBurstEnabled: view.getUint8(offset + 6) as 0 | 1,
    flexibleEnabled: view.getUint8(offset + 7) as 0 | 1,
    reserved1: view.getUint8(offset + 8),
    reserved2: view.getUint8(offset + 9),
  };
}

function normalizeGoldenStep(step: Partial<GoldenRhythmStep>, index: number): GoldenRhythmStep {
  return {
    index: step.index ?? index,
    mode: step.mode ?? 1,
    gearDisplay: clamp(step.gearDisplay ?? 6, 1, 15),
    frequency: clamp(step.frequency ?? 0, 0, 2),
    durationSec: clamp(step.durationSec ?? 12, 0, 1800),
    milkBurstEnabled: (step.milkBurstEnabled ?? 0) as 0 | 1,
    flexibleEnabled: (step.flexibleEnabled ?? 0) as 0 | 1,
    reserved1: step.reserved1 ?? 0,
    reserved2: step.reserved2 ?? 0,
  };
}

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join(" ")
    .toUpperCase();
}

export function buildB4SetGoldenRhythmPacket(customModeId: number, steps: GoldenRhythmStep[]): Uint8Array {
  const safeSteps = steps.slice(0, 10).map((step, index) => normalizeGoldenStep(step, index));
  const cab = new Uint8Array(5 + safeSteps.length * 10);
  const view = new DataView(cab.buffer);

  view.setUint32(0, customModeId >>> 0, true);
  cab[4] = safeSteps.length;
  safeSteps.forEach((step, index) => {
    stepToPacket(step, index, view, cab, 5 + index * 10);
  });

  return buildReq(CID_B4, cab);
}

export function buildB5SetSoftTransitionPacket(config: SoftTransitionConfig): Uint8Array {
  const cab = new Uint8Array([
    config.enabled,
    clamp(config.stepKpa, 1, 10),
    clamp(config.stepCount, 1, 10),
    clamp(config.transitionGear, 1, 10),
  ]);
  return buildReq(CID_B5, cab);
}

export function buildB6SetSmartForceLinePacket(config: SmartForceLineConfig): Uint8Array {
  const cab = new Uint8Array(6);
  const view = new DataView(cab.buffer);
  cab[0] = config.workMode;
  cab[1] = clamp(config.gearDisplay - 1, 0, 14);
  cab[2] = clamp(config.maxPressureKpa, 10, 40);
  cab[3] = clamp(config.frequencyPcm, 20, 90);
  view.setUint16(4, clamp(config.holdTimeMs, 0, 1000), true);
  return buildReq(CID_B6, cab);
}

export function buildE4QueryGoldenRhythmPacket(customModeId: number): Uint8Array {
  const cab = new Uint8Array(4);
  new DataView(cab.buffer).setUint32(0, customModeId >>> 0, true);
  return buildReq(CID_E4, cab);
}

export function buildE5QuerySoftTransitionPacket(): Uint8Array {
  return buildReq(CID_E5, new Uint8Array(0));
}

export function buildE6QuerySmartForceLinePacket(workMode: 0 | 1, gearDisplay: number): Uint8Array {
  return buildReq(CID_E6, new Uint8Array([workMode, clamp(gearDisplay - 1, 0, 14)]));
}

export function parseE4GoldenRhythmResponse(frame: Uint8Array): GoldenRhythmConfig {
  ensureResponsePayloadLength(frame, 9, CID_E4);

  const view = new DataView(frame.buffer, frame.byteOffset, frame.byteLength);
  const payloadLength = frame[4];
  const stepCount = view.getUint8(13);
  const expectedLength = 4 + 4 + 1 + stepCount * 10;

  if (payloadLength !== expectedLength) {
    throw new Error("黄金韵律回帧长度不匹配");
  }

  const steps: GoldenRhythmStep[] = [];
  for (let i = 0; i < stepCount; i += 1) {
    steps.push(parseGoldenStep(view, 14 + i * 10));
  }

  return {
    bootTimeUtc: view.getUint32(5, true),
    customModeId: view.getUint32(9, true),
    steps,
  };
}

export function parseE5SoftTransitionResponse(frame: Uint8Array): SoftTransitionConfig {
  ensureResponsePayloadLength(frame, 8, CID_E5);
  const view = new DataView(frame.buffer, frame.byteOffset, frame.byteLength);
  return {
    bootTimeUtc: view.getUint32(5, true),
    enabled: view.getUint8(9) as 0 | 1,
    stepKpa: view.getUint8(10),
    stepCount: view.getUint8(11),
    transitionGear: view.getUint8(12),
  };
}

export function parseE6SmartForceLineResponse(frame: Uint8Array, workMode: 0 | 1, gearDisplay: number): SmartForceLineConfig {
  ensureResponsePayloadLength(frame, 8, CID_E6);
  const view = new DataView(frame.buffer, frame.byteOffset, frame.byteLength);
  return {
    bootTimeUtc: view.getUint32(5, true),
    workMode,
    gearDisplay,
    maxPressureKpa: view.getUint8(9),
    frequencyPcm: view.getUint8(10),
    holdTimeMs: view.getUint16(11, true),  // 小端模式
  };
}

export async function queryGoldenRhythmConfig(deviceId: string, customModeId = 0): Promise<GoldenRhythmConfig> {
  const frame = await sendProtocolFrame(deviceId, buildE4QueryGoldenRhythmPacket(customModeId), {
    acceptCts: [CT_REQ, CT_ACK],
  });
  return parseE4GoldenRhythmResponse(frame);
}

export async function saveGoldenRhythmConfig(deviceId: string, customModeId: number, steps: GoldenRhythmStep[]): Promise<void> {
  const frame = await sendProtocolFrame(deviceId, buildB4SetGoldenRhythmPacket(customModeId, steps), {
    acceptCts: [CT_ACK],
  });
  assertAck(frame, CID_B4);
}

export async function querySoftTransitionConfig(deviceId: string): Promise<SoftTransitionConfig> {
  const frame = await sendProtocolFrame(deviceId, buildE5QuerySoftTransitionPacket(), {
    acceptCts: [CT_REQ, CT_ACK],
  });
  return parseE5SoftTransitionResponse(frame);
}

export async function saveSoftTransitionConfig(deviceId: string, config: SoftTransitionConfig): Promise<void> {
  const frame = await sendProtocolFrame(deviceId, buildB5SetSoftTransitionPacket(config), {
    acceptCts: [CT_ACK],
  });
  assertAck(frame, CID_B5);
}

export async function querySmartForceLineConfig(deviceId: string, workMode: 0 | 1, gearDisplay: number): Promise<SmartForceLineConfig> {
  const frame = await sendProtocolFrame(deviceId, buildE6QuerySmartForceLinePacket(workMode, gearDisplay), {
    acceptCts: [CT_REQ, CT_ACK],
  });
  return parseE6SmartForceLineResponse(frame, workMode, gearDisplay);
}

export async function saveSmartForceLineConfig(deviceId: string, config: SmartForceLineConfig): Promise<void> {
  const frame = await sendProtocolFrame(deviceId, buildB6SetSmartForceLinePacket(config), {
    acceptCts: [CT_ACK],
  });
  assertAck(frame, CID_B6);
}
