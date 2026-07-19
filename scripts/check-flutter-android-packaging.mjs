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

const flutterBaseAppId = "com.momcozymai.app.flutterpoc";

contains(
  "android/app/build.gradle.kts",
  `namespace = "com.momcozymai.momcozy_flutter_app"`,
  "Flutter namespace remains isolated from the application ID",
);
contains(
  "android/app/build.gradle.kts",
  `applicationId = "${flutterBaseAppId}"`,
  "Flutter production-shaped applicationId remains independent",
);
matches(
  "android/app/build.gradle.kts",
  /create\("local"\)[\s\S]*applicationIdSuffix = "\.local"/,
  "Flutter local flavor keeps a local suffix",
);
matches(
  "android/app/build.gradle.kts",
  /create\("staging"\)[\s\S]*applicationIdSuffix = "\.staging"/,
  "Flutter staging flavor keeps a staging suffix",
);
contains(
  "android/app/src/local/res/values/strings.xml",
  "<string name=\"app_name\">Momcozy Lab</string>",
  "Flutter local label matches current unified branding",
);
contains(
  "android/app/src/staging/res/values/strings.xml",
  "<string name=\"app_name\">Momcozy Lab</string>",
  "Flutter staging label matches current unified branding",
);
contains(
  "android/app/src/production/res/values/strings.xml",
  "<string name=\"app_name\">Momcozy Lab</string>",
  "Flutter production-shaped label matches current unified branding",
);

notMatches(
  "android/app/src/main/AndroidManifest.xml",
  /androidx\.core\.content\.FileProvider|android:authorities=/,
  "Flutter app does not declare a FileProvider authority yet",
);
notMatches(
  "android/app/src/main/AndroidManifest.xml",
  /android\.intent\.action\.VIEW|android\.intent\.category\.BROWSABLE/,
  "Flutter app does not claim external deep links yet",
);
matches(
  "android/app/src/main/AndroidManifest.xml",
  /android\.intent\.action\.MAIN[\s\S]*android\.intent\.category\.LAUNCHER/,
  "Flutter app exposes only the launcher intent filter",
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
