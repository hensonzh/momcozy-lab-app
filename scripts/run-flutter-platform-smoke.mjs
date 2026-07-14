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

const testFiles = [
  "test/native/p0_platform_interfaces_test.dart",
  "test/native/android_p0_platform_channels_test.dart",
  "test/native/ble_pump_protocol_platform_test.dart",
  "test/native/pump_agent_upload_snapshot_sync_test.dart",
  "test/native/pump_device_snapshot_binding_test.dart",
  "test/native/pump_native_runtime_coordinator_test.dart",
];

if (!existsSync(path.join(flutterAppDir, "pubspec.yaml"))) {
  console.error("Missing flutter_app/pubspec.yaml. Run make flutter-init first.");
  process.exit(1);
}

const result = spawnSync("flutter", ["test", ...testFiles], {
  cwd: flutterAppDir,
  env,
  stdio: "inherit",
});

process.exit(result.status ?? 1);
