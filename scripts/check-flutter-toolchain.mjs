#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
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
const TOOLCHAIN_PATHS = [
  path.join(TOOLCHAIN_ROOT, toolchainConfig.flutter.path, "bin"),
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
    validate: ({ stdout }) => validateFlutter(stdout),
  },
  {
    name: "Java runtime",
    command: "java",
    args: ["-version"],
    hint: "Install a JDK supported by the Android Gradle plugin.",
    validate: ({ stdout, stderr }) => validateJava(`${stdout}\n${stderr}`),
  },
];

const OPTIONAL = [
  {
    name: "Android Debug Bridge",
    command: "adb",
    args: ["version"],
    hint: "Install Android platform-tools before real-device smoke tests.",
    validate: ({ stdout }) => validateAdb(stdout),
  },
];

const PATH_CHECKS = [
  {
    name: "Flutter SDK directory",
    path: path.join(TOOLCHAIN_ROOT, toolchainConfig.flutter.path),
    required: true,
  },
  {
    name: "JDK home",
    path: JAVA_HOME,
    required: true,
  },
  {
    name: "Android SDK platform",
    path: path.join(
      ANDROID_SDK_ROOT,
      "platforms",
      toolchainConfig.android.platform,
    ),
    required: true,
  },
  {
    name: "Android build-tools",
    path: path.join(
      ANDROID_SDK_ROOT,
      "build-tools",
      toolchainConfig.android.buildTools,
    ),
    required: true,
  },
  {
    name: "Android NDK",
    path: path.join(ANDROID_SDK_ROOT, "ndk", toolchainConfig.android.ndk),
    required: true,
  },
  {
    name: "CMake",
    path: path.join(ANDROID_SDK_ROOT, "cmake", toolchainConfig.android.cmake),
    required: true,
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

function validateFlutter(stdout) {
  const expectedVersion = toolchainConfig.flutter.version;
  const expectedChannel = toolchainConfig.flutter.channel;
  try {
    const data = JSON.parse(stdout);
    const actualVersion = data.frameworkVersion || "unknown";
    const actualChannel = data.channel || "unknown";
    if (actualVersion !== expectedVersion || actualChannel !== expectedChannel) {
      return {
        ok: false,
        message: `expected ${expectedVersion} (${expectedChannel}), got ${actualVersion} (${actualChannel})`,
      };
    }
    if (data.dartSdkVersion && !String(data.dartSdkVersion).startsWith(toolchainConfig.dart.version)) {
      return {
        ok: false,
        message: `expected Dart ${toolchainConfig.dart.version}, got ${data.dartSdkVersion}`,
      };
    }
    return { ok: true };
  } catch {
    return {
      ok: false,
      message: "could not parse flutter --version --machine output",
    };
  }
}

function validateJava(output) {
  const expected = String(toolchainConfig.jdk.version).split("+")[0];
  if (!output.includes(expected)) {
    return {
      ok: false,
      message: `expected JDK ${toolchainConfig.jdk.version}, got ${firstLine(output) || "unknown"}`,
    };
  }
  return { ok: true };
}

function validateAdb(stdout) {
  const expected = toolchainConfig.android.platformTools;
  if (!stdout.includes(expected)) {
    return {
      ok: false,
      message: `expected platform-tools ${expected}, got ${firstLine(stdout) || "unknown"}`,
    };
  }
  return { ok: true };
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

  const validation = tool.validate?.({
    stdout: result.stdout,
    stderr: result.stderr,
  });
  if (validation && !validation.ok) {
    return {
      ok: false,
      required,
      line: `${tool.name} version mismatch: ${validation.message}`,
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

function checkPath(entry) {
  if (existsSync(entry.path)) {
    return {
      ok: true,
      required: entry.required,
      line: `${entry.name}: ${entry.path}`,
    };
  }
  return {
    ok: false,
    required: entry.required,
    line: `missing ${entry.name}: ${entry.path}`,
  };
}

const checks = [
  ...PATH_CHECKS.map(checkPath),
  ...REQUIRED.map((tool) => checkTool(tool, true)),
  ...OPTIONAL.map((tool) => checkTool(tool, false)),
];

console.log("Flutter migration toolchain check");
console.log("--------------------------------");
console.log(`toolchain config: ${path.relative(process.cwd(), path.join(projectRoot, "flutter-toolchain.json"))}`);
console.log(`toolchain root: ${TOOLCHAIN_ROOT}`);
for (const check of checks) {
  console.log(`${check.ok ? "OK" : check.required ? "FAIL" : "WARN"} ${check.line}`);
}

const failedRequired = checks.filter((check) => check.required && !check.ok);

if (failedRequired.length > 0) {
  console.error("");
  console.error("Toolchain is not ready.");
  console.error("After installing the missing required tools, rerun make flutter-check.");
  process.exit(1);
}

console.log("");
console.log("Toolchain is ready.");
