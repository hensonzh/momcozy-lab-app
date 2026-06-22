import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  queryPregnancyDiaryList,
  queryPregnancyDiaryToday,
  queryUserProfile,
} from "@/lib/agentApi";
import { queryMomBabyToday, queryPumpMilkRecords } from "@/lib/momPumpTwinAgentApi";
import { notifyMilkRecordsChanged } from "@/lib/milkRecordsEvents";
import StatusOverviewBody from "./StatusOverviewBody";

vi.mock("recharts", () => ({
  Area: () => null,
  CartesianGrid: () => null,
  ComposedChart: ({ children }: { children?: React.ReactNode }) => <div>{children}</div>,
  Line: () => null,
  ResponsiveContainer: ({ children }: { children?: React.ReactNode }) => <div>{children}</div>,
  Tooltip: () => null,
  XAxis: () => null,
  YAxis: () => null,
}));

vi.mock("@/lib/agentApi", async () => {
  const actual = await vi.importActual<typeof import("@/lib/agentApi")>("@/lib/agentApi");
  return {
    ...actual,
    createPregnancyDiaryEntry: vi.fn(),
    deleteCarePlanArtifact: vi.fn(),
    queryCarePlanList: vi.fn(async () => ({ error: 0, plan_list: [] })),
    queryPregnancyDiaryList: vi.fn(async () => ({ error: 0, diary_list: [] })),
    queryPregnancyDiaryToday: vi.fn(async () => ({ error: 0, diary: null })),
    queryUserProfile: vi.fn(async () => ({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "",
    })),
    updatePregnancyDiaryEntry: vi.fn(),
  };
});

vi.mock("@/lib/momPumpTwinAgentApi", () => ({
  getPumpInfo: vi.fn(async () => ({ error: 0, lactation_info_list: [] })),
  queryMomBabyInfo: vi.fn(async () => ({
    error: -1,
    delivery_date: "",
    lactation_advice: null,
    feeding_advice: null,
    status_page_tabs: [],
    status_page_card: null,
  })),
  queryMomBabyToday: vi.fn(async () => ({
    error: -1,
    pump_milk_volum: 0,
    feeding_volum: 0,
    feeding_forecast_volum: 0,
    pumping_count: 0,
    device_pumping_count: 0,
    manual_pumping_count: 0,
    plan_pumping_count: 0,
    status_page_tabs: [],
    status_page_card: null,
  })),
  queryPumpMilkRecords: vi.fn(async () => ({ error: 0, pump_milk_list: [] })),
}));

vi.mock("@/lib/babyTwinAgentApi", () => ({
  addGrowthRecord: vi.fn(),
  getGrowthHistory: vi.fn(async () => ({ error: 0, growth_data: [] })),
  queryFeedingRecords: vi.fn(async () => ({ error: 0, feed_list: [], total_feed: 0 })),
  queryLatestGrowth: vi.fn(async () => ({ error: -1 })),
  reviseGrowthRecord: vi.fn(),
}));

