#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = path.join(projectRoot, "flutter_app");
const toolchainConfig = JSON.parse(
  readFileSync(path.join(projectRoot, "flutter-toolchain.json"), "utf8"),
);

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  console.log(`Usage:
  npm run flutter:invite-dev

Environment overrides:
  MOMCOZY_API_BASE_URL=http://10.0.2.2:8000
  MOMCOZY_FLUTTER_EMULATOR_DEVICE=emulator-5554
  MOMCOZY_RESET_INVITE_APP=0
  MOMCOZY_DEFAULT_USER_ID=invite-bootstrap-user
  MOMCOZY_DEFAULT_BABY_ID=invite-bootstrap-baby
  MOMCOZY_LOCALE=zh-CN

This command intentionally does not pass MOMCOZY_API_TOKEN or MOMCOZY_REFRESH_TOKEN.`);
  process.exit(0);
}

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
    path.join(androidSdkRoot, "emulator"),
    process.env.PATH || "",
  ].join(path.delimiter),
};

const packageName =
  process.env.MOMCOZY_FLUTTER_EMULATOR_PACKAGE ||
  "com.momcozymai.app.flutterpoc.local";
const apiBaseUrl =
  process.env.MOMCOZY_API_BASE_URL || "http://10.0.2.2:8000";
const defaultUserId =
  process.env.MOMCOZY_DEFAULT_USER_ID || "invite-bootstrap-user";
const defaultBabyId =
  process.env.MOMCOZY_DEFAULT_BABY_ID || "invite-bootstrap-baby";
const locale = process.env.MOMCOZY_LOCALE || "zh-CN";
const resetApp = String(process.env.MOMCOZY_RESET_INVITE_APP || "1").trim() !== "0";

if (!existsSync(path.join(flutterAppDir, "pubspec.yaml"))) {
  console.error("Missing flutter_app/pubspec.yaml. Run npm run flutter:init first.");
  process.exit(1);
}

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    cwd: options.cwd || projectRoot,
    env,
    encoding: options.encoding ?? "utf8",
    stdio: options.stdio || ["ignore", "pipe", "pipe"],
    maxBuffer: options.maxBuffer || 20 * 1024 * 1024,
  });
}

function runRequired(command, args, options = {}) {
  const result = run(command, args, options);
  if (result.status !== 0) {
    const output = [result.stdout, result.stderr]
      .filter(Boolean)
      .join("\n")
      .trim();
    console.error(output || `${command} ${args.join(" ")} failed`);
    process.exit(result.status ?? 1);
  }
  return result;
}

function firstOnlineEmulator() {
  const result = runRequired("adb", ["devices"]);
  return result.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => /^emulator-\d+\s+device$/.test(line))
    ?.split(/\s+/)[0];
}

const deviceId =
  process.env.MOMCOZY_FLUTTER_EMULATOR_DEVICE ||
  process.env.MOMCOZY_FLUTTER_DEVICE ||
  firstOnlineEmulator();

if (!deviceId) {
  console.error(
    "No online Android emulator found. Start an AVD or set MOMCOZY_FLUTTER_EMULATOR_DEVICE.",
  );
  process.exit(1);
}

if (resetApp) {
  console.log(`Resetting installed app package: ${packageName}`);
  run("adb", ["-s", deviceId, "uninstall", packageName], { stdio: "ignore" });
}

const flutterArgs = [
  "run",
  "-d",
  deviceId,
  "--flavor",
  "local",
  `--dart-define=MOMCOZY_API_BASE_URL=${apiBaseUrl}`,
  `--dart-define=MOMCOZY_DEFAULT_USER_ID=${defaultUserId}`,
  `--dart-define=MOMCOZY_DEFAULT_BABY_ID=${defaultBabyId}`,
  `--dart-define=MOMCOZY_LOCALE=${locale}`,
  ...process.argv.slice(2),
];

console.log(`Starting Flutter invite-login dev app on ${deviceId}`);
console.log(`Backend API: ${apiBaseUrl}`);
console.log("No bootstrap API token will be passed; the app should open the invite login page.");

const result = spawnSync("flutter", flutterArgs, {
  cwd: flutterAppDir,
  env,
  stdio: "inherit",
});

process.exit(result.status ?? 1);
