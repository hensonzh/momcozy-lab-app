#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  AGENT_API_DEFINE,
  PRODUCT_API_DEFINE,
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
    if (!["platform", "environment", "mode", "format", "config"].includes(key)) {
      fail(`Unknown argument: ${arg}`);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) fail(`${arg} requires a value.`);
    result[key] = value;
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
if (
  options.platform === "android" &&
  options.environment === "production" &&
  options.mode === "release" &&
  !hasAndroidReleaseSigning()
) {
  fail("Production Android release signing variables are incomplete.");
}

const defaultConfig = path.join(
  projectRoot,
  "config",
  "environments",
  `${options.environment}.json`,
);
const configPath = path.resolve(projectRoot, options.config || defaultConfig);
const config = loadConfig(configPath, options.environment);
const productUrl = String(process.env[PRODUCT_API_DEFINE] || config[PRODUCT_API_DEFINE] || "");
const agentUrl = String(process.env[AGENT_API_DEFINE] || config[AGENT_API_DEFINE] || "");
const resolved = resolveFlutterApiConfig({
  flavor: options.environment,
  productUrl,
  agentUrl,
});
const dartDefines = Object.entries({
  ...config,
  MOMCOZY_ENV: options.environment,
  [PRODUCT_API_DEFINE]: resolved.productUrl,
  [AGENT_API_DEFINE]: resolved.agentUrl,
}).map(([name, value]) => `--dart-define=${name}=${String(value)}`);

console.log(`Environment: ${options.environment}`);
console.log(`Platform:    ${options.platform}`);
console.log(`Mode:        ${options.mode}`);
console.log(`Format:      ${options.format}`);
console.log(`Product API: ${resolved.productUrl}`);
console.log(`Agent API:   ${resolved.agentUrl}`);
console.log(`Config:      ${path.relative(projectRoot, configPath)}`);
if (options.checkConfig) process.exit(0);

if (options.platform === "android") {
  const args = [
    path.join("scripts", "build-flutter-android-apk.mjs"),
    "--mode",
    options.mode,
    "--flavor",
    options.environment,
    "--format",
    options.format,
    ...dartDefines,
  ];
  run("node", args);
  process.exit(0);
}

const args = ["build", options.format, `--${options.mode}`];
if (options.unsigned) args.push("--no-codesign");
args.push(...dartDefines);
run("flutter", args);
