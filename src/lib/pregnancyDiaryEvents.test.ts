import { beforeEach, describe, expect, it } from "vitest";
import {
  clearPregnancyDiaryCardNotification,
  clearPregnancyDiaryChangedNotification,
  notifyPregnancyDiaryChanged,
  transferPregnancyDiaryNotificationToStatusCard,
} from "./pregnancyDiaryEvents";

describe("pregnancy diary notification state", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("moves created diary notice from status nav to pregnancy diary card", () => {
    notifyPregnancyDiaryChanged("created");

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBe("1");
    expect(localStorage.getItem("mmc_pregnancy_diary_card_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBe("日记已记录");

    transferPregnancyDiaryNotificationToStatusCard();

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_pending")).toBe("1");
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBe("日记已记录");

    clearPregnancyDiaryCardNotification();

    expect(localStorage.getItem("mmc_pregnancy_diary_card_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
  });

  it("uses an updated record label and clears notices on delete", () => {
    notifyPregnancyDiaryChanged("updated");

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBe("1");
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBe("记录更新");

    notifyPregnancyDiaryChanged("deleted");

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
  });

  it("clears both nav and card notices", () => {
    notifyPregnancyDiaryChanged("created");
    transferPregnancyDiaryNotificationToStatusCard();

    clearPregnancyDiaryChangedNotification();

    expect(localStorage.getItem("mmc_pregnancy_diary_nav_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_pending")).toBeNull();
    expect(localStorage.getItem("mmc_pregnancy_diary_card_label")).toBeNull();
  });
});
