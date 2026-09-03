#!/usr/bin/env node
import { X509Certificate } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");

const read = (relativePath) =>
  readFileSync(path.join(projectRoot, relativePath), "utf8");

const failures = [];
const testCaPath = "assets/certificates/momcozy-test-internal-ca.pem";
const testCaFingerprint =
  "B2:1B:37:43:4D:40:47:DC:83:FE:B9:E0:DB:E7:F7:D7:C2:55:81:E9:4A:AB:0B:18:AE:63:AF:1C:E5:D1:9F:78";

const requireContains = (relativePath, needle, description) => {
  if (!read(relativePath).includes(needle)) {
    failures.push(`${description}: missing ${needle} in ${relativePath}`);
  }
};

const forbidContains = (relativePath, needle, description) => {
  if (read(relativePath).includes(needle)) {
    failures.push(`${description}: found ${needle} in ${relativePath}`);
  }
};

requireContains(
  "lib/features/agent_hub/data/voice_api.dart",
  "TransportSecurityPolicy.requireSecureHttp(baseUri)",
  "Voice API must reuse transport security policy",
);
requireContains(
  "lib/features/agent_hub/data/voice_api.dart",
  "redactedRealtimeVoiceStreamLogContext",
  "Voice API must expose redacted stream log context",
);
requireContains(
  "lib/core/privacy/log_redactor.dart",
  "normalized == 'text'",
  "Log redactor must redact free-form voice text",
);
requireContains(
  "lib/core/privacy/log_redactor.dart",
  "normalized == 'message'",
  "Log redactor must redact free-form message content",
);
requireContains(
  "lib/core/network/test_certificate_trust.dart",
  "backend-test.lute-momcozylab.luteos.cloud",
  "Test trust must allow the Product Backend SNI host",
);
requireContains(
  "lib/core/network/test_certificate_trust.dart",
  "agent-test.lute-momcozylab.luteos.cloud",
  "Test trust must allow the Agent Runtime SNI host",
);
requireContains(
  "lib/core/network/test_certificate_trust.dart",
  testCaPath,
  "Test trust must load the internal CA asset",
);
forbidContains(
  "lib/core/network/test_certificate_trust.dart",
  "lute-momcozylab-test.pem",
  "Test trust must not load the retired leaf certificate",
);
forbidContains(
  "lib/core/network/test_certificate_trust.dart",
  "lute-momcozylab-staging.pem",
  "Test trust must not retain the legacy retired leaf certificate",
);

const testCa = new X509Certificate(read(testCaPath));
if (!testCa.ca) {
  failures.push(`${testCaPath} must be a CA certificate`);
}
if (testCa.fingerprint256 !== testCaFingerprint) {
  failures.push(`${testCaPath} fingerprint does not match the reviewed CA`);
}
if (Date.parse(testCa.validTo) <= Date.now()) {
  failures.push(`${testCaPath} is expired`);
}

if (failures.length > 0) {
  console.error("Flutter security privacy check failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Flutter security privacy check passed.");
