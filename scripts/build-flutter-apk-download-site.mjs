#!/usr/bin/env node
import { copyFile, mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import QRCode from "qrcode";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const flutterAppDir = path.join(projectRoot, "flutter_app");
const defaultDistDir = path.join(projectRoot, "dist", "android-apk");
const defaultBaseUrl = "https://download.momcozy.ai/app";

if (process.argv.includes("--help")) {
  console.log(`Usage:
  MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app npm run flutter:apk-download-site

Environment:
  MOMCOZY_DOWNLOAD_BASE_URL     Public HTTPS URL of the uploaded dist/android-apk directory.
                                Default: ${defaultBaseUrl}
  MOMCOZY_APK_FLAVOR            local | staging | production. Default: staging
  MOMCOZY_APK_MODE              debug | release. Default: release
  MOMCOZY_APK_INPUT             Existing APK path. When set, skips Flutter build.
  MOMCOZY_SKIP_APK_BUILD        Set to 1 to use the expected APK output path without building.
  MOMCOZY_DOWNLOAD_DIST         Output directory. Default: dist/android-apk
  MOMCOZY_APK_DART_DEFINES      Comma-separated --dart-define pairs, e.g. A=1,B=2
  MOMCOZY_REQUIRE_RELEASE_SIGNING Set to 1 to fail release builds without signing env.
`);
  process.exit(0);
}

const toolchainConfig = JSON.parse(
  await readFile(path.join(projectRoot, "flutter-toolchain.json"), "utf8"),
);
const pubspec = await readFile(path.join(flutterAppDir, "pubspec.yaml"), "utf8");
const version = parsePubspecVersion(pubspec);
const flavor = envText("MOMCOZY_APK_FLAVOR", "staging");
const mode = envText("MOMCOZY_APK_MODE", "release");
const baseUrl = normalizeBaseUrl(envText("MOMCOZY_DOWNLOAD_BASE_URL", defaultBaseUrl));
const distDir = path.resolve(envText("MOMCOZY_DOWNLOAD_DIST", defaultDistDir));
const releaseDir = path.join(distDir, "releases");
const assetDir = path.join(distDir, "assets");
const pageUrl = `${baseUrl}/`;
const apkInput = envText("MOMCOZY_APK_INPUT", "");
const skipBuild = envFlag("MOMCOZY_SKIP_APK_BUILD");
const buildApkPath =
  apkInput || path.join(flutterAppDir, "build", "app", "outputs", "flutter-apk", `app-${flavor}-${mode}.apk`);
const artifactName = `momcozy-android-${flavor}-${version.versionName}-${version.buildNumber}.apk`;
const artifactPath = path.join(releaseDir, artifactName);

assertMode(mode);
assertFlavor(flavor);
checkReleaseSigning({ mode });

if (!apkInput && !skipBuild) {
  buildApk({ flavor, mode });
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
await copyFile(path.join(flutterAppDir, "assets", "images", "momcozy_logo.png"), path.join(assetDir, "momcozy_logo.png"));

const apkBytes = await readFile(artifactPath);
const apkInfo = await stat(artifactPath);
const sha256 = crypto.createHash("sha256").update(apkBytes).digest("hex");
const generatedAt = new Date().toISOString();
const gitCommit = gitShortHead();
const apkUrl = `releases/${artifactName}`;
const qrSvg = await QRCode.toString(pageUrl, {
  type: "svg",
  errorCorrectionLevel: "M",
  margin: 2,
  color: {
    dark: "#6f2a4b",
    light: "#ffffff",
  },
});

const manifest = {
  app: "Momcozy",
  platform: "android",
  flavor,
  mode,
  versionName: version.versionName,
  buildNumber: version.buildNumber,
  apkFile: artifactName,
  apkUrl,
  pageUrl,
  sha256,
  sizeBytes: apkInfo.size,
  generatedAt,
  gitCommit,
};

await writeFile(path.join(releaseDir, `${artifactName}.sha256`), `${sha256}  ${artifactName}\n`);
await writeFile(path.join(distDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
await writeFile(path.join(distDir, "qr.svg"), qrSvg);
await writeFile(path.join(distDir, "index.html"), renderDownloadPage(manifest));

console.log("");
console.log("Android APK download site generated.");
console.log(`Output: ${path.relative(projectRoot, distDir)}`);
console.log(`Page:   ${pageUrl}`);
console.log(`APK:    ${artifactName}`);
console.log(`SHA256: ${sha256}`);

function buildApk({ flavor, mode }) {
  const env = buildToolchainEnv();
  const dartDefines = [
    `MOMCOZY_ENV=${flavor}`,
    ...parseDartDefines(envText("MOMCOZY_APK_DART_DEFINES", "")),
  ];
  const args = [
    "build",
    "apk",
    `--${mode}`,
    "--flavor",
    flavor,
    ...dartDefines.map((define) => `--dart-define=${define}`),
  ];
  run("node", ["scripts/check-flutter-android-packaging.mjs"], projectRoot, env);
  run("flutter", args, flutterAppDir, env);
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
    throw new Error("Missing version in flutter_app/pubspec.yaml");
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
  const sizeMb = (manifest.sizeBytes / 1024 / 1024).toFixed(1);
  const generated = new Date(manifest.generatedAt).toLocaleString("zh-CN", { hour12: false });
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
      --primary: #8a3d5b;
      --border: #eadde2;
      --soft: #f7eef2;
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
    }
    main {
      width: min(760px, 100%);
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 24px;
      padding: 28px;
      box-shadow: 0 18px 42px rgba(79, 46, 61, .10);
    }
    .brand { width: 190px; height: auto; display: block; margin-bottom: 24px; }
    h1 { margin: 0 0 10px; font-size: clamp(28px, 5vw, 40px); line-height: 1.15; }
    p { margin: 0; color: var(--muted); line-height: 1.7; }
    .layout { display: grid; grid-template-columns: 1fr 220px; gap: 28px; align-items: start; margin-top: 26px; }
    .qr { width: 220px; padding: 12px; border: 1px solid var(--border); border-radius: 18px; background: #fff; }
    .qr img { width: 100%; height: auto; display: block; }
    .button {
      display: inline-flex;
      justify-content: center;
      align-items: center;
      min-height: 48px;
      padding: 0 24px;
      border-radius: 999px;
      margin: 22px 0 16px;
      background: var(--primary);
      color: #fff;
      text-decoration: none;
      font-weight: 800;
    }
    .meta {
      display: grid;
      gap: 10px;
      margin-top: 16px;
      padding: 16px;
      border-radius: 16px;
      background: var(--soft);
      color: var(--muted);
      font-size: 14px;
    }
    .meta strong { color: var(--text); }
    code { word-break: break-all; color: var(--text); }
    ol { margin: 16px 0 0; padding-left: 22px; color: var(--muted); line-height: 1.75; }
    @media (max-width: 700px) {
      main { padding: 22px; }
      .layout { grid-template-columns: 1fr; }
      .qr { width: 180px; }
    }
  </style>
</head>
<body>
  <main>
    <img class="brand" src="assets/momcozy_logo.png" alt="Momcozy" />
    <h1>Momcozy Android 内测包</h1>
    <p>请使用 Android 手机扫码打开本页，或点击按钮下载 APK。下载后根据系统提示允许安装未知来源应用。</p>
    <div class="layout">
      <section>
        <a class="button" href="${escapeHtml(manifest.apkUrl)}" download>下载 APK</a>
        <div class="meta">
          <div><strong>版本：</strong>${escapeHtml(manifest.versionName)} (${escapeHtml(manifest.buildNumber)})</div>
          <div><strong>渠道：</strong>${escapeHtml(manifest.flavor)} / ${escapeHtml(manifest.mode)}</div>
          <div><strong>大小：</strong>${sizeMb} MB</div>
          <div><strong>生成时间：</strong>${escapeHtml(generated)}</div>
          <div><strong>Git：</strong>${escapeHtml(manifest.gitCommit || "-")}</div>
          <div><strong>SHA256：</strong><code>${escapeHtml(manifest.sha256)}</code></div>
        </div>
        <ol>
          <li>如果浏览器提示风险，请确认下载来源是 Momcozy 内测链接。</li>
          <li>安装时请选择“允许来自此来源的应用”。</li>
          <li>如已安装旧包，遇到签名冲突时请先卸载旧包再安装。</li>
        </ol>
      </section>
      <aside class="qr">
        <img src="qr.svg" alt="APK 下载二维码" />
      </aside>
    </div>
  </main>
</body>
</html>
`;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function gitShortHead() {
  const result = spawnSync("git", ["rev-parse", "--short", "HEAD"], {
    cwd: projectRoot,
    encoding: "utf8",
  });
  return result.status === 0 ? result.stdout.trim() : "";
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
  if (!["local", "staging", "production"].includes(value)) {
    throw new Error(`Unsupported MOMCOZY_APK_FLAVOR: ${value}`);
  }
}

function expandHome(value) {
  return String(value || "").startsWith("~/")
    ? path.join(os.homedir(), String(value).slice(2))
    : String(value || "");
}
