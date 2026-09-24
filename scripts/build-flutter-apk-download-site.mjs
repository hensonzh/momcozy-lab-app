#!/usr/bin/env node
import { copyFile, mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  assertNoReservedApiDartDefines,
  withFlutterApiDartDefines,
} from "./flutter-api-config.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = projectRoot;
const defaultDistDir = path.join(projectRoot, "dist", "android-apk");
const defaultBaseUrl = "https://download.momcozy.ai/app";
const qrLabel = "momcozy AI";
const qrFileName = "momcozy-lab-download-qr.svg";

if (process.argv.includes("--help")) {
  console.log(`Usage:
  MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app make flutter-apk-download-site
  node scripts/build-flutter-apk-download-site.mjs --check-config

Environment:
  MOMCOZY_DOWNLOAD_BASE_URL     Public HTTPS URL of the uploaded dist/android-apk directory.
                                Default: ${defaultBaseUrl}
  MOMCOZY_GITHUB_RELEASE_REPO   Public GitHub repository used for APK release assets,
                                e.g. hensonzh/momcozy-lab-releases.
  MOMCOZY_APK_FLAVOR            local | unified | production. Default: unified
  MOMCOZY_APK_MODE              debug | release. Default: release
  MOMCOZY_API_BASE_URL          Product Backend API URL. Required outside local.
  MOMCOZY_AGENT_API_BASE_URL    Agent Runtime API URL. Required outside local.
  MOMCOZY_APK_INPUT             Existing APK path. When set, skips Flutter build.
  MOMCOZY_SKIP_APK_BUILD        Set to 1 to use the expected APK output path without building.
  MOMCOZY_DOWNLOAD_DIST         Output directory. Default: dist/android-apk
  MOMCOZY_APK_DART_DEFINES      Other comma-separated --dart-define pairs; the
                                two API URL keys are reserved.
  MOMCOZY_REQUIRE_RELEASE_SIGNING Set to 1 to fail release builds without signing env.
`);
  process.exit(0);
}

const flavor = envText("MOMCOZY_APK_FLAVOR", "unified");
const mode = envText("MOMCOZY_APK_MODE", "release");
const runtimeEnvironment = flavor === "unified" ? "test" : flavor;
let dartDefines;
try {
  assertMode(mode);
  assertFlavor(flavor);
  const extraDartDefines = parseDartDefines(
    envText("MOMCOZY_APK_DART_DEFINES", ""),
  );
  assertNoReservedApiDartDefines(extraDartDefines, {
    sourceName: "MOMCOZY_APK_DART_DEFINES",
  });
  dartDefines = withFlutterApiDartDefines({
    flavor,
    dartDefines: [
      `MOMCOZY_API_BASE_URL=${envText("MOMCOZY_API_BASE_URL", "")}`,
      `MOMCOZY_AGENT_API_BASE_URL=${envText("MOMCOZY_AGENT_API_BASE_URL", "")}`,
      ...extraDartDefines,
    ],
  });
} catch (error) {
  console.error(`FAIL ${error.message}`);
  process.exit(1);
}

if (process.argv.includes("--check-config")) {
  console.log(`Flutter APK download config is valid for ${flavor}.`);
  process.exit(0);
}

const QRCode = await loadQrCodeLibrary();

const toolchainConfig = JSON.parse(
  await readFile(path.join(projectRoot, "flutter-toolchain.json"), "utf8"),
);
const pubspec = await readFile(path.join(flutterAppDir, "pubspec.yaml"), "utf8");
const version = parsePubspecVersion(pubspec);
const baseUrl = normalizeBaseUrl(envText("MOMCOZY_DOWNLOAD_BASE_URL", defaultBaseUrl));
const githubReleaseRepo = envText("MOMCOZY_GITHUB_RELEASE_REPO", "");
const distDir = path.resolve(envText("MOMCOZY_DOWNLOAD_DIST", defaultDistDir));
const releaseDir = path.join(distDir, "releases");
const assetDir = path.join(distDir, "assets");
const pageUrl = `${baseUrl}/`;
const apkInput = envText("MOMCOZY_APK_INPUT", "");
const skipBuild = envFlag("MOMCOZY_SKIP_APK_BUILD");
const buildApkPath =
  apkInput || path.join(flutterAppDir, "build", "app", "outputs", "flutter-apk", `app-${flavor}-${mode}.apk`);
