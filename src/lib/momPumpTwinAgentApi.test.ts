import { afterEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  apiRequest: vi.fn(),
}));

vi.mock("@/lib/http", () => ({
  apiRequest: mocks.apiRequest,
}));

import { MILK_RECORDS_CHANGED_EVENT, type MilkRecordsChangedDetail } from "@/lib/milkRecordsEvents";
import { deletePumpMilkRecord, queryMomBabyToday, uploadPumpMilkRecord } from "@/lib/momPumpTwinAgentApi";

describe("momPumpTwinAgentApi", () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it("passes timestamp to the mom-baby today summary query", async () => {
    mocks.apiRequest.mockResolvedValue({ error: 0 });

    await queryMomBabyToday("user-1", { timestamp: "2026-05-21" });

    expect(mocks.apiRequest).toHaveBeenCalledWith(
      "/v1/mom-baby/today/query",
      expect.objectContaining({
        method: "GET",
        params: { user_id: "user-1", timestamp: "2026-05-21" },
      }),
    );
  });

  it("notifies listeners after successful pump milk upload and delete", async () => {
    const details: MilkRecordsChangedDetail[] = [];
    const listener = (event: Event) => {
      details.push((event as CustomEvent<MilkRecordsChangedDetail>).detail);
    };
    window.addEventListener(MILK_RECORDS_CHANGED_EVENT, listener);
    mocks.apiRequest.mockResolvedValue({ error: 0 });

    try {
      await uploadPumpMilkRecord({
        user_id: "user-1",
        pump_type: 1,
        pump_source: 1,
        pump_time: "08:30",
        pump_milk_volum: 90,
      });
      await deletePumpMilkRecord({ user_id: "user-1", pump_id: 12 });
    } finally {
      window.removeEventListener(MILK_RECORDS_CHANGED_EVENT, listener);
    }

    expect(details).toEqual([{ user_id: "user-1" }, { user_id: "user-1" }]);
  });
});
