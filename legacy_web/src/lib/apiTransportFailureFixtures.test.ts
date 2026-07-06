import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const API_FIXTURE_ROOT = path.join(repoRoot, "test/fixtures/api");

const REQUIRED_TRANSPORT_FAILURE_FIXTURES = [
  "media/upload_cancelled.json",
  "media/upload_timeout.json",
  "voice/realtime_voice_stream_cancelled.json",
  "voice/realtime_voice_session_ws_disconnect.json",
  "voice/speech_transcribe_chunk_timeout.json",
  "pump/session_summary_timeout.json",
  "pump/session_summary_ws_disconnect.json",
  "pump/session_summary_idempotent_retry.json",
] as const;

type TransportFailureFixture = {
  domain: string;
  scenario: string;
  endpoint: string;
  method: string;
  transport: string;
  expected_client_behavior: Record<string, unknown>;
  idempotency_key?: string;
};

const readFixture = (relativePath: string): TransportFailureFixture =>
  JSON.parse(fs.readFileSync(path.join(API_FIXTURE_ROOT, relativePath), "utf8")) as TransportFailureFixture;

describe("API transport failure fixtures", () => {
  it("keeps upload, voice, and pump summary failure fixtures present and parseable", () => {
    for (const file of REQUIRED_TRANSPORT_FAILURE_FIXTURES) {
      const fixture = readFixture(file);

      expect(fixture.domain, file).toBeTruthy();
      expect(fixture.scenario, file).toBeTruthy();
      expect(fixture.endpoint, file).toMatch(/^\/v1\//);
      expect(fixture.method, file).toBeTruthy();
      expect(fixture.transport, file).toBeTruthy();
      expect(fixture.expected_client_behavior, file).toBeTruthy();
    }
  });

  it("requires idempotency for retryable pump summary failures", () => {
    for (const file of [
      "pump/session_summary_timeout.json",
      "pump/session_summary_ws_disconnect.json",
    ]) {
      const fixture = readFixture(file);

      expect(fixture.expected_client_behavior).toMatchObject({
        retry_automatically: true,
        requires_idempotency_key: true,
      });
    }

    expect(readFixture("pump/session_summary_idempotent_retry.json")).toMatchObject({
      idempotency_key: "pump-summary-fixture-001",
      expected_client_behavior: {
        mark_uploaded_once: true,
      },
    });
  });

  it("keeps cancellation distinct from user-visible errors", () => {
    for (const file of [
      "media/upload_cancelled.json",
      "voice/realtime_voice_stream_cancelled.json",
    ]) {
      const fixture = readFixture(file);

      expect(fixture.expected_client_behavior).toMatchObject({
        exception: "RequestCancelled",
        show_error_toast: false,
        retry_automatically: false,
      });
    }
  });

  it("does not include secrets in transport failure fixtures", () => {
    const payload = JSON.stringify(
      REQUIRED_TRANSPORT_FAILURE_FIXTURES.map((file) => readFixture(file))
    );

    expect(payload).not.toMatch(/Bearer\s+/i);
    expect(payload).not.toMatch(/Authorization/i);
    expect(payload).not.toMatch(/token/i);
  });
});
