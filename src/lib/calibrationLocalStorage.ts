/**
 * 耐受度滴定结果在 localStorage 中的读写（与 ComfortCalibration 写入结构一致）。
 */

import type { DeviceSide } from "@/lib/deviceStore";
import { createScopedConsole } from "@/lib/logger";

const log = createScopedConsole("calibrationLocalStorage");

export const CALIBRATION_LOCAL_STORAGE_KEY = "calibration";

/** 与 E1 线值 0xFF 对应：写入 JSON 表示该轴设备未保存滴定；{@link parseComfortSidesFromCalibrationLocalStorage} 不接受此值（返回 null） */
export const CALIBRATION_UI_UNSAVED_SENTINEL = 0xff;

/** Hub 展示用：左右刺激/深度舒适档 */
export type CalibrationComfortSides = {
  L: { stim: number; deep: number };
  R: { stim: number; deep: number };
};

/** 与 ComfortCalibration 的 MAX_GEAR 一致（Hub 远端回填 `maxSafe` 字段） */
const MAX_CALIBRATION_SAFE_GEAR = 15;

const COMFORT_UI_MIN = 1;

function isComfortUiGear(n: unknown): n is number {
  return typeof n === "number" && Number.isInteger(n) && n >= COMFORT_UI_MIN && n <= MAX_CALIBRATION_SAFE_GEAR;
}

/** 仅用于日志：说明某轴为何未通过 1～15 严格解析 */
function comfortGearDiag(n: unknown): string {
  if (isComfortUiGear(n)) return `ok(${n})`;
  if (n === CALIBRATION_UI_UNSAVED_SENTINEL) return "sentinel_0xff_not_valid_for_resolve_local_hit";
  if (typeof n === "number" && Number.isInteger(n)) return `out_of_range(${n})`;
  if (n === undefined) return "undefined";
  if (typeof n === "number") return `non_integer_number(${n})`;
  return `type_${typeof n}`;
}

/** 宽松读取（供 E1 合并）：允许 0xFF 等任意整数档，不校验舒适 UI 范围 */
// E1 pumpGearCalib is device history and must not be imported as user calibration.

/**
 * 从 localStorage 读取 `calibration` 并解析为左右舒适档。
 * @returns 解析成功且**四轴档位均在舒适 UI 合理范围 1～15**时返回结构；无数据、JSON 非法、缺字段或含 0xFF 占位等时为 null
 */
export function parseComfortSidesFromCalibrationLocalStorage(): CalibrationComfortSides | null {
  try {
    const raw = localStorage.getItem(CALIBRATION_LOCAL_STORAGE_KEY);
    if (!raw) {
      log.log("parseComfortSides", {
        outcome: "miss",
        reason: "no_localStorage_raw",
        resolveCalibrationComfortForPumpStart: "will_try_getPumpThreshold_if_invoked",
      });
      return null;
    }
    const data = JSON.parse(raw) as Record<string, unknown>;
    const hasLR = Boolean(data?.L || data?.R);
    if (hasLR) {
      const rawL = data.L as { stimCozy?: unknown; deepCozy?: unknown } | undefined;
      const rawR = data.R as { stimCozy?: unknown; deepCozy?: unknown } | undefined;
      // stringify 会省略值为 undefined 的键，可能仅存一侧
      const left = rawL ?? rawR;
      const right = rawR ?? rawL;
      if (!left || !right) {
        log.log("parseComfortSides", {
          outcome: "miss",
          reason: "missing_L_or_R_slot_after_fallback",
          hasRawL: Boolean(rawL),
          hasRawR: Boolean(rawR),
          resolveCalibrationComfortForPumpStart: "will_try_getPumpThreshold_if_invoked",
        });
        return null;
      }
      const ls = left.stimCozy;
      const ld = left.deepCozy;
      const rs = right.stimCozy;
      const rd = right.deepCozy;
      if (!isComfortUiGear(ls) || !isComfortUiGear(ld) || !isComfortUiGear(rs) || !isComfortUiGear(rd)) {
        log.log("parseComfortSides", {
          outcome: "miss",
          reason: "L_R_shape_but_gear_not_all_in_1_15",
          L_stim: comfortGearDiag(ls),
          L_deep: comfortGearDiag(ld),
          R_stim: comfortGearDiag(rs),
          R_deep: comfortGearDiag(rd),
          resolveCalibrationComfortForPumpStart: "will_try_getPumpThreshold_if_invoked",
        });
        return null;
      }
      const hit: CalibrationComfortSides = {
        L: { stim: ls, deep: ld },
        R: { stim: rs, deep: rd },
      };
      log.log("parseComfortSides", {
        outcome: "hit",
        shape: "L_R",
        L: hit.L,
        R: hit.R,
        resolveCalibrationComfortForPumpStart: "local_ok_source_local",
      });
      return hit;
    }
    const stim = data.stimCozy;
    const deep = data.deepCozy;
    if (!isComfortUiGear(stim) || !isComfortUiGear(deep)) {
      log.log("parseComfortSides", {
        outcome: "miss",
        reason: "top_level_stim_deep_not_both_in_1_15",
        stimCozy: comfortGearDiag(stim),
        deepCozy: comfortGearDiag(deep),
        resolveCalibrationComfortForPumpStart: "will_try_getPumpThreshold_if_invoked",
      });
      return null;
    }
    const hit: CalibrationComfortSides = {
      L: { stim, deep },
      R: { stim, deep },
    };
    log.log("parseComfortSides", {
      outcome: "hit",
      shape: "top_level_only",
      stimCozy: stim,
      deepCozy: deep,
      resolveCalibrationComfortForPumpStart: "local_ok_source_local",
    });
    return hit;
  } catch (e) {
    log.warn("parseComfortSides", {
      outcome: "miss",
      reason: "json_parse_or_unexpected_error",
      error: e instanceof Error ? e.message : String(e),
      resolveCalibrationComfortForPumpStart: "will_try_getPumpThreshold_if_invoked",
    });
    return null;
  }
}

