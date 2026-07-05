import { act, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { MemoryRouter } from "react-router-dom";
import { IbclcChatPanel } from "./IbclcChat";

describe("IbclcChatPanel", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("starts the H5 loading flow with a 1 second health information stage", () => {
    vi.useFakeTimers();

    render(
      <MemoryRouter>
        <IbclcChatPanel conversationId="thread_1" consultId="ibclc_1" />
      </MemoryRouter>,
    );

    expect(screen.getByText("健康信息整理中")).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(999);
    });
    expect(screen.getByText("健康信息整理中")).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(1);
    });
    expect(screen.getByText("连接中")).toBeInTheDocument();
  });
});
