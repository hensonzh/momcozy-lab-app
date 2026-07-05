/**
 * 宝宝信息、喂养与生长发育相关 HTTP 封装（原 AgentHub 主包内 agentApi 子集）。
 * 独立为模块，供日后「状态」等页接入真实宝宝数据时复用；路径与 `agentApi.ts` 中原 API_PATHS 常量一致。
 */

import { apiRequest } from "./http";
import type {
  BabyInfoCreateBody,
  BabyInfoCreateData,
  BabyInfoQueryData,
  FeedingAddBody,
  FeedingAddData,
  FeedingDeleteBody,
  FeedingDeleteData,
  FeedingQueryData,
  FeedingQueryParams,
  GrowthAddBody,
  GrowthAddData,
  GrowthHistoryData,
  GrowthHistoryParams,
  GrowthQueryData,
  GrowthQueryParams,
  GrowthReviseBody,
  GrowthReviseData,
} from "./agentApiTypes";

const V1 = "/v1" as const;
const PATHS = {
  FEEDING_ADD: `${V1}/feeding/add`,
  FEEDING_DELETE: `${V1}/feeding/delete`,
  FEEDING_QUERY: `${V1}/feeding/query`,
  GROWTH_ADD: `${V1}/growth/add`,
  GROWTH_QUERY: `${V1}/growth/query`,
  GROWTH_REVISE: `${V1}/growth/revise`,
  GROWTH_HISTORY: `${V1}/growth/history`,
} as const;

export async function createBabyInfo(
  _body: BabyInfoCreateBody,
  _opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<BabyInfoCreateData> {
  return Promise.reject(new Error("createBabyInfo: /v1/baby-info/create is not available in API V1.3"));
}

export async function queryBabyInfo(
  _params: { user_id: string; infant_id?: number },
  _opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<BabyInfoQueryData> {
  return Promise.reject(new Error("queryBabyInfo: /v1/baby-info/query is not available in API V1.3"));
}

export async function addFeedingRecord(
  body: FeedingAddBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<FeedingAddData> {
  return apiRequest<FeedingAddData>(PATHS.FEEDING_ADD, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function deleteFeedingRecord(
  body: FeedingDeleteBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<FeedingDeleteData> {
  return apiRequest<FeedingDeleteData>(PATHS.FEEDING_DELETE, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function queryFeedingRecords(
  params: FeedingQueryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<FeedingQueryData> {
  return apiRequest<FeedingQueryData>(PATHS.FEEDING_QUERY, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function addGrowthRecord(
  body: GrowthAddBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<GrowthAddData> {
  return apiRequest<GrowthAddData>(PATHS.GROWTH_ADD, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function queryLatestGrowth(
  params: GrowthQueryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<GrowthQueryData> {
  return apiRequest<GrowthQueryData>(PATHS.GROWTH_QUERY, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function reviseGrowthRecord(
  body: GrowthReviseBody,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<GrowthReviseData> {
  return apiRequest<GrowthReviseData>(PATHS.GROWTH_REVISE, {
    method: "POST",
    body,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}

export async function getGrowthHistory(
  params: GrowthHistoryParams,
  opts?: { token?: string; skipAuth?: boolean; signal?: AbortSignal },
): Promise<GrowthHistoryData> {
  return apiRequest<GrowthHistoryData>(PATHS.GROWTH_HISTORY, {
    method: "GET",
    params,
    token: opts?.token,
    skipAuth: opts?.skipAuth,
    signal: opts?.signal,
  });
}
