/**
 * BLE 公共协议：组包（REQ 下发）、校验、解析（上报）。
 * 参见 doc/设备APP蓝牙通信协议.md 3.1 节。
 */

// ─── 常量 ─────────────────────────────────────────────────────────────
export const SOP = 0xaa;
export const FCF = 0x55;
export const CT_REQ = 0x00;
export const CT_ACK = 0x01;
export const CT_NACK = 0x02;
/** 设备主动通知上报（如 0x80 实时数据） */
export const CT_NOTIFY = 0x03;
export const CT_DEVICE = 0x04;
export const CAL_MAX = 100;

/** CheckSum8: 除校验字节外所有字节按字节求和取反（低 8 位） */
export function checkSum8(dat: Uint8Array): number {
  let sum = 0;
  for (let i = 0; i < dat.length; i++) sum += dat[i];
  return (~(sum & 0xff)) & 0xff;
}

/** 组 REQ 包：AA 55 00 cid cal cab... checksum */
export function buildReq(cid: number, cab: Uint8Array): Uint8Array {
  const cal = cab.length;
  if (cal > CAL_MAX) throw new Error(`CAL ${cal} > ${CAL_MAX}`);
  const len = 5 + cal + 1; // sop+fcf+ct+cid+cal + cab + checksum
  const out = new Uint8Array(len);
  out[0] = SOP;
  out[1] = FCF;
  out[2] = CT_REQ;
  out[3] = cid & 0xff;
  out[4] = cal & 0xff;
  out.set(cab, 5);
  out[len - 1] = checkSum8(out.subarray(0, len - 1));
  return out;
}

// ─── 下发命令封装（3.1.2–3.1.12）───────────────────────────────────────
const CID_F0 = 0xf0;
const CID_F1 = 0xf1;
const CID_F2 = 0xf2;
const CID_F3 = 0xf3;
const CID_FE = 0xfe;
const CID_FF = 0xff;
const CID_B0 = 0xb0;
const CID_B1 = 0xb1;
const CID_B2 = 0xb2;
const CID_B3 = 0xb3;
const CID_BF = 0xbf;
const CID_E0 = 0xe0;
const CID_E1 = 0xe1;

/** 3.1.2 获取设备信息 F0，默认 SN 0xAA551100（4 字节小端） */
export function buildF0GetDeviceInfo(sn: number = 0xaa551100): Uint8Array {
  const cab = new Uint8Array(4);
  const v = sn >>> 0;
  cab[0] = (v >>> 0) & 0xff;
  cab[1] = (v >>> 8) & 0xff;
  cab[2] = (v >>> 16) & 0xff;
  cab[3] = (v >>> 24) & 0xff;
  return buildReq(CID_F0, cab);
}

/** F0 ACK 响应体：协议 3.1.2 设备应答，CAL 至少 4 字节。版本字节含义如 111 表示 11.1。 */
export interface F0DeviceInfo {
  productModel: number;
  hwPlatform: number;
  hwVersion: string;
  softwareVersion: string;
}

/** 将 F0 ACK 的 CAB 解析为设备信息；CAB 至少 4 字节（产品型号、硬件平台、硬件版本、软件版本）。 */
export function parseF0DeviceInfo(cab: Uint8Array): F0DeviceInfo | null {
  if (cab.length < 4) return null;
  const versionByteToString = (b: number) => `${Math.floor(b / 10)}.${b % 10}`;
  return {
    productModel: cab[0],
    hwPlatform: cab[1],
    hwVersion: versionByteToString(cab[2]),
    softwareVersion: versionByteToString(cab[3]),
  };
}

/** 3.1.3 设置用户个性化参数 F1：刺激挡位、吸乳挡位、有效性 0|1 */
export function buildF1SetUserParams(
  stimulateGear: number,
  lactateGear: number,
  persist: 0 | 1
): Uint8Array {
  const cab = new Uint8Array([stimulateGear & 0xff, lactateGear & 0xff, persist]);
  return buildReq(CID_F1, cab);
}

