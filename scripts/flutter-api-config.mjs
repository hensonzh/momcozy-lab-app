#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { isIP } from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const PRODUCT_API_DEFINE = "MOMCOZY_API_BASE_URL";
export const AGENT_API_DEFINE = "MOMCOZY_AGENT_API_BASE_URL";
export const INVITE_LOGIN_DEFINE = "MOMCOZY_INTERNAL_INVITE_LOGIN";
export const DEFAULT_LOCAL_PRODUCT_API_URL = "http://127.0.0.1:8769";
export const DEFAULT_LOCAL_AGENT_API_URL = "http://127.0.0.1:8010";

const supportedFlavors = new Set([
  "local",
  "staging",
  "production",
]);
const reservedApiDefines = new Set([PRODUCT_API_DEFINE, AGENT_API_DEFINE]);

export function resolveFlutterApiConfig({ flavor, productUrl, agentUrl }) {
  const normalizedFlavor = String(flavor || "").trim();
  if (!supportedFlavors.has(normalizedFlavor)) {
    throw new Error(
      `Unsupported flavor: ${normalizedFlavor || "(empty)"}. Expected local, staging, or production.`,
    );
  }

  const local = normalizedFlavor === "local";
  const resolvedProductUrl = resolveUrl({
    name: PRODUCT_API_DEFINE,
    value: productUrl,
    fallback: local ? DEFAULT_LOCAL_PRODUCT_API_URL : "",
    flavor: normalizedFlavor,
    allowLoopback: local,
  });
  const resolvedAgentUrl = resolveUrl({
    name: AGENT_API_DEFINE,
    value: agentUrl,
    fallback: local ? DEFAULT_LOCAL_AGENT_API_URL : "",
    flavor: normalizedFlavor,
    allowLoopback: local,
  });

  return {
    flavor: normalizedFlavor,
    productUrl: resolvedProductUrl,
    agentUrl: resolvedAgentUrl,
  };
}

export function withFlutterApiDartDefines({ flavor, dartDefines = [] }) {
  const parsedDefines = parseDartDefines(dartDefines);
  const valuesByName = new Map();
  for (const define of parsedDefines) {
    const values = valuesByName.get(define.name) || [];
    values.push(define.value);
    valuesByName.set(define.name, values);
  }

  for (const name of reservedApiDefines) {
    if ((valuesByName.get(name) || []).length > 1) {
      throw new Error(`${name} must be defined exactly once.`);
    }
  }

  const config = resolveFlutterApiConfig({
    flavor,
    productUrl: valuesByName.get(PRODUCT_API_DEFINE)?.[0],
    agentUrl: valuesByName.get(AGENT_API_DEFINE)?.[0],
  });
  const resolvedByName = new Map([
    [PRODUCT_API_DEFINE, config.productUrl],
    [AGENT_API_DEFINE, config.agentUrl],
  ]);
  const emittedReserved = new Set();
  const result = parsedDefines.map((define) => {
    if (!reservedApiDefines.has(define.name)) return define.raw;
    emittedReserved.add(define.name);
    return `${define.name}=${resolvedByName.get(define.name)}`;
  });

  for (const name of reservedApiDefines) {
    if (!emittedReserved.has(name)) {
      result.push(`${name}=${resolvedByName.get(name)}`);
    }
  }
  return result;
}

export function assertNoReservedApiDartDefines(
  dartDefines,
  { sourceName = "extra dart defines" } = {},
) {
  for (const define of parseDartDefines(dartDefines)) {
    if (reservedApiDefines.has(define.name)) {
      throw new Error(
        `${sourceName} must not include ${define.name}; use the first-class environment variable instead.`,
      );
    }
  }
}

export function assertLegacyInviteDartDefines(dartDefines) {
  const parsedDefines = parseDartDefines(dartDefines);
  if (parsedDefines.some((define) => define.name === "MOMCOZY_ENV")) {
    throw new Error("MOMCOZY_ENV is fixed to staging in A release builds.");
  }
  const values = parsedDefines
    .filter((define) => define.name === INVITE_LOGIN_DEFINE);
  if (values.length !== 1 || values[0].value !== "true") {
    throw new Error(`legacy-staging requires exactly one ${INVITE_LOGIN_DEFINE}=true.`);
  }
}

export function assertLegacyReleaseLane(lane) {
  if (String(lane || "").trim() !== "legacy-staging") {
    throw new Error("A staging APK requires MOMCOZY_RELEASE_LANE=legacy-staging.");
  }
}

export function assertLegacyPublishedUrls({ productUrl, agentUrl }) {
  const config = JSON.parse(readFileSync(
    path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../config/environments/staging.json"),
    "utf8",
  ));
  if (productUrl !== config.MOMCOZY_API_BASE_URL ||
      agentUrl !== config.MOMCOZY_AGENT_API_BASE_URL) {
    throw new Error("A publication must use both URLs from config/environments/staging.json, not a B target.");
  }
}

