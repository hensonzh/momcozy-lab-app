import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  queryPregnancyDiaryList,
  queryPregnancyDiaryToday,
  queryUserProfile,
} from "@/lib/agentApi";
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
    vi.mocked(queryPregnancyDiaryList).mockResolvedValue({ error: 0, diary_list: [] });
    vi.mocked(queryPregnancyDiaryToday).mockResolvedValue({ error: 0, diary: null });
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "",
    });
  });

  it("shows prenatal services and locks baby tab when pregnancy profile exists", async () => {
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
      expect(screen.getByText("生产全过程计划")).toBeInTheDocument();
    });
    expect(screen.getByText("孕期日记")).toBeInTheDocument();
    expect(screen.getByText("还没有计划哦")).toBeInTheDocument();
    expect(screen.getByText("今天还没有记录哦")).toBeInTheDocument();
    expect(await screen.findByText("孕期 25 周")).toBeInTheDocument();
    expect(screen.getByText("宝宝孕育中")).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /宝宝/ })).toBeDisabled();
    expect(screen.queryByText("母乳产出")).not.toBeInTheDocument();
  });

  it("shows pregnancy diary data under prenatal services", async () => {
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "孕32周",
    });
    const diary = {
      entry_id: 1,
      user_id: "demo_mama_increase_001",
      entry_date: "2026-06-14",
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
      health_notes: [],
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
      expect(screen.getByText("生产全过程计划")).toBeInTheDocument();
    });
    expect(screen.getByText("孕期日记")).toBeInTheDocument();
    expect(await screen.findByText("今日已记录：心情平稳，睡得一般")).toBeInTheDocument();
    expect(screen.getByText("最近7天记录 1 天")).toBeInTheDocument();
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
    expect(screen.queryByText("生产全过程计划")).not.toBeInTheDocument();
    expect(screen.queryByText("孕期日记")).not.toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /宝宝/ })).not.toBeDisabled();
  });

  it("prefers explicit postpartum stage over stale pregnancy profile fields", async () => {
    vi.mocked(queryUserProfile).mockResolvedValue({
      error: 0,
      user_id: "demo_mama_increase_001",
      birth_prep_due_date_or_week: "孕32周",
      current_care_stage: "postpartum",
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
    expect(screen.queryByText("生产全过程计划")).not.toBeInTheDocument();
    expect(screen.queryByText("孕期日记")).not.toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /宝宝/ })).not.toBeDisabled();
  });
});
