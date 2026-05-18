// Global volume unit store (mL ↔ oz)
import { useState, useEffect } from "react";

const ML_TO_OZ = 0.033814;

type VolumeUnit = "mL" | "oz";

const KEY = "volume-unit";

let current: VolumeUnit = (typeof localStorage !== "undefined" && localStorage.getItem(KEY) as VolumeUnit) || "mL";
const listeners = new Set<(u: VolumeUnit) => void>();

export const volumeUnitStore = {
  get: () => current,
  set: (u: VolumeUnit) => {
    current = u;
    if (typeof localStorage !== "undefined") localStorage.setItem(KEY, u);
    listeners.forEach(fn => fn(u));
  },
  toggle: () => {
    volumeUnitStore.set(current === "mL" ? "oz" : "mL");
  },
  subscribe: (fn: (u: VolumeUnit) => void) => {
    listeners.add(fn);
    return () => { listeners.delete(fn); };
  },
};

/** Format a mL value according to the given unit */
export function formatVol(ml: number, unit: VolumeUnit): string {
  if (unit === "oz") return (ml * ML_TO_OZ).toFixed(1);
  return String(Math.round(ml));
}

/** Get the unit label */
export function unitLabel(unit: VolumeUnit): string {
  return unit;
}

/** React hook for the global volume unit */
export function useVolumeUnit(): [VolumeUnit, () => void] {
  const [unit, setUnit] = useState<VolumeUnit>(current);
  useEffect(() => volumeUnitStore.subscribe(setUnit), []);
  return [unit, volumeUnitStore.toggle];
}
