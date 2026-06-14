import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const bottomNavSource = readFileSync(resolve(here, "BottomNav.tsx"), "utf8");

describe("BottomNav birth journey notification wiring", () => {
  it("shows an aggregated status notification badge and transfers notices to status cards on click", () => {
    expect(bottomNavSource).toContain("useBirthJourneyPlanNavNotification");
    expect(bottomNavSource).toContain("transferBirthJourneyPlanNotificationToStatusCard");
    expect(bottomNavSource).toContain("usePregnancyDiaryNavNotification");
    expect(bottomNavSource).toContain("transferPregnancyDiaryNotificationToStatusCard");
    expect(bottomNavSource).toContain("statusNotificationCount");
    expect(bottomNavSource).toContain('aria-label="宝宝和我有新通知"');
    expect(bottomNavSource).toContain("bg-[#e3405f]");
    expect(bottomNavSource).toContain("{statusNotificationCount}");
    expect(bottomNavSource).toContain('label: "宝宝和我"');
    expect(bottomNavSource).toContain('tab.path === "/status"');
  });
});
