import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const bottomNavSource = readFileSync(resolve(here, "BottomNav.tsx"), "utf8");
const appCssSource = readFileSync(resolve(here, "../../index.css"), "utf8");

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

describe("BottomNav agent wake animation", () => {
  it("preloads and replays the one-shot animated avatar in a route-persistent overlay", () => {
    expect(bottomNavSource).toContain("preloadAgentAwakenAvatar");
    expect(bottomNavSource).toContain("preloadAgentAwakenAvatarBlob");
    expect(bottomNavSource).toContain("agentAwakenPreloadImage");
    expect(bottomNavSource).toContain("agentAwakenAvatarBlob");
    expect(bottomNavSource).toContain("createAgentWakePlaybackUrl");
    expect(bottomNavSource).toContain("URL.createObjectURL");
    expect(bottomNavSource).toContain("wake=${agentWakePlaybackNonce}");
    expect(bottomNavSource).toContain("playAgentWakeOverlay");
    expect(bottomNavSource).toContain("data-agent-wake-overlay");
    expect(bottomNavSource).toContain("momcozyAgentAwakenAvatar");
  });

  it("keeps the wake media independent from the global img max-width reset", () => {
    expect(appCssSource).toContain(".agent-nav-avatar-wake-overlay-media");
    expect(appCssSource).toContain("width: 3.75rem");
    expect(appCssSource).toContain("height: 3.75rem");
    expect(appCssSource).toContain("max-width: none");
    expect(appCssSource).toContain("clip-path: circle(49% at 50% 50%)");
  });
});
