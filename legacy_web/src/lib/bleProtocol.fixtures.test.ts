import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import {
  buildAck,
  buildB0SetWorkMode,
  buildB1SetPumpParams,
  buildB2SetFlexibleForceLine,
  buildB3SetLactationCurve,
  buildBFEndRun,
  buildE0QueryDeviceInfo,
  buildE1QueryDeviceStatus,
  buildF0GetDeviceInfo,
  buildF1SetUserParams,
  buildF2SetRtc,
  buildF3SetFlags,
  buildFEPowerOff,
  parse80RealtimeMilk,
  parseBFEndRunResponse,
  parseD0OperationRecord,
  parseD6Battery,
  parseE1DeviceStatus,
  parseF0DeviceInfo,
  parseFrame,
} from "@/lib/bleProtocol";

type ReqCase = {
  id: string;
  builder: string;
  args: unknown[];
  expectedHex: string;
};

type ReqFixtures = {
  cases: ReqCase[];
};

type FrameExpectation = {
  ct: number;
  cid: number;
  cal: number;
  cabHex: string;
};

type ParseCase = {
  id: string;
  frameHex: string;
  expectedFrame?: FrameExpectation;
  parser?: ParserName;
  expectedValue?: unknown;
  expectedParseFrame?: null;
};

type ParseFixtures = {
  validFrames: ParseCase[];
  invalidFrames: ParseCase[];
  parserEdgeCases: Array<{
    id: string;
    parser: ParserName;
    cabHex: string;
    expectedValue: unknown;
  }>;
};

const parsers = {
  parse80RealtimeMilk,
  parseBFEndRunResponse,
  parseD0OperationRecord,
  parseD6Battery,
  parseE1DeviceStatus,
  parseF0DeviceInfo,
};

type ParserName = keyof typeof parsers;

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const fixtureRoot = path.join(repoRoot, "test/fixtures/ble");

const readFixture = <T,>(filename: string): T => {
  return JSON.parse(
    fs.readFileSync(path.join(fixtureRoot, filename), "utf8")
  ) as T;
};

const readTextFixture = (filename: string): string => {
  return fs.readFileSync(path.join(fixtureRoot, filename), "utf8").trim();
};

const toHex = (bytes: Uint8Array): string =>
  Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");

const hexToBytes = (value: string): Uint8Array => {
  const clean = value.trim();
  if (clean.length % 2 !== 0 || !/^[0-9a-f]*$/i.test(clean)) {
    throw new Error(`Invalid hex fixture: ${value}`);
  }
  const pairs = clean.match(/../g) ?? [];
  return new Uint8Array(pairs.map((pair) => Number.parseInt(pair, 16)));
};

const buildPacket = (testCase: ReqCase): Uint8Array => {
  switch (testCase.builder) {
    case "buildAck": {
      const [cid] = testCase.args as [number];
      return buildAck(cid);
    }
    case "buildB0SetWorkMode": {
      const [mode] = testCase.args as [1 | 2 | 3];
      return buildB0SetWorkMode(mode);
    }
    case "buildB1SetPumpParams": {
      const [startStop, mode, gear, scene] = testCase.args as [
        0 | 1,
        0 | 1 | 2,
        number,
        0 | 1,
      ];
      return buildB1SetPumpParams(startStop, mode, gear, scene);
    }
    case "buildB2SetFlexibleForceLine": {
      const [cab, persist] = testCase.args as [number[], 0 | 1];
      return buildB2SetFlexibleForceLine(new Uint8Array(cab), persist);
    }
    case "buildB3SetLactationCurve": {
      const [mode, gear, freqCpm, pressure, holdPressure, holdTimeMs, persist] =
        testCase.args as [number, number, number, number, number, number, 0 | 1];
      return buildB3SetLactationCurve(
        mode,
        gear,
        freqCpm,
        pressure,
        holdPressure,
        holdTimeMs,
        persist
      );
    }
    case "buildBFEndRun":
      return buildBFEndRun();
    case "buildE0QueryDeviceInfo": {
      const [queryType] = testCase.args as [number];
      return buildE0QueryDeviceInfo(queryType);
    }
    case "buildE1QueryDeviceStatus":
      return buildE1QueryDeviceStatus();
    case "buildF0GetDeviceInfo":
      return buildF0GetDeviceInfo();
    case "buildF1SetUserParams": {
      const [stimulateGear, lactateGear, persist] = testCase.args as [
        number,
        number,
        0 | 1,
      ];
      return buildF1SetUserParams(stimulateGear, lactateGear, persist);
    }
    case "buildF2SetRtc": {
      const [utcSeconds] = testCase.args as [number];
      return buildF2SetRtc(utcSeconds);
    }
    case "buildF3SetFlags": {
      const [flagsByte, persist] = testCase.args as [number, 0 | 1];
      return buildF3SetFlags(flagsByte, persist);
    }
    case "buildFEPowerOff": {
      const [reboot] = testCase.args as [0 | 1];
      return buildFEPowerOff(reboot);
    }
    default:
      throw new Error(`Unsupported BLE fixture builder: ${testCase.builder}`);
  }
};

