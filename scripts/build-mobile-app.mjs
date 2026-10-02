#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  AGENT_API_DEFINE,
  PRODUCT_API_DEFINE,
  assertLegacyPublishedUrls,
  resolveFlutterApiConfig,
} from "./flutter-api-config.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const supportedEnvironments = new Set(["local", "staging", "production"]);
const supportedPlatforms = new Set(["android", "ios"]);
const supportedModes = new Set(["debug", "release"]);
const provisionalIosBundleIds = new Set(["com.momcozymai.app.flutterpoc"]);
const allowedConfigKeys = new Set([
  "MOMCOZY_ENV",
  PRODUCT_API_DEFINE,
  AGENT_API_DEFINE,
]);

function usage() {
  console.log(`Usage:
  node scripts/build-mobile-app.mjs \\
    --platform <android|ios> \\
    --environment <local|staging|production> \\
    [--mode <debug|release>] \\
    [--format <apk|appbundle|ios|ipa>] \\
    [--config <path>] \\
    [--release-lane <legacy-staging|north-america-staging>] \\
    [--unsigned] \\
    [--check-config]

Defaults:
  mode:   debug for local, release otherwise
  format: apk for Android, ios for iOS
  config: config/environments/<environment>.json

The committed production file is an example only. Copy
config/environments/production.json.example to the ignored
config/environments/production.json and fill the reviewed production URLs
before building production artifacts.`);
}

function fail(message) {
  console.error(`FAIL ${message}`);
  process.exit(2);
}

function parseArgs(argv) {
  const result = {
    platform: "",
    environment: "",
    mode: "",
    format: "",
    config: "",
    releaseLane: "",
    unsigned: false,
    checkConfig: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    }
    if (arg === "--unsigned") {
      result.unsigned = true;
      continue;
    }
    if (arg === "--check-config") {
      result.checkConfig = true;
      continue;
    }
    const key = arg.startsWith("--") ? arg.slice(2) : "";
    if (!["platform", "environment", "mode", "format", "config", "release-lane"].includes(key)) {
      fail(`Unknown argument: ${arg}`);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) fail(`${arg} requires a value.`);
    result[key === "release-lane" ? "releaseLane" : key] = value;
    index += 1;
  }
  return result;
}

function loadConfig(configPath, environment) {
  if (!existsSync(configPath)) {
    const hint = environment === "production"
      ? " Copy config/environments/production.json.example to the ignored production.json first."
      : "";
    fail(`Missing environment config: ${configPath}.${hint}`);
  }
  let payload;
  try {
    payload = JSON.parse(readFileSync(configPath, "utf8"));
  } catch (error) {
    fail(`Invalid JSON in ${configPath}: ${error.message}`);
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    fail(`${configPath} must contain a JSON object.`);
  }
  const unexpectedKeys = Object.keys(payload).filter(
    (key) => !allowedConfigKeys.has(key),
  );
  if (unexpectedKeys.length > 0) {
    fail(`${configPath} contains unsupported keys: ${unexpectedKeys.join(", ")}.`);
  }
  if (payload.MOMCOZY_ENV !== environment) {
    fail(`${configPath} MOMCOZY_ENV must be ${environment}.`);
  }
  return payload;
}

function validateProductionIosIdentity() {
  const projectFile = path.join(
    projectRoot,
    "ios",
    "Runner.xcodeproj",
    "project.pbxproj",
  );
  const project = readFileSync(projectFile, "utf8");
  const identifiers = [...project.matchAll(
    /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g,
  )]
    .map((match) => match[1].trim())
    .filter((value) => !value.endsWith(".RunnerTests"));
  if (identifiers.length === 0 || identifiers.some((value) => provisionalIosBundleIds.has(value))) {
    fail(
      "Production iOS build is blocked until the final Bundle ID replaces com.momcozymai.app.flutterpoc.",
    );
  }
}

function hasAndroidReleaseSigning() {
  return [
    "MOMCOZY_FLUTTER_RELEASE_STORE_FILE",
    "MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD",
    "MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS",
    "MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD",
  ].every((name) => String(process.env[name] || "").trim());
}

