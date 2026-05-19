import React, { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bluetooth,
  BatteryMedium,
  Signal,
  Camera,
  ChevronRight,
  Info,
  Sparkles,
  Plus,
} from "lucide-react";
import { motion } from "framer-motion";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";
import DeviceInfoSheet from "@/components/device/DeviceInfoSheet";
import BluetoothSearchDrawer from "@/components/device/BluetoothSearchDrawer";
import DeviceControlPanel from "@/components/device/DeviceControlPanel";
import DeviceDebugDrawer from "@/components/device/DeviceDebugDrawer";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";
import {
  isBleSupported,
  configurePumpAfterBleConnect,
  resetBleProtocolStateForDevice,
  disconnect as bleDisconnect,
} from "@/lib/ble";
import { reportDeviceInfoAfterProtocolConfigured } from "@/lib/deviceInfoReport";
import { tryReconnectOfflineDevices } from "@/lib/reconnectOfflineDevices";
import { cn } from "@/lib/utils";
import { devices as deviceData } from "@/data/mockData";
import type { DeviceInfo } from "@/data/mockData";
import pairedPumpImg from "@/assets/M9.png";

function storedToDeviceInfo(stored: StoredDeviceInfo, side: "L" | "R"): DeviceInfo {
  return {
    id: stored.deviceId,
    side,
    connected: stored.connected,
    battery: stored.battery,
    flangeSize: stored.flangeSize,
    sealSize: stored.sealSize,
    model: stored.model,
    firmware: stored.firmware,
    serialNumber: stored.serialNumber,
  };
}
/* ── Device Card（与 mai-moms-magic 一致的布局，数据仍用 DeviceInfo） ── */
const DeviceCard: React.FC<{
  side: "L" | "R";
  device: DeviceInfo | null;
  onOpenInfo: () => void;
  onCardClick: () => void;
}> = ({ side, device, onOpenInfo, onCardClick }) => {
  const paired = device !== null;
  const isConnected = Boolean(device?.connected);

  const connectButton = (
    <button
      type="button"
      onClick={(e) => {
        e.stopPropagation();
        onCardClick();
      }}
      className="w-full h-12 rounded-full bg-white text-foreground shadow-sm hover:shadow-md hover:scale-[1.02] transition-all border border-border/50 text-[14px] font-bold flex items-center justify-center gap-2"
    >
      <Bluetooth className="w-4 h-4" />
      连接设备
    </button>
  );

  return (
    <div
      onClick={!isConnected ? onCardClick : undefined}
      className={cn(
        "flex-1 relative rounded-[20px] p-2.5 transition-all duration-500 overflow-hidden min-h-[180px] flex flex-col items-center justify-between",
        isConnected
          ? "bg-card shadow-sm border border-primary/10"
          : "bg-[#F7F7F8] border border-transparent"
      )}
    >
      <div className="w-full flex items-start justify-between relative z-10 mt-1 px-0.5">
        <p className="text-[14px] font-bold text-foreground/80 uppercase tracking-widest">
          {side === "L" ? "Left" : "Right"}
        </p>
        {paired ? (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              onOpenInfo();
            }}
            className="w-7 h-7 rounded-full bg-background/80 flex items-center justify-center text-muted-foreground hover:text-primary border border-border/40 shadow-sm"
            title="设备详情"
          >
            <Info className="w-3.5 h-3.5" />
          </button>
        ) : null}
      </div>

      <div
        className="flex-1 w-full flex items-center justify-center py-2 relative z-10"
        onClick={isConnected ? onCardClick : undefined}
        style={{ cursor: isConnected ? "pointer" : "default" }}
      >
        <div className="relative w-20 h-20 flex items-center justify-center">
          <div
            className={cn(
              "absolute inset-0 rounded-full transition-all duration-700",
              isConnected ? "bg-primary/5" : "bg-background shadow-sm border border-border/40"
            )}
          />
          <div className="text-center relative z-10">
            {paired ? (
              <img
                src={pairedPumpImg}
                alt=""
                className="w-[72px] h-[72px] object-contain select-none pointer-events-none"
                draggable={false}
              />
            ) : (
              <div className="flex items-center justify-center opacity-40">
                <Camera className="w-6 h-6 text-foreground" />
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="w-full relative z-10">
        {!paired ? (
          connectButton
        ) : isConnected ? (
          <div
            onClick={onCardClick}
            className="w-full bg-background rounded-[20px] p-3 shadow-sm border border-border/50 cursor-pointer hover:bg-secondary/40 transition-colors"
          >
            <div className="flex items-center justify-between mb-2 px-1">
              <div className="flex items-center gap-1.5">
                <div className="w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.6)] ml-1" />
                <span className="text-[12px] font-bold text-foreground">已连接</span>
              </div>
            </div>
            <div className="flex items-center justify-between px-1">
              <div className="flex items-center gap-1">
                <BatteryMedium
                  className={cn(
                    "w-3.5 h-3.5",
                    device && device.battery > 20 ? "text-foreground" : "text-destructive"
                  )}
                />
                <span className="text-[10px] font-bold text-foreground">{device?.battery ?? 0}%</span>
              </div>
              <div className="flex items-center gap-1">
                <Signal className="w-3 h-3 text-muted-foreground" />
                <span className="text-[10px] font-bold text-muted-foreground">强</span>
              </div>
            </div>
          </div>
        ) : (
          <div
            onClick={onCardClick}
            className="w-full bg-background rounded-[20px] p-3 shadow-sm border border-border/50 cursor-pointer hover:bg-secondary/40 transition-colors"
          >
            <div className="flex items-center gap-1.5 px-1">
              <div className="w-2 h-2 rounded-full bg-muted-foreground/45 ml-1 shrink-0" />
              <span className="text-[12px] font-bold text-muted-foreground">未连接</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

/* ── Main Page ── */
const DeviceManagement: React.FC = () => {
  const navigate = useNavigate();
  const [deviceInfoOpen, setDeviceInfoOpen] = useState(false);
  const [activeDevice, setActiveDevice] = useState<DeviceInfo | null>(null);
  const [btDrawerOpen, setBtDrawerOpen] = useState(false);
  const [btDrawerSide, setBtDrawerSide] = useState<"L" | "R">("L");
  const [controlPanelOpen, setControlPanelOpen] = useState(false);
  const [controlPanelSide, setControlPanelSide] = useState<"L" | "R">("L");
  const [debugDrawerOpen, setDebugDrawerOpen] = useState(false);
  const [debugDrawerSide, setDebugDrawerSide] = useState<"L" | "R">("L");
  const [quickMenuOpen, setQuickMenuOpen] = useState(false);
  const quickMenuRef = useRef<HTMLDivElement | null>(null);
  /** BLE 连接后的设备信息，按侧别存储，用于在主机卡片显示；挂载与 store 变更时从 deviceStore 同步（含设备离线） */
  const [connectedDevices, setConnectedDevices] = useState<Record<"L" | "R", DeviceInfo | null>>(() => {
    const s = deviceStore.get();
    return {
      L: s.L ? storedToDeviceInfo(s.L, "L") : null,
      R: s.R ? storedToDeviceInfo(s.R, "R") : null,
    };
  });

  React.useEffect(() => {
    const syncFromStore = () => {
      const s = deviceStore.get();
      setConnectedDevices({
        L: s.L ? storedToDeviceInfo(s.L, "L") : null,
        R: s.R ? storedToDeviceInfo(s.R, "R") : null,
      });
    };
    return deviceStore.subscribe(syncFromStore);
  }, []);

  /** 进入「智能设备」页时：有绑定且离线则直连重连（不扫描） */
  React.useEffect(() => {
    if (!isBleSupported()) return;
    tryReconnectOfflineDevices({ onlyOffline: true });
  }, []);

  /** 打开设备信息 Sheet 时：再次执行与启动时相同的绑定设备直连逻辑 */
  React.useEffect(() => {
    if (!deviceInfoOpen) return;
    if (!isBleSupported()) return;
    tryReconnectOfflineDevices({ onlyOffline: true });
  }, [deviceInfoOpen]);

  /** 优先使用已绑定设备（含 BLE 离线，卡片显示「离线」+ 置灰）；无绑定时再回退 mock，便于未接真机演示 */
  const leftDevice = connectedDevices.L ?? deviceData.find((d) => d.side === "L") ?? null;
  const rightDevice = connectedDevices.R ?? deviceData.find((d) => d.side === "R") ?? null;

  const openDeviceInfo = (device: DeviceInfo) => {
    setActiveDevice(device);
    setDeviceInfoOpen(true);
  };

  const openBtDrawer = (side: "L" | "R") => {
    setBtDrawerSide(side);
    setBtDrawerOpen(true);
  };

  const handleDeviceCardActivate = (side: "L" | "R") => {
    const device = side === "L" ? leftDevice : rightDevice;
    if (device?.connected) {
      setControlPanelSide(side);
      setControlPanelOpen(true);
    } else {
      openBtDrawer(side);
    }
  };

  const openDebugDrawer = (side: "L" | "R") => {
    setDebugDrawerSide(side);
    setDebugDrawerOpen(true);
  };

  const handleManualDisconnect = async (side: "L" | "R") => {
    const current = deviceStore.get()[side];
    if (!current?.deviceId) return;
    try {
      await bleDisconnect(current.deviceId);
    } catch {
      // 即使物理断开报错，也继续执行本地离线标记，避免 UI 卡在已连接
    }
    resetBleProtocolStateForDevice(current.deviceId);
    deviceStore.setConnected(side, false);
    setConnectedDevices((prev) => {
      const next = prev[side];
      if (!next) return prev;
      return {
        ...prev,
        [side]: { ...next, connected: false },
      };
    });
  };

  const handleOpenDebugFromInfo = (device: DeviceInfo) => {
    setDeviceInfoOpen(false);
    openDebugDrawer(device.side);
  };

  useEffect(() => {
    if (!quickMenuOpen) return;
    const onPointerDown = (event: MouseEvent | TouchEvent) => {
      if (!quickMenuRef.current) return;
      const target = event.target as Node | null;
      if (target && !quickMenuRef.current.contains(target)) {
        setQuickMenuOpen(false);
      }
    };
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("touchstart", onPointerDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("touchstart", onPointerDown);
    };
  }, [quickMenuOpen]);

  return (
    <>
      <div className="flex flex-col min-h-0 bg-background w-full" style={{ height: "100vh", maxHeight: "100vh" }}>
        <TabPageTopReserve />
      <div className="flex-shrink-0 px-4 pt-5 pb-2 flex items-center justify-between">
        <h1 className="text-lg font-bold text-foreground flex items-center gap-2">设备连接</h1>
        <div className="relative" ref={quickMenuRef}>
          <button
            type="button"
            onClick={() => setQuickMenuOpen((prev) => !prev)}
            className="w-10 h-10 rounded-full border border-border/50 bg-card text-foreground flex items-center justify-center shadow-sm active:scale-95 transition-transform"
            aria-label="打开设备快捷菜单"
          >
            <Plus className="w-5 h-5" />
          </button>
          {quickMenuOpen ? (
            <div className="absolute right-0 mt-2 w-32 rounded-xl bg-foreground/80 text-background backdrop-blur-sm shadow-xl overflow-hidden z-30">
              <span className="absolute right-4 -top-1.5 w-2.5 h-2.5 rotate-45 bg-foreground/80" aria-hidden="true" />
              <button
                type="button"
                onClick={() => {
                  setQuickMenuOpen(false);
                }}
                className="w-full text-center px-2 py-3 text-[15px] font-semibold hover:bg-background/10 transition-colors"
              >
                添加设备
              </button>
              <div className="mx-3 h-px bg-background/25" />
              <button
                type="button"
                onClick={() => {
                  setQuickMenuOpen(false);
                  navigate("/device/user");
                }}
                className="w-full text-center px-2 py-3 text-[15px] font-semibold hover:bg-background/10 transition-colors"
              >
                用户管理
              </button>
              <div className="mx-3 h-px bg-background/25" />
              <button
                type="button"
                onClick={() => {
                  setQuickMenuOpen(false);
                  navigate("/device/manage");
                }}
                className="w-full text-center px-2 py-3 text-[15px] font-semibold hover:bg-background/10 transition-colors"
              >
                设备提醒
              </button>
            </div>
          ) : null}
        </div>
      </div>

      <TabPageScrollRegion>
      <div className="px-4 space-y-4">
        {/* W1 Promo Banner */}
        <motion.button
          onClick={() => navigate("/w1")}
          whileTap={{ scale: 0.98 }}
          className="w-full rounded-2xl overflow-hidden border border-primary/20 shadow-md"
          style={{
            background: `linear-gradient(135deg, hsl(340 35% 25%) 0%, hsl(345 40% 32%) 60%, hsl(350 35% 28%) 100%)`,
          }}
        >
          <div className="px-4 py-3 flex items-center gap-3">
            <div className="w-9 h-9 rounded-full bg-primary-foreground/10 flex items-center justify-center flex-shrink-0">
              <Sparkles className="w-4 h-4 text-primary-foreground/80" />
            </div>
            <div className="flex-1 text-left min-w-0">
              <p className="text-xs font-bold text-primary-foreground tracking-wide">
                Momcozy W1 · 全新上市
              </p>
            </div>
            <ChevronRight className="w-4 h-4 text-primary-foreground/40 flex-shrink-0" />
          </div>
        </motion.button>
        <section className="space-y-2">
          <div className="bg-card rounded-[24px] p-3 shadow-sm border border-primary/10 relative overflow-hidden">
            <div className="text-left mb-3 mt-1 ml-1 relative z-10">
              <h3 className="text-[16px] font-black text-foreground tracking-tight">Air One</h3>
            </div>
            <div className="flex gap-2 relative z-10">
              <DeviceCard
                side="L"
                device={leftDevice}
                onOpenInfo={() => leftDevice && openDeviceInfo(leftDevice)}
                onCardClick={() => handleDeviceCardActivate("L")}
              />
              <DeviceCard
                side="R"
                device={rightDevice}
                onOpenInfo={() => rightDevice && openDeviceInfo(rightDevice)}
                onCardClick={() => handleDeviceCardActivate("R")}
              />
            </div>
          </div>
        </section>
      </div>
      </TabPageScrollRegion>
      <TabPageEmbeddedNav />
      </div>

      {/* Device Info Sheet */}
      <DeviceInfoSheet
        device={activeDevice}
        open={deviceInfoOpen}
        onClose={() => setDeviceInfoOpen(false)}
        onOpenDebug={handleOpenDebugFromInfo}
      />

      {/* Bluetooth Search Drawer */}
      <BluetoothSearchDrawer
        open={btDrawerOpen}
        side={btDrawerSide}
        currentDeviceId={btDrawerSide === "L" ? leftDevice?.id : rightDevice?.id}
        onClose={() => setBtDrawerOpen(false)}
        onConnect={(deviceId, deviceName, rssi) => {
          const side = btDrawerSide;
          const fullInfo: StoredDeviceInfo = {
            deviceId,
            deviceName,
            connected: true,
            battery: 0,
            rssi,
            flangeSize: 24,
            sealSize: "M",
            model: deviceName,
            firmware: "-",
            serialNumber: deviceId,
          };
          deviceStore.setDevice(side, fullInfo);
          reportDeviceInfoAfterProtocolConfigured();
          setConnectedDevices((prev) => ({
            ...prev,
            [side]: storedToDeviceInfo(fullInfo, side),
          }));
          configurePumpAfterBleConnect(deviceId, side)
            .then(() => {
              const store = deviceStore.get();
              const next = side === "L" ? store.L : store.R;
              if (next) {
                setConnectedDevices((prev) => ({
                  ...prev,
                  [side]: storedToDeviceInfo(next, side),
                }));
              }
            })
            .catch(() => {});
        }}
        onDisconnect={(deviceId) => {
          resetBleProtocolStateForDevice(deviceId);
          const store = deviceStore.get();
          if (store.L?.deviceId === deviceId) deviceStore.setConnected("L", false);
          if (store.R?.deviceId === deviceId) deviceStore.setConnected("R", false);
          setConnectedDevices((prev) => {
            const next = { ...prev };
            if (prev.L?.id === deviceId && next.L) next.L = { ...next.L, connected: false };
            if (prev.R?.id === deviceId && next.R) next.R = { ...next.R, connected: false };
            return next;
          });
        }}
      />

      <DeviceControlPanel
        side={controlPanelSide}
        open={controlPanelOpen}
        onClose={() => setControlPanelOpen(false)}
        onDisconnect={handleManualDisconnect}
      />

      {((debugDrawerSide === "L" ? leftDevice : rightDevice)) ? (
        <DeviceDebugDrawer
          open={debugDrawerOpen}
          side={debugDrawerSide}
          device={(debugDrawerSide === "L" ? leftDevice : rightDevice)!}
          onClose={() => setDebugDrawerOpen(false)}
        />
      ) : null}
    </>
  );
};

export default DeviceManagement;
