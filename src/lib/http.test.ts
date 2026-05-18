import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  apiRequest,
  appendQueryParams,
  buildNativeMultipartEntries,
  generateMultipartBoundary,
  parseContentDispositionFileName,
  streamSSE,
  toCapacitorParams,
  unwrapApiData,
  uploadMultipart,
} from "./http";
import { Capacitor, CapacitorHttp } from "@capacitor/core";

vi.mock("@capacitor/core", () => ({
  Capacitor: { isNativePlatform: vi.fn(() => false) },
  CapacitorHttp: { request: vi.fn() },
}));

describe("unwrapApiData", () => {
  it("status 为 200 时返回 data", () => {
    const out = unwrapApiData<{ x: number }>({ status: 200, message: "ok", data: { x: 1 } });
    expect(out).toEqual({ x: 1 });
  });

  it("status 非 200 时抛出 ApiError", () => {
    expect(() => unwrapApiData({ status: 400, message: "bad", data: null })).toThrowError(ApiError);
  });
});

describe("appendQueryParams / toCapacitorParams", () => {
  it("拼接 query 并做编码", () => {
    const u = appendQueryParams("/v1/a", { name: "北京", n: 1 });
    expect(u).toContain("name=");
    expect(u).toContain("n=1");
  });

  it("toCapacitorParams 省略 undefined", () => {
    expect(toCapacitorParams({ a: "1", b: undefined })).toEqual({ a: "1" });
  });
});

describe("multipart 辅助", () => {
  it("buildNativeMultipartEntries 顺序与字段正确", () => {
    const entries = buildNativeMultipartEntries("u1", "Ym9keQ==", "a.png", "image/png", "file", { x: "y" });
    expect(entries[0]).toEqual({ type: "string", key: "user_id", value: "u1" });
    expect(entries[1]).toEqual({ type: "string", key: "x", value: "y" });
    expect(entries[2]).toMatchObject({
      type: "base64File",
      key: "file",
      value: "Ym9keQ==",
      fileName: "a.png",
      contentType: "image/png",
    });
  });

  it("generateMultipartBoundary 非空", () => {
    expect(generateMultipartBoundary().length).toBeGreaterThan(8);
  });
});

describe("parseContentDispositionFileName", () => {
  it("解析 filename", () => {
    expect(parseContentDispositionFileName('attachment; filename="a.mp3"')).toBe("a.mp3");
  });
});

describe("apiRequest（mock fetch）", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("合并显式 token 的 Authorization 并解包 data", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: new Headers({ "Content-Type": "application/json" }),
      json: async () => ({ status: 200, message: "ok", data: { id: 2 } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    const data = await apiRequest<{ id: number }>("/v1/x", {
      method: "POST",
      body: { a: 1 },
      token: "explicit-token",
    });
    expect(data).toEqual({ id: 2 });
    const [, init] = fetchMock.mock.calls[0];
    expect((init as RequestInit).headers).toMatchObject({
      Authorization: "Bearer explicit-token",
    });
  });

  it("skipAuth 时不加 Authorization", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: new Headers({ "Content-Type": "application/json" }),
      json: async () => ({ status: 200, message: "ok", data: {} }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await apiRequest("/v1/x", { method: "GET", skipAuth: true });
    const [, init] = fetchMock.mock.calls[0];
    const h = (init as RequestInit).headers as Record<string, string>;
    expect(h.Authorization).toBeUndefined();
  });
});

describe("uploadMultipart 原生分支", () => {
  beforeEach(() => {
    vi.mocked(Capacitor.isNativePlatform).mockReturnValue(true);
    vi.mocked(CapacitorHttp.request).mockResolvedValue({
      status: 200,
      data: { status: 200, message: "ok", data: { error: 0 } },
      headers: {},
      url: "",
    });
  });

  afterEach(() => {
    vi.mocked(Capacitor.isNativePlatform).mockReturnValue(false);
    vi.mocked(CapacitorHttp.request).mockReset();
  });

  it("使用 formData + dataType 与 boundary", async () => {
    const blob = new Blob([new Uint8Array([1, 2, 3])], { type: "image/png" });
    const data = await uploadMultipart<{ error: number }>({
      url: "/v1/files/upload",
      userId: "user-1",
      file: blob,
      skipAuth: true,
    });

    expect(data.error).toBe(0);
    expect(CapacitorHttp.request).toHaveBeenCalledTimes(1);
    const opts = vi.mocked(CapacitorHttp.request).mock.calls[0][0];
    expect(opts.dataType).toBe("formData");
    expect(opts.headers?.["Content-Type"]).toMatch(/multipart\/form-data; boundary=/);
    expect(Array.isArray(opts.data)).toBe(true);
    expect(
      (opts.data as { type: string; key: string }[]).some((e) => e.type === "base64File" && e.key === "file"),
    ).toBe(true);
  });
});

describe("streamSSE（fetch ReadableStream）", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.mocked(Capacitor.isNativePlatform).mockReturnValue(false);
  });

  it("按块接收并解析 data: 行，结束时 onDone", async () => {
    const received: unknown[] = [];
    const encoder = new TextEncoder();
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(encoder.encode('data:{"n":1}\n'));
        controller.enqueue(encoder.encode("data:done\n"));
        controller.close();
      },
    });

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        body: stream,
      }),
    );

    await new Promise<void>((resolve, reject) => {
      streamSSE({
        url: "/api/sse",
        skipAuth: true,
        parseJSON: true,
        onMessage: (m) => received.push(m),
        onDone: () => resolve(),
        onError: (e) => reject(e),
      });
    });

    expect(received).toEqual([{ n: 1 }]);
  });
});
