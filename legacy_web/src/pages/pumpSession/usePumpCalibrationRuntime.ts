import { useState } from "react";
import { parseComfortSidesFromCalibrationLocalStorage } from "@/lib/calibrationLocalStorage";

type CalPromptStep = "ask" | "declined" | "disableAsk" | null;

type PumpCalibrationDeviceSnapshot = {
  L: { connected?: boolean } | null;
  R: { connected?: boolean } | null;
};

export function canStartPumpCalibration(snapshot: PumpCalibrationDeviceSnapshot): boolean {
  return Boolean(snapshot.L?.connected && snapshot.R?.connected);
}

export type PumpCalibrationSessionConfig = {
  hasCalibration: boolean;
  initGearL: number;
  initGearR: number;
  targetGearL: number;
  targetGearR: number;
};

export function shouldSkipCalibrationInitialGearSetup(fromCalibration: boolean, autoStarted: string | null): boolean {
  return fromCalibration && autoStarted === "1";
}

export function readPumpCalibrationSessionConfig(
  fromCalibration: boolean,
  skipInitialGearSetup = false,
): PumpCalibrationSessionConfig {
  const comfort = parseComfortSidesFromCalibrationLocalStorage();
  if (!comfort) {
    return {
      hasCalibration: false,
      initGearL: 5,
      initGearR: 5,
      targetGearL: 5,
      targetGearR: 5,
    };
  }
  return {
    hasCalibration: true,
    initGearL: skipInitialGearSetup ? 5 : fromCalibration ? comfort.L.stim : Math.max(1, comfort.L.stim - 2),
    initGearR: skipInitialGearSetup ? 5 : fromCalibration ? comfort.R.stim : Math.max(1, comfort.R.stim - 2),
    targetGearL: comfort.L.stim,
    targetGearR: comfort.R.stim,
  };
}

export function shouldPromptForPumpCalibration(): boolean {
  const { hasCalibration } = readPumpCalibrationSessionConfig(false);
  const calDisabled = localStorage.getItem("calibration_prompt_disabled") === "true";
  return !hasCalibration && !calDisabled;
}

export function usePumpCalibrationRuntime(hasCalibration: boolean) {
  const calDisabled = localStorage.getItem("calibration_prompt_disabled") === "true";
  const [calPromptStep, setCalPromptStep] = useState<CalPromptStep>(() => {
    if (hasCalibration || calDisabled) return null;
    return "ask";
  });
  const [calPromptRunning, setCalPromptRunning] = useState(calPromptStep === null);

  const handleCalPromptNo = () => {
    const prevCount = parseInt(localStorage.getItem("calibration_decline_count") || "0", 10);
    const newCount = prevCount + 1;
    localStorage.setItem("calibration_decline_count", String(newCount));
    if (newCount >= 3) {
      setCalPromptStep("disableAsk");
    } else {
      setCalPromptStep("declined");
    }
  };

  const handleCalPromptDeclinedOk = () => {
    setCalPromptStep(null);
    setCalPromptRunning(true);
  };

  const handleCalDisableYes = () => {
    localStorage.setItem("calibration_prompt_disabled", "true");
    setCalPromptStep(null);
    setCalPromptRunning(true);
  };

  const handleCalDisableNo = () => {
    localStorage.setItem("calibration_decline_count", "0");
    setCalPromptStep(null);
    setCalPromptRunning(true);
  };

  return {
    calPromptStep,
    setCalPromptStep,
    calPromptRunning,
    handleCalPromptNo,
    handleCalPromptDeclinedOk,
    handleCalDisableYes,
    handleCalDisableNo,
  };
}