/** 3.1.4 设置 RTC 时间 F2：UTC 时间戳（秒，4 字节小端） */
export function buildF2SetRtc(utcSeconds: number): Uint8Array {
  const cab = new Uint8Array(4);
  const v = (utcSeconds >>> 0) >>> 0;
  cab[0] = (v >>> 0) & 0xff;
  cab[1] = (v >>> 8) & 0xff;
  cab[2] = (v >>> 16) & 0xff;
  cab[3] = (v >>> 24) & 0xff;
  return buildReq(CID_F2, cab);
}

/** 3.1.5 设置标志位 F3 */
export function buildF3SetFlags(flagsByte: number, persist: 0 | 1): Uint8Array {
  return buildReq(CID_F3, new Uint8Array([flagsByte & 0xff, persist]));
}

/** 3.1.6 恢复出厂设置 FF，reboot 0-不重启 1-重启 */
export function buildFFRestoreFactory(reboot: 0 | 1): Uint8Array {
  return buildReq(CID_FF, new Uint8Array([reboot]));
}

/** 控制设备关机 FE，reboot 0-不重启 1-重启 */
export function buildFEPowerOff(reboot: 0 | 1 = 0): Uint8Array {
  return buildReq(CID_FE, new Uint8Array([reboot]));
}

/** 3.1.7 设置工作模式 B0：1-设备 2-引导 3-Agent */
export function buildB0SetWorkMode(mode: 1 | 2 | 3): Uint8Array {
  return buildReq(CID_B0, new Uint8Array([mode]));
}

/**
 * 3.1.8 设置吸乳参数 B1：CAL=4 — 启停、模式、挡位、场景（协议：0x00 手动，0x01 自动）
 * 真机核对：固件须接受 CAL=4；若拒收请对照 doc/设备APP蓝牙通信协议.md「设置吸乳参数 B1」与 E1 的 scene/workState 字节。
 * @param startStop 0 停止，1 启动
 * @param mode 0 刺激，1 吸乳，2 混合
 * @param gear 挡位（B1 线 0–14，与 E1 经 e1GearToB1Gear 对齐）
 * @param scene 0 手动场景，1 自动场景
 * @returns 完整 REQ 帧
 */
export function buildB1SetPumpParams(
  startStop: 0 | 1,
  mode: 0 | 1 | 2,
  gear: number,
  scene: 0 | 1
): Uint8Array {
  return buildReq(
    CID_B1,
    new Uint8Array([startStop, mode, gear & 0xff, scene & 0xff])
  );
}

/** 3.1.9 设置柔性力线参数 B2：可变 CAB + 有效性 1 字节 */
export function buildB2SetFlexibleForceLine(
  cabWithoutValid: Uint8Array,
  persist: 0 | 1
): Uint8Array {
  const cab = new Uint8Array(cabWithoutValid.length + 1);
  cab.set(cabWithoutValid);
  cab[cab.length - 1] = persist;
  return buildReq(CID_B2, cab);
}

/** 3.1.10 设置泌乳曲线参数 B3：模式、挡位、频率(cpm)、负压、保持负压、保持时间(ms)、有效性 */
export function buildB3SetLactationCurve(
  mode: number,
  gear: number,
  freqCpm: number,
  pressure: number,
  holdPressure: number,
  holdTimeMs: number,
  persist: 0 | 1
): Uint8Array {
  const cab = new Uint8Array(10);
  cab[0] = mode & 0xff;
  cab[1] = gear & 0xff;
  cab[2] = freqCpm & 0xff;
  cab[3] = (pressure >>> 0) & 0xff;
  cab[4] = (pressure >>> 8) & 0xff;
  cab[5] = (holdPressure >>> 0) & 0xff;
  cab[6] = (holdPressure >>> 8) & 0xff;
  cab[7] = (holdTimeMs >>> 0) & 0xff;
  cab[8] = (holdTimeMs >>> 8) & 0xff;
  cab[9] = persist;
  return buildReq(CID_B3, cab);
}

