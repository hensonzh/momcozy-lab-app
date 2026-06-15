import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryRouter } from "react-router-dom";
import AgentHubRichTextBlock, { type IbclcConsultOpenRequest } from "./AgentHubRichTextBlock";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";

const here = dirname(fileURLToPath(import.meta.url));
const appCssSource = readFileSync(resolve(here, "../../index.css"), "utf8");

vi.mock("@/lib/agentConversationSession", () => ({
  getAgUiThreadIdForRequest: () => "thread_test",
}));

function ibclcPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "ibclc_consult",
        artifact_id: "ibclc_artifact_1",
        card: {
          title: "IBCLC 在线咨询",
          consult_id: "ibclc_1",
          consultant: {
            name: "Emily Chen",
            credentials: "IBCLC 国际认证哺乳顾问",
            experience: "8 年产后哺乳支持经验",
            bio: "擅长含乳评估、吸吮观察和排乳计划。",
          },
          chat: {
            label: "咨询 IBCLC",
            url: "/ibclc-chat.html",
          },
        },
      },
    ],
  };
}

function supportTicketPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "support_ticket_draft",
        artifact_id: "ticket_1",
        submit_label: "确认并提交",
        ticket: {
          issue_type: "malfunction",
          issue_summary: "吸奶器无法启动",
          product_model: "Air1",
          order_number: "MC123",
          purchase_channel: "官网",
          urgency: "normal",
        },
      },
    ],
  };
}

function birthJourneyPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "card",
        artifact_id: "birth_journey_1",
        card: {
          card_type: "birth_journey_plan_card",
          schema_version: "1.0",
          card_json: {
            title: "孕期计划",
            owner: {
              current_week: "孕20周",
              estimated_due_date: "2026/10/15",
            },
            phases: [
              {
                id: "middle",
                title: "孕中期",
                date_range: "孕14周-27周",
                status: "current",
	                goal: "先把产检和医院流程确认清楚。",
	                watchouts: ["按时产检。"],
	                actions: ["记录下次产检问题。"],
	                comate_help: ["整理产检问题。"],
              },
              {
                id: "late",
                title: "孕晚期",
                date_range: "孕28周-36周",
                status: "upcoming",
	                goal: "把入院准备收拢。",
	                watchouts: ["留意胎动变化。"],
	                actions: ["确认待产包。"],
	                comate_help: [],
              },
            ],
          },
        },
      },
    ],
  };
}

function hospitalBagFormPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "form",
        artifact_id: "hospital_bag_form_1",
        form: {
          id: "hospital_bag_intake",
          title: "信息采集",
          default_values: {
            due_date_or_week: "孕34周",
          },
          fields: [
            {
              id: "due_date_or_week",
              label: "基本信息｜预产期或当前孕周",
              type: "text",
            },
            {
              id: "birth_path",
              label: "生产信息｜分娩方式",
              type: "select",
              options: ["顺产", "剖宫产", "还不确定"],
              default_value: "剖宫产",
            },
            {
              id: "fetus_count",
              label: "基本信息｜这次是单胎、双胎，还是三胎及以上？",
              type: "select",
              options: ["单胎", "双胎", "三胎及以上", "不确定"],
              default_value: "单胎",
            },
            {
              id: "feeding_intention",
              label: "喂养信息｜喂养意向",
              type: "select",
              options: ["亲喂母乳", "配方奶", "混合喂养", "还不确定"],
              default_value: "亲喂母乳",
            },
            {
              id: "support_person",
              label: "照护信息｜产后前两周支持情况",
              type: "select",
              options: ["有人全天帮忙", "白天主要自己", "夜间主要自己", "支持少", "不确定"],
              default_value: "有人全天帮忙",
            },
            {
              id: "pregnancy_history_or_notes",
              label: "基本信息｜医生是否提示过特殊情况",
              type: "multi_select",
              options: ["没有", "妊娠糖尿病", "计划剖宫产"],
              default_value: ["没有"],
            },
            {
              id: "return_to_work_timing",
              label: "偏好信息｜产后多久返工",
              type: "text",
            },
            {
              id: "top_worries",
              label: "偏好信息｜最焦虑的三件事",
              type: "textarea",
            },
          ],
        },
      },
    ],
  };
}

function birthJourneyBasicInfoFormPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "form",
        artifact_id: "birth_journey_basic_info_1",
        form: {
          id: "birth_journey_basic_info_intake",
          title: "孕周与基本情况",
          description: "",
          submit_label: "提交",
          fields: [
            {
              id: "current_week",
              label: "当前孕周",
              type: "text",
              required: true,
              default_value: "孕25周",
            },
            {
              id: "ivf",
              label: "是否 IVF（体外受精）",
              type: "select",
              options: ["是", "否", "不确定/暂不说"],
            },
            {
              id: "fetus_count",
              label: "单胎/双胎",
              type: "select",
              required: true,
              options: ["单胎", "双胎", "多胎", "不确定/暂不说"],
            },
            {
              id: "age",
              label: "年龄",
              type: "number",
              required: true,
              placeholder: "例如：32",
            },
            {
              id: "city_or_country",
              label: "所在城市/国家",
              type: "text",
              default_value: "深圳",
            },
          ],
        },
      },
    ],
  };
}

function renderBlock({
  payload = ibclcPayload(),
  birthPrepProfileDefaults = null,
  onButtonSelect = vi.fn(),
  onOpenIbclcConsult = vi.fn(),
}: {
  payload?: ChatRichTextPayload;
  birthPrepProfileDefaults?: React.ComponentProps<typeof AgentHubRichTextBlock>["birthPrepProfileDefaults"];
  onButtonSelect?: (value: string, options?: { displayText?: string; assistantReply?: string }) => void;
  onOpenIbclcConsult?: (request: IbclcConsultOpenRequest) => void;
} = {}) {
  return render(
    <MemoryRouter initialEntries={["/agent?tab=agent#latest"]}>
      <AgentHubRichTextBlock
        payload={payload}
        birthPrepProfileDefaults={birthPrepProfileDefaults}
        onButtonSelect={onButtonSelect}
        onOpenIbclcConsult={onOpenIbclcConsult}
      />
    </MemoryRouter>,
  );
}

describe("AgentHubRichTextBlock IBCLC consult card", () => {
  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  it("keeps the consult button disabled until the agreement is accepted", () => {
    const onOpenIbclcConsult = vi.fn();
    renderBlock({ onOpenIbclcConsult });

    const button = screen.getByRole("button", { name: "咨询 IBCLC" });

    expect(screen.getByRole("checkbox", { name: /隐私政策/ })).not.toBeChecked();
    expect(screen.getByText("启动咨询后，会自动将你的问题同步给顾问")).toBeInTheDocument();
    expect(button).toBeDisabled();

    fireEvent.click(button);

    expect(onOpenIbclcConsult).not.toHaveBeenCalled();
  });

  it("opens the IBCLC consult after the agreement is accepted", () => {
    const onOpenIbclcConsult = vi.fn<[IbclcConsultOpenRequest], void>();
    renderBlock({ onOpenIbclcConsult });

    fireEvent.click(screen.getByRole("checkbox", { name: /隐私政策/ }));
    const button = screen.getByRole("button", { name: "咨询 IBCLC" });

    expect(button).toBeEnabled();

    fireEvent.click(button);

    expect(onOpenIbclcConsult).toHaveBeenCalledWith(
      expect.objectContaining({
        consultId: "ibclc_1",
        threadId: "thread_test",
        returnTo: "/agent?tab=agent#latest",
      }),
    );
  });
});

describe("AgentHubRichTextBlock support ticket draft", () => {
  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  it("renders order and purchase fields and returns the default submitted reply", () => {
    const onButtonSelect = vi.fn();
    renderBlock({ payload: supportTicketPayload(), onButtonSelect });

    expect(screen.getByRole("textbox", { name: "产品型号" })).toBeRequired();
    expect(screen.getByRole("textbox", { name: "订单号" })).toHaveValue("MC123");
    expect(screen.getByRole("textbox", { name: "购买渠道" })).toHaveValue("官网");

    fireEvent.click(screen.getByRole("button", { name: "确认并提交" }));

    expect(onButtonSelect).toHaveBeenCalledWith(
      "已提交售后工单",
      expect.objectContaining({
        displayText: "已提交售后工单",
        assistantReply: expect.stringContaining("人工客服团队会在 24 小时内主动联系你"),
      }),
    );
  });
});

