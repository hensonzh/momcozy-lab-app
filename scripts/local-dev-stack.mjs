#!/usr/bin/env node

import {
  chmodSync,
  copyFileSync,
  existsSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(scriptDir, "..");
const workspaceRoot = path.resolve(
  process.env.MOMCOZY_WORKSPACE_ROOT || path.join(appRoot, ".."),
);
const backendRoot = path.join(workspaceRoot, "backend");
const agentRoot = path.join(workspaceRoot, "agent");
const resolvedAppRoot = path.join(workspaceRoot, "app");
const backendEnv = path.join(backendRoot, "env", "compose.local.env");
const agentEnv = path.join(agentRoot, "env", "compose.local.env");
const dryRun = process.env.MOMCOZY_LOCAL_DEV_DRY_RUN === "1";
const productUrl = (
  process.env.MOMCOZY_LOCAL_PRODUCT_URL || "http://127.0.0.1:8769"
).replace(/\/$/, "");
const agentUrl = (
  process.env.MOMCOZY_LOCAL_AGENT_URL || "http://127.0.0.1:8010"
).replace(/\/$/, "");

function printHelp() {
  console.log(`Usage: node scripts/local-dev-stack.mjs <command> [options]

Commands:
  init                 Prepare ignored local env files and validate shared auth settings
  up                   Start Product Backend and Agent Runtime, then verify the stack
  start [flutter args] Start and verify services, then launch the Android app
  app [flutter args]   Verify services, then launch the Android app
  verify               Check readiness, JWT issuance, Product API, and Agent API
  status               Show both Docker Compose projects
  logs [backend|agent] Show recent service logs
  down                 Stop both Docker Compose projects

Environment overrides:
  MOMCOZY_WORKSPACE_ROOT=${workspaceRoot}
  MOMCOZY_LOCAL_PRODUCT_URL=http://127.0.0.1:8769
  MOMCOZY_LOCAL_AGENT_URL=http://127.0.0.1:8010
  MOMCOZY_LOCAL_INVITE_CODE=MOMCOZY-BETA
  MOMCOZY_LOCAL_DEV_SKIP_VERIFY=1
  MOMCOZY_LOCAL_DEV_DRY_RUN=1`);
}

function validateWorkspace() {
  const required = [
    path.join(backendRoot, "docker-compose.local.yml"),
    path.join(backendRoot, "env", "compose.local.env.example"),
    path.join(agentRoot, "docker-compose.local.yml"),
    path.join(agentRoot, "env", "compose.local.env.example"),
  ];
  const missing = required.filter((item) => !existsSync(item));
  if (missing.length > 0) {
    throw new Error(
      `Invalid MomCozy workspace; missing:\n${missing
        .map((item) => `  - ${item}`)
        .join("\n")}`,
    );
  }
}

function copyExampleIfMissing(destination) {
  if (existsSync(destination)) return false;
  copyFileSync(`${destination}.example`, destination);
  chmodSync(destination, 0o600);
  console.log(`Created ${path.relative(workspaceRoot, destination)}`);
  return true;
}

function parseEnv(filePath) {
  const values = new Map();
  for (const rawLine of readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const separator = line.indexOf("=");
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }
    values.set(key, value);
  }
  return values;
}

function updateEnv(filePath, updates) {
  const original = readFileSync(filePath, "utf8");
  const seen = new Set();
  const lines = original.split(/\r?\n/).map((line) => {
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=/);
    if (!match || !Object.hasOwn(updates, match[1])) return line;
    const key = match[1];
    seen.add(key);
    return `${key}=${updates[key]}`;
  });
  for (const [key, value] of Object.entries(updates)) {
    if (!seen.has(key)) lines.push(`${key}=${value}`);
  }
  const updated = `${lines.join("\n").replace(/\n+$/, "")}\n`;
  if (updated === original) return false;
  const temporary = `${filePath}.tmp-${process.pid}`;
  writeFileSync(temporary, updated, { mode: 0o600 });
  renameSync(temporary, filePath);
  chmodSync(filePath, 0o600);
  return true;
}

