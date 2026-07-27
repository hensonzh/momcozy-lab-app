#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
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

const packageName =
  process.env.MOMCOZY_FLUTTER_EMULATOR_PACKAGE ||
  "com.momcozymai.app.flutterpoc.local";
const activityName =
  process.env.MOMCOZY_FLUTTER_EMULATOR_ACTIVITY ||
  "com.momcozymai.app.MainActivity";
const skipBuild =
  String(process.env.MOMCOZY_FLUTTER_EMULATOR_SKIP_BUILD || "").trim() === "1";
const apkPath = path.join(
  flutterAppDir,
  "build/app/outputs/flutter-apk/app-local-debug.apk",
);
const screenshotDir = path.join(flutterAppDir, "build/emulator-smoke");

if (!existsSync(path.join(flutterAppDir, "pubspec.yaml"))) {
  console.error("Invalid repository root: missing pubspec.yaml.");
  process.exit(1);
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
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
  process.env.MOMCOZY_FLUTTER_EMULATOR_DEVICE || firstOnlineEmulator();

if (!deviceId) {
  console.error(
    "No online Android emulator found. Start an AVD or set MOMCOZY_FLUTTER_EMULATOR_DEVICE.",
  );
  process.exit(1);
}

function adb(args, options = {}) {
  return runRequired("adb", ["-s", deviceId, ...args], options);
}

function parsePhysicalSize(value) {
  const matches = [...String(value || "").matchAll(/(\d+)x(\d+)/g)];
  if (!matches.length) {
    return { width: 1080, height: 2400 };
  }
  const match = matches[matches.length - 1];
  return { width: Number(match[1]), height: Number(match[2]) };
}

function tap(width, height, xRatio, yRatio) {
  adb([
    "shell",
    "input",
    "tap",
    String(Math.round(width * xRatio)),
    String(Math.round(height * yRatio)),
  ]);
  sleep(700);
}

function screenshot(name) {
  mkdirSync(screenshotDir, { recursive: true });
  const result = run("adb", ["-s", deviceId, "exec-out", "screencap", "-p"], {
    encoding: "buffer",
    maxBuffer: 30 * 1024 * 1024,
  });
  if (result.status !== 0 || !result.stdout?.length) {
    console.error(`Failed to capture ${name} screenshot.`);
    process.exit(result.status ?? 1);
  }
  const target = path.join(screenshotDir, `${name}.png`);
  writeFileSync(target, result.stdout);
  return path.relative(projectRoot, target);
}

if (!skipBuild || !existsSync(apkPath)) {
  console.log("$ flutter build apk --debug --flavor local");
  runRequired("flutter", ["build", "apk", "--debug", "--flavor", "local"], {
    cwd: flutterAppDir,
    stdio: "inherit",
  });
}

console.log(`$ adb -s ${deviceId} install -r ${path.relative(projectRoot, apkPath)}`);
adb(["install", "-r", apkPath], { stdio: "inherit" });

adb(["shell", "am", "force-stop", packageName]);
adb(["logcat", "-c"]);

console.log(`$ adb -s ${deviceId} shell monkey -p ${packageName} ...`);
adb([
  "shell",
  "monkey",
  "-p",
  packageName,
  "-c",
  "android.intent.category.LAUNCHER",
  "1",
]);
sleep(2500);

const pid = adb(["shell", "pidof", packageName]).stdout.trim();
if (!pid) {
  console.error(`App process not found for ${packageName}.`);
  process.exit(1);
}

const windowDump = adb(["shell", "dumpsys", "window"]).stdout;
if (!windowDump.includes(packageName) || !windowDump.includes(activityName)) {
  console.error(`Flutter MainActivity is not focused for ${packageName}.`);
  process.exit(1);
}

const { width, height } = parsePhysicalSize(adb(["shell", "wm", "size"]).stdout);
const screenshots = [
  screenshot("agent_hub"),
];
tap(width, height, 0.3, 0.91);
screenshots.push(screenshot("schedule"));
tap(width, height, 0.89, 0.91);
screenshots.push(screenshot("device"));

const logcat = adb(["logcat", "-d", "--pid", pid]).stdout;
const fatalPattern = /FATAL EXCEPTION|AndroidRuntime|E\/flutter|Fatal signal|CRASH/i;
if (fatalPattern.test(logcat)) {
  console.error("Fatal/crash logs detected during emulator smoke.");
  process.exit(1);
}

console.log("");
console.log("Flutter emulator smoke passed.");
console.log(`OK device: ${deviceId}`);
console.log(`OK package: ${packageName}`);
console.log(`OK pid: ${pid}`);
console.log(`OK screenshots: ${screenshots.join(", ")}`);
