/**
 * 重连已绑定设备：仅处理 store 中存在的设备；可选仅处理离线侧。
 * 不执行蓝牙扫描：先 initializeBle，再对已绑定 deviceId 直连；连接成功后发 F0/E1 更新 store。
 */

import { deviceStore, type DeviceSide } from "@/lib/deviceStore";
import {
  initializeBle,
  connect,
  resetBleProtocolStateForDevice,
  configurePumpAfterBleConnect,
  startLEScan,
  stopLEScan,
} from "@/lib/ble";
import { reportDeviceInfoAfterProtocolConfigured } from "@/lib/deviceInfoReport";

/**
 * 已绑定设备处于离线（未 BLE 连接）时，周期性发起直连重连的间隔（毫秒）。
 * 修改此常量即可调整全局重试节奏，无需改业务代码。
 */
export const OFFLINE_RECONNECT_INTERVAL_MS = 20_000;

/**
 * 判断是否存在「已配对但未连接」的侧，用于决定是否保持后台重连定时器。
 * @returns 任一侧有绑定且 connected === false 时为 true
 */
export function hasOfflineBoundDevices(): boolean {
  const { L, R } = deviceStore.get();
  return (L != null && !L.connected) || (R != null && !R.connected);
}

export interface TryReconnectOptions {
  /** 为 true 时只重连 store 里 connected === false 的侧；为 false 时尝试所有已存储的侧（如应用启动时） */
  onlyOffline?: boolean;
}

/**
 * 对已绑定且（在 onlyOffline 为 true 时）离线的设备尝试直连重连（不扫描）。
 * 功能：初始化 BLE → 重置该侧协议状态 → connect → 与首次连接相同：configurePumpAfterBleConnect（F0 → F2+E1）。
 * @param options.onlyOffline 是否仅处理离线侧，默认 true
 * @returns Promise<void> 无返回值；单侧失败时静默继续下一侧
 */
// 标志：是否正在进行用户操作
let isUserOperationInProgress = false;
// 上次重连时间
let lastReconnectTime = 0;
// 重连间隔（毫秒）
const RECONNECT_INTERVAL = 10000; // 10秒

/**
 * 设置用户操作状态
 * @param inProgress 是否正在进行用户操作
 */
export function setUserOperationInProgress(inProgress: boolean): void {
  isUserOperationInProgress = inProgress;
  console.log(`[重连] 用户操作状态更新为: ${inProgress ? '进行中' : '空闲'}`);
}

export function tryReconnectOfflineDevices(
  options: TryReconnectOptions = {}
): void {
  // 如果正在进行用户操作，跳过重连
  if (isUserOperationInProgress) {
    console.log(`[重连] 正在进行用户操作，跳过重连`);
    return;
  }

  // 检查重连间隔，避免过于频繁的重连尝试
  const now = Date.now();
  if (now - lastReconnectTime < RECONNECT_INTERVAL) {
    console.log(`[重连] 重连间隔未到，跳过重连`);
    return;
  }

  const { onlyOffline = true } = options;
  const store = deviceStore.get();
  const offlineDevices: Array<{ side: DeviceSide; deviceId: string }> = [];
  if (store.L && (!onlyOffline || !store.L.connected)) {
    offlineDevices.push({ side: "L", deviceId: store.L.deviceId });
  }
  if (store.R && (!onlyOffline || !store.R.connected)) {
    offlineDevices.push({ side: "R", deviceId: store.R.deviceId });
  }
  if (offlineDevices.length === 0) return;

  // 更新上次重连时间
  lastReconnectTime = now;
  console.log(`[重连] 开始扫描并尝试重连离线设备: ${offlineDevices.map(d => d.side).join(', ')}`);

  // 与扫描抽屉一致：直连前须先初始化 BLE（权限/适配器就绪）
  setTimeout(() => {
    (async () => {
      // 再次检查用户操作状态
      if (isUserOperationInProgress) {
        console.log(`[重连] 正在进行用户操作，跳过重连`);
        return;
      }

      try {
        await initializeBle({});
      } catch {
        return;
      }

      // 存储已找到的设备
      const foundDevices = new Set<string>();
      // 存储连接任务
      const connectTasks: Promise<void>[] = [];

      // 开始扫描
      console.log(`[重连] 开始扫描 BLE 设备`);
      await startLEScan((result) => {
        // 检查是否正在进行用户操作
        if (isUserOperationInProgress) {
          console.log(`[重连] 正在进行用户操作，停止扫描`);
          stopLEScan();
          return;
        }

        // 检查是否是已绑定的离线设备
        const device = offlineDevices.find(d => d.deviceId === result.device?.deviceId);
        if (device && !foundDevices.has(device.deviceId)) {
          console.log(`[重连] 扫描到设备: ${device.deviceId} (${device.side})`);
          foundDevices.add(device.deviceId);

          // 执行连接操作
          const connectTask = (async () => {
            const onDisconnect = () => {
              resetBleProtocolStateForDevice(device.deviceId);
              deviceStore.setConnected(device.side, false);
            };

            try {
              // 与首次连接一致：新 GATT 会话前丢弃旧 Notify/REQ 状态，确保重新 enable notify 并完成 F0/F2/E1
              resetBleProtocolStateForDevice(device.deviceId);
              await connect(device.deviceId, onDisconnect);
              deviceStore.setConnected(device.side, true);
              reportDeviceInfoAfterProtocolConfigured();
              try {
                await configurePumpAfterBleConnect(device.deviceId, device.side);
              } catch {
                // 协议配置失败时连接可能仍存活，由后续重试或用户操作处理
              }
            } catch (e) {
              console.log(`[重连] 连接设备 ${device.deviceId} 失败:`, e);
            }
          })();

          connectTasks.push(connectTask);

          // 当所有离线设备都被找到后，停止扫描
          if (foundDevices.size === offlineDevices.length) {
            console.log(`[重连] 所有离线设备都已找到，停止扫描`);
            stopLEScan();
          }
        }
      });

      // 扫描超时设置
      setTimeout(() => {
        if (!isUserOperationInProgress) {
          stopLEScan();
          console.log(`[重连] 扫描超时，停止扫描`);
        }
      }, 5000); // 5秒扫描超时

      // 等待所有连接任务完成
      if (connectTasks.length > 0) {
        await Promise.all(connectTasks);
      }
    })();
  }, 0);
}
