#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";

const projectRoot = process.cwd();
const flutterAppDir = path.join(projectRoot, "flutter_app");
const pubspecPath = path.join(flutterAppDir, "pubspec.yaml");
const TOOLCHAIN_ROOT =
  process.env.MOMCOZY_TOOLCHAIN_ROOT ||
  path.join(os.homedir(), ".local", "share", "momcozy-toolchains");
const JAVA_HOME =
  process.env.JAVA_HOME ||
  path.join(TOOLCHAIN_ROOT, "jdk", "jdk-17.0.19+10", "Contents", "Home");
const ANDROID_SDK_ROOT =
  process.env.ANDROID_SDK_ROOT || path.join(TOOLCHAIN_ROOT, "android-sdk");
const ENV = {
  ...process.env,
  JAVA_HOME,
  ANDROID_SDK_ROOT,
  ANDROID_HOME: process.env.ANDROID_HOME || ANDROID_SDK_ROOT,
  PATH: [
    path.join(TOOLCHAIN_ROOT, "flutter", "bin"),
    path.join(JAVA_HOME, "bin"),
    path.join(ANDROID_SDK_ROOT, "cmdline-tools", "latest", "bin"),
    path.join(ANDROID_SDK_ROOT, "platform-tools"),
    process.env.PATH || "",
  ].join(path.delimiter),
};

function run(command, args) {
  return spawnSync(command, args, {
    cwd: projectRoot,
    stdio: "inherit",
    env: ENV,
  });
}

function hasCommand(command, args) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    env: ENV,
  });
  return !result.error && result.status === 0;
}

if (!hasCommand("flutter", ["--version"])) {
  console.error("Flutter SDK is not available. Run npm run flutter:check first.");
  process.exit(1);
}

if (existsSync(pubspecPath)) {
  console.log("flutter_app already exists. Skipping flutter create.");
  console.log("Next: cd flutter_app && flutter pub get && flutter test");
  process.exit(0);
}

if (existsSync(flutterAppDir)) {
  console.error("flutter_app exists but pubspec.yaml is missing. Refusing to overwrite it.");
  process.exit(1);
}

const create = run("flutter", [
  "create",
  "--platforms=android",
  "--org",
  "com.momcozymai",
  "--project-name",
  "momcozy_flutter_app",
  "flutter_app",
]);

if (create.status !== 0) {
  process.exit(create.status ?? 1);
}

console.log("");
console.log("Flutter shell created at flutter_app/.");
console.log("Next:");
console.log("  cd flutter_app");
console.log("  flutter pub get");
console.log("  flutter test");
console.log("  flutter build apk --debug");
