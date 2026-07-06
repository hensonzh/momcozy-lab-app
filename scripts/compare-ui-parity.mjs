#!/usr/bin/env node

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pixelmatch from "pixelmatch";
import { PNG } from "pngjs";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const viewport = process.env.MOMCOZY_UI_PARITY_VIEWPORT || "compact_390x844";
const legacyDir =
  process.env.MOMCOZY_UI_PARITY_LEGACY_DIR ||
  path.join(repoRoot, "test", "screenshots", "legacy_web", viewport);
const flutterDir =
  process.env.MOMCOZY_UI_PARITY_FLUTTER_DIR ||
  path.join(repoRoot, "flutter_app", "test", "goldens", "feature_pages");
const outputDir =
  process.env.MOMCOZY_UI_PARITY_OUTPUT_DIR ||
  path.join(repoRoot, "test", "reports", "ui_parity", viewport);
const diffDir = path.join(outputDir, "diffs");
const triptychDir = path.join(outputDir, "triptychs");

const pixelThreshold = numberFromEnv("MOMCOZY_UI_PARITY_PIXEL_THRESHOLD", 0.12);
const warnRatio = numberFromEnv("MOMCOZY_UI_PARITY_WARN_RATIO", 0.015);
const maxDiffRatio = numberFromEnv("MOMCOZY_UI_PARITY_MAX_DIFF_RATIO", warnRatio);
const failOnThreshold = process.env.MOMCOZY_UI_PARITY_FAIL === "1";

const pagePairs = [
  { id: "agent_hub", label: "Agent Hub", legacy: "agent_hub.png", flutter: "agent_hub_mobile.png" },
  { id: "status", label: "宝宝和我", legacy: "status.png", flutter: "status_page_mobile.png" },
  { id: "schedule", label: "计划", legacy: "schedule.png", flutter: "schedule_page_mobile.png" },
  { id: "device", label: "设备", legacy: "device.png", flutter: "device_page_mobile.png" },
  { id: "device_manage", label: "设备提醒", legacy: "device_manage.png", flutter: "device_manage_page_mobile.png" },
  { id: "device_user", label: "用户参数", legacy: "device_user.png", flutter: "device_user_page_mobile.png" },
  { id: "w1", label: "W1", legacy: "w1.png", flutter: "w1_page_mobile.png" },
  { id: "hospital_bag_cart", label: "待产包", legacy: "hospital_bag_cart.png", flutter: "hospital_bag_page_mobile.png" },
  { id: "ibclc_chat", label: "IBCLC", legacy: "ibclc_chat.png", flutter: "ibclc_page_mobile.png" },
  { id: "calibration", label: "舒适负压调节", legacy: "calibration.png", flutter: "calibration_page_mobile.png" },
  { id: "community", label: "社区", legacy: "community.png", flutter: "community_page_mobile.png" },
];

await main();

async function main() {
  await mkdir(diffDir, { recursive: true });
  await mkdir(triptychDir, { recursive: true });

  const results = [];
  for (const pair of pagePairs) {
    results.push(await comparePair(pair));
  }

  results.sort((a, b) => b.diffRatio - a.diffRatio);

  const report = buildMarkdownReport(results);
  const jsonReport = {
    generatedAt: new Date().toISOString(),
    viewport,
    legacyDir: relativePath(legacyDir),
    flutterDir: relativePath(flutterDir),
    outputDir: relativePath(outputDir),
    pixelThreshold,
    warnRatio,
    maxDiffRatio,
    failOnThreshold,
    pages: results,
  };

  await writeFile(path.join(outputDir, "report.md"), report);
  await writeFile(path.join(outputDir, "summary.json"), `${JSON.stringify(jsonReport, null, 2)}\n`);

  const failed = results.filter((result) => result.status === "review");
  console.log(`UI parity report written to ${relativePath(path.join(outputDir, "report.md"))}`);
  console.log(`${failed.length}/${results.length} pages require visual review at warn ratio ${(warnRatio * 100).toFixed(2)}%.`);

  if (failOnThreshold) {
    const thresholdFailures = results.filter((result) => result.diffRatio > maxDiffRatio);
    if (thresholdFailures.length > 0) {
      console.error(
        `UI parity gate failed: ${thresholdFailures.length} page(s) exceed ${(maxDiffRatio * 100).toFixed(2)}%.`,
      );
      process.exitCode = 1;
    }
  }
}

