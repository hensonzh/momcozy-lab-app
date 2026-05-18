/**
 * 在 BLE 协议配置完成或物理断连后，将左右侧设备概览 POST 到 {@link API_PATHS.DEVICE_INFO}。
 */
import { API_PATHS, uploadDeviceInfo } from "./agentApi";
import type { DeviceConnectionSide, DeviceInfoBody } from "./agentApiTypes";
import type { StoredDeviceInfo } from "./deviceStore";
import { deviceStore } from "./deviceStore";
import { createScopedConsole } from "./logger";

const console = createScopedConsole("deviceInfoReport");
const DEFAULT_USER_ID =
  (import.meta.env.VITE_DEFAULT_USER_ID as string | undefined) || "app-user";

function storedToConnectionSide(
  stored: StoredDeviceInfo | null
): DeviceConnectionSide {
  if (!stored) {
    return {
      model: "",
      state: "offline",
      battery: 0,
      sn: "",
      rssi: 0,
      version: "",
    };
  }
  return {
    model: stored.model || "",
    state: stored.connected ? "online" : "offline",
    battery: Number.isFinite(stored.battery) ? stored.battery : 0,
    sn: stored.serialNumber || "",
    rssi: 0,
    version: stored.firmware || "",
  };
}

/**
 * 根据当前 deviceStore 构造 POST /v1/device/info 的 body（与联调类型 {@link DeviceInfoBody} 一致）。
 */
export function buildDeviceInfoBodyFromStore(
  userId: string = DEFAULT_USER_ID
): DeviceInfoBody {
  const { L, R } = deviceStore.get();
  return {
    user_id: userId,
    device_left: storedToConnectionSide(L),
    device_right: storedToConnectionSide(R),
  };
}

export type DeviceInfoReportPhase =
  | "ble_connected"
  | "protocol_f0_e1_ready"
  | "d6_battery";

/**
 * 将当前 store 中左右侧状态 POST 到 `/v1/device/info`（fire-and-forget）。
 * @param phase 日志用阶段标签：仅 BLE 已连、或 F0/E1/Notify 后、或 D6 电量上报后
 */
export function reportDeviceInfoAfterProtocolConfigured(phase: DeviceInfoReportPhase = "ble_connected"): void {
  const phaseLabel =
    phase === "protocol_f0_e1_ready"
      ? "F0/E1/Notify 后（含固件与电量）"
      : phase === "d6_battery"
        ? "D6 电池上报后（已刷新 store 电量）"
        : "连接建立后（协议未就绪或待刷新）";
  const body = buildDeviceInfoBodyFromStore();
  console.log(`[设备信息上报] 请求开始（${phaseLabel}）`, {
    path: API_PATHS.DEVICE_INFO,
    method: "POST",
    phase,
    body,
  });
  void uploadDeviceInfo(body)
    .then((resp) => {
      console.log(`[设备信息上报] 响应成功（${phaseLabel}）`, {
        path: API_PATHS.DEVICE_INFO,
        user_id: body.user_id,
        phase,
        response: resp,
      });
    })
    .catch((e) => {
      console.warn(`[设备信息上报] 响应失败（${phaseLabel}）`, {
        path: API_PATHS.DEVICE_INFO,
        user_id: body.user_id,
        phase,
        body,
        error: e,
      });
    });
}

/**
 * 物理断连后：先由调用方在 onDisconnect 内更新 store，再调用本方法上传当前两侧状态。
 */
export function reportDeviceInfoAfterPhysicalDisconnect(): void {
  const body = buildDeviceInfoBodyFromStore();
  console.log("[设备信息上报] 请求开始（物理断连）", {
    path: API_PATHS.DEVICE_INFO,
    method: "POST",
    body,
  });
  void uploadDeviceInfo(body)
    .then((resp) => {
      console.log("[设备信息上报] 响应成功（物理断连）", {
        path: API_PATHS.DEVICE_INFO,
        user_id: body.user_id,
        response: resp,
      });
    })
    .catch((e) => {
      console.warn("[设备信息上报] 响应失败（物理断连）", {
        path: API_PATHS.DEVICE_INFO,
        user_id: body.user_id,
        body,
        error: e,
      });
    });
}
