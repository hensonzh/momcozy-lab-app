#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";

const TOOLCHAIN_ROOT =
  process.env.MOMCOZY_TOOLCHAIN_ROOT ||
  path.join(os.homedir(), ".local", "share", "momcozy-toolchains");
const JAVA_HOME =
  process.env.JAVA_HOME ||
  path.join(TOOLCHAIN_ROOT, "jdk", "jdk-17.0.19+10", "Contents", "Home");
const ANDROID_SDK_ROOT =
  process.env.ANDROID_SDK_ROOT || path.join(TOOLCHAIN_ROOT, "android-sdk");
const TOOLCHAIN_PATHS = [
  path.join(TOOLCHAIN_ROOT, "flutter", "bin"),
  path.join(JAVA_HOME, "bin"),
  path.join(ANDROID_SDK_ROOT, "cmdline-tools", "latest", "bin"),
  path.join(ANDROID_SDK_ROOT, "platform-tools"),
];
const ENV = {
  ...process.env,
  JAVA_HOME,
  ANDROID_SDK_ROOT,
  ANDROID_HOME: process.env.ANDROID_HOME || ANDROID_SDK_ROOT,
  PATH: [...TOOLCHAIN_PATHS, process.env.PATH || ""].join(path.delimiter),
};

const REQUIRED = [
  {
    name: "Flutter SDK",
    command: "flutter",
    args: ["--version", "--machine"],
    hint: "Install Flutter SDK and add its bin directory to PATH.",
  },
  {
    name: "Java runtime",
    command: "java",
    args: ["-version"],
    hint: "Install a JDK supported by the Android Gradle plugin.",
  },
];

const OPTIONAL = [
  {
    name: "Android Debug Bridge",
    command: "adb",
    args: ["version"],
    hint: "Install Android platform-tools before real-device smoke tests.",
  },
];

function run(command, args) {
  return spawnSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    env: ENV,
    timeout: 15000,
  });
}

function firstLine(value) {
  return String(value || "")
    .trim()
    .split(/\r?\n/)
    .find(Boolean);
}

function describeFlutter(stdout) {
  try {
    const data = JSON.parse(stdout);
    return `${data.frameworkVersion || "unknown"} (${data.channel || "unknown channel"})`;
  } catch {
    return firstLine(stdout) || "available";
  }
}

function checkTool(tool, required) {
  const result = run(tool.command, tool.args);

  if (result.error?.code === "ENOENT") {
    return {
      ok: false,
      required,
      line: `missing ${tool.name}: ${tool.hint}`,
    };
  }

  if (result.error?.code === "ETIMEDOUT") {
    return {
      ok: false,
      required,
      line: `${tool.name} timed out: ${tool.hint}`,
    };
  }

  if (result.status !== 0) {
    return {
      ok: false,
      required,
      line: `${tool.name} returned ${result.status}: ${firstLine(result.stderr) || firstLine(result.stdout) || tool.hint}`,
    };
  }

  const detail =
    tool.command === "flutter"
      ? describeFlutter(result.stdout)
      : firstLine(result.stdout) || firstLine(result.stderr) || "available";

  return {
    ok: true,
    required,
    line: `${tool.name}: ${detail}`,
  };
}

const checks = [
  ...REQUIRED.map((tool) => checkTool(tool, true)),
  ...OPTIONAL.map((tool) => checkTool(tool, false)),
];

console.log("Flutter migration toolchain check");
console.log("--------------------------------");
console.log(`toolchain root: ${TOOLCHAIN_ROOT}`);
for (const check of checks) {
  console.log(`${check.ok ? "OK" : check.required ? "FAIL" : "WARN"} ${check.line}`);
}

const failedRequired = checks.filter((check) => check.required && !check.ok);

if (failedRequired.length > 0) {
  console.error("");
  console.error("Toolchain is not ready. Do not run npm run flutter:init yet.");
  console.error("After installing the missing required tools, rerun npm run flutter:check.");
  process.exit(1);
}

console.log("");
console.log("Toolchain is ready for npm run flutter:init.");