function generatePrivateKey() {
  const result = spawnSync(
    "openssl",
    ["genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048"],
    { encoding: "buffer", stdio: ["ignore", "pipe", "pipe"] },
  );
  if (result.status !== 0) {
    throw new Error(
      `Unable to generate the local JWT key with openssl: ${String(
        result.stderr || "unknown error",
      ).trim()}`,
    );
  }
  return Buffer.from(result.stdout).toString("base64");
}

function requireEqual(backend, backendKey, agent, agentKey) {
  const left = backend.get(backendKey) || "";
  const right = agent.get(agentKey) || "";
  if (!left || left !== right) {
    throw new Error(
      `Local service contract mismatch: backend ${backendKey} must equal agent ${agentKey}.`,
    );
  }
}

function initEnvironment() {
  validateWorkspace();
  copyExampleIfMissing(backendEnv);
  copyExampleIfMissing(agentEnv);

  const backend = parseEnv(backendEnv);
  const currentKey = backend.get("AUTH_JWT_PRIVATE_KEY_B64") || "";
  if (
    !currentKey ||
    currentKey === "${AUTH_JWT_PRIVATE_KEY_B64}" ||
    currentKey === "replace-me"
  ) {
    updateEnv(backendEnv, { AUTH_JWT_PRIVATE_KEY_B64: generatePrivateKey() });
    console.log("Generated an ignored local JWT signing key.");
  }

  if (
    updateEnv(agentEnv, {
      PRODUCT_BACKEND_BASE_URL: "http://host.docker.internal:8769",
      AUTH_JWKS_URL:
        "http://host.docker.internal:8769/.well-known/jwks.json",
    })
  ) {
    console.log("Synchronized Agent Runtime local Product Backend endpoints.");
  }

  const finalBackend = parseEnv(backendEnv);
  const finalAgent = parseEnv(agentEnv);
  requireEqual(
    finalBackend,
    "AGENT_RUNTIME_SERVICE_API_KEY",
    finalAgent,
    "PRODUCT_BACKEND_SERVICE_KEY",
  );
  requireEqual(
    finalBackend,
    "AUTH_JWT_ISSUER",
    finalAgent,
    "AUTH_JWT_ISSUER",
  );
  requireEqual(
    finalBackend,
    "AUTH_JWT_RUNTIME_AUDIENCE",
    finalAgent,
    "AUTH_JWT_AUDIENCE",
  );
  console.log("Local environment contract is ready.");
}

function printableCommand(command, args) {
  return [command, ...args]
    .map((value) =>
      /^[A-Za-z0-9_./:=@+-]+$/.test(value) ? value : JSON.stringify(value),
    )
    .join(" ");
}

function runRequired(command, args, cwd, options = {}) {
  const display = printableCommand(command, args);
  if (dryRun) {
    console.log(
      `[dry-run] (${path.relative(workspaceRoot, cwd) || "."}) ${display}`,
    );
    return;
  }
  const startedAt = Date.now();
  const result = spawnSync(command, args, {
    cwd,
    env: { ...process.env, ...(options.env || {}) },
    encoding: "utf8",
    stdio: options.capture ? ["ignore", "pipe", "pipe"] : "inherit",
    maxBuffer: 20 * 1024 * 1024,
  });
  if (result.status !== 0) {
    const details = options.capture
      ? [result.stdout, result.stderr].filter(Boolean).join("\n").trim()
      : "";
    throw new Error(`${display} failed${details ? `:\n${details}` : "."}`);
  }
  console.log(
    `Completed in ${((Date.now() - startedAt) / 1000).toFixed(1)}s: ${display}`,
  );
}

function ensureDocker() {
  if (dryRun) return;
  runRequired("docker", ["info"], workspaceRoot, { capture: true });
}

async function requestJson(label, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(10_000),
    headers: {
      Accept: "application/json",
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...(options.headers || {}),
    },
  });
  const responseText = await response.text();
  let body = {};
  if (responseText) {
    try {
      body = JSON.parse(responseText);
    } catch {
      throw new Error(
        `${label} returned non-JSON content (HTTP ${response.status}).`,
      );
    }
  }
  if (!response.ok) {
    const code = body?.error?.code || body?.detail || "request_failed";
    throw new Error(`${label} failed (HTTP ${response.status}, ${code}).`);
  }
  console.log(`PASS ${label}`);
  return body;
}

