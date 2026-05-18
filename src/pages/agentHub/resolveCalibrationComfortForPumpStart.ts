import { getPumpThreshold } from "@/lib/agentApi";
import type { PumpThresholdData } from "@/lib/agentApiTypes";
import { sendF1SetUserParams } from "@/lib/ble";
import { deviceStore, type DeviceSide } from "@/lib/deviceStore";
import { createScopedConsole } from "@/lib/logger";
import {
  parseComfortSidesFromCalibrationLocalStorage,
  persistPumpThresholdToCalibrationLocalStorage,
  type CalibrationComfortSides,
} from "@/lib/calibrationLocalStorage";

const log = createScopedConsole("resolveCalibrationComfortForPumpStart");

/** 「开始吸奶」力度解析结果（用于日志与判断） */
export type PumpStartCalibrationResolveResult = {
  ok: boolean;
  /** 本地已存在 / 远端拉取并写入后视为完成 */
  source: "local" | "remote" | "none";
  /** 左右刺激、深度舒适档（与 calibration 本地缓存语义一致）；未完成时为 null */
  comfortSides: CalibrationComfortSides | null;
  /** 调用过 getPumpThreshold 时的服务端返回（仅本地命中时通常为 null） */
  remoteThreshold: PumpThresholdData | null;
  /** 拉取失败时的错误文案 */
  remoteFetchError: string | null;
};

function isValidApiGearLevel(level?: number): boolean {
  return typeof level === "number" && level >= 1 && level <= 15;
}

function pairFromSide(stim?: number, deep?: number): { stim: number; deep: number } | null {
  if (!isValidApiGearLevel(stim) || !isValidApiGearLevel(deep)) return null;
  return { stim, deep };
}

/** 与 PumpSession 侧一致：至少一侧有效即认为服务端存在滴定结果 */
function pumpThresholdHasValidComfortData(t: PumpThresholdData): boolean {
  const leftOk = isValidApiGearLevel(t.stimulate_level_l) && isValidApiGearLevel(t.deep_level_l);
  const rightOk = isValidApiGearLevel(t.stimulate_level_r) && isValidApiGearLevel(t.deep_level_r);
  return leftOk || rightOk;
}

function thresholdToComfortSides(t: PumpThresholdData): CalibrationComfortSides | null {
  const l = pairFromSide(t.stimulate_level_l, t.deep_level_l);
  const r = pairFromSide(t.stimulate_level_r, t.deep_level_r);
  if (l && r) return { L: l, R: r };
  if (l) return { L: l, R: { stim: l.stim, deep: l.deep } };
  if (r) return { L: { stim: r.stim, deep: r.deep }, R: r };
  return null;
}

/** 远端阈值已写入本地后：对已连接对应侧下发 F1（线值 0～14，与 ComfortCalibration 一致 persist=1）。失败不阻断 resolve。 */
async function pushF1ComfortSidesToConnectedPumps(sides: CalibrationComfortSides): Promise<void> {
  const snap = deviceStore.get();
  await Promise.all(
    (["L", "R"] as const).map(async (side: DeviceSide) => {
      const dev = snap[side];
      const p = sides[side];
      if (!dev?.connected || !dev.deviceId) return;
      const stimWire = p.stim - 1;
      const deepWire = p.deep - 1;
      if (stimWire < 0 || stimWire > 14 || deepWire < 0 || deepWire > 14) {
        log.warn("pushF1ComfortSides skip invalid wire", { side, stimUi: p.stim, deepUi: p.deep });
        return;
      }
      try {
        const ok = await sendF1SetUserParams(dev.deviceId, stimWire, deepWire, 1);
        if (!ok) {
          log.warn("pushF1ComfortSides no ACK", { side, deviceId: dev.deviceId, stimWire, deepWire });
        }
      } catch (e: unknown) {
        log.warn("pushF1ComfortSides failed", {
          side,
          deviceId: dev.deviceId,
          error: e instanceof Error ? e.message : String(e),
        });
      }
    }),
  );
}

/**
 * Hub「开始吸奶」前置：先读本地 calibration，缺失则拉取 getPumpThreshold；任一侧有效即写入本地并视为已完成。
 * 远端拉回有效阈值并 persist 后，会对已连接对应侧泵下发 F1 同步舒适档。
 */
export async function resolveCalibrationComfortForPumpStart(
  userId: string,
  opts?: { signal?: AbortSignal },
): Promise<PumpStartCalibrationResolveResult> {
  const localComfort = parseComfortSidesFromCalibrationLocalStorage();
  if (localComfort) {
    return {
      ok: true,
      source: "local",
      comfortSides: localComfort,
      remoteThreshold: null,
      remoteFetchError: null,
    };
  }

  try {
    const remote = await getPumpThreshold(userId, { signal: opts?.signal });
    if (!pumpThresholdHasValidComfortData(remote)) {
      return {
        ok: false,
        source: "none",
        comfortSides: null,
        remoteThreshold: remote,
        remoteFetchError: null,
      };
    }
    const sides = thresholdToComfortSides(remote);
    if (!sides) {
      return {
        ok: false,
        source: "none",
        comfortSides: null,
        remoteThreshold: remote,
        remoteFetchError: null,
      };
    }
    persistPumpThresholdToCalibrationLocalStorage(sides);
    await pushF1ComfortSidesToConnectedPumps(sides);
    return {
      ok: true,
      source: "remote",
      comfortSides: sides,
      remoteThreshold: remote,
      remoteFetchError: null,
    };
  } catch (e: unknown) {
    const remoteFetchError = e instanceof Error ? e.message : String(e);
    return {
      ok: false,
      source: "none",
      comfortSides: null,
      remoteThreshold: null,
      remoteFetchError,
    };
  }
}
