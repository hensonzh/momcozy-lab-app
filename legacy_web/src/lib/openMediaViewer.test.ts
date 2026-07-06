import { describe, expect, it } from "vitest";
import { resolveMediaViewerUrl, resolveViewerKindFromDocLink } from "@/lib/openMediaViewer";

describe("openMediaViewer", () => {
  it("detects image urls from common extensions", () => {
    expect(resolveViewerKindFromDocLink("/assets/photo.jpg")).toBe("image");
    expect(resolveViewerKindFromDocLink("https://example.com/diagram.PNG?token=1")).toBe("image");
    expect(resolveViewerKindFromDocLink("/assets/illustration.webp")).toBe("image");
  });

  it("keeps existing pdf and video detection", () => {
    expect(resolveViewerKindFromDocLink("/files/manual.pdf")).toBe("pdf");
    expect(resolveViewerKindFromDocLink("/files/demo.mp4")).toBe("video");
    expect(resolveViewerKindFromDocLink("/files/manual.pdf#page=2")).toBe("pdf");
    expect(resolveViewerKindFromDocLink("/files/demo.mov?token=1")).toBe("video");
  });

  it("keeps skill assets on the app resource route", () => {
    expect(resolveMediaViewerUrl("/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf")).toBe(
      "/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf",
    );
  });
});