const artifactName =
  flavor === "unified"
    ? `momcozy-unified-android-test-${version.versionName}-${version.buildNumber}.apk`
    : `momcozy-android-${flavor}-${version.versionName}-${version.buildNumber}.apk`;
const artifactPath = path.join(releaseDir, artifactName);
const provenanceFile = `${artifactName}.provenance.json`;
const githubReleaseTag =
  flavor === "unified"
    ? `unified-android-v${version.versionName}-${version.buildNumber}`
    : `android-v${version.versionName}-${version.buildNumber}`;
const sourceServices = {
  productBackend: releaseServiceIdentity("MOMCOZY_BACKEND"),
  agentRuntime: releaseServiceIdentity("MOMCOZY_AGENT"),
};

assertGithubReleaseRepo(githubReleaseRepo);
checkReleaseSigning({ mode });

if (!apkInput && !skipBuild) {
  buildApk({ flavor, mode, dartDefines });
} else {
  console.log(`Using existing APK: ${path.relative(projectRoot, buildApkPath)}`);
}

if (!existsSync(buildApkPath)) {
  console.error(`Missing APK: ${buildApkPath}`);
  console.error("Build it first or pass MOMCOZY_APK_INPUT=/path/to/app.apk.");
  process.exit(1);
}

await mkdir(releaseDir, { recursive: true });
await mkdir(assetDir, { recursive: true });
await copyFile(buildApkPath, artifactPath);

const apkBytes = await readFile(artifactPath);
const apkInfo = await stat(artifactPath);
const sha256 = crypto.createHash("sha256").update(apkBytes).digest("hex");
const generatedAt = new Date().toISOString();
const gitCommit = gitHead();
const signingCertSha256 = optionalSha256(
  "MOMCOZY_APK_SIGNING_CERT_SHA256",
);
const apkPath = `releases/${artifactName}`;
const apkUrl = githubReleaseRepo
  ? `https://github.com/${githubReleaseRepo}/releases/download/${githubReleaseTag}/${artifactName}`
  : `${baseUrl}/${apkPath}`;
const qrCodePath = `assets/${qrFileName}`;
const qrCodeUrl = `${baseUrl}/${qrCodePath}`;
const manifest = {
  app: qrLabel,
  platform: "android",
  flavor,
  runtimeEnvironment,
  mode,
  versionName: version.versionName,
  buildNumber: version.buildNumber,
  apkFile: artifactName,
  apkPath,
  apkUrl,
  pageUrl,
  qrCodePath,
  qrCodeUrl,
  qrCodeLabel: qrLabel,
  sha256,
  sizeBytes: apkInfo.size,
  generatedAt,
  gitCommit,
  signingCertSha256,
  githubReleaseRepo: githubReleaseRepo || null,
  githubReleaseTag: githubReleaseRepo ? githubReleaseTag : null,
  provenanceFile,
  sourceServices,
};

const { generatedAt: _generatedAt, ...immutableProvenance } = manifest;

