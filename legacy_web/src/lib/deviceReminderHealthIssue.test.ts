import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { HEALTH_ISSUE_NOTIFICATION_MESSAGE } from "@/lib/deviceReminderActions";

const legacyWebRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

function source(path: string): string {
  return readFileSync(resolve(legacyWebRoot, path), "utf8");
}

describe("health issue reminder wiring", () => {
  it("exposes the health issue reminder in the web action surface", () => {
    expect(HEALTH_ISSUE_NOTIFICATION_MESSAGE).toBe("嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗");
    expect(source("src/lib/deviceReminderActions.ts")).toContain('title: "健康问题通知"');
    expect(source("src/lib/deviceReminderActions.ts")).toContain('event: "health_issue"');
    expect(source("src/pages/DeviceManageActions.tsx")).toContain('{ key: "health_issue", label: "健康问题通知" }');
    expect(source("src/lib/deviceReminderWebSocket.ts")).toContain('"health_issue_reminder"');
    expect(source("src/App.tsx")).toContain('o?.event === "health_issue"');
  });

  it("supports health issue reminders in Android native notification code", () => {
    expect(source("android/app/src/main/java/com/momcozymai/app/NotifyMessageResolver.java")).toContain('case "health_issue"');
    expect(source("android/app/src/main/java/com/momcozymai/app/NotifyMessageResolver.java")).toContain("健康问题通知");
    expect(source("android/app/src/main/java/com/momcozymai/app/DeviceReminderWebSocketService.java")).toContain('"health_issue_reminder"');
    expect(source("android/app/src/main/java/com/momcozymai/app/DeviceReminderWebSocketService.java")).toContain('"health_issue"');
  });
});
