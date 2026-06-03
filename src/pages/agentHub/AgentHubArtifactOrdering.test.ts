import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const agentHubSource = readFileSync(resolve(here, "../AgentHub.tsx"), "utf8");

describe("AgentHub artifact ordering wiring", () => {
  it("defers ag-ui artifacts and keeps later final text before artifacts", () => {
    expect(agentHubSource).toContain("deferAgUiArtifacts: true");
    expect(agentHubSource).toContain("onAgUiArtifactRichText");
    expect(agentHubSource).toContain("appendTextRenderItemBeforeAgUiArtifacts(next.streamRenderItems, delta)");
    expect(agentHubSource).not.toContain("streamRenderItems: appendTextRenderItem(next.streamRenderItems, delta)");
  });

  it("adds extra separation between assistant text and ag-ui artifacts", () => {
    expect(agentHubSource).toContain('const AG_UI_ARTIFACT_AFTER_TEXT_CLASS = "mt-3.5"');
    expect(agentHubSource).toContain('const AG_UI_ARTIFACT_STACK_OFFSET_CLASS = "mt-2"');
    expect(agentHubSource).toContain('agUiArtifactSpacingClass(itemHasAgUiArtifact, i > 0, "stack")');
    expect(agentHubSource).toContain(
      "agUiArtifactSpacingClass(richTextHasAgUiArtifactForMsg, Boolean(msg.content.trim()))",
    );
  });
});
