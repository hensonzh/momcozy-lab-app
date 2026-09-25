#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(scriptDir, "..");
const workspaceRoot = path.resolve(
  process.env.MOMCOZY_WORKSPACE_ROOT || path.join(appRoot, ".."),
);
const backendRoot = path.join(workspaceRoot, "backend");
const agentRoot = path.join(workspaceRoot, "agent");

const sharedKeys = [
  "MOMCOZY_BACKEND_COMPOSE_PROJECT",
  "MOMCOZY_AGENT_COMPOSE_PROJECT",
  "MOMCOZY_NETWORK_NAME",
  "MOMCOZY_BACKEND_API_BIND",
  "MOMCOZY_AGENT_API_BIND",
  "MOMCOZY_POSTGRES_ADMIN_USER",
  "MOMCOZY_AGENT_POSTGRES_DB",
  "MOMCOZY_AGENT_POSTGRES_USER",
  "MOMCOZY_AGENT_MINIO_BUCKET",
];

function fail(message) {
  throw new Error(message);
}

function readEnv(filePath) {
  if (!existsSync(filePath)) fail(`Missing environment file: ${filePath}`);
  const result = new Map();
  for (const rawLine of readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const separator = line.indexOf("=");
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim().replace(/^['"]|['"]$/g, "");
    result.set(key, value);
  }
  return result;
}

function readJson(filePath) {
  if (!existsSync(filePath)) fail(`Missing environment file: ${filePath}`);
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function requireEqual(environment, key, left, right) {
  if (!left || left !== right) {
    fail(`${environment}: ${key} differs between Backend and Agent`);
  }
}

for (const environment of ["staging", "production"]) {
  const backend = readEnv(
    path.join(backendRoot, "env", `${environment}.env.example`),
  );
  const agent = readEnv(
    path.join(agentRoot, "env", `${environment}.env.example`),
  );
  const appConfigName = environment === "production"
    ? "production.json.example"
    : "staging.json";
  const app = readJson(path.join(appRoot, "config", "environments", appConfigName));

  if (backend.get("APP_ENV") !== environment) {
    fail(`${environment}: Backend APP_ENV is invalid`);
  }
  if (agent.get("APP_ENV") !== environment) {
    fail(`${environment}: Agent APP_ENV is invalid`);
  }
  if (app.MOMCOZY_ENV !== environment) {
    fail(`${environment}: App MOMCOZY_ENV is invalid`);
  }

  for (const key of sharedKeys) {
    requireEqual(environment, key, backend.get(key), agent.get(key));
  }

  const backendUrl = backend.get("MOMCOZY_BACKEND_PUBLIC_URL");
  const agentUrl = backend.get("MOMCOZY_AGENT_PUBLIC_URL");
  requireEqual(
    environment,
    "MOMCOZY_BACKEND_PUBLIC_URL",
    backendUrl,
    agent.get("MOMCOZY_BACKEND_PUBLIC_URL"),
  );
  requireEqual(
    environment,
    "MOMCOZY_AGENT_PUBLIC_URL",
    agentUrl,
    agent.get("MOMCOZY_AGENT_PUBLIC_URL"),
  );
  requireEqual(environment, "App Product API URL", backendUrl, app.MOMCOZY_API_BASE_URL);
  requireEqual(environment, "App Agent API URL", agentUrl, app.MOMCOZY_AGENT_API_BASE_URL);

  if (agent.get("PRODUCT_BACKEND_BASE_URL") !== backendUrl) {
    fail(`${environment}: Agent PRODUCT_BACKEND_BASE_URL must match Backend public URL`);
  }
  if (agent.get("AUTH_JWKS_URL") !== `${backendUrl}/.well-known/jwks.json`) {
    fail(`${environment}: Agent AUTH_JWKS_URL must derive from Backend public URL`);
  }
}

for (const [root, label] of [[backendRoot, "Backend"], [agentRoot, "Agent"]]) {
  const local = readEnv(path.join(root, "env", "local.env.example"));
  if (local.get("APP_ENV") !== "local") fail(`${label}: local APP_ENV is invalid`);
}
const localApp = readJson(path.join(appRoot, "config", "environments", "local.json"));
if (localApp.MOMCOZY_ENV !== "local") fail("App: local MOMCOZY_ENV is invalid");

console.log("Workspace environment contracts are aligned.");
