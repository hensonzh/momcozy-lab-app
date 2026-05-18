import React, { createContext, useContext } from "react";
import type { Plan } from "@/data/planMockData";

/** Context：接口 plan/query 映射后的计划数据，供 Milestone/月历与今日条使用 */
export interface SchedulePlanContextValue {
  /** 非空时表示优先用服务端计划渲染 Milestone/月历 */
  serverPlans: Plan[] | null;
  setServerPlans: React.Dispatch<React.SetStateAction<Plan[] | null>>;
}

const SchedulePlanContext = createContext<SchedulePlanContextValue | null>(null);

/**
 * 读取呵护计划页的「服务端计划」上下文（须在 Provider 内使用）。
 * @returns serverPlans 与 setServerPlans
 */
export function useSchedulePlanContext(): SchedulePlanContextValue {
  const v = useContext(SchedulePlanContext);
  if (!v) {
    throw new Error("useSchedulePlanContext 须在 SchedulePlanProvider 内使用");
  }
  return v;
}

/**
 * 包裹计划页子树，向 Milestone / 月历注入服务端计划状态。
 * @param props.value 上下文值（由 Schedule 页组装）
 * @param props.children 子节点
 * @returns Provider
 */
export function SchedulePlanProvider({
  value,
  children,
}: {
  value: SchedulePlanContextValue;
  children: React.ReactNode;
}): React.ReactElement {
  return <SchedulePlanContext.Provider value={value}>{children}</SchedulePlanContext.Provider>;
}