describe("StatusOverviewBody render", () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    vi.mocked(queryMomBabyToday).mockReset();
    vi.mocked(queryMomBabyToday).mockResolvedValue({
      error: -1,
      pump_milk_volum: 0,
      feeding_volum: 0,
      feeding_forecast_volum: 0,
      pumping_count: 0,
      device_pumping_count: 0,
      manual_pumping_count: 0,
      plan_pumping_count: 0,
      status_page_tabs: [],
      status_page_card: null,
    });
    vi.mocked(queryPumpMilkRecords).mockClear();
    vi.mocked(queryPregnancyDiaryList).mockResolvedValue({ error: 0, diary_list: [] });
    vi.mocked(queryPregnancyDiaryToday).mockResolvedValue({ error: 0, diary: null });
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "",
    });
  });

  it("shows the care-stage switch and opens prenatal services from it", async () => {
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "孕25周",
    });

    render(
      <MemoryRouter initialEntries={["/status"]}>
        <StatusOverviewBody />
      </MemoryRouter>,
    );

    await waitFor(() => {
      expect(screen.getByText("母乳产出")).toBeInTheDocument();
    });
    expect(screen.getByRole("tab", { name: "孕期" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "哺乳期" })).toHaveAttribute("aria-selected", "true");

    fireEvent.click(screen.getByRole("tab", { name: "孕期" }));

    expect(screen.getByRole("tab", { name: "孕期" })).toHaveAttribute("aria-selected", "true");
    const diaryHeading = screen.getByText("孕期日记");
    const birthPlanHeading = screen.getByText("孕期计划");
    expect(diaryHeading).toBeInTheDocument();
    expect(birthPlanHeading).toBeInTheDocument();
    expect(diaryHeading.compareDocumentPosition(birthPlanHeading)).toBe(Node.DOCUMENT_POSITION_FOLLOWING);
    expect(screen.getByText("今日日记")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "查看日记" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "记录今天" })).toBeInTheDocument();
    expect(screen.queryByText("今天还没有记录哦")).not.toBeInTheDocument();
    expect(screen.queryByText("今天还没有记录")).not.toBeInTheDocument();
    expect(screen.queryByText("还没有计划哦")).not.toBeInTheDocument();
    expect(screen.queryByText("还没有孕期日记")).not.toBeInTheDocument();
    expect(screen.getByText("今天还没有记录哦。可以先写下心情、身体感受、胎动或想问医生的问题。")).toBeInTheDocument();
    expect(await screen.findByText("孕期 25 周")).toBeInTheDocument();
    expect(screen.getByText("宝宝孕育中")).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /宝宝/ })).toBeDisabled();
    expect(screen.queryByText("母乳产出")).not.toBeInTheDocument();
  });

  it("shows pregnancy diary data under prenatal services", async () => {
    localStorage.setItem("momcozy_status_care_stage", "pregnancy");
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "孕32周",
    });
    const now = new Date();
    const todayDateKey = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, "0"),
      String(now.getDate()).padStart(2, "0"),
    ].join("-");
    const diary = {
      entry_id: 1,
      user_id: "demo_mama_increase_001",
      entry_date: todayDateKey,
      gestational_week: "孕32周",
      mood: "平稳",
      energy_level: "",
      sleep_summary: "睡得一般",
      fetal_movement: "",
      symptom_tags: [],
      appointment_note: "",
      nutrition_note: "",
      content: "今天睡得一般。",
      attachments: [],
      health_notes: [
        {
          note_id: 11,
          entry_id: 1,
          user_id: "demo_mama_increase_001",
          entry_date: todayDateKey,
          topic: "胎动咨询",
          user_report: "下午胎动比平时少一点。",
          asked_questions: [],
          known_answers: [],
          suggestion_summary: "先观察胎动变化，如明显减少及时联系医生。",
          follow_up: "",
          created_at: "2026-06-14 10:00:00",
        },
      ],
      created_at: "2026-06-14 09:00:00",
      updated_at: "2026-06-14 09:00:00",
    };
    vi.mocked(queryPregnancyDiaryList).mockResolvedValue({ error: 0, diary_list: [diary] });
    vi.mocked(queryPregnancyDiaryToday).mockResolvedValue({ error: 0, diary });

    render(
      <MemoryRouter initialEntries={["/status"]}>
        <StatusOverviewBody />
      </MemoryRouter>,
    );

    await waitFor(() => {
      expect(screen.getByText("孕期计划")).toBeInTheDocument();
    });
    expect(screen.getByText("孕期日记")).toBeInTheDocument();
    expect(screen.getByText("今日日记")).toBeInTheDocument();
    expect(await screen.findByText("今天睡得一般。")).toBeInTheDocument();
    expect(screen.getByText("下午胎动比平时少一点。")).toBeInTheDocument();
    expect(screen.queryByText("先观察胎动变化，如明显减少及时联系医生。")).not.toBeInTheDocument();
    expect(screen.getByText("记录几天后，我可以帮你回顾睡眠、情绪、胎动和身体感受的变化。")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "记录今天" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "编辑今天" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "查看日记" })).toBeInTheDocument();
  });

  it("shows postpartum services and hides prenatal cards when pregnancy profile is absent", async () => {
    render(
      <MemoryRouter initialEntries={["/status"]}>
        <StatusOverviewBody />
      </MemoryRouter>,
    );

    await waitFor(() => {
      expect(screen.getByText("母乳产出")).toBeInTheDocument();
    });
    expect(screen.getByText("乳房健康")).toBeInTheDocument();
    expect(screen.getByText("产后恢复")).toBeInTheDocument();
    expect(screen.getByText("补能与休息")).toBeInTheDocument();
    expect(screen.queryByText("孕期计划")).not.toBeInTheDocument();
    expect(screen.queryByText("孕期日记")).not.toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /宝宝/ })).not.toBeDisabled();
  });

  it("keeps manual postpartum mode over stale pregnancy profile fields", async () => {
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "孕32周",
      current_care_stage: "pregnancy",
    });

    render(
      <MemoryRouter initialEntries={["/status"]}>
        <StatusOverviewBody />
      </MemoryRouter>,
    );

    await waitFor(() => {
      expect(screen.getByText("母乳产出")).toBeInTheDocument();
    });
    expect(screen.getByText("乳房健康")).toBeInTheDocument();
    expect(screen.queryByText("孕期计划")).not.toBeInTheDocument();
    expect(screen.queryByText("孕期日记")).not.toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /宝宝/ })).not.toBeDisabled();
  });

  it("uses the unified mom-baby today summary for today's pump count", async () => {
    vi.mocked(queryMomBabyToday).mockResolvedValue({
      error: 0,
      pump_milk_volum: 120,
      feeding_volum: 0,
      feeding_forecast_volum: 0,
      pumping_count: 3,
      device_pumping_count: 1,
      manual_pumping_count: 1,
      plan_pumping_count: 1,
      status_page_tabs: [],
      status_page_card: null,
    });

    render(
      <MemoryRouter initialEntries={["/status"]}>
        <StatusOverviewBody />
      </MemoryRouter>,
    );

    expect(await screen.findByText("3次")).toBeInTheDocument();
    expect(queryPumpMilkRecords).not.toHaveBeenCalled();
  });

  it("refreshes today's pump summary after milk records change", async () => {
    vi.mocked(queryMomBabyToday)
      .mockResolvedValueOnce({
        error: 0,
        pump_milk_volum: 80,
        feeding_volum: 0,
        feeding_forecast_volum: 0,
        pumping_count: 1,
        device_pumping_count: 1,
        manual_pumping_count: 0,
        plan_pumping_count: 0,
        status_page_tabs: [],
        status_page_card: null,
      })
      .mockResolvedValue({
        error: 0,
        pump_milk_volum: 140,
        feeding_volum: 0,
        feeding_forecast_volum: 0,
        pumping_count: 2,
        device_pumping_count: 1,
        manual_pumping_count: 1,
        plan_pumping_count: 0,
        status_page_tabs: [],
        status_page_card: null,
      });

    render(
      <MemoryRouter initialEntries={["/status"]}>
        <StatusOverviewBody />
      </MemoryRouter>,
    );

    expect(await screen.findByText("1次")).toBeInTheDocument();

    act(() => {
      notifyMilkRecordsChanged();
    });

    expect(await screen.findByText("2次")).toBeInTheDocument();
  });
});
