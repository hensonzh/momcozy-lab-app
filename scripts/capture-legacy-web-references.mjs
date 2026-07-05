#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const legacyWebRoot = path.resolve(
  repoRoot,
  process.env.MOMCOZY_LEGACY_WEB_ROOT || "legacy_web",
);

const viewport = {
  width: numberFromEnv("MOMCOZY_REFERENCE_WIDTH", 390),
  height: numberFromEnv("MOMCOZY_REFERENCE_HEIGHT", 844),
};
const host = process.env.MOMCOZY_REFERENCE_HOST || "127.0.0.1";
const port = numberFromEnv("MOMCOZY_REFERENCE_PORT", 4187);
const baseUrl = `http://${host}:${port}`;
const outputRoot = path.join(
  repoRoot,
  "test",
  "screenshots",
  "legacy_web",
  `compact_${viewport.width}x${viewport.height}`,
);
const fixedNowIso =
  process.env.MOMCOZY_REFERENCE_NOW || "2026-07-03T09:00:00+08:00";
const stabilizeMs = numberFromEnv("MOMCOZY_REFERENCE_STABILIZE_MS", 1200);

const routes = [
  { id: "agent_hub", path: "/" },
  { id: "status", path: "/status" },
  { id: "schedule", path: "/schedule" },
  { id: "device", path: "/device" },
  { id: "device_manage", path: "/device/manage" },
  { id: "device_user", path: "/device/user" },
  { id: "w1", path: "/w1" },
  { id: "hospital_bag_cart", path: "/hospital-bag-cart" },
  { id: "ibclc_chat", path: "/ibclc-chat.html" },
  { id: "media_viewer", path: "/media-viewer" },
  { id: "pump", path: "/pump" },
  { id: "calibration", path: "/calibration" },
  { id: "records", path: "/records" },
  { id: "community", path: "/community" },
  { id: "not_found", path: "/__reference_not_found__" },
];

const stableCss = `
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    caret-color: transparent !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
  video, canvas { visibility: visible !important; }
`;

async function main() {
  const server = startViteServer();
  let browser;
  try {
    await waitForServer(`${baseUrl}/`);
    await rm(outputRoot, { recursive: true, force: true });
    await mkdir(outputRoot, { recursive: true });

    browser = await launchBrowser();
    const context = await browser.newContext({
      colorScheme: "light",
      deviceScaleFactor: 1,
      hasTouch: true,
      isMobile: true,
      locale: "zh-CN",
      reducedMotion: "reduce",
      timezoneId: "Asia/Shanghai",
      viewport,
    });
    await context.addInitScript(
      ({ fixedNow }) => {
        const originalDate = Date;
        class FixedDate extends originalDate {
          constructor(...args) {
            super(...(args.length === 0 ? [fixedNow] : args));
          }

          static now() {
            return fixedNow;
          }
        }
        FixedDate.UTC = originalDate.UTC;
        FixedDate.parse = originalDate.parse;
        FixedDate.prototype = originalDate.prototype;
        window.Date = FixedDate;
        window.localStorage.setItem("momcozy_reference_capture", "1");
      },
      { fixedNow: Date.parse(fixedNowIso) },
    );

    const manifest = {
      source: "legacy-web",
      command: "npm run ui:legacy-reference",
      baseUrl,
      fixedNowIso,
      legacyWebRoot: path.relative(repoRoot, legacyWebRoot),
      viewport,
      routes: [],
    };

    for (const route of routes) {
      const page = await context.newPage();
      const consoleErrors = [];
      page.on("console", (message) => {
        if (message.type() === "error") consoleErrors.push(message.text());
      });
      page.on("pageerror", (error) => consoleErrors.push(error.message));

      const url = new URL(route.path, baseUrl).toString();
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30_000 });
      await page.addStyleTag({ content: stableCss });
      await page.waitForTimeout(stabilizeMs);

      const fileName = `${route.id}.png`;
      const screenshotPath = path.join(outputRoot, fileName);
      await page.screenshot({ path: screenshotPath, fullPage: false });
      const bytes = await readFile(screenshotPath);

      manifest.routes.push({
        id: route.id,
        path: route.path,
        file: fileName,
        sha256: createHash("sha256").update(bytes).digest("hex"),
        bytes: bytes.length,
        consoleErrorCount: consoleErrors.length,
      });
      await page.close();
      console.log(`captured ${route.path} -> ${path.relative(repoRoot, screenshotPath)}`);
    }

    await writeFile(
      path.join(outputRoot, "manifest.json"),
      `${JSON.stringify(manifest, null, 2)}\n`,
    );
    console.log(`legacy web references written to ${path.relative(repoRoot, outputRoot)}`);
  } finally {
    if (browser) await closeBrowser(browser);
    await stopServer(server);
  }
}

function numberFromEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${name} must be a positive number; received ${raw}`);
  }
  return value;
}

function startViteServer() {
  const viteBin = process.platform === "win32" ? "vite.cmd" : "vite";
  const child = spawn(
    viteBin,
    ["--host", host, "--port", String(port), "--strictPort"],
    {
      cwd: legacyWebRoot,
      env: {
        ...process.env,
        BROWSER: "none",
        PATH: `${path.join(legacyWebRoot, "node_modules", ".bin")}${path.delimiter}${process.env.PATH || ""}`,
        VITE_API_BASE_URL:
          process.env.VITE_API_BASE_URL || "http://127.0.0.1:8769",
      },
      detached: process.platform !== "win32",
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  const logs = [];
  const collect = (chunk) => {
    const text = chunk.toString();
    logs.push(text);
    if (process.env.MOMCOZY_REFERENCE_VERBOSE === "1") process.stdout.write(text);
  };
  child.stdout.on("data", collect);
  child.stderr.on("data", collect);
  child.recentLogs = () => logs.join("").slice(-4000);
  return child;
}

async function waitForServer(url) {
  const deadline = Date.now() + 30_000;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Timed out waiting for ${url}: ${lastError?.message || "no response"}`);
}

async function launchBrowser() {
  const preferredChannel = process.env.PLAYWRIGHT_CHANNEL || "chrome";
  try {
    return await chromium.launch({ channel: preferredChannel, headless: true });
  } catch (channelError) {
    try {
      return await chromium.launch({ headless: true });
    } catch (bundledError) {
      throw new Error(
        [
          `Unable to launch Playwright Chromium.`,
          `Tried channel "${preferredChannel}" and bundled Chromium.`,
          `Install a browser with: npx playwright install chromium`,
          `Channel error: ${channelError.message}`,
          `Bundled error: ${bundledError.message}`,
        ].join("\n"),
      );
    }
  }
}

async function stopServer(child) {
  if (!child) return;
  signalServer(child, "SIGTERM");
  await Promise.race([
    new Promise((resolve) => child.once("exit", resolve)),
    new Promise((resolve) => setTimeout(resolve, 3000)),
  ]);
  if (child.exitCode === null && child.signalCode === null) {
    signalServer(child, "SIGKILL");
  }
  child.stdout?.destroy();
  child.stderr?.destroy();
  child.unref();
}

async function closeBrowser(browser) {
  await Promise.race([
    browser.close(),
    new Promise((resolve) => setTimeout(resolve, 3000)),
  ]);
}

function signalServer(child, signal) {
  try {
    if (process.platform === "win32") {
      child.kill(signal);
    } else {
      process.kill(-child.pid, signal);
    }
  } catch {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill(signal);
    }
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
