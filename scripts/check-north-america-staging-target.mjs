#!/usr/bin/env node
// Static declaration check only. No build, DNS request, cloud operation or publish.
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { resolveFlutterApiConfig } from "./flutter-api-config.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const examplePath = "config/release-lanes/north-america-staging.json.example";
const targetPath = "config/release-lanes/north-america-staging.json";
const approvedApiOrigins = {
  productApiBaseUrl: "https://backend-us-dev.lute-momcozylab.luteos.cloud",
  agentApiBaseUrl: "https://agent-us-dev.lute-momcozylab.luteos.cloud",
};
const keys = [
  "deploymentTarget", "runtimeEnvironment", "productApiBaseUrl",
  "agentApiBaseUrl", "androidApplicationId", "iosBundleId",
];

if (process.argv.includes("--help")) {
  console.log(`Usage: node scripts/check-north-america-staging-target.mjs [--config ${targetPath}]\nCopy ${examplePath} to the ignored target file, then fill approved non-secret values. This check does not authorize a release.`);
  process.exit(0);
}
if (process.argv.length !== 2 &&
    !(process.argv.length === 4 && process.argv[2] === "--config")) {
  console.error("FAIL Expected optional --config <path>.");
  process.exit(2);
}
const configPath = path.resolve(root, process.argv[3] || targetPath);
function load(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

try {
  const target = load(configPath);
  const legacy = load(path.join(root, "config/environments/staging.json"));
  if (!target || Array.isArray(target) || typeof target !== "object" ||
      keys.some((key) => typeof target[key] !== "string" || !target[key].trim() || target[key].trim() === "TBD") ||
      Object.keys(target).some((key) => !keys.includes(key))) {
    throw new Error("B target declaration must fill exactly the approved fields; TBD is not release-ready.");
  }
  if (target.deploymentTarget !== "north-america-staging" || target.runtimeEnvironment !== "staging") {
    throw new Error("B must use deploymentTarget=north-america-staging and runtimeEnvironment=staging.");
  }
  const config = resolveFlutterApiConfig({
    flavor: "staging",
    productUrl: target.productApiBaseUrl,
    agentUrl: target.agentApiBaseUrl,
  });
  for (const [name, url, oldUrl] of [
    ["productApiBaseUrl", config.productUrl, legacy.MOMCOZY_API_BASE_URL],
    ["agentApiBaseUrl", config.agentUrl, legacy.MOMCOZY_AGENT_API_BASE_URL],
  ]) {
    const host = new URL(url).hostname.toLowerCase();
    if (/\.(?:test|example|invalid|localhost)$/.test(host) ||
        host === new URL(oldUrl).hostname.toLowerCase() ||
        host === new URL(legacy.MOMCOZY_API_BASE_URL).hostname.toLowerCase() ||
        host === new URL(legacy.MOMCOZY_AGENT_API_BASE_URL).hostname.toLowerCase()) {
      throw new Error(`${name} must use a real B hostname distinct from both A endpoints.`);
    }
    if (url !== approvedApiOrigins[name]) {
      throw new Error(`${name} must match the approved B HTTPS origin.`);
    }
  }
  const gradle = readFileSync(path.join(root, "android/app/build.gradle.kts"), "utf8");
  const aBaseId = gradle.match(/applicationId\s*=\s*"([^"]+)"/)?.[1];
  const aSuffix = gradle.match(/create\("staging"\)\s*\{[\s\S]*?applicationIdSuffix\s*=\s*"([^"]+)"/)?.[1];
  if (!aBaseId || !aSuffix) throw new Error("Cannot determine the A Android application ID from Gradle.");
  const androidId = target.androidApplicationId;
  const iosId = target.iosBundleId;
  if (!/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/.test(androidId) ||
      androidId === `${aBaseId}${aSuffix}`) {
    throw new Error("androidApplicationId must be a reviewed B Play package distinct from the A APK.");
  }
  const playId = gradle.match(/create\("play"\)\s*\{[^}]*applicationId\s*=\s*"([^"]+)"/)?.[1];
  if (androidId !== playId) {
    throw new Error("androidApplicationId must match the native play flavor applicationId.");
  }
  if (!/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(iosId) ||
      iosId === "com.momcozymai.app.flutterpoc") {
    throw new Error("iosBundleId must be an approved, non-provisional B App ID.");
  }
  console.log(`B target declaration passes static checks for ${androidId}; cloud isolation, signing, contracts and stores remain unverified. No build or release was performed.`);
} catch (error) {
  console.error(`FAIL ${error.message}${error.code === "ENOENT" ? ` Copy ${examplePath} to ${targetPath} after approval.` : ""}`);
  process.exit(1);
}
