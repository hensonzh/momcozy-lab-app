#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { withFlutterApiDartDefines } from "./flutter-api-config.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = projectRoot;

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  console.log(`Usage:
  MOMCOZY_API_BASE_URL=https://product.example.test \\
  MOMCOZY_AGENT_API_BASE_URL=https://agent.example.test \\
  make flutter-release-gate

Use --check-config to validate the required staging URLs and join barrier without running the gate.`);
  process.exit(0);
}

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
const requiresStagingJoinBarrier =
  String(env.MOMCOZY_REQUIRE_STAGING_JOIN_BARRIER || "").trim() === "1";
const releaseFlavor = String(env.MOMCOZY_APK_FLAVOR || "staging").trim();
const runtimeEnvironment = releaseFlavor;

if (requiresStagingJoinBarrier) {
  const missingSmokeFlags = [
    "MOMCOZY_STAGING_SMOKE",
    "MOMCOZY_STAGING_SMOKE_MUTATE",
    "MOMCOZY_STAGING_SMOKE_AGENT",
  ].filter((key) => String(env[key] || "").trim() !== "1");
  if (missingSmokeFlags.length > 0) {
    console.error(
      `FAIL staging join barrier requires ${missingSmokeFlags.join(" and ")} to be 1.`,
    );
    process.exit(1);
  }
}

let stagingApiDartDefines;
try {
  stagingApiDartDefines = withFlutterApiDartDefines({
    flavor: releaseFlavor,
    dartDefines: [
      `MOMCOZY_API_BASE_URL=${env.MOMCOZY_API_BASE_URL || ""}`,
      `MOMCOZY_AGENT_API_BASE_URL=${env.MOMCOZY_AGENT_API_BASE_URL || ""}`,
    ],
  });
} catch (error) {
  console.error(`FAIL ${error.message}`);
  process.exit(1);
}

if (process.argv.includes("--check-config")) {
  console.log(
    `Flutter release gate config is valid for ${releaseFlavor} (${runtimeEnvironment} runtime).`,
  );
  process.exit(0);
}

if (!existsSync(path.join(flutterAppDir, "pubspec.yaml"))) {
  console.error("Invalid repository root: missing pubspec.yaml.");
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
  ["flutter", ["pub", "get"], flutterAppDir],
  // The access token is deliberately issued immediately before this gate.
  // Keep the live smoke before the long static/test/build sequence.
  ["flutter", ["test", "--no-pub", "tool/staging_environment_smoke_test.dart"], flutterAppDir],
  ["node", ["scripts/check-flutter-android-packaging.mjs"], projectRoot],
  ["node", ["scripts/check-flutter-security-privacy.mjs"], projectRoot],
  [
    "dart",
    [
      "format",
      "--output=none",
      "--set-exit-if-changed",
      "lib",
      "test",
      "integration_test",
      "tool",
    ],
    flutterAppDir,
  ],
  ["flutter", ["analyze", "--no-pub"], flutterAppDir],
  ["flutter", ["test", "--no-pub", "--exclude-tags=golden"], flutterAppDir],
  [
    "node",
    [
      "scripts/build-flutter-android-apk.mjs",
      "--mode",
      "release",
      "--flavor",
      releaseFlavor,
      `--dart-define=MOMCOZY_ENV=${runtimeEnvironment}`,
      ...stagingApiDartDefines.map((define) => `--dart-define=${define}`),
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
