import { describe, expect, it, beforeEach } from "vitest";
import {
  BIRTH_JOURNEY_PLAN_DELETED_EVENT,
  clearBirthJourneyPlanCardNotification,
  clearBirthJourneyPlanGeneratedNotification,
  markBirthJourneyPlanGeneratedNotification,
  notifyBirthJourneyPlanDeleted,
  richTextPayloadHasBirthJourneyPlanCard,
  subscribeBirthJourneyPlanDeleted,
  transferBirthJourneyPlanNotificationToStatusCard,
} from "./birthJourneyPlanNotification";

describe("birth journey plan notification state", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("moves generated plan notice from status nav to status card", () => {
    markBirthJourneyPlanGeneratedNotification();

    expect(localStorage.getItem("mmc_birth_journey_plan_nav_pending")).toBe("1");
    expect(localStorage.getItem("mmc_birth_journey_plan_card_pending")).toBeNull();

    transferBirthJourneyPlanNotificationToStatusCard();

    expect(localStorage.getItem("mmc_birth_journey_plan_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_birth_journey_plan_card_pending")).toBe("1");

    clearBirthJourneyPlanCardNotification();

    expect(localStorage.getItem("mmc_birth_journey_plan_card_pending")).toBeNull();
  });

  it("clears both nav and card generated notices without emitting a deleted event", () => {
    const events: string[] = [];
    const unsubscribe = subscribeBirthJourneyPlanDeleted(() => {
      events.push("deleted");
    });

    markBirthJourneyPlanGeneratedNotification();
    transferBirthJourneyPlanNotificationToStatusCard();
    clearBirthJourneyPlanGeneratedNotification();
    unsubscribe();

    expect(localStorage.getItem("mmc_birth_journey_plan_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_birth_journey_plan_card_pending")).toBeNull();
    expect(events).toEqual([]);
  });

  it("clears generated plan notices and emits a deleted event", () => {
    const events: string[] = [];
    const unsubscribe = subscribeBirthJourneyPlanDeleted(() => {
      events.push("deleted");
    });
    window.addEventListener(BIRTH_JOURNEY_PLAN_DELETED_EVENT, () => {
      events.push("window");
    }, { once: true });

    markBirthJourneyPlanGeneratedNotification();
    transferBirthJourneyPlanNotificationToStatusCard();
    notifyBirthJourneyPlanDeleted();
    unsubscribe();

    expect(localStorage.getItem("mmc_birth_journey_plan_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_birth_journey_plan_card_pending")).toBeNull();
    expect(events).toEqual(["deleted", "window"]);
  });

  it("detects birth journey plan card artifacts in rich text", () => {
    expect(
      richTextPayloadHasBirthJourneyPlanCard({
        title: "",
        content: "",
        button: [],
        card: [],
        action: [
          {
            kind: "ag_ui_artifact",
            artifact_type: "card",
            card: { card_type: "birth_journey_plan_card", title: "生产全过程计划" },
          },
        ],
      }),
    ).toBe(true);
  });
});
