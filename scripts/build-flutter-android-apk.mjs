#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { withFlutterApiDartDefines } from "./flutter-api-config.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = projectRoot;

if (process.argv.includes("--help")) {
  console.log(`Usage:
  node scripts/build-flutter-android-apk.mjs [--check-config] \\
    --mode <debug|release> \\
    --flavor <local|staging|production> \\
    [--format <apk|appbundle>] \\
    [--dart-define=KEY=VALUE]
`);
  process.exit(0);
}

const options = parseArgs(process.argv.slice(2));
try {
  options.dartDefines = withFlutterApiDartDefines({
    flavor: options.flavor,
    dartDefines: options.dartDefines,
  });
} catch (error) {
  fail(error.message);
}

if (options.checkConfig) {
  console.log(
    `Flutter Android ${options.format} config is valid for ${options.flavor}.`,
  );
  process.exit(0);
}

const buildVariant = `${options.flavor}${capitalize(options.mode)}`;
const artifactPath = options.format === "apk"
  ? path.join(
      flutterAppDir,
      "build",
      "app",
      "outputs",
      "flutter-apk",
      `app-${options.flavor}-${options.mode}.apk`,
    )
  : path.join(
      flutterAppDir,
      "build",
      "app",
      "outputs",
      "bundle",
      buildVariant,
      `app-${options.flavor}-${options.mode}.aab`,
    );
const removeWasm = options.mode === "release";

let buildFailure;
let restoreFailure;

try {
  if (removeWasm) {
    // Release artifacts must not reuse an AOT snapshot from another revision.
    run("flutter", ["clean"], flutterAppDir);
    run("flutter", ["pub", "get"], flutterAppDir);
    run("dart", ["run", "pdfrx:remove_wasm_modules"], flutterAppDir);
  }
  run(
    "flutter",
    [
      "build",
      options.format,
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

verifyPdfPackaging(artifactPath, {
  release: removeWasm,
  appBundle: options.format === "appbundle",
});
console.log(
  `Verified Android ${options.format}: ${path.relative(projectRoot, artifactPath)}`,
);

function parseArgs(args) {
  let mode = "";
  let flavor = "";
  let format = "apk";
  let checkConfig = false;
  const dartDefines = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--check-config") {
      checkConfig = true;
    } else if (arg === "--mode") {
      mode = args[++index] || "";
    } else if (arg.startsWith("--mode=")) {
      mode = arg.slice("--mode=".length);
    } else if (arg === "--flavor") {
      flavor = args[++index] || "";
    } else if (arg.startsWith("--flavor=")) {
      flavor = arg.slice("--flavor=".length);
    } else if (arg === "--format") {
      format = args[++index] || "";
    } else if (arg.startsWith("--format=")) {
      format = arg.slice("--format=".length);
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
  if (!["apk", "appbundle"].includes(format)) {
    fail(`Unsupported --format: ${format || "(empty)"}`);
  }
  if (dartDefines.some((value) => !value.includes("="))) {
    fail("Every --dart-define must use KEY=VALUE format.");
  }

  return { mode, flavor, format, dartDefines, checkConfig };
}

function verifyPdfPackaging(targetArtifact, { release, appBundle }) {
  if (!existsSync(targetArtifact)) {
    fail(`Missing Android artifact: ${targetArtifact}`);
  }
  const result = spawnSync("unzip", ["-Z1", targetArtifact], {
    cwd: projectRoot,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
  if (result.status !== 0) {
    fail(`Could not inspect Android artifact: ${result.stderr || result.stdout}`);
  }
  const entries = new Set(result.stdout.split(/\r?\n/));
  const prefix = appBundle ? "base/" : "";
  if (!entries.has(`${prefix}lib/arm64-v8a/libpdfium.so`)) {
    fail("Android artifact is missing lib/arm64-v8a/libpdfium.so.");
  }
  const wasmAsset =
    `${prefix}assets/flutter_assets/packages/pdfrx/assets/pdfium.wasm`;
  if (release && entries.has(wasmAsset)) {
    fail("Release Android artifact still contains the pdfrx PDFium WASM module.");
  }
}

function capitalize(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
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
