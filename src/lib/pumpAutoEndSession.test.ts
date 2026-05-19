import { describe, expect, test } from "vitest";
import { shouldShowPumpAutoEndReminder } from "@/lib/pumpAutoEndSession";

describe("shouldShowPumpAutoEndReminder", () => {
  test("suppresses the reminder only while the pump page is visible in the foreground", () => {
    expect(shouldShowPumpAutoEndReminder({
      routePath: "/pump",
      appVisible: true,
    })).toBe(false);

    expect(shouldShowPumpAutoEndReminder({
      routePath: "/pump",
      appVisible: false,
    })).toBe(true);
  });

  test("keeps reminders enabled away from the pump page", () => {
    expect(shouldShowPumpAutoEndReminder({
      routePath: "/",
      appVisible: true,
    })).toBe(true);
  });
});
