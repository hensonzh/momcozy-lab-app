import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryRouter } from "react-router-dom";
import AgentHubRichTextBlock, { type IbclcConsultOpenRequest } from "./AgentHubRichTextBlock";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";

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

function renderBlock({
  payload = ibclcPayload(),
  onButtonSelect = vi.fn(),
  onOpenIbclcConsult = vi.fn(),
}: {
  payload?: ChatRichTextPayload;
  onButtonSelect?: (value: string, options?: { displayText?: string }) => void;
  onOpenIbclcConsult?: (request: IbclcConsultOpenRequest) => void;
} = {}) {
  render(
    <MemoryRouter initialEntries={["/agent?tab=agent#latest"]}>
      <AgentHubRichTextBlock
        payload={payload}
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

  it("renders order and purchase fields and includes them in the submit summary", () => {
    const onButtonSelect = vi.fn();
    renderBlock({ payload: supportTicketPayload(), onButtonSelect });

    expect(screen.getByRole("textbox", { name: "产品型号" })).toBeRequired();
    expect(screen.getByRole("textbox", { name: "订单号" })).toHaveValue("MC123");
    expect(screen.getByRole("textbox", { name: "购买渠道" })).toHaveValue("官网");

    fireEvent.click(screen.getByRole("button", { name: "确认并提交" }));

    expect(onButtonSelect).toHaveBeenCalledWith(
      expect.stringContaining("订单号：MC123"),
      expect.objectContaining({ displayText: "已提交售后工单" }),
    );
    expect(onButtonSelect).toHaveBeenCalledWith(
      expect.stringContaining("购买渠道：官网"),
      expect.objectContaining({ displayText: "已提交售后工单" }),
    );
    expect(onButtonSelect).toHaveBeenCalledWith(
      expect.stringContaining("当前系统不支持查看工单进度"),
      expect.objectContaining({ displayText: "已提交售后工单" }),
    );
  });
});
