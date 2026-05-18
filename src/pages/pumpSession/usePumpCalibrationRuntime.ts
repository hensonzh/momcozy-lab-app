import { useState } from "react";

type CalPromptStep = "ask" | "declined" | "disableAsk" | null;

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
