import type { StoredDeviceInfo, PumpGearMemoryPair } from "@/lib/deviceStore";

export type { PumpGearMemoryPair } from "@/lib/deviceStore";

/**
 * 根据 D0/B1 更新单侧「Mai 场景 / 手动场景 × 刺激/深度」档位记忆。
 * @param cur 当前 store 中单侧信息
 * @param scene 0 手动 1 Mai/自动
 * @param modeB1 B1 吸乳模式 0 刺激 1 深度 2 混合
 * @param gearB1 B1 线档位 0–14
 * @returns 仅含 pumpGearMemoryAi / pumpGearMemoryManual 的补丁，供 setDevice 合并
 */
export function patchGearMemory(
  cur: StoredDeviceInfo,
  scene: 0 | 1,
  modeB1: 0 | 1 | 2,
  gearB1: number
): Pick<StoredDeviceInfo, "pumpGearMemoryAi" | "pumpGearMemoryManual"> {
  const gi = Math.max(0, Math.min(14, gearB1));
  const isAi = scene === 1;
  const prev = isAi ? cur.pumpGearMemoryAi : cur.pumpGearMemoryManual;
  const next: PumpGearMemoryPair = { ...prev };
  if (modeB1 === 0) next.stimulate = gi;
  else if (modeB1 === 1) next.deep = gi;
  else {
    next.stimulate = gi;
    next.deep = gi;
  }
  return isAi ? { pumpGearMemoryAi: next } : { pumpGearMemoryManual: next };
}

/**
 * 切换 Mai/手动或刺激/深度后，从记忆中取目标场景+目标模式对应的 B1 档位。
 * @param cur 单侧 store，可为空
 * @param scene 目标 B1 场景 0 手动 1 自动
 * @param modeB1 目标 B1 吸乳模式
 * @param fallbackGearB1 无记忆时的回退（如当前 snap 或 gear）
 * @returns 钳位后的 B1 档位 0–14
 */
export function readGearB1FromMemory(
  cur: StoredDeviceInfo | null | undefined,
  scene: 0 | 1,
  modeB1: 0 | 1 | 2,
  fallbackGearB1: number
): number {
  const fb = Math.max(0, Math.min(14, fallbackGearB1));
  if (!cur) return fb;
  const m = scene === 1 ? cur.pumpGearMemoryAi : cur.pumpGearMemoryManual;
  let g: number | undefined;
  if (modeB1 === 0) g = m?.stimulate;
  else if (modeB1 === 1) g = m?.deep;
  else g = m?.stimulate ?? m?.deep;
  if (g == null) return fb;
  return Math.max(0, Math.min(14, g));
}
