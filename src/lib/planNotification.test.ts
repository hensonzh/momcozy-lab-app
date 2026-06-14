import { beforeEach, describe, expect, it } from "vitest";
import {
  consumePlanPageNotification,
  markMilkPlanSyncedNotification,
  milkPlanNotificationConfig,
  milkPlanNotificationFromAgUiData,
  transferPlanNotificationToPage,
} from "./planNotification";

describe("plan notification state", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("extracts confirmed milk plan notification from tool result events", () => {
    const notification = milkPlanNotificationFromAgUiData({
      content: JSON.stringify({
        ok: true,
        tool_name: "milk_plan_mutate",
        card: {
          card_type: "milk_plan_card",
          card_json: {
            title: "追奶计划",
            status: "confirmed",
          },
        },
        data: {
          plan_id: 42,
          plan_type: "increase_milk",
          calendar_items: [
            { date: "2026-06-15", task_time: "08:00" },
            { date: "2026-06-15", task_time: "11:00" },
            { date: "2026-06-16", task_time: "08:00" },
          ],
        },
      }),
    });

    expect(notification).toEqual({
      kind: "milk_plan",
      target: "schedule",
      label: "追奶计划",
      planId: 42,
      planType: "increase_milk",
      dates: ["2026-06-15", "2026-06-16"],
    });
  });

  it("uses sanitized calendar dates from milk plan tool result events", () => {
    const notification = milkPlanNotificationFromAgUiData({
      ok: true,
      tool_name: "milk_plan_mutate",
      calendar_dates: ["2026-06-15", "2026-06-15", "2026-06-16"],
      card: {
        card_type: "milk_plan_card",
        card_json: {
          title: "追奶计划",
          status_label: "已确认",
        },
      },
    });

    expect(notification?.dates).toEqual(["2026-06-15", "2026-06-16"]);
  });

  it("moves milk plan notification from nav to schedule page payload", () => {
    markMilkPlanSyncedNotification({
      kind: "milk_plan",
      target: "schedule",
      label: "追奶计划",
      planId: 42,
      planType: "increase_milk",
      dates: ["2026-06-15"],
    });

    expect(localStorage.getItem("mmc_milk_plan_nav_pending")).toContain("追奶计划");
    expect(localStorage.getItem("mmc_milk_plan_schedule_pending")).toBeNull();

    transferPlanNotificationToPage(milkPlanNotificationConfig);

    expect(localStorage.getItem("mmc_milk_plan_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_milk_plan_schedule_pending")).toContain("追奶计划");

    const payload = consumePlanPageNotification(milkPlanNotificationConfig);
    expect(payload?.dates).toEqual(["2026-06-15"]);
    expect(localStorage.getItem("mmc_milk_plan_schedule_pending")).toBeNull();
  });
});
