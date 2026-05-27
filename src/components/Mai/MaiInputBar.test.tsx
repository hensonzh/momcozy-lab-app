import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import MaiInputBar from "./MaiInputBar";

describe("MaiInputBar", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("does not send while IME composition is active", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="ni" onChange={vi.fn()} onSend={onSend} />);

    const input = screen.getByPlaceholderText("和 M.ai 聊聊...");
    fireEvent.compositionStart(input);
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    expect(onSend).not.toHaveBeenCalled();
  });

  it("requires a fresh Enter after IME composition ends", () => {
    vi.useFakeTimers();
    const onSend = vi.fn();
    render(<MaiInputBar value="你" onChange={vi.fn()} onSend={onSend} />);

    const input = screen.getByPlaceholderText("和 M.ai 聊聊...");
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

    fireEvent.keyDown(screen.getByPlaceholderText("和 M.ai 聊聊..."), {
      key: "Enter",
      code: "Enter",
      keyCode: 229,
    });

    expect(onSend).not.toHaveBeenCalled();
  });

  it("allows Enter to stop an active response even when the input is empty", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={onSend} sendLoading />);

    fireEvent.keyDown(screen.getByPlaceholderText("和 M.ai 聊聊..."), { key: "Enter", code: "Enter" });

    expect(onSend).toHaveBeenCalledTimes(1);
  });

  it("allows Enter to send when an attachment is ready and text is empty", () => {
    const onSend = vi.fn();
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={onSend} canSendWithoutText />);

    fireEvent.keyDown(screen.getByPlaceholderText("和 M.ai 聊聊..."), { key: "Enter", code: "Enter" });

    expect(onSend).toHaveBeenCalledTimes(1);
  });

  it("stages pasted clipboard images through the existing photo upload flow", () => {
    const onPhotoFile = vi.fn();
    const image = new File(["image"], "schedule.png", { type: "image/png" });
    render(<MaiInputBar value="" onChange={vi.fn()} onSend={vi.fn()} onPhotoFile={onPhotoFile} />);

    fireEvent.paste(screen.getByPlaceholderText("和 M.ai 聊聊..."), {
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

    const allowed = fireEvent.paste(screen.getByPlaceholderText("和 M.ai 聊聊..."), {
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
});
