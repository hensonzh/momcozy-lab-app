import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryRouter } from "react-router-dom";
import AgentHubRichTextBlock, {
  type IbclcConsultOpenRequest,
} from "./AgentHubRichTextBlock";
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

function birthJourneyLayeredPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "card",
        artifact_id: "birth_journey_layered_1",
        card: {
          card_type: "birth_journey_plan_card",
          schema_version: "1.0",
          card_json: {
            title: "孕期计划",
            subtitle: "从孕20周到产后 42 天的阶段路线图",
            owner: {
              current_week: "孕20周",
              estimated_due_date: "2026/10/15",
            },
            planning_layers: {
              current_week_focus: {
                title: "本周重点",
                items: [
                  {
                    title: "确认本周产检安排",
                    reason:
                      "孕早期常见孕吐、反酸、乏力或尿频，把每天最影响生活的变化记录下来更方便问医生。",
                    steps: ["确认下次产检日期", "准备当天要带的检查报告"],
                  },
                ],
              },
              next_7_days: {
                title: "未来 7 天",
                subtitle: "先处理近期任务",
                items: ["今天完成建档材料整理"],
              },
              next_2_4_weeks: {
                title: "未来 2-4 周",
                items: [{ title: "整理下一次产检问题" }],
              },
              later_milestones: {
                title: "后续重要节点",
                items: [{ title: "孕晚期确认待产包" }],
              },
            },
          },
        },
      },
    ],
  };
}

function birthJourneyTodoPlanPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "card",
        artifact_id: "birth_journey_todo_1",
        card: {
          card_type: "birth_journey_plan_card",
          schema_version: "1.0",
          card_json: {
            title: "孕期计划",
            owner: {
              current_week: "孕25周",
            },
            todo_plan: {
              title: "孕期 To do list",
              cadence: "monthly",
              cadence_label: "按月计划",
              periods: [
                {
                  id: "period_01",
                  title: "孕 25-27 周",
                  subtitle: "重点完成糖耐、血常规/尿常规和血压体重等复查。",
                  display_mode: "expanded",
                  status: "current",
                  items: [
                    {
                      title: "完成糖耐并记录复查结果",
                      reason:
                        "排好禁食、抽血、检查后进食和结果回看，并问清是否需要复查。",
                      priority_label: "重要",
                      steps: [
                        "确认禁食开始时间",
                        "保存抽血流程和耗时",
                        "安排检查后第一餐和返程",
                      ],
                    },
                  ],
                },
                {
                  id: "period_02",
                  title: "孕 28-29 周",
                  subtitle: "开始固定胎动、血压、水肿和胎儿生长观察节奏。",
                  display_mode: "collapsed",
                  status: "upcoming",
                  items: [
                    {
                      title: "固定胎动和血压观察",
                      reason: "每天固定观察胎动和明显不适。",
                      priority_label: "建议",
                      steps: [
                        "定一个每天看胎动的时间",
                        "保存不对劲时联系医院的方式",
                      ],
                    },
                  ],
                },
                {
                  id: "period_terminal",
                  title: "临产与住院生产",
                  subtitle: "把临产信号、医院入口、证件报告和陪同分工收口。",
                  display_mode: "terminal",
                  status: "terminal",
                  items: [
                    {
                      title: "定好临产后怎么联系医院",
                      reason: "临近生产时提前知道联系谁、走哪个入口。",
                      priority_label: "重要",
                      steps: ["保存产科或急诊联系电话"],
                    },
                  ],
                },
              ],
            },
            planning_layers: {
              current_week_focus: {
                title: "旧本周重点",
                items: [{ title: "旧结构事项" }],
              },
            },
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
              options: [
                "有人全天帮忙",
                "白天主要自己",
                "夜间主要自己",
                "支持少",
                "不确定",
              ],
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

function hospitalBagCardPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "card",
        artifact_id: "hospital_bag_card_1",
        card: {
          card_type: "hospital_bag_card",
          schema_version: "1.0",
          card_json: {
            title: "待产包",
            packing_groups: [
              {
                group_id: "mom_hospital_bag",
                title: "妈妈住院包",
                items: [
                  {
                    label: "产褥垫组合装",
                    quantity: "1包",
                    priority: "must",
                  },
                ],
              },
            ],
            disclaimer: "以医院实际要求为准。",
          },
        },
      },
    ],
  };
}

