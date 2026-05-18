import React, { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Play, Pause, Square, Droplets, Waves, SlidersHorizontal, BatteryMedium, Signal } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useDeviceStore, DeviceSide } from "@/store/deviceStore";
import { deviceStore } from "@/lib/deviceStore";
import { resolveCalibrationComfortForPumpStart } from "@/pages/agentHub/resolveCalibrationComfortForPumpStart";
import { parseComfortSidesFromCalibrationLocalStorage } from "@/lib/calibrationLocalStorage";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

interface Props {
  side: DeviceSide;
  open: boolean;
  onClose: () => void;
  onDisconnect?: (side: DeviceSide) => Promise<void> | void;
}

type HubPumpGateDialog = "calibration" | "device" | "device_strength";

const DeviceControlPanel: React.FC<Props> = ({ side, open, onClose, onDisconnect }) => {
  const navigate = useNavigate();
  const deviceState = useDeviceStore((state) => side === "L" ? state.leftDevice : state.rightDevice);
  const { startSession, pauseSession, stopSession } = useDeviceStore();
  const [startPumpBusy, setStartPumpBusy] = useState(false);
  const [hubPumpGateDialog, setHubPumpGateDialog] = useState<HubPumpGateDialog | null>(null);
  const [bestComfortLine, setBestComfortLine] = useState<string | null>(null);
  const [bestComfortLoading, setBestComfortLoading] = useState(false);
  const [disconnecting, setDisconnecting] = useState(false);
  const [storedDevice, setStoredDevice] = useState(() => deviceStore.get()[side]);
  const startPumpLockRef = useRef(false);

  const isRunning = deviceState.sessionState === "running";
  const isPaused = deviceState.sessionState === "paused";
  const displayBattery = storedDevice?.battery ?? deviceState.battery;
  const displaySignal = (() => {
    if (!storedDevice?.connected) return "无";
    const rssi = storedDevice.rssi;
    if (!Number.isFinite(rssi)) return "良";
    if (rssi > -50) return "强";
    if (rssi > -65) return "良";
    return "弱";
  })();

  useEffect(() => {
    const sync = () => {
      setStoredDevice(deviceStore.get()[side]);
    };
    sync();
    return deviceStore.subscribe(sync);
  }, [side]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    const pairFromSides = (stim: number, deep: number) =>
      `刺激：${stim}档      吸乳：${deep}档`;

    const local = parseComfortSidesFromCalibrationLocalStorage();
    if (local) {
      const p = side === "L" ? local.L : local.R;
      setBestComfortLine(pairFromSides(p.stim, p.deep));
      setBestComfortLoading(false);
      return () => {
        cancelled = true;
      };
    }

    setBestComfortLine(null);
    setBestComfortLoading(true);
    void resolveCalibrationComfortForPumpStart(DEFAULT_CHAT_USER_ID).then((result) => {
      if (cancelled) return;
      setBestComfortLoading(false);
      if (result.comfortSides) {
        const p = side === "L" ? result.comfortSides.L : result.comfortSides.R;
        setBestComfortLine(pairFromSides(p.stim, p.deep));
      } else {
        setBestComfortLine(null);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [open, side]);

  const handleStartPump = useCallback(async () => {
    if (startPumpLockRef.current) return;
    startPumpLockRef.current = true;
    setStartPumpBusy(true);
    try {
      const cal = await resolveCalibrationComfortForPumpStart(DEFAULT_CHAT_USER_ID);
      const snap = deviceStore.get();
      const leftOk = Boolean(snap.L?.connected && snap.L.deviceId);
      const rightOk = Boolean(snap.R?.connected && snap.R.deviceId);
      const anyConnected = leftOk || rightOk;

      if (!cal.ok) {
        setHubPumpGateDialog("calibration");
        return;
      }
      if (!anyConnected) {
        setHubPumpGateDialog("device");
        return;
      }
      onClose();
      navigate("/pump");
    } finally {
      startPumpLockRef.current = false;
      setStartPumpBusy(false);
    }
  }, [navigate, onClose]);

  const handleOpenStrengthCalibration = useCallback(() => {
    const snap = deviceStore.get();
    const leftOk = Boolean(snap.L?.connected && snap.L.deviceId);
    const rightOk = Boolean(snap.R?.connected && snap.R.deviceId);
    if (!leftOk || !rightOk) {
      setHubPumpGateDialog("device_strength");
      return;
    }
    onClose();
    navigate("/calibration");
  }, [navigate, onClose]);

  return (
    <Drawer open={open} onOpenChange={(v) => !v && onClose()}>
      <DrawerContent className="max-h-[90vh] max-w-lg mx-auto bg-card border-t border-border shadow-2xl">
        <DrawerHeader className="sr-only">
          <DrawerTitle>{side === "L" ? "左侧" : "右侧"}主机控制面板</DrawerTitle>
        </DrawerHeader>

        {/* Drag handle & Header */}
        <div className="flex flex-col items-center pt-2 pb-2 border-b border-border/50 relative flex-shrink-0">
          <h2 className="text-base font-bold text-foreground mt-2">{side === "L" ? "左侧" : "右侧"}主机控制面板</h2>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-6 space-y-6 pb-safe">
          
          {/* Status Bar */}
          <div className="flex items-center justify-between bg-secondary/50 rounded-2xl p-4">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1.5">
                <BatteryMedium className="w-5 h-5 text-primary" />
                <span className="text-sm font-semibold">{displayBattery}%</span>
              </div>
              <div className="flex items-center gap-1.5">
                <Signal className="w-4 h-4 text-primary" />
                <span className="text-sm font-semibold">{displaySignal}</span>
              </div>
            </div>
            <Button 
              variant="ghost" 
              size="sm" 
              className="text-xs text-destructive hover:text-destructive/80 hover:bg-destructive/10 h-7"
              disabled={disconnecting}
              onClick={() => {
                setDisconnecting(true);
                Promise.resolve(onDisconnect?.(side))
                  .finally(() => {
                    setDisconnecting(false);
                    onClose();
                  });
              }}
            >
              {disconnecting ? "断开中..." : "断开连接"}
            </Button>
          </div>

          {/* Core Controls */}
          <div className="space-y-6 pt-2">
            <div className="space-y-4">
              <div>
                <h3 className="text-sm font-bold text-foreground mb-1.5">模式介绍</h3>
                <p className="text-[13px] text-muted-foreground leading-relaxed bg-secondary/30 p-3 rounded-xl border border-border/40">
                  <span className="font-semibold text-foreground flex items-center gap-1.5 mb-1">
                    <Waves className="w-3.5 h-3.5" /> 刺激模式
                  </span>
                  频率快、吸力小，模仿宝宝吸吮初期的短促动作，刺激奶阵产生。
                  <br />
                  <span className="font-semibold text-foreground flex items-center gap-1.5 mt-2 mb-1">
                    <Droplets className="w-3.5 h-3.5" /> 吸乳模式
                  </span>
                  频率慢、吸力大，模仿宝宝出奶后的深长吞咽，高效排空乳房。
                </p>
              </div>

              <div>
                <h3 className="text-sm font-bold text-foreground mb-1.5">档位介绍</h3>
                <p className="text-[13px] text-muted-foreground leading-relaxed bg-secondary/30 p-3 rounded-xl border border-border/40">
                  共设 1-15 档吸力调节。建议从 1 档开始，逐渐上调至感到明显拉扯感但不感到疼痛的位置（即「最大舒适负压」）。
                </p>
              </div>

              <div className="flex items-center justify-between bg-primary/5 border border-primary/20 rounded-xl p-3.5">
                <div>
                  <h3 className="text-[13px] font-bold text-foreground">最佳档位记录</h3>
                  <p className="text-[11px] text-muted-foreground mt-0.5 tabular-nums">
                    {bestComfortLoading
                      ? "正在读取档位记录…"
                      : bestComfortLine ?? "暂无，需要通过力度调节来探索"}
                  </p>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={handleOpenStrengthCalibration}
                  className="h-8 text-xs font-bold rounded-lg border-primary/30 text-primary bg-background shadow-sm hover:bg-primary/10 transition-colors"
                >
                  <SlidersHorizontal className="w-3.5 h-3.5 mr-1.5" /> 力度调节
                </Button>
              </div>
            </div>

            {/* Play/Pause Actions */}
            <div className="flex gap-4 pt-4 border-t border-border/50">
              {isRunning || isPaused ? (
                <>
                  <Button 
                    className="flex-1 h-14 rounded-2xl gap-2 shadow-lg" 
                    variant={isRunning ? "outline" : "default"}
                    onClick={() => isRunning ? pauseSession(side) : startSession(side)}
                  >
                    {isRunning ? <Pause className="w-5 h-5" /> : <Play className="w-5 h-5" />}
                    <span className="text-base font-bold">{isRunning ? "暂停" : "继续"}</span>
                  </Button>
                  <Button 
                    variant="destructive" 
                    className="flex-1 h-14 rounded-2xl gap-2 shadow-lg"
                    onClick={() => stopSession(side)}
                  >
                    <Square className="w-5 h-5" />
                    <span className="text-base font-bold">结束</span>
                  </Button>
                </>
              ) : (
                <Button 
                  className="w-full h-14 rounded-2xl gap-2 text-base font-bold shadow-lg"
                  onClick={() => void handleStartPump()}
                  disabled={startPumpBusy}
                >
                  <Play className="w-5 h-5" />
                  {startPumpBusy ? "检查中..." : "开始吸奶"}
                </Button>
              )}
            </div>

          </div>
        </div>
      </DrawerContent>
      <AlertDialog
        open={hubPumpGateDialog !== null}
        onOpenChange={(nextOpen) => {
          if (!nextOpen) setHubPumpGateDialog(null);
        }}
      >
        <AlertDialogContent className="z-[70] max-w-[min(100vw-2rem,22rem)] rounded-2xl border-border/60 p-5 gap-3 shadow-xl">
          <AlertDialogHeader className="text-left space-y-2.5">
            <AlertDialogTitle className="text-base font-bold text-black dark:text-white leading-snug pr-8">
              {hubPumpGateDialog === "calibration"
                ? "需要先完成首次力度调节"
                : "吸奶器设备未连接"}
            </AlertDialogTitle>
            <AlertDialogDescription className="text-[13px] leading-relaxed text-muted-foreground">
              {hubPumpGateDialog === "calibration"
                ? "首次吸奶前需要先找到你的舒适吸力档位。完成后，M.ai 会按你的舒适档位启动吸奶。"
                : hubPumpGateDialog === "device_strength"
                  ? "力度调节需要左右两侧吸奶器均已连接。请先进入设备页完成两侧连接后再进行力度调节。"
                  : "开始吸奶前需要确认左右吸奶器已连接。请先进入设备页完成连接后再开始。"}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-row justify-end gap-2 sm:flex-row sm:justify-end sm:space-x-0">
            <AlertDialogCancel type="button" className="m-0 rounded-full border-border/80 bg-background">
              稍后再说
            </AlertDialogCancel>
            <AlertDialogAction
              type="button"
              className="m-0 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 focus-visible:ring-ring"
              onClick={() => {
                const route =
                  hubPumpGateDialog === "calibration" ? "/calibration" : "/device";
                setHubPumpGateDialog(null);
                onClose();
                navigate(route);
              }}
            >
              {hubPumpGateDialog === "calibration" ? "去力度调节" : "去连接设备"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </Drawer>
  );
};

export default DeviceControlPanel;