async function comparePair(pair) {
  const legacyPath = path.join(legacyDir, pair.legacy);
  const flutterPath = path.join(flutterDir, pair.flutter);
  const [legacy, flutter] = await Promise.all([readPng(legacyPath), readPng(flutterPath)]);
  const width = Math.max(legacy.width, flutter.width);
  const height = Math.max(legacy.height, flutter.height);
  const normalizedLegacy = normalizePng(legacy, width, height);
  const normalizedFlutter = normalizePng(flutter, width, height);
  const diff = new PNG({ width, height });

  const diffPixels = pixelmatch(
    normalizedLegacy.data,
    normalizedFlutter.data,
    diff.data,
    width,
    height,
    { threshold: pixelThreshold },
  );
  const totalPixels = width * height;
  const diffRatio = diffPixels / totalPixels;
  const diffFile = `diffs/${pair.id}.png`;
  const triptychFile = `triptychs/${pair.id}.png`;

  await Promise.all([
    writePng(path.join(outputDir, diffFile), diff),
    writePng(path.join(outputDir, triptychFile), buildTriptych(normalizedLegacy, normalizedFlutter, diff)),
  ]);

  return {
    id: pair.id,
    label: pair.label,
    status: diffRatio > warnRatio ? "review" : "ok",
    diffPixels,
    totalPixels,
    diffRatio,
    legacySize: `${legacy.width}x${legacy.height}`,
    flutterSize: `${flutter.width}x${flutter.height}`,
    normalizedSize: `${width}x${height}`,
    legacyFile: relativePath(legacyPath),
    flutterFile: relativePath(flutterPath),
    diffFile,
    triptychFile,
  };
}

async function readPng(filePath) {
  const buffer = await readFile(filePath);
  return PNG.sync.read(buffer);
}

async function writePng(filePath, png) {
  await writeFile(filePath, PNG.sync.write(png));
}

function normalizePng(source, width, height) {
  if (source.width === width && source.height === height) return source;

  const target = new PNG({ width, height });
  fill(target, 255, 255, 255, 255);
  blit(source, target, 0, 0);
  return target;
}

function buildTriptych(legacy, flutter, diff) {
  const gutter = 12;
  const width = legacy.width * 3 + gutter * 2;
  const height = legacy.height;
  const triptych = new PNG({ width, height });
  fill(triptych, 255, 255, 255, 255);
  blit(legacy, triptych, 0, 0);
  blit(flutter, triptych, legacy.width + gutter, 0);
  blit(diff, triptych, legacy.width * 2 + gutter * 2, 0);
  return triptych;
}

function blit(source, target, offsetX, offsetY) {
  for (let y = 0; y < source.height; y += 1) {
    for (let x = 0; x < source.width; x += 1) {
      const targetX = x + offsetX;
      const targetY = y + offsetY;
      if (targetX >= target.width || targetY >= target.height) continue;
      const sourceIndex = (source.width * y + x) << 2;
      const targetIndex = (target.width * targetY + targetX) << 2;
      target.data[targetIndex] = source.data[sourceIndex];
      target.data[targetIndex + 1] = source.data[sourceIndex + 1];
      target.data[targetIndex + 2] = source.data[sourceIndex + 2];
      target.data[targetIndex + 3] = source.data[sourceIndex + 3];
    }
  }
}

function fill(png, r, g, b, a) {
  for (let index = 0; index < png.data.length; index += 4) {
    png.data[index] = r;
    png.data[index + 1] = g;
    png.data[index + 2] = b;
    png.data[index + 3] = a;
  }
}

function buildMarkdownReport(results) {
  const rows = results
    .map((result, index) => {
      const status = result.status === "review" ? "REVIEW" : "OK";
      return [
        index + 1,
        status,
        result.label,
        percent(result.diffRatio),
        result.diffPixels.toLocaleString("en-US"),
        result.normalizedSize,
        `[triptych](${result.triptychFile})`,
        `[diff](${result.diffFile})`,
      ].join(" | ");
    })
    .map((row) => `| ${row} |`)
    .join("\n");

  const reviewCount = results.filter((result) => result.status === "review").length;
  return `# Flutter UI Parity Report

Generated: ${new Date().toISOString()}

Legacy source: \`${relativePath(legacyDir)}\`  
Flutter source: \`${relativePath(flutterDir)}\`  
Viewport: \`${viewport}\`  
Pixel threshold: \`${pixelThreshold}\`  
Review threshold: \`${percent(warnRatio)}\`

${reviewCount} of ${results.length} pages require review.

| Rank | Status | Page | Diff | Pixels | Size | Side-by-side | Diff |
|---:|---|---|---:|---:|---|---|---|
${rows}

Notes:

- Side-by-side images are ordered as legacy Web, Flutter, diff.
- This report is a triage aid. Pixel differences from fonts, antialiasing, and animation timing still need human review.
- Set \`MOMCOZY_UI_PARITY_FAIL=1\` and \`MOMCOZY_UI_PARITY_MAX_DIFF_RATIO\` to use this as a CI gate.
`;
}

function numberFromEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`${name} must be a non-negative number; received ${raw}`);
  }
  return value;
}

function percent(value) {
  return `${(value * 100).toFixed(2)}%`;
}

function relativePath(filePath) {
  return path.relative(repoRoot, filePath) || ".";
}
