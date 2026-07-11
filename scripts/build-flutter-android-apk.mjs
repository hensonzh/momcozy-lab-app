#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = path.join(projectRoot, "flutter_app");

if (process.argv.includes("--help")) {
  console.log(`Usage:
  node scripts/build-flutter-android-apk.mjs --mode <debug|release> --flavor <local|staging|production> [--dart-define=KEY=VALUE]
`);
  process.exit(0);
}

const options = parseArgs(process.argv.slice(2));
const apkPath = path.join(
  flutterAppDir,
  "build",
  "app",
  "outputs",
  "flutter-apk",
  `app-${options.flavor}-${options.mode}.apk`,
);
const removeWasm = options.mode === "release";

let buildFailure;
let restoreFailure;

try {
  if (removeWasm) {
    run("dart", ["run", "pdfrx:remove_wasm_modules"], flutterAppDir);
  }
  run(
    "flutter",
    [
      "build",
      "apk",
      `--${options.mode}`,
      "--flavor",
      options.flavor,
      ...options.dartDefines.map((value) => `--dart-define=${value}`),
    ],
    flutterAppDir,
  );
} catch (error) {
  buildFailure = error;
} finally {
  if (removeWasm) {
    try {
      run(
        "dart",
        ["run", "pdfrx:remove_wasm_modules", "--revert"],
        flutterAppDir,
      );
    } catch (error) {
      restoreFailure = error;
    }
  }
}

if (buildFailure || restoreFailure) {
  const failure = buildFailure || restoreFailure;
  if (buildFailure && restoreFailure) {
    console.error(`WARN failed to restore pdfrx assets: ${restoreFailure.message}`);
  }
  console.error(`FAIL ${failure.message}`);
  process.exit(failure.status || 1);
}

verifyPdfPackaging(apkPath, { release: removeWasm });
console.log(`Verified PDF packaging: ${path.relative(projectRoot, apkPath)}`);

function parseArgs(args) {
  let mode = "";
  let flavor = "";
  const dartDefines = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--mode") {
      mode = args[++index] || "";
    } else if (arg.startsWith("--mode=")) {
      mode = arg.slice("--mode=".length);
    } else if (arg === "--flavor") {
      flavor = args[++index] || "";
    } else if (arg.startsWith("--flavor=")) {
      flavor = arg.slice("--flavor=".length);
    } else if (arg === "--dart-define") {
      dartDefines.push(args[++index] || "");
    } else if (arg.startsWith("--dart-define=")) {
      dartDefines.push(arg.slice("--dart-define=".length));
    } else {
      fail(`Unsupported argument: ${arg}`);
    }
  }

  if (!["debug", "release"].includes(mode)) {
    fail(`Unsupported or missing --mode: ${mode || "(empty)"}`);
  }
  if (!["local", "staging", "production"].includes(flavor)) {
    fail(`Unsupported or missing --flavor: ${flavor || "(empty)"}`);
  }
  if (dartDefines.some((value) => !value.includes("="))) {
    fail("Every --dart-define must use KEY=VALUE format.");
  }

  return { mode, flavor, dartDefines };
}

function verifyPdfPackaging(targetApk, { release }) {
  if (!existsSync(targetApk)) {
    fail(`Missing APK: ${targetApk}`);
  }
  const result = spawnSync("unzip", ["-Z1", targetApk], {
    cwd: projectRoot,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
  if (result.status !== 0) {
    fail(`Could not inspect APK: ${result.stderr || result.stdout}`);
  }
  const entries = new Set(result.stdout.split(/\r?\n/));
  if (!entries.has("lib/arm64-v8a/libpdfium.so")) {
    fail("APK is missing lib/arm64-v8a/libpdfium.so.");
  }
  const wasmAsset =
    "assets/flutter_assets/packages/pdfrx/assets/pdfium.wasm";
  if (release && entries.has(wasmAsset)) {
    fail("Release APK still contains the pdfrx PDFium WASM module.");
  }
}

function run(command, args, cwd) {
  console.log("");
  console.log(`$ ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, {
    cwd,
    env: process.env,
    stdio: "inherit",
  });
  if (result.status !== 0) {
    const error = new Error(`${command} exited with status ${result.status}`);
    error.status = result.status ?? 1;
    throw error;
  }
}

function fail(message) {
  console.error(`FAIL ${message}`);
  process.exit(1);
}
