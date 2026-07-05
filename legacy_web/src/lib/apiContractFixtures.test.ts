import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const legacyWebRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const API_FIXTURE_ROOT = path.join(legacyWebRoot, "..", "test", "fixtures", "api");

const REQUIRED_DOMAINS = [
  "user_profile",
  "pump",
  "pump_milk",
  "mom_baby",
  "feeding",
  "growth",
  "plan",
  "pregnancy_diary",
  "notify",
  "media",
] as const;

const REQUIRED_VARIANTS = [
  "success",
  "business_error",
  "http_error",
  "empty",
  "partial",
  "legacy_alias",
] as const;

type ApiFixtureVariant = (typeof REQUIRED_VARIANTS)[number];

type ApiFixture = {
  domain: string;
  endpoint: string;
  method: string;
  variant: ApiFixtureVariant;
  request: unknown;
  response: unknown;
};

const readFixture = (domain: string, variant: ApiFixtureVariant): ApiFixture => {
  const file = path.join(API_FIXTURE_ROOT, domain, `${variant}.json`);
  return JSON.parse(fs.readFileSync(file, "utf8")) as ApiFixture;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value != null && typeof value === "object" && !Array.isArray(value);

describe("API contract fixtures", () => {
  it("provides every required variant for each Flutter API domain", () => {
    for (const domain of REQUIRED_DOMAINS) {
      for (const variant of REQUIRED_VARIANTS) {
        const fixture = readFixture(domain, variant);

        expect(fixture.domain, `${domain}/${variant}`).toBe(domain);
        expect(fixture.variant, `${domain}/${variant}`).toBe(variant);
        expect(fixture.endpoint, `${domain}/${variant}`).toMatch(/^\/(?:api|v1)\//);
        expect(fixture.method, `${domain}/${variant}`).toBeTruthy();
        expect(fixture).toHaveProperty("request");
        expect(fixture).toHaveProperty("response");
      }
    }
  });

  it("keeps success, empty, partial, and legacy fixtures in the current API envelope", () => {
    for (const domain of REQUIRED_DOMAINS) {
      for (const variant of ["success", "empty", "partial", "legacy_alias"] as const) {
        const response = readFixture(domain, variant).response;

        expect(response, `${domain}/${variant}`).toMatchObject({
          status: 200,
        });
        expect(isRecord(response) && "data" in response, `${domain}/${variant}`).toBe(true);
      }
    }
  });

  it("keeps business errors and HTTP errors distinct", () => {
    for (const domain of REQUIRED_DOMAINS) {
      const business = readFixture(domain, "business_error").response;
      const http = readFixture(domain, "http_error").response;

      expect(business, `${domain}/business_error`).toMatchObject({
        status: expect.any(Number),
        message: expect.any(String),
      });
      expect(isRecord(business) && business.status !== 200, `${domain}/business_error`).toBe(true);
      expect(http, `${domain}/http_error`).toMatchObject({
        http_status: expect.any(Number),
        request_id: expect.any(String),
      });
      expect(isRecord(http) && !("data" in http), `${domain}/http_error`).toBe(true);
    }
  });

  it("does not include secrets or real-user markers in fixture payloads", () => {
    const payload = JSON.stringify(
      REQUIRED_DOMAINS.flatMap((domain) =>
        REQUIRED_VARIANTS.map((variant) => readFixture(domain, variant))
      )
    );

    expect(payload).not.toMatch(/Bearer\s+/i);
    expect(payload).not.toMatch(/token/i);
    expect(payload).not.toMatch(/Authorization/i);
    expect(payload).toContain("demo-user-fixture");
  });
});
