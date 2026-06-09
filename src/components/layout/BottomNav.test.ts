import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const bottomNavSource = readFileSync(resolve(here, "BottomNav.tsx"), "utf8");

describe("BottomNav birth journey notification wiring", () => {
  it("shows a status notification dot and transfers it to the status card on click", () => {
    expect(bottomNavSource).toContain("useBirthJourneyPlanNavNotification");
    expect(bottomNavSource).toContain("transferBirthJourneyPlanNotificationToStatusCard");
    expect(bottomNavSource).toContain('aria-label="状态有新通知"');
    expect(bottomNavSource).toContain('tab.path === "/status"');
  });
});