async function verifyStack() {
  await requestJson(
    "Product Backend readiness",
    `${productUrl}/v1/health/ready`,
  );
  const jwks = await requestJson(
    "Product Backend JWKS",
    `${productUrl}/.well-known/jwks.json`,
  );
  if (!Array.isArray(jwks.keys) || jwks.keys.length === 0) {
    throw new Error("Product Backend JWKS contains no signing key.");
  }
  await requestJson("Agent Runtime readiness", `${agentUrl}/v1/health/ready`);

  const session = await requestJson(
    "invite login",
    `${productUrl}/v1/auth/invite-login`,
    {
      method: "POST",
      body: JSON.stringify({
        invite_code:
          process.env.MOMCOZY_LOCAL_INVITE_CODE || "MOMCOZY-BETA",
        device_id: "momcozy-local-dev-smoke",
      }),
    },
  );
  if (typeof session.access_token !== "string" || !session.access_token) {
    throw new Error("Invite login returned no access token.");
  }
  const authorization = { Authorization: `Bearer ${session.access_token}` };
  await requestJson("authenticated Product API", `${productUrl}/v1/babies`, {
    headers: authorization,
  });
  await requestJson(
    "authenticated Agent API",
    `${agentUrl}/v1/agent/threads?limit=1`,
    { headers: authorization },
  );

  const toolchainCheck = path.join(
    resolvedAppRoot,
    "scripts",
    "check-flutter-toolchain.mjs",
  );
  if (existsSync(toolchainCheck)) {
    runRequired(
      "node",
      ["scripts/check-flutter-toolchain.mjs"],
      resolvedAppRoot,
    );
  }
  console.log("End-to-end local stack verification passed.");
}

async function up() {
  initEnvironment();
  ensureDocker();
  runRequired("make", ["backend-local-up"], backendRoot, {
    env: { MOMCOZY_BACKEND_API_BIND: "127.0.0.1:8769" },
  });
  runRequired(
    "docker",
    [
      "compose",
      "-f",
      "docker-compose.local.yml",
      "up",
      "-d",
      "--build",
      "--wait",
      "api",
      "worker",
    ],
    agentRoot,
  );
  if (process.env.MOMCOZY_LOCAL_DEV_SKIP_VERIFY !== "1" && !dryRun) {
    await verifyStack();
  }
}

function composeArgs(...args) {
  return ["compose", "-f", "docker-compose.local.yml", ...args];
}

function status() {
  ensureDocker();
  runRequired("docker", composeArgs("ps"), backendRoot);
  runRequired("docker", composeArgs("ps"), agentRoot);
}

function logs(scope) {
  ensureDocker();
  if (!scope || scope === "backend") {
    runRequired(
      "docker",
      composeArgs(
        "logs",
        "--tail=100",
        "api",
      ),
      backendRoot,
    );
  }
  if (!scope || scope === "agent") {
    runRequired(
      "docker",
      composeArgs("logs", "--tail=100", "api", "worker"),
      agentRoot,
    );
  }
  if (scope && scope !== "backend" && scope !== "agent") {
    throw new Error("logs accepts only backend or agent.");
  }
}

function down() {
  ensureDocker();
  runRequired("docker", composeArgs("down"), agentRoot);
  runRequired("docker", composeArgs("down"), backendRoot);
}

function launchApp(args) {
  runRequired(
    "node",
    ["scripts/run-flutter-invite-dev.mjs", ...args],
    resolvedAppRoot,
  );
}

async function main() {
  const [command = "up", ...args] = process.argv.slice(2);
  switch (command) {
    case "help":
    case "--help":
    case "-h":
      printHelp();
      return;
    case "init":
      initEnvironment();
      return;
    case "up":
      await up();
      return;
    case "start":
      await up();
      launchApp(args);
      return;
    case "app":
      await verifyStack();
      launchApp(args);
      return;
    case "verify":
      await verifyStack();
      return;
    case "status":
      status();
      return;
    case "logs":
      logs(args[0]);
      return;
    case "down":
      down();
      return;
    default:
      printHelp();
      throw new Error(`Unknown command: ${command}`);
  }
}

main().catch((error) => {
  console.error(`FAIL ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