await writeFile(path.join(releaseDir, `${artifactName}.sha256`), `${sha256}  ${artifactName}\n`);
await writeFile(
  path.join(releaseDir, provenanceFile),
  JSON.stringify(immutableProvenance, null, 2) + "\n",
);
await writeFile(
  path.join(assetDir, qrFileName),
  renderQrCodeSvg(apkUrl, qrLabel),
);
await writeFile(path.join(distDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
await writeFile(path.join(distDir, "index.html"), renderDownloadPage(manifest));

console.log("");
console.log("Android APK download site generated.");
console.log(`Output: ${path.relative(projectRoot, distDir)}`);
console.log(`Page:   ${pageUrl}`);
console.log(`APK:    ${artifactName}`);
console.log(`APK URL:${apkUrl}`);
console.log(`QR:     ${qrCodeUrl}`);
console.log(`SHA256: ${sha256}`);

function buildApk({ flavor, mode, dartDefines }) {
  const env = buildToolchainEnv();
  const buildDartDefines = [
    `MOMCOZY_ENV=${runtimeEnvironment}`,
    ...dartDefines,
  ];
  const args = [
    "scripts/build-flutter-android-apk.mjs",
    "--mode",
    mode,
    "--flavor",
    flavor,
    ...buildDartDefines.map((define) => `--dart-define=${define}`),
  ];
  run("node", ["scripts/check-flutter-android-packaging.mjs"], projectRoot, env);
  run("node", args, projectRoot, env);
}

function buildToolchainEnv() {
  const toolchainRoot =
    process.env.MOMCOZY_TOOLCHAIN_ROOT ||
    expandHome(toolchainConfig.toolchainRootDefault);
  const javaHome =
    process.env.JAVA_HOME ||
    path.join(toolchainRoot, toolchainConfig.jdk.homePath);
  const androidSdkRoot =
    process.env.ANDROID_SDK_ROOT ||
    path.join(toolchainRoot, toolchainConfig.android.sdkPath);
  return {
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
}

function run(command, args, cwd, env) {
  console.log("");
  console.log(`$ ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, { cwd, env, stdio: "inherit" });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function parsePubspecVersion(content) {
  const match = content.match(/^version:\s*([^\n#]+)/m);
  if (!match) {
    throw new Error("Missing version in pubspec.yaml");
  }
  const raw = match[1].trim();
  const [versionName, buildNumber = "1"] = raw.split("+");
  return {
    raw,
    versionName: sanitizeVersionPart(versionName),
    buildNumber: sanitizeVersionPart(buildNumber),
  };
}

function sanitizeVersionPart(value) {
  return String(value || "")
    .trim()
    .replace(/[^0-9A-Za-z._-]/g, "-");
}

function parseDartDefines(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function renderDownloadPage(manifest) {
  const displayVersion = formatDisplayVersion(
    manifest.versionName,
    manifest.buildNumber,
  );
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Momcozy Android 内测包下载</title>
  <style>
    :root {
      --bg: #fbf7f5;
      --card: #fff;
      --text: #342431;
      --muted: #7f6b76;
      --border: #eadde2;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 24px;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      text-align: center;
    }
    main {
      width: min(420px, 100%);
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 24px;
      padding: 32px;
      box-shadow: 0 18px 42px rgba(79, 46, 61, .10);
    }
    h1 { margin: 0; font-size: clamp(26px, 7vw, 34px); line-height: 1.2; }
    .intro { margin: 12px 0 0; color: var(--muted); line-height: 1.6; }
    .version { margin: 18px 0 22px; font-size: 15px; font-weight: 700; }
    .qr-link {
      display: block;
      border-radius: 18px;
      touch-action: manipulation;
      -webkit-tap-highlight-color: rgba(142, 66, 99, .16);
      transition: transform .12s ease, opacity .12s ease;
    }
    .qr-link:active { transform: scale(.985); opacity: .86; }
    .qr { display: block; width: 100%; height: auto; border-radius: 18px; }
    @media (max-width: 700px) {
      body { padding: 16px; }
      main { padding: 26px 22px; }
    }
  </style>
</head>
<body>
  <main>
    <h1>momcozy AI 内测版</h1>
    <p class="intro">使用 Android 手机扫描或点击二维码下载 APK。</p>
    <p class="version">版本 ${escapeHtml(displayVersion)}</p>
    <a class="qr-link" href="${escapeHtml(manifest.apkUrl)}" aria-label="下载 momcozy AI Android APK">
      <img class="qr" src="${escapeHtml(manifest.qrCodePath)}" alt="momcozy AI APK 下载二维码" />
    </a>
  </main>
</body>
</html>
`;
}

function formatDisplayVersion(versionName, buildNumber) {
  const normalizedVersion = String(versionName ?? "");
  const normalizedBuild = String(buildNumber ?? "");
  const zeroPatchVersion = /^(\d+)\.(\d+)\.0$/.exec(normalizedVersion);

  if (zeroPatchVersion && /^\d+$/.test(normalizedBuild)) {
    return `${zeroPatchVersion[1]}.${zeroPatchVersion[2]}.${normalizedBuild}`;
  }

  return normalizedVersion;
}

function renderQrCodeSvg(value, label) {
  const qr = QRCode.create(value, { errorCorrectionLevel: "H" });
  const moduleSize = 8;
  const quietZone = 4;
  const labelHeight = 56;
  const qrSize = (qr.modules.size + quietZone * 2) * moduleSize;
  const canvasHeight = qrSize + labelHeight;
  const pathCommands = [];

  for (let row = 0; row < qr.modules.size; row += 1) {
    for (let column = 0; column < qr.modules.size; column += 1) {
      if (!qr.modules.get(row, column)) continue;
      const x = (column + quietZone) * moduleSize;
      const y = (row + quietZone) * moduleSize;
      pathCommands.push(`M${x} ${y}h${moduleSize}v${moduleSize}h-${moduleSize}z`);
    }
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${qrSize} ${canvasHeight}" role="img" aria-labelledby="title description">
  <title id="title">${escapeXml(label)} APK 下载二维码</title>
  <desc id="description">扫描后直接下载 Android APK</desc>
  <rect width="${qrSize}" height="${canvasHeight}" rx="16" fill="#fff" />
  <path d="${pathCommands.join("")}" fill="#171217" shape-rendering="crispEdges" />
  <text x="${qrSize / 2}" y="${qrSize + 36}" fill="#342431" font-family="Arial, Helvetica, sans-serif" font-size="24" font-weight="700" text-anchor="middle">${escapeXml(label)}</text>
</svg>
`;
}

async function loadQrCodeLibrary() {
  try {
    return (await import("qrcode")).default;
  } catch (error) {
    if (error?.code === "ERR_MODULE_NOT_FOUND") {
      console.error("Missing Node build dependencies. Run npm ci from the repository root.");
      process.exit(1);
    }
    throw error;
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function escapeXml(value) {
  return escapeHtml(value).replace(/'/g, "&apos;");
}

function gitHead() {
  const result = spawnSync("git", ["rev-parse", "HEAD"], {
    cwd: projectRoot,
    encoding: "utf8",
  });
  return result.status === 0 ? result.stdout.trim() : "";
}

function optionalSha256(name) {
  const value = envText(name, "");
  if (!value) return null;
  if (!/^[0-9a-f]{64}$/.test(value)) {
    throw new Error(`${name} must be 64 lowercase hex characters.`);
  }
  return value;
}

function checkReleaseSigning({ mode }) {
  if (mode !== "release") return;
  const signingKeys = [
    "MOMCOZY_FLUTTER_RELEASE_STORE_FILE",
    "MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD",
    "MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS",
    "MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD",
  ];
  const hasReleaseSigning = signingKeys.every((key) => String(process.env[key] || "").trim());
  if (hasReleaseSigning) return;
  const message =
    "release signing env is not fully configured; release APK may use debug signing and should only be used as an internal smoke artifact.";
  if (envFlag("MOMCOZY_REQUIRE_RELEASE_SIGNING")) {
    console.error(`FAIL ${message}`);
    process.exit(1);
  }
  console.warn(`WARN ${message}`);
}

function normalizeBaseUrl(value) {
  const normalized = String(value || "").trim().replace(/\/+$/, "");
  if (!normalized.startsWith("https://") && !normalized.startsWith("http://localhost")) {
    console.warn("WARN MOMCOZY_DOWNLOAD_BASE_URL should be HTTPS for Android downloads.");
  }
  return normalized || defaultBaseUrl;
}

function envText(name, fallback) {
  const value = process.env[name];
  return value === undefined || value === "" ? fallback : value;
}

function envFlag(name) {
  return String(process.env[name] || "").trim() === "1";
}

function assertMode(value) {
  if (!["debug", "release"].includes(value)) {
    throw new Error(`Unsupported MOMCOZY_APK_MODE: ${value}`);
  }
}

function assertFlavor(value) {
  if (!["local", "unified", "production"].includes(value)) {
    throw new Error(`Unsupported MOMCOZY_APK_FLAVOR: ${value}`);
  }
}

function assertGithubReleaseRepo(value) {
  if (value && !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(value)) {
    throw new Error(`Invalid MOMCOZY_GITHUB_RELEASE_REPO: ${value}`);
  }
}

function releaseServiceIdentity(prefix) {
  const values = {
    commit: envText(`${prefix}_COMMIT_SHA`, ""),
    imageDigest: envText(`${prefix}_IMAGE_DIGEST`, ""),
    openapiSha256: envText(`${prefix}_OPENAPI_SHA256`, ""),
  };
  if (Object.values(values).every((value) => !value)) return null;
  if (!/^[0-9a-f]{40}$/.test(values.commit)) {
    throw new Error(`${prefix}_COMMIT_SHA must be a full lowercase commit SHA.`);
  }
  if (!/^sha256:[0-9a-f]{64}$/.test(values.imageDigest)) {
    throw new Error(`${prefix}_IMAGE_DIGEST must be a sha256 digest.`);
  }
  if (!/^[0-9a-f]{64}$/.test(values.openapiSha256)) {
    throw new Error(`${prefix}_OPENAPI_SHA256 must be 64 lowercase hex characters.`);
  }
  return values;
}

function expandHome(value) {
  return String(value || "").startsWith("~/")
    ? path.join(os.homedir(), String(value).slice(2))
    : String(value || "");
}
