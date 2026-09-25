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
const stagingCaPath = "assets/certificates/momcozy-staging-internal-ca.pem";
const stagingCaFingerprint =
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
  "lib/features/motion_assessment/data/motion_voice_signaling.dart",
  "TransportSecurityPolicy.requireSecureHttp(baseUri)",
  "Motion voice signaling must reuse transport security policy",
);
requireContains(
  "lib/features/motion_assessment/data/motion_realtime_voice.dart",
  "final code = error['code']?.toString() ?? 'unknown';",
  "Motion voice logs must select non-content server error metadata",
);
requireContains(
  "lib/features/motion_assessment/data/motion_realtime_voice.dart",
  "final type = error['type']?.toString() ?? 'unknown';",
  "Motion voice logs must select non-content server error type",
);
forbidContains(
  "lib/features/motion_assessment/data/motion_realtime_voice.dart",
  "debugPrint(event.toString())",
  "Motion voice logs must not print the complete server event",
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
  "lib/core/network/staging_certificate_trust.dart",
  "backend-test.lute-momcozylab.luteos.cloud",
  "Staging trust must allow the Product Backend SNI host",
);
requireContains(
  "lib/core/network/staging_certificate_trust.dart",
  "agent-test.lute-momcozylab.luteos.cloud",
  "Staging trust must allow the Agent Runtime SNI host",
);
requireContains(
  "lib/core/network/staging_certificate_trust.dart",
  stagingCaPath,
  "Staging trust must load the internal CA asset",
);
forbidContains(
  "lib/core/network/staging_certificate_trust.dart",
  "lute-momcozylab-test.pem",
  "Staging trust must not load the retired leaf certificate",
);
forbidContains(
  "lib/core/network/staging_certificate_trust.dart",
  "lute-momcozylab-staging.pem",
  "Staging trust must not retain the legacy retired leaf certificate",
);

const stagingCa = new X509Certificate(read(stagingCaPath));
if (!stagingCa.ca) {
  failures.push(`${stagingCaPath} must be a CA certificate`);
}
if (stagingCa.fingerprint256 !== stagingCaFingerprint) {
  failures.push(`${stagingCaPath} fingerprint does not match the reviewed CA`);
}
if (Date.parse(stagingCa.validTo) <= Date.now()) {
  failures.push(`${stagingCaPath} is expired`);
}

if (failures.length > 0) {
  console.error("Flutter security privacy check failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Flutter security privacy check passed.");
