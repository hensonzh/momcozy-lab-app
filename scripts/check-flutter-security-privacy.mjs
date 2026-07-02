#!/usr/bin/env node
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");

const read = (relativePath) =>
  readFileSync(path.join(projectRoot, relativePath), "utf8");

const failures = [];

const requireContains = (relativePath, needle, description) => {
  if (!read(relativePath).includes(needle)) {
    failures.push(`${description}: missing ${needle} in ${relativePath}`);
  }
};

const forbidContains = (relativePath, needle, description) => {
  if (read(relativePath).includes(needle)) {
    failures.push(`${description}: found ${needle} in ${relativePath}`);
  }
};

requireContains(
  "flutter_app/lib/features/agent_hub/data/voice_api.dart",
  "TransportSecurityPolicy.requireSecureHttp(baseUri)",
  "Voice API must reuse transport security policy",
);
requireContains(
  "flutter_app/lib/features/agent_hub/data/voice_api.dart",
  "redactedRealtimeVoiceStreamLogContext",
  "Voice API must expose redacted stream log context",
);
requireContains(
  "flutter_app/lib/core/privacy/log_redactor.dart",
  "normalized == 'text'",
  "Log redactor must redact free-form voice text",
);
requireContains(
  "flutter_app/lib/core/privacy/log_redactor.dart",
  "normalized == 'message'",
  "Log redactor must redact free-form message content",
);

forbidContains(
  "android/app/src/main/java/com/momcozymai/app/DeviceNativeStateStore.java",
  'deviceId=" + deviceId',
  "Native device logs must not include raw device id",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/PumpAgentBackgroundRunner.java",
  "request body=",
  "Native background pump logs must not include raw request body",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/PumpAgentUploadPlugin.java",
  "request body=",
  "Native upload logs must not include raw request body",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/NotifyAlarmScheduler.java",
  'title=" + title',
  "Native alarm logs must not include raw notification title",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/NotifyAlarmScheduler.java",
  'body=" + body',
  "Native alarm logs must not include raw notification body",
);
requireContains(
  "android/app/src/main/java/com/momcozymai/app/PumpNavigationBridge.java",
  "sanitizeNotifyJson",
  "Native pending route payload must be sanitized before storage",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/PumpNavigationBridge.java",
  "pendingNotifyJson = notifyJson",
  "Native pending route must not store raw notifyJson",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/NotifyMessageResolver.java",
  'o.put("body"',
  "Native pending route notifyJson must not include full notification body",
);
requireContains(
  "android/app/src/main/java/com/momcozymai/app/PumpSessionForegroundService.java",
  'launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, "/pump")',
  "Pump foreground notification should navigate with route only",
);
forbidContains(
  "android/app/src/main/java/com/momcozymai/app/PumpSessionForegroundService.java",
  "EXTRA_NOTIFY_JSON",
  "Pump foreground notification must not carry business payload",
);

if (failures.length > 0) {
  console.error("Flutter security privacy check failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Flutter security privacy check passed.");
