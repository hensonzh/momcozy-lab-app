import { describe, expect, it } from "vitest";
import { resolveViewerKindFromDocLink } from "@/lib/openMediaViewer";

describe("openMediaViewer", () => {
  it("detects image urls from common extensions", () => {
    expect(resolveViewerKindFromDocLink("/assets/photo.jpg")).toBe("image");
    expect(resolveViewerKindFromDocLink("https://example.com/diagram.PNG?token=1")).toBe("image");
    expect(resolveViewerKindFromDocLink("/assets/illustration.webp")).toBe("image");
  });

  it("keeps existing pdf and video detection", () => {
    expect(resolveViewerKindFromDocLink("/files/manual.pdf")).toBe("pdf");
    expect(resolveViewerKindFromDocLink("/files/demo.mp4")).toBe("video");
  });
});