const frameSummary = (frame: NonNullable<ReturnType<typeof parseFrame>>): FrameExpectation => ({
  ct: frame.ct,
  cid: frame.cid,
  cal: frame.cal,
  cabHex: toHex(frame.cab),
});

describe("ble protocol fixtures", () => {
  it("keeps encoded request packets aligned with golden hex", () => {
    const fixtures = [
      ...readFixture<ReqFixtures>("req_golden_packets.json").cases,
      ...readFixture<ReqFixtures>("boundary_cases.json").cases,
    ];

    for (const testCase of fixtures) {
      expect(toHex(buildPacket(testCase)), testCase.id).toBe(testCase.expectedHex);
    }
  });

  it("keeps required standalone hex fixtures aligned with structured fixtures", () => {
    const fixtures = readFixture<ReqFixtures>("req_golden_packets.json");
    const byId = new Map(fixtures.cases.map((testCase) => [testCase.id, testCase]));

    expect(readTextFixture("f0_get_device_info.hex")).toBe(
      byId.get("f0_get_device_info_default_sn")?.expectedHex
    );
    expect(readTextFixture("f2_set_rtc.hex")).toBe(
      byId.get("f2_set_rtc_fixed_timestamp")?.expectedHex
    );
    expect(readTextFixture("b0_set_work_mode.hex")).toBe(
      byId.get("b0_set_work_mode_agent")?.expectedHex
    );
    expect(readTextFixture("b1_set_pump_params.hex")).toBe(
      byId.get("b1_start_deep_gear6_auto")?.expectedHex
    );
    expect(readTextFixture("b2_set_flexible_force_line.hex")).toBe(
      byId.get("b2_set_flexible_force_line_minimal")?.expectedHex
    );
    expect(readTextFixture("b3_set_lactation_curve.hex")).toBe(
      byId.get("b3_set_lactation_curve_typical")?.expectedHex
    );
    expect(readTextFixture("bf_end_run.hex")).toBe(
      byId.get("bf_end_run_reserved_zero")?.expectedHex
    );
  });

  it("parses valid frame fixtures into stable domain values", () => {
    const fixtures = readFixture<ParseFixtures>("parse_frames.json");

    for (const testCase of fixtures.validFrames) {
      const frame = parseFrame(hexToBytes(testCase.frameHex));
      if (!frame) throw new Error(`Expected valid frame for fixture ${testCase.id}`);

      expect(frameSummary(frame), testCase.id).toEqual(testCase.expectedFrame);
      if (testCase.parser) {
        expect(parsers[testCase.parser](frame.cab), testCase.id).toEqual(
          testCase.expectedValue
        );
      }
    }
  });

  it("keeps E1 status standalone fixtures aligned with parser output", () => {
    const frame = parseFrame(hexToBytes(readTextFixture("e1_device_status_input.hex")));
    if (!frame) throw new Error("Expected E1 status standalone input frame to parse");

    expect(parseE1DeviceStatus(frame.cab)).toEqual(
      readFixture("e1_device_status_expected.json")
    );
  });

  it("rejects invalid frames and parser edge cases with null", () => {
    const fixtures = readFixture<ParseFixtures>("parse_frames.json");

    for (const testCase of fixtures.invalidFrames) {
      const frame = parseFrame(hexToBytes(testCase.frameHex));
      if (testCase.expectedParseFrame === null) {
        expect(frame, testCase.id).toBeNull();
        continue;
      }

      if (!frame) throw new Error(`Expected frame to parse before parser fallback: ${testCase.id}`);
      expect(frameSummary(frame), testCase.id).toEqual(testCase.expectedFrame);
      if (testCase.parser) {
        expect(parsers[testCase.parser](frame.cab), testCase.id).toEqual(
          testCase.expectedValue
        );
      }
    }

    for (const testCase of fixtures.parserEdgeCases) {
      expect(parsers[testCase.parser](hexToBytes(testCase.cabHex)), testCase.id).toEqual(
        testCase.expectedValue
      );
    }
  });
});