function milkPlanPayload(): ChatRichTextPayload {
  return {
    title: "",
    content: "",
    button: [],
    card: [],
    action: [
      {
        kind: "ag_ui_artifact",
        artifact_type: "card",
        artifact_id: "milk_plan_1",
        card: {
          card_type: "milk_plan_card",
          schema_version: "1.0",
          card_json: {
            title: "追奶计划",
            status_label: "待确认",
            sections: [
              {
                id: "target",
                title: "目标",
                tone: "normal",
                items: ["当前每日奶量约 549 ml，目标约 709.2 ml。"],
              },
              {
                id: "plan",
                title: "计划",
                tone: "info",
                metrics: [
                  { label: "周期", value: "3 天", detail: "从明天开始" },
                ],
                items: ["保留原有 8 个吸奶任务，新增 1 个吸奶任务。"],
              },
              {
                id: "how",
                title: "每次怎么做",
                tone: "default",
                items: [
                  "吸奶过程中如果有明显痛感，暂停吸奶并联系医生或IBCLC顾问。",
                ],
              },
            ],
          },
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
              required: true,
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
              id: "first_birth",
              label: "是否第一胎",
              type: "select",
              required: true,
              options: ["是", "否", "不确定/暂不说"],
            },
            {
              id: "birth_path",
              label: "计划分娩方式",
              type: "select",
              required: true,
              options: ["顺产", "剖宫产", "还没确定", "不确定/暂不说"],
            },
            {
              id: "city_or_country",
              label: "所在城市/国家",
              type: "text",
              default_value: "深圳",
            },
            {
              id: "birth_hospital",
              label: "建档/生产医院",
              type: "text",
              placeholder: "如果还没建档，可以写“还没确定”",
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
  birthPrepProfileDefaults?: React.ComponentProps<
    typeof AgentHubRichTextBlock
  >["birthPrepProfileDefaults"];
  onButtonSelect?: (
    value: string,
    options?: { displayText?: string; assistantReply?: string },
  ) => boolean | void;
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

    expect(
      screen.getByRole("checkbox", { name: /隐私政策/ }),
    ).not.toBeChecked();
    expect(
      screen.getByText("启动咨询后，会自动将你的问题同步给顾问"),
    ).toBeInTheDocument();
    expect(button).toBeDisabled();

    fireEvent.click(button);

    expect(onOpenIbclcConsult).not.toHaveBeenCalled();
  });

  it("opens the IBCLC consult after the agreement is accepted", () => {
    const onOpenIbclcConsult = vi.fn<[IbclcConsultOpenRequest], void>();
    localStorage.setItem("momcozy_user_id", "old-ibclc-user");
    renderBlock({ onOpenIbclcConsult });

    fireEvent.click(screen.getByRole("checkbox", { name: /隐私政策/ }));
    const button = screen.getByRole("button", { name: "咨询 IBCLC" });

    expect(button).toBeEnabled();

    fireEvent.click(button);

    expect(onOpenIbclcConsult).toHaveBeenCalledTimes(1);
    const request = onOpenIbclcConsult.mock.calls[0][0];
    expect(request).toMatchObject({
      consultId: "ibclc_1",
      threadId: "thread_test",
      returnTo: "/agent?tab=agent#latest",
    });
    expect(request.userId).toBeTruthy();
    expect(request.userId).not.toBe("old-ibclc-user");
    expect(
      new URL(request.chatUrl, window.location.origin).searchParams.get(
        "user_id",
      ),
    ).toBe(request.userId);
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
    expect(screen.getByRole("textbox", { name: "订单号" })).toHaveValue(
      "MC123",
    );
    expect(screen.getByRole("textbox", { name: "购买渠道" })).toHaveValue(
      "官网",
    );

    fireEvent.click(screen.getByRole("button", { name: "确认并提交" }));

    expect(onButtonSelect).toHaveBeenCalledWith(
      "已提交售后工单",
      expect.objectContaining({
        displayText: "已提交售后工单",
        assistantReply: expect.stringContaining(
          "人工客服团队会在 24 小时内主动联系你",
        ),
      }),
    );
  });
});

describe("AgentHubRichTextBlock hospital bag form", () => {
  it("keeps backend-provided default values in the intake form", () => {
    renderBlock({ payload: hospitalBagFormPayload() });

    expect(screen.getByLabelText("预产期或当前孕周")).toHaveValue("孕34周");
    expect(screen.getByLabelText("分娩方式")).toHaveValue("剖宫产");
    expect(
      screen.getByLabelText("这次是单胎、双胎，还是三胎及以上？"),
    ).toHaveValue("单胎");
    expect(screen.getByLabelText("喂养意向")).toHaveValue("亲喂母乳");
    expect(screen.getByLabelText("产后前两周支持情况")).toHaveValue(
      "有人全天帮忙",
    );
    expect(screen.getByRole("checkbox", { name: "没有" })).toBeChecked();
    expect(
      screen.queryByRole("checkbox", { name: "计划剖宫产" }),
    ).not.toBeInTheDocument();
  });

  it("ignores duplicate form submits before the disabled state renders", () => {
    let form: HTMLFormElement | null = null;
    const onButtonSelect = vi.fn(() => {
      if (form) fireEvent.submit(form);
    });
    renderBlock({ payload: hospitalBagFormPayload(), onButtonSelect });

    const submitButton = screen.getByRole("button", { name: "Confirm" });
    form = submitButton.closest("form");
    expect(form).not.toBeNull();

    fireEvent.submit(form!);

    expect(onButtonSelect).toHaveBeenCalledTimes(1);
    expect(screen.getByRole("button", { name: "已提交" })).toBeDisabled();
  });

  it("keeps the form available when the parent rejects submission", () => {
    const onButtonSelect = vi.fn(() => false);
    renderBlock({ payload: hospitalBagFormPayload(), onButtonSelect });

    const submitButton = screen.getByRole("button", { name: "Confirm" });
    const form = submitButton.closest("form");
    expect(form).not.toBeNull();

    fireEvent.submit(form!);
    fireEvent.submit(form!);

    expect(onButtonSelect).toHaveBeenCalledTimes(2);
    expect(screen.getByRole("button", { name: "Confirm" })).toBeEnabled();
  });

  it("fills legacy hospital bag forms from birth-prep profile defaults", () => {
    const payload = hospitalBagFormPayload();
    const form = payload.action?.[0]?.form;
    if (form) {
      delete form.default_values;
      const dueField = form.fields?.find(
        (field) => field.id === "due_date_or_week",
      );
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
    expect(
      screen.getByLabelText("这次是单胎、双胎，还是三胎及以上？"),
    ).toHaveValue("单胎");
    expect(screen.getByLabelText("喂养意向")).toHaveValue("亲喂母乳");
  });
});

describe("AgentHubRichTextBlock hospital bag card", () => {
  it("renders a cart entry from the generated hospital bag card", () => {
    const openCart = vi.fn((event: Event) => event.preventDefault());
    window.addEventListener("momcozy-open-hospital-bag-cart", openCart);
    try {
      renderBlock({ payload: hospitalBagCardPayload() });

      fireEvent.click(screen.getByRole("button", { name: "打开待产包购物车" }));

      expect(openCart).toHaveBeenCalledTimes(1);
      expect((openCart.mock.calls[0][0] as CustomEvent).detail).toMatchObject({
        href: "/hospital-bag-cart",
        source: "hospital_bag_card",
      });
    } finally {
      window.removeEventListener("momcozy-open-hospital-bag-cart", openCart);
    }
  });
});

describe("AgentHubRichTextBlock birth journey basic info form", () => {
  it("renders as a grouped intake form with required fields and defaults", () => {
    const { container } = renderBlock({
      payload: birthJourneyBasicInfoFormPayload(),
    });

    expect(
      screen.getByRole("heading", { name: "孕周与基本情况" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByText("请尽量填写当前孕周；其它不清楚可以留空。"),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "基本信息" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("当前孕周")).toHaveValue("孕25周");
    expect(screen.getByLabelText("当前孕周")).toBeRequired();
    expect(screen.getByLabelText("是否 IVF（体外受精）")).toBeRequired();
    expect(screen.getByLabelText("单胎/双胎")).toBeRequired();
    expect(screen.getByLabelText("年龄")).toBeRequired();
    expect(screen.getByLabelText("是否第一胎")).toBeRequired();
    expect(screen.getByLabelText("计划分娩方式")).toBeRequired();
    expect(screen.getByLabelText("所在城市/国家")).toHaveValue("深圳");
    expect(screen.getByLabelText("建档/生产医院")).not.toBeRequired();
    expect(screen.getByText("提交")).toHaveClass("rounded-[14px]");
    expect(container.querySelectorAll("span[aria-hidden='true']")).toHaveLength(
      6,
    );
  });

  it("submits with the birth journey form id even when fields overlap with hospital bag", () => {
    const onButtonSelect = vi.fn();
    renderBlock({
      payload: birthJourneyBasicInfoFormPayload(),
      onButtonSelect,
    });

    fireEvent.change(screen.getByLabelText("是否 IVF（体外受精）"), {
      target: { value: "否" },
    });
    fireEvent.change(screen.getByLabelText("年龄"), {
      target: { value: "31" },
    });
    fireEvent.change(screen.getByLabelText("单胎/双胎"), {
      target: { value: "单胎" },
    });
    fireEvent.change(screen.getByLabelText("是否第一胎"), {
      target: { value: "是" },
    });
    fireEvent.change(screen.getByLabelText("计划分娩方式"), {
      target: { value: "还没确定" },
    });
    fireEvent.change(screen.getByLabelText("建档/生产医院"), {
      target: { value: "深圳市妇幼" },
    });
    fireEvent.click(screen.getByRole("button", { name: "提交" }));

    expect(onButtonSelect).toHaveBeenCalledTimes(1);
    const [message, options] = onButtonSelect.mock.calls[0];
    expect(options).toMatchObject({ displayText: "已提交：孕周与基本情况" });
    expect(message).toContain("form_id: birth_journey_basic_info_intake");
    expect(message).not.toContain("form_id: hospital_bag_intake");
  });
});

describe("AgentHubRichTextBlock milk plan card", () => {
  it("renders section item copy as list items", () => {
    renderBlock({ payload: milkPlanPayload() });

    expect(screen.queryByText("待确认")).toBeNull();
    expect(
      screen
        .getByText("当前每日奶量约 549 ml，目标约 709.2 ml。")
        .closest("li"),
    ).toBeTruthy();
    expect(
      screen
        .getByText("保留原有 8 个吸奶任务，新增 1 个吸奶任务。")
        .closest("li"),
    ).toBeTruthy();
    expect(
      screen
        .getByText("吸奶过程中如果有明显痛感，暂停吸奶并联系医生或IBCLC顾问。")
        .closest("li"),
    ).toBeTruthy();
  });
});

describe("AgentHubRichTextBlock birth journey plan card", () => {
  it("renders todo plan periods before legacy planning layers", () => {
    renderBlock({ payload: birthJourneyTodoPlanPayload() });

    const currentHeading = screen.getByRole("heading", { name: "孕 25-27 周" });
    const nextHeading = screen.getByRole("heading", { name: "孕 28-29 周" });
    const terminalHeading = screen.getByRole("heading", {
      name: "临产与住院生产",
    });
    expect(currentHeading.closest("details")).toHaveAttribute("open");
    expect(nextHeading.closest("details")).not.toHaveAttribute("open");
    expect(terminalHeading.closest("details")).not.toHaveAttribute("open");
    expect(screen.getByText("完成糖耐并记录复查结果")).toBeInTheDocument();
    expect(screen.getByText("确认禁食开始时间")).toBeInTheDocument();
    expect(screen.getByText("保存抽血流程和耗时")).toBeInTheDocument();
    expect(screen.getByText("定好临产后怎么联系医院")).toBeInTheDocument();
    expect(screen.getAllByText("重要").length).toBeGreaterThan(0);
    expect(
      screen.queryByRole("heading", { name: "旧本周重点" }),
    ).not.toBeInTheDocument();
  });

  it("renders the planning layers structure", () => {
    renderBlock({ payload: birthJourneyLayeredPayload() });

    expect(
      screen.getByRole("heading", { name: "本周重点" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "未来 7 天" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "未来 2-4 周" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "后续重要节点" }),
    ).toBeInTheDocument();
    expect(screen.getByText("确认本周产检安排")).toBeInTheDocument();
    expect(screen.getByText("确认下次产检日期")).toBeInTheDocument();
    expect(
      screen.getByText(
        "孕早期常见孕吐、反酸、乏力或尿频，把每天最影响生活的变化记录下来更方便问医生。",
      ),
    ).toBeInTheDocument();
    expect(screen.queryByText(/更方便…/u)).not.toBeInTheDocument();
    expect(screen.getByText("今天完成建档材料整理")).toBeInTheDocument();
    expect(
      screen.queryByText("从孕20周到产后 42 天的阶段路线图"),
    ).not.toBeInTheDocument();
  });
});