function buildToolchainEnv() {
  const toolchain = JSON.parse(
    readFileSync(path.join(projectRoot, "flutter-toolchain.json"), "utf8"),
  );
  const toolchainRoot = process.env.MOMCOZY_TOOLCHAIN_ROOT || path.join(
    os.homedir(), toolchain.toolchainRootDefault.replace(/^~\//, ""),
  );
  const javaHome = process.env.JAVA_HOME || path.join(toolchainRoot, toolchain.jdk.homePath);
  const sdkRoot = process.env.ANDROID_SDK_ROOT || path.join(toolchainRoot, toolchain.android.sdkPath);
  const env = {
    ...process.env,
    JAVA_HOME: javaHome,
    ANDROID_SDK_ROOT: sdkRoot,
    ANDROID_HOME: process.env.ANDROID_HOME || sdkRoot,
    PATH: [
      path.join(toolchainRoot, toolchain.flutter.path, "bin"),
      path.join(javaHome, "bin"),
      path.join(sdkRoot, "platform-tools"),
      process.env.PATH || "",
    ].join(path.delimiter),
  };
  const aapt2 = path.join(sdkRoot, "build-tools", toolchain.android.buildTools, "aapt2");
  if (process.platform === "darwin" && existsSync(aapt2)) {
    env["ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride"] =
      process.env["ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride"] || aapt2;
  }
  return env;
}

function run(command, args) {
  console.log(`$ ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, {
    cwd: projectRoot,
    env: buildToolchainEnv(),
    stdio: "inherit",
  });
  process.exitCode = result.status ?? 1;
  if (process.exitCode !== 0) process.exit(process.exitCode);
}

const options = parseArgs(process.argv.slice(2));
if (!supportedPlatforms.has(options.platform)) {
  fail("--platform must be android or ios.");
}
if (!supportedEnvironments.has(options.environment)) {
  fail("--environment must be local, staging, or production.");
}
options.mode ||= options.environment === "local" ? "debug" : "release";
if (!supportedModes.has(options.mode)) fail("--mode must be debug or release.");
options.format ||= options.platform === "android" ? "apk" : "ios";

const allowedFormats = options.platform === "android"
  ? new Set(["apk", "appbundle"])
  : new Set(["ios", "ipa"]);
if (!allowedFormats.has(options.format)) {
  fail(`Unsupported ${options.platform} format: ${options.format}.`);
}
if (options.format === "ipa" && options.mode !== "release") {
  fail("IPA output requires --mode release.");
}
if (options.unsigned && options.platform !== "ios") {
  fail("--unsigned is supported only for iOS compiler preflight builds.");
}
if (options.environment === "production" && options.unsigned) {
  fail("Production iOS artifacts must be signed.");
}
if (options.platform === "ios" && options.environment === "production") {
  validateProductionIosIdentity();
}
if (options.releaseLane && !["legacy-staging", "north-america-staging"].includes(options.releaseLane)) {
  fail(`Unsupported release lane: ${options.releaseLane}.`);
}
if (options.releaseLane && (options.environment !== "staging" || options.mode !== "release")) {
  fail("Release lanes require the staging environment and release mode.");
}
if (options.releaseLane === "legacy-staging" &&
    (options.platform !== "android" || options.format !== "apk")) {
  fail("legacy-staging distributes only an Android APK.");
}
if (options.releaseLane === "north-america-staging" &&
    (options.format !== (options.platform === "android" ? "appbundle" : "ipa") || options.unsigned)) {
  fail("north-america-staging requires a signed Android appbundle or iOS ipa.");
}
if (
  options.platform === "android" &&
  options.environment === "production" &&
  options.mode === "release" &&
  !hasAndroidReleaseSigning()
) {
  fail("Production Android release signing variables are incomplete.");
}

const defaultConfig = options.releaseLane === "north-america-staging"
  ? path.join(projectRoot, "config", "release-lanes", "north-america-staging.json")
  : path.join(projectRoot, "config", "environments", `${options.environment}.json`);
const configPath = path.resolve(projectRoot, options.config || defaultConfig);
let config;
if (options.releaseLane === "north-america-staging") {
  const check = spawnSync("node", ["scripts/check-north-america-staging-target.mjs", "--config", configPath], {
    cwd: projectRoot, encoding: "utf8",
  });
  if (check.status !== 0) fail((check.stderr || "B target check failed.").trim().replace(/^FAIL /, ""));
  const target = JSON.parse(readFileSync(configPath, "utf8"));
  for (const [name, value] of [
    [PRODUCT_API_DEFINE, target.productApiBaseUrl],
    [AGENT_API_DEFINE, target.agentApiBaseUrl],
  ]) {
    if (process.env[name] && process.env[name] !== value) {
      fail(`${name} must match the B target declaration; do not override it with A.`);
    }
  }
  config = {
    MOMCOZY_ENV: "staging",
    [PRODUCT_API_DEFINE]: target.productApiBaseUrl,
    [AGENT_API_DEFINE]: target.agentApiBaseUrl,
  };
  if (options.platform === "ios") {
    const project = readFileSync(path.join(projectRoot, "ios/Runner.xcodeproj/project.pbxproj"), "utf8");
    if (project.split(`PRODUCT_BUNDLE_IDENTIFIER = ${target.iosBundleId};`).length - 1 !== 3) {
      fail("B iOS Bundle ID does not match the existing staging Xcode configurations.");
    }
  }
} else {
  config = loadConfig(configPath, options.environment);
}
const productUrl = String(process.env[PRODUCT_API_DEFINE] || config[PRODUCT_API_DEFINE] || "");
const agentUrl = String(process.env[AGENT_API_DEFINE] || config[AGENT_API_DEFINE] || "");
const resolved = resolveFlutterApiConfig({
  flavor: options.environment,
  productUrl,
  agentUrl,
});
if (options.releaseLane === "legacy-staging") {
  try {
    assertLegacyPublishedUrls(resolved);
  } catch (error) {
    fail(error.message);
  }
}
const dartDefines = Object.entries({
  ...config,
  MOMCOZY_ENV: options.environment,
  [PRODUCT_API_DEFINE]: resolved.productUrl,
  [AGENT_API_DEFINE]: resolved.agentUrl,
}).map(([name, value]) => `--dart-define=${name}=${String(value)}`);
if (options.releaseLane) {
  dartDefines.push(`--dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=${options.releaseLane === "legacy-staging"}`);
}

console.log(`Environment: ${options.environment}`);
console.log(`Platform:    ${options.platform}`);
console.log(`Mode:        ${options.mode}`);
console.log(`Format:      ${options.format}`);
console.log(`Product API: ${resolved.productUrl}`);
console.log(`Agent API:   ${resolved.agentUrl}`);
console.log(`Config:      ${path.relative(projectRoot, configPath)}`);
if (options.releaseLane) console.log(`Login define: MOMCOZY_INTERNAL_INVITE_LOGIN=${options.releaseLane === "legacy-staging"}`);
if (options.releaseLane === "north-america-staging" && options.platform === "android") {
  console.log("Android flavor: play");
}
if (options.checkConfig) process.exit(0);
if (options.releaseLane === "north-america-staging") {
  if (options.platform === "android" && !hasAndroidReleaseSigning()) {
    fail("B Android upload signing is required before building an appbundle.");
  }
  if (options.platform === "ios") {
    if (process.env.MOMCOZY_B_IOS_SIGNING_READY !== "1") {
      fail("B iOS signing must be verified before building an ipa.");
    }
    if (!process.env.MOMCOZY_B_EXPORT_OPTIONS_PLIST || !existsSync(process.env.MOMCOZY_B_EXPORT_OPTIONS_PLIST)) {
      fail("B iOS export options must be prepared before building an ipa.");
    }
  }
}
if (options.releaseLane === "legacy-staging" && !hasAndroidReleaseSigning()) {
  fail("A release signing variables are incomplete; refuse a debug-signed distribution artifact.");
}

if (options.platform === "android") {
  const args = [
    path.join("scripts", "build-flutter-android-apk.mjs"),
    "--mode",
    options.mode,
    "--flavor",
    options.releaseLane === "north-america-staging" ? "play" : options.environment,
    "--format",
    options.format,
    ...dartDefines,
  ];
  if (options.releaseLane === "north-america-staging") {
    process.env.MOMCOZY_B_PLAY_BUILD_APPROVED = "1";
  }
  run("node", args);
  process.exit(0);
}

const args = ["build", options.format, `--${options.mode}`];
if (options.unsigned) args.push("--no-codesign");
if (options.environment === "staging") args.push("--flavor", "staging");
if (options.releaseLane === "north-america-staging") {
  args.push(`--export-options-plist=${process.env.MOMCOZY_B_EXPORT_OPTIONS_PLIST}`);
}
args.push(...dartDefines);
run("flutter", args);
