#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const pubspecPath = path.join(projectRoot, "pubspec.yaml");
const toolchainConfig = JSON.parse(
  readFileSync(path.join(projectRoot, "flutter-toolchain.json"), "utf8"),
);
const expandHome = (value) =>
  String(value || "").startsWith("~/")
    ? path.join(os.homedir(), String(value).slice(2))
    : String(value || "");
const TOOLCHAIN_ROOT =
  process.env.MOMCOZY_TOOLCHAIN_ROOT ||
  expandHome(toolchainConfig.toolchainRootDefault);
const JAVA_HOME =
  process.env.JAVA_HOME ||
  path.join(TOOLCHAIN_ROOT, toolchainConfig.jdk.homePath);
const ANDROID_SDK_ROOT =
  process.env.ANDROID_SDK_ROOT ||
  path.join(TOOLCHAIN_ROOT, toolchainConfig.android.sdkPath);
const ENV = {
  ...process.env,
  JAVA_HOME,
  ANDROID_SDK_ROOT,
  ANDROID_HOME: process.env.ANDROID_HOME || ANDROID_SDK_ROOT,
  PATH: [
    path.join(TOOLCHAIN_ROOT, toolchainConfig.flutter.path, "bin"),
    path.join(JAVA_HOME, "bin"),
    path.join(ANDROID_SDK_ROOT, "cmdline-tools", "latest", "bin"),
    path.join(ANDROID_SDK_ROOT, "platform-tools"),
    process.env.PATH || "",
  ].join(path.delimiter),
};

function hasCommand(command, args) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    env: ENV,
  });
  return !result.error && result.status === 0;
}

if (!hasCommand("flutter", ["--version"])) {
  console.error("Flutter SDK is not available. Run make flutter-check first.");
  process.exit(1);
}

if (existsSync(pubspecPath)) {
  console.log("Flutter project is ready at the repository root.");
  console.log("Next: flutter pub get && flutter test");
  process.exit(0);
}

console.error("Missing pubspec.yaml at the repository root; refusing to initialize over a non-empty repository.");
process.exit(1);