/** 3.1.11 查询设备信息 E0，queryType 0x01 设备模式 0x02 吸乳参数 0x03 柔性力线等 */
export function buildE0QueryDeviceInfo(queryType: number): Uint8Array {
  return buildReq(CID_E0, new Uint8Array([queryType & 0xff]));
}

/** 3.1.12 查询设备状态 E1，无参数 */
export function buildE1QueryDeviceStatus(): Uint8Array {
  return buildReq(CID_E1, new Uint8Array(0));
}

/** 结束运行 BF，参数长度为1，该参数字段为预留 */
export function buildBFEndRun(): Uint8Array {
  // 预留参数设为0
  return buildReq(CID_BF, new Uint8Array([0]));
}

/** E1 ACK 响应体：CAL 0x0D，CAB 13 字节（协议「查询设备状态 E1」设备应答）
 * 字节顺序（紧随 4 字节开机时间 UTC 小端之后）：
 * 工作模式 → 吸乳模式 → 挡位 → 场景 → 工作状态 → 电池电量 → 充电状态 → 吸乳时长（2字节小端）
 */
export interface E1DeviceStatus {
  /** UTC 时间戳（秒），小端 4 字节 */
  bootTime: number;
  /** 工作模式：0x01 设备，0x02 引导，0x03 Agent */
  workMode: number;
  /** 吸乳模式：0x00 刺激，0x01 吸乳，0x02 混合 */
  pumpMode: number;
  /** 挡位：0-14 挡位值 */
  gear: number;
  /** 场景：0x00 手动，0x01 自动 */
  scene: number;
  /** 工作状态：0x00 暂停，0x01 工作 */
  workState: number;
  /** 电池电量：0–100 */
  batteryPct: number;
  /** 充电状态：0x00 未充电，0x01 充电中 */
  charging: number;
  /** 吸乳时长 2字节 单位为s */
  duration: number;
  /** 滴定挡位：刺激档位*/
  pumpGearCalibStimulate: number;
  /** 滴定挡位：深度档位*/
  pumpGearCalibDeep: number;
}

/** E1 CAB 最小长度（与 CAL 0x0F 一致） */
export const E1_CAB_MIN_LEN = 15;

/**
 * 解析 E1 ACK 的 CAB 为设备状态。
 * - cab.length >= 13：按当前协议解析（包含吸乳时长）。
 * - cab.length === 11：兼容旧固件（无「场景」字段，cab[7] 为启停/工作状态，cab[8–9] 为电量与充电）。
 * - cab.length === 10：兼容更旧固件（无「场景」和「吸乳时长」字段）。
 */
export function parseE1DeviceStatus(cab: Uint8Array): E1DeviceStatus | null {
  if (cab.length < 10) return null;
  const view = new DataView(cab.buffer, cab.byteOffset, cab.byteLength);
  const bootTime = view.getUint32(0, true);
  if (cab.length >= E1_CAB_MIN_LEN) {
    return {
      bootTime,
      workMode: cab[4],
      pumpMode: cab[5],
      gear: cab[6],
      scene: cab[7],
      workState: cab[8],
      batteryPct: cab[9],
      charging: cab[10],
      duration: view.getUint16(11, true),
      pumpGearCalibStimulate: cab[13],
      pumpGearCalibDeep: cab[14],
    };
  }
  // 旧版 11 字节：bootTime + workMode + pumpMode + gear + scene + startStop + battery + charging
  if (cab.length >= 11) {
    return {
      bootTime,
      workMode: cab[4],
      pumpMode: cab[5],
      gear: cab[6],
      scene: cab[7],
      workState: cab[8],
      batteryPct: cab[9],
      charging: cab[10],
      duration: 0,
      pumpGearCalibStimulate: 0,
      pumpGearCalibDeep: 0,
    };
  }
  // 旧版 10 字节：bootTime + workMode + pumpMode + gear + startStop + battery + charging
  return {
    bootTime,
    workMode: cab[4],
    pumpMode: cab[5],
    gear: cab[6],
    scene: 0,
    workState: cab[7],
    batteryPct: cab[8],
    charging: cab[9],
    duration: 0,
    pumpGearCalibStimulate: 0,
    pumpGearCalibDeep: 0,
  };
}

