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
  console.error("Missing flutter_app/pubspec.yaml. Run npm run flutter:init first.");
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
  ["flutter", ["pub", "get"]],
  ["dart", ["format", "--set-exit-if-changed", "lib", "test", "tool"]],
  ["flutter", ["analyze"]],
  ["flutter", ["test"]],
  ["dart", ["run", "tool/staging_smoke.dart"]],
  ["dart", ["run", "tool/storage_migration_dry_run.dart"]],
  ["flutter", ["build", "apk", "--debug", "--flavor", "local"]],
  [
    "flutter",
    [
      "build",
      "apk",
      "--release",
      "--flavor",
      "staging",
      "--dart-define=MOMCOZY_ENV=staging",
    ],
  ],
];

for (const [command, args] of steps) {
  console.log("");
  console.log(`$ ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, {
    cwd: flutterAppDir,
    env,
    stdio: "inherit",
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log("");
console.log("Flutter release gate passed.");