describe("AgentHubRichTextBlock hospital bag form", () => {
  it("keeps backend-provided default values in the intake form", () => {
    renderBlock({ payload: hospitalBagFormPayload() });

    expect(screen.getByLabelText("预产期或当前孕周")).toHaveValue("孕34周");
    expect(screen.getByLabelText("分娩方式")).toHaveValue("剖宫产");
    expect(screen.getByLabelText("这次是单胎、双胎，还是三胎及以上？")).toHaveValue("单胎");
    expect(screen.getByLabelText("喂养意向")).toHaveValue("亲喂母乳");
    expect(screen.getByLabelText("产后前两周支持情况")).toHaveValue("有人全天帮忙");
    expect(screen.getByRole("checkbox", { name: "没有" })).toBeChecked();
    expect(screen.queryByRole("checkbox", { name: "计划剖宫产" })).not.toBeInTheDocument();
  });

  it("fills legacy hospital bag forms from birth-prep profile defaults", () => {
    const payload = hospitalBagFormPayload();
    const form = payload.action?.[0]?.form;
    if (form) {
      delete form.default_values;
      const dueField = form.fields?.find((field) => field.id === "due_date_or_week");
      if (dueField) {
        delete dueField.default_value;
        dueField.type = "date";
      }
    }

    renderBlock({
      payload,
      birthPrepProfileDefaults: {
        birth_prep_due_date_or_week: "25周",
        birth_prep_fetus_count: "单胎",
        birth_prep_feeding_intention: "亲喂母乳",
      },
    });

    expect(screen.getByLabelText("预产期或当前孕周")).toHaveValue("25周");
    expect(screen.getByLabelText("这次是单胎、双胎，还是三胎及以上？")).toHaveValue("单胎");
    expect(screen.getByLabelText("喂养意向")).toHaveValue("亲喂母乳");
  });
});

describe("AgentHubRichTextBlock birth journey basic info form", () => {
  it("renders as a grouped intake form with required fields and defaults", () => {
    const { container } = renderBlock({ payload: birthJourneyBasicInfoFormPayload() });

    expect(screen.getByRole("heading", { name: "孕周与基本情况" })).toBeInTheDocument();
    expect(screen.queryByText("请尽量填写当前孕周；其它不清楚可以留空。")).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "基本信息" })).toBeInTheDocument();
    expect(screen.getByLabelText("当前孕周")).toHaveValue("孕25周");
    expect(screen.getByLabelText("当前孕周")).toBeRequired();
    expect(screen.getByLabelText("单胎/双胎")).toBeRequired();
    expect(screen.getByLabelText("年龄")).toBeRequired();
    expect(screen.getByLabelText("所在城市/国家")).toHaveValue("深圳");
    expect(screen.getByText("提交")).toHaveClass("rounded-[14px]");
    expect(container.querySelectorAll("span[aria-hidden='true']")).toHaveLength(3);
  });
});

describe("AgentHubRichTextBlock birth journey plan card", () => {
  it("keeps phase date text regular weight", () => {
    const phaseDateRule = appCssSource.match(/\.birth-journey-phase-date\s*\{[^}]+\}/)?.[0] ?? "";
    expect(phaseDateRule).toContain("font-weight: 400;");
    expect(phaseDateRule).not.toContain("font-weight: 620;");
  });

  it("collapses upcoming phases to the phase title and expands them on click", () => {
    renderBlock({ payload: birthJourneyPayload() });

    expect(screen.getByRole("heading", { name: "孕中期" })).toBeInTheDocument();
        expect(screen.getByText("当前阶段")).toBeInTheDocument();
        expect(screen.getAllByText("当前重点：").length).toBeGreaterThan(0);
        expect(screen.getAllByText("温馨提醒").length).toBeGreaterThan(0);
        expect(screen.getAllByText("接下来建议").length).toBeGreaterThan(0);
        expect(screen.getByText("先把产检和医院流程确认清楚。")).toBeInTheDocument();
        expect(screen.getByText("记录下次产检问题。")).toBeInTheDocument();
        expect(screen.queryByText("整理产检问题。")).not.toBeInTheDocument();

        expect(screen.getByRole("heading", { name: "孕晚期" })).toBeInTheDocument();
        expect(screen.queryByText("下一阶段")).not.toBeInTheDocument();
        expect(screen.getByText("孕28周-36周")).toBeVisible();
        expect(screen.getByText("把入院准备收拢。")).not.toBeVisible();
        expect(screen.getByText("确认待产包。")).not.toBeVisible();
        expect(screen.getByText("制定个性化待产清单")).not.toBeVisible();

    const upcomingSummary = screen.getByText("孕晚期").closest("summary");
    expect(upcomingSummary).toBeTruthy();

    fireEvent.click(upcomingSummary!);

        expect(screen.getByText("把入院准备收拢。")).toBeVisible();
        expect(screen.getByText("确认待产包。")).toBeVisible();
        expect(screen.getByText("我能帮你做")).toBeVisible();
        expect(screen.getByText("制定个性化待产清单")).toBeVisible();
        expect(upcomingSummary!.nextElementSibling).toHaveClass("birth-journey-phase-expanded-content");
      });
  });