/**
 * 将 E1 应答中的吸乳模式（0x00–0x02）转为与 B1 一致的 0–2，供 deviceStore / PumpSession 使用。
 */
export function e1PumpModeToB1Mode(pumpMode: number): number {
  if (pumpMode >= 0 && pumpMode <= 2) return pumpMode;
  return Math.max(0, Math.min(2, pumpMode));
}

/**
 * 将 E1 应答中的挡位（协议 0-14）转为 B1 用的 0–14；若为旧版 0–14  wire 则原样钳位。
 */
export function e1GearToB1Gear(gear: number): number {
  return Math.max(0, Math.min(14, gear));
}

/** APP 回 ACK：AA 55 01 cid 00 checksum */
export function buildAck(cid: number): Uint8Array {
  const out = new Uint8Array(6);
  out[0] = SOP;
  out[1] = FCF;
  out[2] = CT_ACK;
  out[3] = cid & 0xff;
  out[4] = 0;
  out[5] = checkSum8(out.subarray(0, 5));
  return out;
}

// ─── 帧解析 ───────────────────────────────────────────────────────────
export interface ParsedFrame {
  ct: number;
  cid: number;
  cal: number;
  cab: Uint8Array;
}

/** 解析一帧，校验 SOP+FCF、CAL、CheckSum8；无效返回 null */
export function parseFrame(buf: Uint8Array): ParsedFrame | null {
  if (buf.length < 5) return null;
  if (buf[0] !== SOP || buf[1] !== FCF) return null;
  const cal = buf[4];
  if (cal > CAL_MAX || buf.length !== 5 + cal + 1) return null;
  const withoutChecksum = buf.subarray(0, buf.length - 1);
  const expectedSum = checkSum8(withoutChecksum);
  if (buf[buf.length - 1] !== expectedSum) return null;
  return {
    ct: buf[2],
    cid: buf[3],
    cal,
    cab: buf.slice(5, 5 + cal),
  };
}

// ─── 上报解析（3.1.13–3.1.18）──────────────────────────────────────────
export interface D0OperationRecord {
  timestamp: number;
  beforeStartStop: number;
  beforeMode: number;
  beforeGear: number;
  beforeAutoFlag: number;
  afterStartStop: number;
  afterMode: number;
  afterGear: number;
  afterAutoFlag: number;
  source: number;
  /** 吸乳时长 2字节 单位为s */
  duration: number;
}

export function parseD0OperationRecord(cab: Uint8Array): D0OperationRecord | null {
  if (cab.length < 0x0d) return null;
  const view = new DataView(cab.buffer, cab.byteOffset, cab.byteLength);
  return {
    timestamp: view.getUint32(0, true),
    beforeStartStop: cab[4],
    beforeMode: cab[5],
    beforeGear: cab[6],
    beforeAutoFlag: cab[7],
    afterStartStop: cab[8],
    afterMode: cab[9],
    afterGear: cab[10],
    afterAutoFlag: cab[11],
    source: cab[12],
    duration: view.getUint16(13, true),
  };
}

export interface D1PowerOff {
  timestamp: number;
}

export function parseD1PowerOff(cab: Uint8Array): D1PowerOff | null {
  if (cab.length < 4) return null;
  return { timestamp: new DataView(cab.buffer, cab.byteOffset, cab.byteLength).getUint32(0, true) };
}

