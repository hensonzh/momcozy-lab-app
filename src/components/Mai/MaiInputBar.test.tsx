import { fireEvent, render, screen } from "@testing-library/react";
import { useState } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";
import MaiInputBar from "./MaiInputBar";

describe("MaiInputBar", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("does not send while IME composition is active", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="ni" onChange={vi.fn()} onSend={onSend} />);

    const input = screen.getByPlaceholderText("和 Comate 聊聊...");
    fireEvent.compositionStart(input);
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    expect(onSend).not.toHaveBeenCalled();
  });

  it("requires a fresh Enter after IME composition ends", () => {
    vi.useFakeTimers();
    const onSend = vi.fn();
    render(<MaiInputBar value="你" onChange={vi.fn()} onSend={onSend} />);

    const input = screen.getByPlaceholderText("和 Comate 聊聊...");
    fireEvent.compositionStart(input);
    fireEvent.compositionEnd(input);
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    expect(onSend).not.toHaveBeenCalled();

    vi.advanceTimersByTime(130);
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    expect(onSend).toHaveBeenCalledTimes(1);
  });

  it("ignores the IME confirmation keyCode", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="ni" onChange={vi.fn()} onSend={onSend} />);

    fireEvent.keyDown(screen.getByPlaceholderText("和 Comate 聊聊..."), {
      key: "Enter",
      code: "Enter",
      keyCode: 229,
    });

    expect(onSend).not.toHaveBeenCalled();
  });

  it("allows Enter to stop an active response even when the input is empty", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={onSend} sendLoading />);

    fireEvent.keyDown(screen.getByPlaceholderText("和 Comate 聊聊..."), { key: "Enter", code: "Enter" });

    expect(onSend).toHaveBeenCalledTimes(1);
  });

  it("keeps the send affordance when text is present during an active response", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="IBCLC" onChange={vi.fn()} onSend={onSend} sendLoading />);

    fireEvent.click(screen.getByTitle("发送"));

    expect(screen.queryByTitle("停止回复")).not.toBeInTheDocument();
    expect(onSend).toHaveBeenCalledTimes(1);
  });

  it("allows Enter to send when an attachment is ready and text is empty", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={onSend} canSendWithoutText />);

    fireEvent.keyDown(screen.getByPlaceholderText("和 Comate 聊聊..."), { key: "Enter", code: "Enter" });

    expect(onSend).toHaveBeenCalledTimes(1);
  });

  it("stages pasted clipboard images through the existing photo upload flow", () => {
    const onPhotoFile = vi.fn();
    const image = new File(["image"], "schedule.png", { type: "image/png" });
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={vi.fn()} onPhotoFile={onPhotoFile} />);

    fireEvent.paste(screen.getByPlaceholderText("和 Comate 聊聊..."), {
      clipboardData: {
        items: [
          {
            kind: "file",
            type: "image/png",
            getAsFile: () => image,
          },
        ],
        files: [],
      },
    });

    expect(onPhotoFile).toHaveBeenCalledWith(image);
  });

  it("does not intercept normal text paste", () => {
    const onPhotoFile = vi.fn();
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={vi.fn()} onPhotoFile={onPhotoFile} />);

    const allowed = fireEvent.paste(screen.getByPlaceholderText("和 Comate 聊聊..."), {
      clipboardData: {
        items: [
          {
            kind: "string",
            type: "text/plain",
            getAsFile: () => null,
          },
        ],
        files: [],
      },
    });

    expect(allowed).toBe(true);
    expect(onPhotoFile).not.toHaveBeenCalled();
  });

  it("switches to hold-to-talk mode when the voice icon is clicked", () => {
    const onVoiceStart = vi.fn();
    const onVoiceEnd = vi.fn();
    const { container } = render(
      <MaiInputBar
        value=""
        onChange={vi.fn()}
        onSend={vi.fn()}
        onVoiceStart={onVoiceStart}
        onVoiceEnd={onVoiceEnd}
      />,
    );

    expect(container.querySelector(".lucide-mic")).toBeInTheDocument();
    expect(container.querySelector(".lucide-keyboard")).not.toBeInTheDocument();

    fireEvent.click(screen.getByTitle("切换到语音输入"));

    expect(screen.queryByPlaceholderText("和 Comate 聊聊...")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "按住说话" })).toBeInTheDocument();
    expect(container.querySelector(".lucide-keyboard")).toBeInTheDocument();
    expect(onVoiceStart).not.toHaveBeenCalled();
  });

  it("restores the typed draft when voice mode is closed before recording", () => {
    const Harness = () => {
      const [value, setValue] = useState("先输入的草稿");
      return (
        <MaiInputBar
          value={value}
          onChange={setValue}
          onSend={vi.fn()}
          onVoiceStart={vi.fn()}
          onVoiceEnd={vi.fn()}
        />
      );
    };
    render(<Harness />);

    expect(screen.getByDisplayValue("先输入的草稿")).toBeInTheDocument();

    fireEvent.click(screen.getByTitle("切换到语音输入"));
    expect(screen.queryByDisplayValue("先输入的草稿")).not.toBeInTheDocument();

    fireEvent.click(screen.getByTitle("切换到文字输入"));
    expect(screen.getByDisplayValue("先输入的草稿")).toBeInTheDocument();
  });

  it("starts voice recognition while the hold-to-talk button is pressed and submits on release", () => {
    const onVoiceStart = vi.fn();
    const onVoiceEnd = vi.fn();
    render(
      <MaiInputBar
        value=""
        onChange={vi.fn()}
        onSend={vi.fn()}
        onVoiceStart={onVoiceStart}
        onVoiceEnd={onVoiceEnd}
      />,
    );

    fireEvent.click(screen.getByTitle("切换到语音输入"));
    const holdButton = screen.getByRole("button", { name: "按住说话" });
    fireEvent.pointerDown(holdButton, { pointerId: 1 });
    fireEvent.pointerUp(holdButton, { pointerId: 1 });

    expect(onVoiceStart).toHaveBeenCalledTimes(1);
    expect(onVoiceEnd).toHaveBeenCalledWith({ submit: true });
  });

  it("shows live transcription text inside the hold-to-talk control", () => {
    const onVoiceStart = vi.fn();
    const onVoiceEnd = vi.fn();
    const { rerender } = render(
      <MaiInputBar
        value=""
        onChange={vi.fn()}
        onSend={vi.fn()}
        onVoiceStart={onVoiceStart}
        onVoiceEnd={onVoiceEnd}
      />,
    );

    fireEvent.click(screen.getByTitle("切换到语音输入"));
    rerender(
      <MaiInputBar
        value="今天吸奶感觉不错"
        onChange={vi.fn()}
        onSend={vi.fn()}
        onVoiceStart={onVoiceStart}
        onVoiceEnd={onVoiceEnd}
        speechListening
      />,
    );

    expect(screen.getByText("今天吸奶感觉不错")).toBeInTheDocument();
  });
});