function resolveUrl({ name, value, fallback, flavor, allowLoopback }) {
  const resolved = String(value || fallback || "").trim();
  if (!resolved) {
    throw new Error(`${name} is required for ${flavor} builds.`);
  }

  let parsed;
  try {
    parsed = new URL(resolved);
  } catch {
    throw new Error(`${name} must be an absolute HTTP(S) URL.`);
  }
  if (!["http:", "https:"].includes(parsed.protocol) || !parsed.hostname) {
    throw new Error(`${name} must be an absolute HTTP(S) URL.`);
  }
  if (parsed.username || parsed.password) {
    throw new Error(`${name} must not contain URL credentials.`);
  }
  if (!allowLoopback && isLoopbackOrUnspecifiedHost(parsed.hostname)) {
    throw new Error(`${name} must not use a loopback or unspecified host for ${flavor} builds.`);
  }
  if (!allowLoopback && parsed.protocol !== "https:") {
    throw new Error(`${name} must use HTTPS for ${flavor} builds.`);
  }
  const hostname = parsed.hostname.toLowerCase().replace(/\.$/, "");
  if (
    flavor === "production" &&
    ["example.com", "example.org", "example.net"].some(
      (domain) => hostname === domain || hostname.endsWith(`.${domain}`),
    )
  ) {
    throw new Error(`${name} must not use a placeholder domain for production builds.`);
  }
  return resolved;
}

function parseDartDefines(value) {
  const rawValues = Array.isArray(value)
    ? value
    : String(value || "").split(",");
  return rawValues
    .map((item) => String(item || "").trim())
    .filter(Boolean)
    .map((raw) => {
      const separator = raw.indexOf("=");
      if (separator <= 0) {
        throw new Error(`Invalid dart define: ${raw}. Expected KEY=VALUE.`);
      }
      const name = raw.slice(0, separator).trim();
      const value = raw.slice(separator + 1).trim();
      if (!name) {
        throw new Error(`Invalid dart define: ${raw}. Expected KEY=VALUE.`);
      }
      return { raw: `${name}=${value}`, name, value };
    });
}

function isLoopbackOrUnspecifiedHost(value) {
  const hostname = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/^\[/, "")
    .replace(/\]$/, "")
    .replace(/\.$/, "");

  if (hostname === "localhost" || hostname.endsWith(".localhost")) return true;
  if (hostname === "::" || hostname === "::1") return true;
  if (hostname === "0:0:0:0:0:0:0:0" || hostname === "0:0:0:0:0:0:0:1") {
    return true;
  }
  if (/^::ffff:(?:127\.|7f[0-9a-f]{2}:)/.test(hostname)) return true;

  if (isIP(hostname) === 4) {
    const octets = hostname.split(".").map(Number);
    return octets[0] === 127 || octets.every((octet) => octet === 0);
  }
  return false;
}

function parseCliArgs(args) {
  const options = {
    flavor: "",
    productUrl: "",
    agentUrl: "",
    extraDartDefines: "",
  };
  const remaining = [...args];
  if (remaining[0] === "validate") remaining.shift();

  for (let index = 0; index < remaining.length; index += 1) {
    const arg = remaining[index];
    if (arg === "--flavor") {
      options.flavor = remaining[++index] || "";
    } else if (arg === "--product-url") {
      options.productUrl = remaining[++index] || "";
    } else if (arg === "--agent-url") {
      options.agentUrl = remaining[++index] || "";
    } else if (arg === "--extra-dart-defines") {
      options.extraDartDefines = remaining[++index] || "";
    } else {
      throw new Error(`Unsupported argument: ${arg}`);
    }
  }
  return options;
}

function printHelp() {
  console.log(`Usage:
  node scripts/flutter-api-config.mjs validate \\
    --flavor <local|staging|production> \\
    --product-url <url> --agent-url <url> \\
    [--extra-dart-defines <KEY=VALUE,...>]

local accepts omitted URLs and uses loopback defaults. staging and production
require both HTTPS URLs and reject loopback or unspecified hosts.`);
}

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isMain) {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    printHelp();
    process.exit(0);
  }
  try {
    const options = parseCliArgs(process.argv.slice(2));
    const resolved = resolveFlutterApiConfig(options);
    if (process.env.MOMCOZY_ENFORCE_LEGACY_TARGET === "1") {
      assertLegacyPublishedUrls(resolved);
    }
    assertNoReservedApiDartDefines(options.extraDartDefines, {
      sourceName: "MOMCOZY_EXTRA_DART_DEFINES",
    });
    if (process.env.MOMCOZY_RELEASE_LANE === "legacy-staging") {
      const extras = parseDartDefines(options.extraDartDefines);
      for (const name of [INVITE_LOGIN_DEFINE, "MOMCOZY_ENV"]) {
        if (extras.some((define) => define.name === name)) {
          throw new Error(`MOMCOZY_EXTRA_DART_DEFINES must not include ${name}; the A release wrapper sets it.`);
        }
      }
    }
  } catch (error) {
    console.error(`FAIL ${error.message}`);
    process.exit(1);
  }
}