export interface D4OfflineData {
  dataType: number;
  timestamp: number;
  source: number;
  mode: number;
  gear: number;
  startStop: number;
  letdownState: number;
  milkMlX10: number;
  batteryPct: number;
  charging: number;
  powerState: number;
}

export function parseD4OfflineData(cab: Uint8Array): D4OfflineData | null {
  if (cab.length < 0x0f) return null;
  const view = new DataView(cab.buffer, cab.byteOffset, cab.byteLength);
  return {
    dataType: cab[0],
    timestamp: view.getUint32(1, true),
    source: cab[5],
    mode: cab[6],
    gear: cab[7],
    startStop: cab[8],
    letdownState: cab[9],
    milkMlX10: view.getUint16(10, true),
    batteryPct: cab[12],
    charging: cab[13],
    powerState: cab[14],
  };
}

export interface D5Letdown {
  timestamp: number;
  state: number;
}

export function parseD5Letdown(cab: Uint8Array): D5Letdown | null {
  if (cab.length < 5) return null;
  return {
    timestamp: new DataView(cab.buffer, cab.byteOffset, cab.byteLength).getUint32(0, true),
    state: cab[4],
  };
}

export interface D6Battery {
  timestamp: number;
  charging: number;
  batteryPct: number;
}

export function parseD6Battery(cab: Uint8Array): D6Battery | null {
  if (cab.length < 6) return null;
  return {
    timestamp: new DataView(cab.buffer, cab.byteOffset, cab.byteLength).getUint32(0, true),
    charging: cab[4],
    batteryPct: cab[5],
  };
}

export interface RealtimeMilk80 {
  timestamp: number;
  flowFloat: number;
  milkMlX10: number;
  milkFlag: number; /** 有无奶标志位 */
  moFlag: number; /** 奶阵标志位 */
  bandpower: number; /** 乳流强度 */
  pitchX10: number;
  rollX10: number;
  pressureCh1X10: number;
  pressureCh2X10: number;
}

export function parse80RealtimeMilk(cab: Uint8Array): RealtimeMilk80 | null {
  if (cab.length < 0x17) return null;
  const view = new DataView(cab.buffer, cab.byteOffset, cab.byteLength);
  return {
    timestamp: view.getUint32(0, true),
    flowFloat: view.getFloat32(4, true),
    milkMlX10: view.getUint16(8, true),
    milkFlag: (cab[10] & 0x01), /** milkFlag为cab[10]的bit0的值 */
    moFlag: ((cab[10] & 0x02) >> 1), /** moFlag为cab[10]的bit1的值 */
    bandpower: view.getFloat32(11, true), /** bandpower为cab[11]的值 */ 
    pitchX10: view.getInt16(15, true), 
    rollX10: view.getInt16(17, true), 
    pressureCh1X10: view.getUint16(19, true), 
    pressureCh2X10: view.getUint16(21, true), 
  };
}

/** BF ACK 响应体：CAL 0x06，CAB 6 字节
 * 字节顺序：前4个字节为UTC时间戳，后两个字节为最终奶量，小端，单位为0.1ml
 */
export interface BFEndRunResponse {
  /** UTC 时间戳（秒），小端 4 字节 */
  timestamp: number;
  /** 最终奶量，小端 2 字节，单位为0.1ml */
  milkMlX10: number;
}

/** 解析 BF ACK 的 CAB 为结束运行响应。 */
export function parseBFEndRunResponse(cab: Uint8Array): BFEndRunResponse | null {
  if (cab.length < 6) return null;
  const view = new DataView(cab.buffer, cab.byteOffset, cab.byteLength);
  return {
    timestamp: view.getUint32(0, true),
    milkMlX10: view.getUint16(4, true),
  };
}

/** 从 REQ 包中取 CID（第 4 字节，0-based index 3） */
export function getCidFromReqPacket(packet: Uint8Array): number {
  return packet.length > 3 ? packet[3] : -1;
}
