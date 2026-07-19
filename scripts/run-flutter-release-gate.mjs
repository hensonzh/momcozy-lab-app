#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = projectRoot;
const toolchainConfig = JSON.parse(
  readFileSync(path.join(projectRoot, "flutter-toolchain.json"), "utf8"),
);

const expandHome = (value) =>
  String(value || "").startsWith("~/")
    ? path.join(os.homedir(), String(value).slice(2))
    : String(value || "");

const toolchainRoot =
  process.env.MOMCOZY_TOOLCHAIN_ROOT ||
  expandHome(toolchainConfig.toolchainRootDefault);
const javaHome =
  process.env.JAVA_HOME ||
  path.join(toolchainRoot, toolchainConfig.jdk.homePath);
const androidSdkRoot =
  process.env.ANDROID_SDK_ROOT ||
  path.join(toolchainRoot, toolchainConfig.android.sdkPath);
const env = {
  ...process.env,
  JAVA_HOME: javaHome,
  ANDROID_SDK_ROOT: androidSdkRoot,
  ANDROID_HOME: process.env.ANDROID_HOME || androidSdkRoot,
  PATH: [
    path.join(toolchainRoot, toolchainConfig.flutter.path, "bin"),
    path.join(javaHome, "bin"),
    path.join(androidSdkRoot, "cmdline-tools", "latest", "bin"),
    path.join(androidSdkRoot, "platform-tools"),
    process.env.PATH || "",
  ].join(path.delimiter),
};

const signingKeys = [
  "MOMCOZY_FLUTTER_RELEASE_STORE_FILE",
  "MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD",
  "MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS",
  "MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD",
];
const hasReleaseSigning = signingKeys.every((key) =>
  String(env[key] || "").trim(),
);
const requiresReleaseSigning =
  String(env.MOMCOZY_REQUIRE_RELEASE_SIGNING || "").trim() === "1";

if (!existsSync(path.join(flutterAppDir, "pubspec.yaml"))) {
  console.error("Missing pubspec.yaml at the repository root. Run make flutter-init first.");
  process.exit(1);
}

if (!hasReleaseSigning) {
  const message =
    "release signing env is not fully configured; release APK will use debug signing as a smoke artifact only.";
  if (requiresReleaseSigning) {
    console.error(`FAIL ${message}`);
    process.exit(1);
  }
  console.warn(`WARN ${message}`);
}

const steps = [
  ["node", ["scripts/check-flutter-android-packaging.mjs"], projectRoot],
  ["node", ["scripts/check-flutter-security-privacy.mjs"], projectRoot],
  ["flutter", ["pub", "get"], flutterAppDir],
  [
    "dart",
    [
      "format",
      "--set-exit-if-changed",
      "lib",
      "test",
      "integration_test",
      "tool",
    ],
    flutterAppDir,
  ],
  ["flutter", ["analyze"], flutterAppDir],
  ["flutter", ["test"], flutterAppDir],
  ["dart", ["run", "tool/staging_smoke.dart"], flutterAppDir],
  ["dart", ["run", "tool/storage_migration_dry_run.dart"], flutterAppDir],
  [
    "node",
    [
      "scripts/build-flutter-android-apk.mjs",
      "--mode",
      "debug",
      "--flavor",
      "local",
    ],
    projectRoot,
  ],
  [
    "node",
    [
      "scripts/build-flutter-android-apk.mjs",
      "--mode",
      "release",
      "--flavor",
      "staging",
      "--dart-define=MOMCOZY_ENV=staging",
    ],
    projectRoot,
  ],
];

for (const [command, args, cwd] of steps) {
  console.log("");
  console.log(`$ ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, {
    cwd,
    env,
    stdio: "inherit",
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log("");
console.log("Flutter release gate passed.");
