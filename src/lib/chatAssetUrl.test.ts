import { beforeEach, describe, expect, it, vi } from "vitest";
import { resolveChatAssetUrl } from "@/lib/chatAssetUrl";

describe("chatAssetUrl", () => {
  beforeEach(() => {
    vi.unstubAllEnvs();
    vi.stubEnv("VITE_CHAT_IMAGE_PROXY_TARGET", "");
    vi.stubEnv("VITE_CHAT_IMAGE_BASE_URL", "");
  });

  it("prefixes relative paths with VITE_CHAT_IMAGE_PROXY_TARGET", () => {
    vi.stubEnv("VITE_CHAT_IMAGE_PROXY_TARGET", "http://192.168.24.182:8900");

    expect(resolveChatAssetUrl("/files/manual.pdf")).toBe("http://192.168.24.182:8900/files/manual.pdf");
    expect(resolveChatAssetUrl("assets/a.png")).toBe("http://192.168.24.182:8900/assets/a.png");
  });

  it("keeps absolute and inline urls unchanged", () => {
    vi.stubEnv("VITE_CHAT_IMAGE_PROXY_TARGET", "http://192.168.24.182:8900");

    expect(resolveChatAssetUrl("https://example.com/a.pdf")).toBe("https://example.com/a.pdf");
    expect(resolveChatAssetUrl("data:image/png;base64,abc")).toBe("data:image/png;base64,abc");
  });

  it("can preserve page-relative anchors and queries", () => {
    vi.stubEnv("VITE_CHAT_IMAGE_PROXY_TARGET", "http://192.168.24.182:8900");

    expect(resolveChatAssetUrl("#section", { preservePageRelative: true })).toBe("#section");
    expect(resolveChatAssetUrl("?tab=agent", { preservePageRelative: true })).toBe("?tab=agent");
  });

  it("can avoid fallback when callers require an explicit proxy target", () => {
    expect(resolveChatAssetUrl("/ibclc-chat.html", { allowBaseFallback: false })).toBe("/ibclc-chat.html");
  });
});
