/**
 * 妈妈乳房健康、泌乳汇总与背奶记录相关 HTTP 封装（原仅妈妈孪生页使用）。
 * 路径与 `agentApi.ts` 中原 API_PATHS 常量一致，供状态页或其它模块后续接入。
 */

import { apiRequest } from "./http";
import type {
  MomBabyInfoData,
  MomBabyTodayData,
  PumpInfoData,
  PumpMilkDeleteBody,
  PumpMilkDeleteData,
  PumpMilkQueryData,
  PumpMilkQueryParams,
  PumpMilkUploadBody,
  PumpMilkUploadData,
} from "./agentApiTypes";
import { notifyMilkRecordsChanged } from "./milkRecordsEvents";

const V1 = "/v1" as const;
const PATHS = {
  MOM_BABY_INFO_QUERY: `${V1}/mom-baby/info/query`,
  MOM_BABY_TODAY_QUERY: `${V1}/mom-baby/today/query`,
  PUMP_INFO_GET: `${V1}/pump/info/get`,
  PUMP_MILK_UPLOAD: `${V1}/pump-milk/upload`,
  PUMP_MILK_DELETE: `${V1}/pump-milk/delete`,
  PUMP_MILK_QUERY: `${V1}/pump-milk/query`,
} as const;

export async function queryMomBabyInfo(
  user_id: string,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<MomBabyInfoData> {
  return apiRequest<MomBabyInfoData>(PATHS.MOM_BABY_INFO_QUERY, {
    method: "GET",
    params: { user_id },
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function queryMomBabyToday(
  user_id: string,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal; timestamp?: string },
): Promise<MomBabyTodayData> {
  return apiRequest<MomBabyTodayData>(PATHS.MOM_BABY_TODAY_QUERY, {
    method: "GET",
    params: { user_id, ...(opts?.timestamp ? { timestamp: opts.timestamp } : {}) },
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function uploadPumpHealth(
  _body: Record<string, never>,
  _opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<Record<string, never>> {
  return Promise.reject(new Error("uploadPumpHealth: /v1/pump/health/upload is not available in API V1.3"));
}

export async function getPumpHealth(
  _user_id: string,
  _opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<Record<string, never>> {
  return Promise.reject(new Error("getPumpHealth: /v1/pump/health/get is not available in API V1.3"));
}

export async function getPumpInfo(
  user_id: string,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpInfoData> {
  return apiRequest<PumpInfoData>(PATHS.PUMP_INFO_GET, {
    method: "GET",
    params: { user_id },
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function uploadPumpMilkRecord(
  body: PumpMilkUploadBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpMilkUploadData> {
  const response = await apiRequest<PumpMilkUploadData>(PATHS.PUMP_MILK_UPLOAD, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
  if (response.error === 0) {
    notifyMilkRecordsChanged({ user_id: body.user_id });
  }
  return response;
}

export async function deletePumpMilkRecord(
  body: PumpMilkDeleteBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpMilkDeleteData> {
  const response = await apiRequest<PumpMilkDeleteData>(PATHS.PUMP_MILK_DELETE, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
  if (response.error === 0) {
    notifyMilkRecordsChanged({ user_id: body.user_id });
  }
  return response;
}

export async function queryPumpMilkRecords(
  params: PumpMilkQueryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<PumpMilkQueryData> {
  return apiRequest<PumpMilkQueryData>(PATHS.PUMP_MILK_QUERY, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}
