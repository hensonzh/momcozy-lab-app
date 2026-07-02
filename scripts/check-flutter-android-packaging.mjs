#!/usr/bin/env node
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");

const files = new Map();

function read(relPath) {
  if (!files.has(relPath)) {
    files.set(relPath, readFileSync(path.join(projectRoot, relPath), "utf8"));
  }
  return files.get(relPath);
}

const checks = [];

function check(label, passed, detail) {
  checks.push({ label, passed, detail });
}

function contains(relPath, needle, label) {
  check(label, read(relPath).includes(needle), `${relPath} must contain ${needle}`);
}

function matches(relPath, pattern, label) {
  check(label, pattern.test(read(relPath)), `${relPath} must match ${pattern}`);
}

function notMatches(relPath, pattern, label) {
  check(label, !pattern.test(read(relPath)), `${relPath} must not match ${pattern}`);
}

const legacyAppId = "com.momcozymai.app";
const flutterBaseAppId = "com.momcozymai.app.flutterpoc";

contains(
  "capacitor.config.ts",
  `appId: '${legacyAppId}'`,
  "Capacitor rollback appId remains unchanged",
);
contains(
  "android/app/build.gradle",
  `applicationId "${legacyAppId}"`,
  "Capacitor Android applicationId remains unchanged",
);
contains(
  "android/app/src/main/res/values/strings.xml",
  `<string name="custom_url_scheme">${legacyAppId}</string>`,
  "Capacitor custom URL scheme remains scoped to the legacy app",
);
contains(
  "android/app/src/main/AndroidManifest.xml",
  'android:authorities="${applicationId}.fileprovider"',
  "Capacitor FileProvider authority remains applicationId-scoped",
);

contains(
  "flutter_app/android/app/build.gradle.kts",
  `namespace = "com.momcozymai.momcozy_flutter_app"`,
  "Flutter namespace remains isolated from the Capacitor package",
);
contains(
  "flutter_app/android/app/build.gradle.kts",
  `applicationId = "${flutterBaseAppId}"`,
  "Flutter production-shaped applicationId remains independent",
);
matches(
  "flutter_app/android/app/build.gradle.kts",
  /create\("local"\)[\s\S]*applicationIdSuffix = "\.local"/,
  "Flutter local flavor keeps a local suffix",
);
matches(
  "flutter_app/android/app/build.gradle.kts",
  /create\("staging"\)[\s\S]*applicationIdSuffix = "\.staging"/,
  "Flutter staging flavor keeps a staging suffix",
);
notMatches(
  "flutter_app/android/app/build.gradle.kts",
  new RegExp(`applicationId\\s*=\\s*"${legacyAppId}"`),
  "Flutter build config never claims the Capacitor production appId",
);

contains(
  "flutter_app/android/app/src/local/res/values/strings.xml",
  "<string name=\"app_name\">Momcozy Local</string>",
  "Flutter local label is distinguishable",
);
contains(
  "flutter_app/android/app/src/staging/res/values/strings.xml",
  "<string name=\"app_name\">Momcozy Staging</string>",
  "Flutter staging label is distinguishable",
);
contains(
  "flutter_app/android/app/src/production/res/values/strings.xml",
  "<string name=\"app_name\">Momcozy</string>",
  "Flutter production-shaped label is explicit",
);

notMatches(
  "flutter_app/android/app/src/main/AndroidManifest.xml",
  /androidx\.core\.content\.FileProvider|android:authorities=/,
  "Flutter PoC does not declare a FileProvider authority yet",
);
notMatches(
  "flutter_app/android/app/src/main/AndroidManifest.xml",
  /android\.intent\.action\.VIEW|android\.intent\.category\.BROWSABLE/,
  "Flutter PoC does not claim external deep links yet",
);
matches(
  "flutter_app/android/app/src/main/AndroidManifest.xml",
  /android\.intent\.action\.MAIN[\s\S]*android\.intent\.category\.LAUNCHER/,
  "Flutter PoC exposes only the launcher intent filter",
);

const failures = checks.filter((item) => !item.passed);
for (const item of checks) {
  console.log(`${item.passed ? "OK" : "FAIL"} ${item.label}`);
  if (!item.passed) console.log(`  ${item.detail}`);
}

if (failures.length > 0) {
  console.error(`\nAndroid packaging check failed: ${failures.length} issue(s).`);
  process.exit(1);
}

console.log("\nAndroid packaging check passed.");
