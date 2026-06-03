import React, { useState, useEffect, useRef, useCallback } from "react";
import { motion } from "framer-motion";
import { X, Bluetooth, Check, Loader2, Navigation, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer";
import {
  isBleSupported,
  initializeBle,
  startLEScan,
  stopLEScan,
  getConnectedPumpDevices,
  connect as bleConnect,
  openBluetoothSettings,
  openAppSettings,
} from "@/lib/ble";
import { log as loggerLog, warn as loggerWarn } from "@/lib/logger";
import { deviceStore } from "@/lib/deviceStore";

interface ScannedDevice {
  id: string;
  name: string;
  rssi: number;
  paired: boolean;
}

interface Props {
  open: boolean;
  side: "L" | "R";
  currentDeviceId?: string;
  onClose: () => void;
  /** 连接成功时回调，传入 deviceId 与设备名称（用于在主机卡片显示） */
  onConnect: (deviceId: string, deviceName: string, rssi: number) => void;
  /** 设备断开连接时回调，用于卡片显示离线状态 */
  onDisconnect?: (deviceId: string) => void;
}

/** 左侧只显示 LT_xxxxxx_L，右侧只显示 LT_xxxxxx_R（x 为任意字母、数字或下划线） */
function matchDeviceNameForSide(name: string, side: "L" | "R"): boolean {
  const pattern = side === "L" ? /^LT_[a-zA-Z0-9_]+_L$/ : /^LT_[a-zA-Z0-9_]+_R$/;
  return pattern.test(name.trim());
}

function getConnectedDeviceForSide(side: "L" | "R"): ScannedDevice | null {
  const stored = deviceStore.get()[side];
  if (!stored?.connected || !stored.deviceId) return null;
  return {
    id: stored.deviceId,
    name: stored.deviceName || stored.model || stored.deviceId,
    rssi: stored.rssi ?? -50,
    paired: true,
  };
}

const BluetoothSearchDrawer: React.FC<Props> = ({
  open,
  side,
  currentDeviceId,
  onClose,
  onConnect,
  onDisconnect,
}) => {
  const [scanning, setScanning] = useState(false);
  const [initializing, setInitializing] = useState(false);
  const [devices, setDevices] = useState<ScannedDevice[]>([]);
  const [connecting, setConnecting] = useState<string | null>(null);
  const [initError, setInitError] = useState<string | null>(null);
  const [connectError, setConnectError] = useState<string | null>(null);
  const deviceIdsRef = useRef<Set<string>>(new Set());
  const finishScanAndRecoverIfEmptyRef = useRef<(cancelled: () => boolean) => Promise<void>>(async () => {});

  const bleSupported = isBleSupported();
  const sideLabel = side === "L" ? "左侧" : "右侧";
  const SCAN_DURATION_MS = 10_000;

  const headerIconDestructive = !bleSupported || !!initError;
  const isConnecting = connecting !== null;

  const uiPhase = (() => {
    if (!bleSupported) return "unsupported" as const;
    if (initError) return "disabled" as const;
    if (initializing) return "checking" as const;
    if (isConnecting) return "connecting" as const;
    if (devices.length > 0) return "found" as const;
    if (scanning) return "scanning" as const;
    return "idle" as const;
  })();

  const showRadarSweep = uiPhase === "checking" || uiPhase === "scanning";
  const showFoundPulse = uiPhase === "found" || uiPhase === "connecting";

  const handleConnect = useCallback(
    async (deviceId: string, deviceName: string, rssi: number): Promise<boolean> => {
      setConnectError(null);
      setConnecting(deviceId);
      try {
        setScanning(false);
        await stopLEScan();
        await bleConnect(deviceId, () => onDisconnect?.(deviceId));
        setConnecting(null);
        onConnect(deviceId, deviceName, rssi);
        onClose();
        return true;
      } catch (e) {
        setConnecting(null);
        setConnectError(e instanceof Error ? e.message : "连接失败，请重试");
        return false;
      }
    },
    [onConnect, onClose, onDisconnect],
  );

  const recoverNativeConnectedDevice = useCallback(async (): Promise<boolean> => {
    const stored = deviceStore.get()[side];
    let connectedDevices: Awaited<ReturnType<typeof getConnectedPumpDevices>> = [];
    try {
      connectedDevices = await getConnectedPumpDevices();
    } catch (error) {
      loggerWarn("[BLE扫描]", "查询底层已连接设备失败", error);
      return false;
    }

    const candidate =
      connectedDevices.find((device) => device.device.deviceId === stored?.deviceId) ??
      connectedDevices.find((device) => {
        const name = device.device.name || device.localName || "";
        return matchDeviceNameForSide(name, side);
      });

    if (!candidate) {
      loggerLog("[BLE扫描]", "未发现可恢复的底层已连接设备", {
        side,
        connectedCount: connectedDevices.length,
      });
      return false;
    }

    const deviceId = candidate.device.deviceId;
    const deviceName =
      candidate.device.name ||
      candidate.localName ||
      stored?.deviceName ||
      stored?.model ||
      deviceId;
    const rssi = candidate.rssi ?? stored?.rssi ?? -50;
    loggerLog("[BLE扫描]", "扫描无结果，恢复底层已连接设备", {
      side,
      deviceId,
      deviceName,
    });
    return handleConnect(deviceId, deviceName, rssi);
  }, [handleConnect, side]);

  const finishScanAndRecoverIfEmpty = useCallback(
    async (cancelled: () => boolean): Promise<void> => {
      try {
        await stopLEScan();
      } catch {
        // ignore stop errors; recovery can still query the native connection table
      }
      if (cancelled()) return;

      setScanning(false);
      const connectedDevice = getConnectedDeviceForSide(side);
      const hasScanResult = deviceIdsRef.current.size > 0;
      const hasKnownConnectedDevice = connectedDevice != null;

      setDevices((current) => {
        const next =
          connectedDevice && !current.some((device) => device.id === connectedDevice.id)
            ? [...current, connectedDevice]
            : current;
        loggerLog(
          "[BLE扫描]",
          "扫描结束，共发现设备数:",
          next.length,
          next.length === 0
            ? "（若为 0：请确认蓝牙/定位已开启、已授权，且附近有 BLE 设备）"
            : "",
        );
        return next;
      });

      if (!hasScanResult && !hasKnownConnectedDevice) {
        await recoverNativeConnectedDevice();
      }
    },
    [recoverNativeConnectedDevice, side],
  );

  useEffect(() => {
    finishScanAndRecoverIfEmptyRef.current = finishScanAndRecoverIfEmpty;
  }, [finishScanAndRecoverIfEmpty]);

  // When drawer opens: init BLE and start scan (if supported); scan 10s then stop
  useEffect(() => {
    if (!open) {
      setInitializing(false);
      return;
    }

    setInitError(null);
    setConnectError(null);
    setDevices([]);
    deviceIdsRef.current = new Set();

    if (!bleSupported) {
      loggerLog("[BLE扫描]", "当前环境不支持 BLE，跳过扫描");
      setScanning(false);
      setInitializing(false);
      return;
    }

    let cancelled = false;
    let scanDurationTimer: ReturnType<typeof setTimeout> | null = null;
    loggerLog("[BLE扫描]", "打开抽屉，开始初始化 BLE");
    setInitializing(true);

    (async () => {
      try {
        setScanning(true);
        await initializeBle({});
        if (cancelled) return;
        loggerLog("[BLE扫描]", "BLE 初始化成功，启动扫描");
        setInitError(null);
        await startLEScan((result) => {
          const id = result.device?.deviceId ?? "";
          const name = result.device?.name || result.localName || "未知设备";
          const rssi = result.rssi ?? -100;
          const hasName = !!(result.device?.name || result.localName);
          if (hasName) {
            loggerLog("[BLE扫描]", "收到扫描回调", { id, name, rssi, cancelled });
          }
          if (cancelled) return;
          if (!matchDeviceNameForSide(name, side)) return;
          if (deviceIdsRef.current.has(id)) return;
          deviceIdsRef.current.add(id);
          const device = { id, name, rssi, paired: false };
          if (hasName) {
            loggerLog("[BLE扫描]", "发现设备（新）", device);
          }
          setDevices((prev) => [...prev, device]);
        });
        if (cancelled) return;
        setInitializing(false);
        loggerLog("[BLE扫描]", "扫描已启动，将在 10 秒后自动停止");
        scanDurationTimer = setTimeout(() => {
          scanDurationTimer = null;
          loggerLog("[BLE扫描]", "10 秒已到，停止扫描");
          void finishScanAndRecoverIfEmptyRef.current(() => cancelled);
        }, SCAN_DURATION_MS);
      } catch (e) {
        if (cancelled) return;
        const message = e instanceof Error ? e.message : "无法使用蓝牙，请检查权限与设置";
        loggerWarn("[BLE扫描]", "初始化或启动扫描失败", e);
        setInitError(message);
        setInitializing(false);
      } finally {
        if (!scanDurationTimer && !cancelled) setScanning(false);
      }
    })();

    return () => {
      cancelled = true;
      setInitializing(false);
      if (scanDurationTimer) clearTimeout(scanDurationTimer);
      if (bleSupported) {
        stopLEScan().catch(() => {});
      }
    };
  }, [open, bleSupported, side]);

  const handleRescan = useCallback(async () => {
    if (!bleSupported) return;
    setInitError(null);
    setConnectError(null);
    setDevices([]);
    deviceIdsRef.current = new Set();
    setInitializing(true);
    try {
      setScanning(true);
      await stopLEScan();
    } catch {
      /* ignore */
    }
    try {
      await startLEScan((result) => {
        const id = result.device.deviceId;
        const name = result.device.name || result.localName || "未知设备";
        const hasName = !!(result.device.name || result.localName);
        if (!matchDeviceNameForSide(name, side)) return;
        if (deviceIdsRef.current.has(id)) return;
        deviceIdsRef.current.add(id);
        const rssi = result.rssi ?? -100;
        const device = { id, name, rssi, paired: false };
        if (hasName) {
          loggerLog("[BLE扫描]", "发现设备", device);
        }
        setDevices((prev) => [...prev, device]);
      });
      setInitializing(false);
      setTimeout(() => {
        void finishScanAndRecoverIfEmpty(() => false);
      }, SCAN_DURATION_MS);
    } catch (e) {
      const message = e instanceof Error ? e.message : "扫描失败";
      setInitError(message);
      setScanning(false);
      setInitializing(false);
    }
  }, [bleSupported, finishScanAndRecoverIfEmpty, side]);

  const signalLabel = (rssi: number) => {
    if (rssi > -50) return { text: "强", color: "text-primary" };
    if (rssi > -65) return { text: "良", color: "text-mai-warm" };
    return { text: "弱", color: "text-muted-foreground" };
  };

  const canDismiss = !isConnecting;

  return (
    <Drawer
      open={open}
      onOpenChange={(v) => {
        if (!v && canDismiss) onClose();
      }}
    >
      <DrawerContent className="max-h-[85vh] max-w-lg mx-auto">
        <DrawerHeader className="sr-only">
          <DrawerTitle>配对{sideLabel}主机</DrawerTitle>
        </DrawerHeader>

        <div className="flex-shrink-0 px-5 pt-2 pb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bluetooth
              className={cn("w-5 h-5", headerIconDestructive ? "text-destructive" : "text-primary")}
            />
            <h2 className="text-base font-bold text-foreground">配对{sideLabel}主机</h2>
          </div>
          <button
            type="button"
            onClick={() => canDismiss && onClose()}
            className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center text-muted-foreground hover:text-foreground transition-colors disabled:opacity-50"
            disabled={!canDismiss}
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex-1 flex flex-col items-center p-8 space-y-6 pb-safe overflow-y-auto min-h-0">
          <div className="relative w-48 h-48 flex items-center justify-center flex-shrink-0">
            <div className="absolute inset-0 rounded-full border border-primary/20" />
            <div className="absolute inset-4 rounded-full border border-primary/30" />
            <div className="absolute inset-10 rounded-full border border-primary/40 bg-primary/5" />

            {showRadarSweep && (
              <motion.div
                animate={{ rotate: 360 }}
                transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                className="absolute inset-0 rounded-full overflow-hidden"
              >
                <div className="w-1/2 h-full bg-gradient-to-r from-transparent to-primary/20 origin-right" />
              </motion.div>
            )}

            <div className="relative z-10 w-16 h-16 bg-card rounded-2xl shadow-lg border border-border/50 flex items-center justify-center">
              {uiPhase === "unsupported" || uiPhase === "disabled" ? (
                <Bluetooth className="w-8 h-8 text-destructive" />
              ) : (
                <Navigation
                  className={cn(
                    "w-8 h-8",
                    uiPhase === "found" || uiPhase === "connecting"
                      ? "text-primary"
                      : "text-muted-foreground",
                  )}
                />
              )}
            </div>

            {showFoundPulse && (
              <motion.div
                initial={{ scale: 0, opacity: 0 }}
                animate={{ scale: [1, 1.2, 1], opacity: [0.8, 0.4, 0.8] }}
                transition={{ duration: 2, repeat: Infinity }}
                className="absolute top-4 right-4 w-12 h-12 bg-primary/20 rounded-full blur-md"
              />
            )}
          </div>

          <div className="text-center space-y-2 h-20 flex-shrink-0 w-full">
            {uiPhase === "unsupported" && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                <h3 className="text-lg font-bold text-destructive">不支持蓝牙扫描</h3>
                <p className="text-sm text-muted-foreground mt-1">
                  请在 Android 或 iOS 应用中使用蓝牙搜索与连接
                </p>
              </motion.div>
            )}

            {uiPhase === "disabled" && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                <h3 className="text-lg font-bold text-destructive">无法启动扫描</h3>
                <p className="text-sm text-muted-foreground mt-1 px-1">{initError}</p>
              </motion.div>
            )}

            {uiPhase === "checking" && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                <h3 className="text-lg font-bold text-foreground">检查蓝牙状态...</h3>
                <p className="text-sm text-muted-foreground mt-1">正在初始化并准备搜索设备</p>
              </motion.div>
            )}

            {uiPhase === "scanning" && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                <h3 className="text-lg font-bold text-foreground">正在寻找设备...</h3>
                <p className="text-sm text-muted-foreground mt-1">
                  请确保设备已开机（长按电源键3秒），并靠近手机
                </p>
              </motion.div>
            )}

            {uiPhase === "found" && (
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
                <h3 className="text-lg font-bold text-primary">
                  {devices.length === 1
                    ? `发现 ${devices[0].name}`
                    : `发现 ${devices.length} 台设备`}
                </h3>
                <p className="text-sm text-muted-foreground mt-1">设备已就绪，点击下方连接</p>
              </motion.div>
            )}

            {uiPhase === "connecting" && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="flex flex-col items-center gap-2"
              >
                <Loader2 className="w-6 h-6 text-primary animate-spin" />
                <h3 className="text-sm font-bold text-foreground">连接中，请稍候...</h3>
              </motion.div>
            )}

            {uiPhase === "idle" && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                <h3 className="text-lg font-bold text-foreground">本轮搜索结束</h3>
                <p className="text-sm text-muted-foreground mt-1">
                  未发现匹配的主机，可确认蓝牙与定位后重新搜索
                </p>
              </motion.div>
            )}
          </div>

          {connectError && (
            <div className="w-full flex items-center gap-2 text-destructive text-xs mt-2 px-1">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span className="text-left">{connectError}</span>
            </div>
          )}

          {bleSupported && uiPhase === "found" && (
            <div className="w-full space-y-2 max-h-[40vh] overflow-y-auto">
              {devices.map((d, i) => {
                const sig = signalLabel(d.rssi);
                const isPairedDevice =
                  d.paired || (currentDeviceId != null && d.id === currentDeviceId);
                const rowConnecting = connecting === d.id;

                return (
                  <motion.div
                    key={d.id}
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: Math.min(i * 0.05, 0.3) }}
                    className={cn(
                      "rounded-2xl border p-3.5 flex items-center gap-3 bg-card/80 shadow-sm",
                      isPairedDevice ? "border-primary/40 bg-primary/5" : "border-border/60",
                    )}
                  >
                    <div
                      className={cn(
                        "w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0",
                        isPairedDevice ? "bg-primary/15" : "bg-secondary",
                      )}
                    >
                      <Bluetooth
                        className={cn(
                          "w-5 h-5",
                          isPairedDevice ? "text-primary" : "text-muted-foreground",
                        )}
                      />
                    </div>
                    <div className="flex-1 min-w-0 text-left">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <p className="text-sm font-bold text-foreground truncate">{d.name}</p>
                        {isPairedDevice && (
                          <span className="text-[10px] font-semibold text-primary bg-primary/10 px-2 py-0.5 rounded-full">
                            已配对
                          </span>
                        )}
                      </div>
                      <p className={cn("text-xs mt-0.5", sig.color)}>信号{sig.text}</p>
                    </div>
                    {isPairedDevice ? (
                      <Button
                        variant="outline"
                        className="w-10 h-10 rounded-full p-0 shadow-sm flex-shrink-0 border-primary/30 text-primary bg-white hover:bg-white/90"
                        disabled={!!connecting}
                        onClick={() => handleConnect(d.id, d.name, d.rssi)}
                      >
                        {rowConnecting ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <Check className="w-5 h-5" />
                        )}
                      </Button>
                    ) : (
                      <Button
                        className="rounded-2xl h-10 px-4 text-sm font-bold shadow-md flex-shrink-0"
                        disabled={!!connecting}
                        onClick={() => handleConnect(d.id, d.name, d.rssi)}
                      >
                        {rowConnecting ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          "连接"
                        )}
                      </Button>
                    )}
                  </motion.div>
                );
              })}
            </div>
          )}

          <div className="w-full pt-4 mt-auto flex-shrink-0 space-y-2">
            {(uiPhase === "scanning" || uiPhase === "checking") && (
              <Button variant="outline" className="w-full rounded-2xl h-12" onClick={onClose}>
                取消
              </Button>
            )}

            {uiPhase === "unsupported" && (
              <Button variant="outline" className="w-full rounded-2xl h-12" onClick={onClose}>
                关闭
              </Button>
            )}

            {uiPhase === "disabled" && (
              <div className="flex flex-col gap-3">
                <div className="flex gap-3">
                  <Button variant="outline" className="flex-1 rounded-2xl h-12" onClick={onClose}>
                    取消
                  </Button>
                  <Button
                    className="flex-1 rounded-2xl h-12 text-base font-bold shadow-lg"
                    onClick={() => openBluetoothSettings().catch(() => {})}
                  >
                    去开启
                  </Button>
                </div>
                <Button
                  variant="outline"
                  className="w-full rounded-2xl h-12"
                  onClick={() => openAppSettings().catch(() => {})}
                >
                  应用设置
                </Button>
              </div>
            )}

            {uiPhase === "idle" && (
              <div className="flex flex-col gap-3">
                <Button
                  className="w-full rounded-2xl h-12 text-base font-bold shadow-lg"
                  onClick={handleRescan}
                  disabled={!!initError}
                >
                  重新搜索
                </Button>
                <Button variant="outline" className="w-full rounded-2xl h-12" onClick={onClose}>
                  关闭
                </Button>
              </div>
            )}
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  );
};

export default BluetoothSearchDrawer;