/**
 * 将服务端查询到的左右滴定档位写入 localStorage，与滴定页 `doApply` 结构对齐。
 * @param sides 左/右刺激与深度舒适档（可为 {@link CALIBRATION_UI_UNSAVED_SENTINEL}，仅 E1 合并路径会写入）
 */
export function persistPumpThresholdToCalibrationLocalStorage(sides: CalibrationComfortSides): void {
  const payload = {
    L: { stimCozy: sides.L.stim, deepCozy: sides.L.deep },
    R: { stimCozy: sides.R.stim, deepCozy: sides.R.deep },
    stimCozy: sides.L.stim,
    deepCozy: sides.L.deep,
    maxSafe: MAX_CALIBRATION_SAFE_GEAR,
    timestamp: Date.now(),
  };
  try {
    localStorage.setItem(CALIBRATION_LOCAL_STORAGE_KEY, JSON.stringify(payload));
    log.log("persistCalibration", { L: payload.L, R: payload.R, maxSafe: payload.maxSafe });
  } catch {
    /* 写入失败时忽略 */
  }
}

/** E1 滴定字节：协议 0～14；0xFF 表示设备未保存该轴滴定 */
const E1_CALIB_WIRE_MAX = 14;
const E1_CALIB_WIRE_UNSAVED = 0xff;

function isE1CalibWireByte(b: number): boolean {
  return Number.isInteger(b) && b >= 0 && b <= E1_CALIB_WIRE_MAX;
}

/** 宽松 JSON 中某轴是否可作为已存储数值使用（含 0xFF 占位 255） */
function isLooseStoredAxis(n: unknown): n is number {
  return typeof n === "number" && Number.isFinite(n) && Number.isInteger(n);
}

/**
 * 将 E1 应答中的滴定线值合并进 `calibration`（由 `configurePumpAfterBleConnect` 在 F2+E1 成功后调用）。
 *
 * **E1 线值校验（`resolveUi` / 当前侧）**：
 * - `0～14` 且为整数 → 视为合法线档，写入 UI 值 `wire + 1`（1～15）。
 * - `0xFF`（255）→ 设备未保存该轴，写入 `CALIBRATION_UI_UNSAVED_SENTINEL`（255）。
 * - 其它（非整数、或不在 0～14 且非 0xFF）→ 若宽松读该侧 JSON 对应轴为 `isLooseStoredAxis` 则沿用，否则写入 sentinel。
 *
 * **对侧**：仅看宽松 JSON；该轴为 `isLooseStoredAxis` 则保留，否则**镜像**本侧合并后的 `stimUi`/`deepUi`。
 *
 * 1. `readCalibrationSidesLooseFromLocalStorage`：读当前 JSON。  
 * 2. 对 **当前连接侧**：按上表把 `stimulateWire`/`deepWire` 转为 `stimUi`/`deepUi`。  
 * 3. **对侧**：宽松读优先，否则镜像本侧。  
 * 4. `persistPumpThresholdToCalibrationLocalStorage`：整表重写 `calibration`。  
 *
 * 与 `resolveCalibrationComfortForPumpStart`：含 sentinel 时严格解析为 miss，仍会走远端阈值直至四轴均为 1～15。
 */
export function mergeE1PumpGearCalibWireIntoCalibrationLocalStorage(
  side: DeviceSide,
  stimulateWire: number,
  deepWire: number,
): void {
  log.log("mergeE1PumpGearCalib", {
    phase: "ignored",
    side,
    e1Wire: { stimulate: stimulateWire, deep: deepWire },
    reason: "device_e1_history_is_not_user_calibration",
  });
}

/**
 * `configurePumpAfterBleConnect` 未进入 `mergeE1PumpGearCalibWireIntoCalibrationLocalStorage` 时调用，便于对照守卫条件。
 */
export function logCalibrationE1MergeSkippedFromConfigurePump(payload: {
  side: DeviceSide;
  expectedDeviceId: string;
  afterDeviceId: string | null | undefined;
  hasPumpGearCalib: boolean;
  stimulateType: string;
  deepType: string;
}): void {
  log.warn("mergeE1FromConfigurePump", { skipped: true, ...payload });
}
