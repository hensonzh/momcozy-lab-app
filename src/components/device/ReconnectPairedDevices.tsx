import React, { useEffect, useRef } from "react";
import { isBleSupported } from "@/lib/ble";
import { deviceStore } from "@/lib/deviceStore";
import {
  tryReconnectOfflineDevices,
  OFFLINE_RECONNECT_INTERVAL_MS,
  hasOfflineBoundDevices,
} from "@/lib/reconnectOfflineDevices";

/**
 * 宏开关：是否执行「离线设备定时扫描重连」（setInterval 周期调用 tryReconnectOfflineDevices）。
 * 设为 false 时关闭定时扫描，仅保留应用启动后约 500ms 的单次重连尝试。
 */
const ENABLE_SCHEDULED_BLE_RECONNECT_SCAN = true;

/**
 * 应用启动后：若本地已有绑定设备（持久化 store），则对离线侧尝试一次直连重连；
 * 在 ENABLE_SCHEDULED_BLE_RECONNECT_SCAN 为 true 且仍有离线绑定侧时，按 OFFLINE_RECONNECT_INTERVAL_MS 周期重复尝试直至连上或侧被解除绑定。
 */
export default function ReconnectPairedDevices() {
  const didRun = useRef(false);

  useEffect(() => {
    if (didRun.current) return;
    if (!isBleSupported()) return;

    didRun.current = true;

    (async () => {
      await new Promise((r) => setTimeout(r, 500));
      await tryReconnectOfflineDevices({ onlyOffline: true });
    })();
  }, []);

  // 设备离线期间：定时直连重连（间隔见 OFFLINE_RECONNECT_INTERVAL_MS）；由 ENABLE_SCHEDULED_BLE_RECONNECT_SCAN 控制是否启用
  useEffect(() => {
    if (!ENABLE_SCHEDULED_BLE_RECONNECT_SCAN) return;
    if (!isBleSupported()) return;

    let intervalId: ReturnType<typeof setInterval> | null = null;

    const syncInterval = () => {
      if (!hasOfflineBoundDevices()) {
        if (intervalId != null) {
          clearInterval(intervalId);
          intervalId = null;
        }
        return;
      }
      if (intervalId != null) return;
      intervalId = setInterval(() => {
        void tryReconnectOfflineDevices({ onlyOffline: true });
      }, OFFLINE_RECONNECT_INTERVAL_MS);
    };

    syncInterval();
    const unsub = deviceStore.subscribe(syncInterval);
    return () => {
      unsub();
      if (intervalId != null) {
        clearInterval(intervalId);
        intervalId = null;
      }
    };
  }, []);

  return null;
}
