import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const agentHubSource = readFileSync(resolve(here, "../AgentHub.tsx"), "utf8");
const appSource = readFileSync(resolve(here, "../../App.tsx"), "utf8");

describe("AgentHub artifact ordering wiring", () => {
  it("defers ag-ui artifacts and keeps later final text before artifacts", () => {
    expect(agentHubSource).toContain("deferAgUiArtifacts: true");
    expect(agentHubSource).toContain("onAgUiArtifactRichText");
    expect(agentHubSource).toContain(
      "streamRenderItems: appendTextRenderItemBeforeAgUiArtifacts(",
    );
    expect(agentHubSource).toContain("next.streamRenderItems");
    expect(agentHubSource).toContain("delta");
    expect(agentHubSource).not.toContain(
      "streamRenderItems: appendTextRenderItem(next.streamRenderItems, delta)",
    );
  });

  it("adds extra separation between assistant text and ag-ui artifacts", () => {
    expect(agentHubSource).toContain(
      'const AG_UI_ARTIFACT_AFTER_TEXT_CLASS = "mt-5"',
    );
    expect(agentHubSource).toContain(
      'const AG_UI_ARTIFACT_STACK_OFFSET_CLASS = "mt-3"',
    );
    expect(agentHubSource).toContain("agUiArtifactSpacingClass(");
    expect(agentHubSource).toContain("itemHasAgUiArtifact");
    expect(agentHubSource).toContain('"stack"');
    expect(agentHubSource).toContain("richTextHasAgUiArtifactForMsg");
    expect(agentHubSource).toContain("Boolean(msg.content.trim())");
  });

  it("moves the visible chat window to the latest page after external chat sync", () => {
    expect(agentHubSource).toContain(
      "showLatestChatHistoryWindow(merged.length)",
    );
    expect(agentHubSource).toContain(
      "visibleStartIndexRef.current = nextStart",
    );
  });

  it("keeps newly sent turns anchored to the latest visible chat window", () => {
    expect(agentHubSource).toContain(
      "pendingLatestChatWindowSyncRef.current = true",
    );
    expect(agentHubSource).toContain("prepareLatestChatWindowForNewTurn()");
    expect(agentHubSource).toContain(
      "? latestChatHistoryStart(messages.length, HUB_CHAT_HISTORY_PAGE)",
    );
  });

  it("uses monotonic local ids for newly inserted AgentHub messages", () => {
    expect(agentHubSource).toContain("let agentHubMessageIdCounter = 0");
    expect(agentHubSource).toContain(
      "function createAgentHubMessageId(prefix: string): string",
    );
    expect(agentHubSource).toContain('id: createAgentHubMessageId("u")');
    expect(agentHubSource).toContain(
      'const replyId = createAgentHubMessageId("m")',
    );
  });

  it("renders professional sources as clickable page title plus url", () => {
    expect(agentHubSource).toContain("{citationDisplayText(citation)}");
    expect(agentHubSource).not.toContain(
      "function citationDisplayUrl(url: string): string",
    );
  });

  it("renders milk analysis reminder notifications like regular assistant text bubbles", () => {
    expect(agentHubSource).toContain("isPlainMilkAnalysisReminder");
    expect(agentHubSource).toContain(
      'msg.id.startsWith("analysis-milk_analysis-")',
    );
    expect(agentHubSource).toContain('msg.chatStreamContext === "main"');
    expect(agentHubSource).toContain("isPlainMilkAnalysisReminder");
  });

  it("keeps voice transcription in the input until the user sends manually", () => {
    expect(agentHubSource).toContain(
      "语音转写结束只回填输入框，需用户主动发送",
    );
    expect(agentHubSource).toContain("setInput(text)");
    expect(agentHubSource).not.toContain("await handleSend(text)");
  });

  it("starts a fresh AgentHub session on app cold start instead of restoring local cached chat", () => {
    expect(agentHubSource).toContain(
      "const isColdStart = inMemory.length === 0",
    );
    expect(agentHubSource).toContain("clearPersistedAgentConversationId()");
    expect(agentHubSource).toContain("clearPersistedAgUiThreadId()");
    expect(agentHubSource).toContain(
      "const merged = isColdStart ? [] : inMemory",
    );
  });

  it("marks manually created new-session greeting for immediate auto voice", () => {
    expect(agentHubSource).toMatch(
      /const greeting = createNewConversationGreetingMessage\(\s*latestUserProfileRef\.current,\s*\);\s*pendingGreetingVoiceIdRef\.current = greeting\.id;\s*chatStore\.setMessages\(\[greeting\]\);/s,
    );
    expect(agentHubSource).toContain("autoVoice?: boolean");
    expect(agentHubSource).toContain("if (opts?.autoVoice ?? true)");
    expect(agentHubSource).toContain("autoVoice: false");
  });

  it("starts hidden milk analysis followup while notification voice is playing", () => {
    expect(agentHubSource).not.toContain("isAgentNotificationVoicePlaying()");
    expect(agentHubSource).toContain("mainChatRuntimeSnapshot.running");
    expect(agentHubSource).toContain("mainChatCancelRef.current");
    expect(agentHubSource).toContain("preserveCurrentVoicePlayback?: boolean");
    expect(agentHubSource).toContain(
      "preserveFocusVoice: opts?.preserveCurrentVoicePlayback",
    );
    expect(agentHubSource).toContain("preserveCurrentVoicePlayback: true");
    expect(agentHubSource).toContain("AGENT_NOTIFICATION_VOICE_IDLE_EVENT");
    expect(agentHubSource).toContain(
      "scheduleMilkAnalysisFollowupBlockedRetry",
    );
    expect(agentHubSource).toContain(
      "tryStartMilkAnalysisReminderFollowupRef.current()",
    );
    expect(agentHubSource).toContain(
      "window.setTimeout(tryStartMilkAnalysisReminderFollowup, 0)",
    );
  });

  it("keeps notification voice lifecycle bounded", () => {
    expect(appSource).toContain("NOTIFICATION_VOICE_TIMEOUT_MS");
    expect(appSource).toContain("new AbortController()");
    expect(appSource).toContain("setAgentNotificationVoicePlaying(false)");
    expect(appSource).toContain("dispatchAgentNotificationVoiceIdle()");
  });

  it("consumes route prefill state into the bottom input once", () => {
    expect(agentHubSource).toContain("consumedAgentPrefillKeyRef");
    expect(agentHubSource).toContain("state?.agentPrefill");
    expect(agentHubSource).toContain("setInput(agentPrefill)");
    expect(agentHubSource).toContain("replace: true");
    expect(agentHubSource).toContain("state: null");
  });

  it("marks status notification when a birth journey plan artifact is generated", () => {
    expect(agentHubSource).toContain("richTextPayloadHasBirthJourneyPlanCard");
    expect(agentHubSource).toContain(
      "markBirthJourneyPlanGeneratedNotification",
    );
    expect(agentHubSource).toContain(
      "maybeMarkBirthJourneyNotification(payload)",
    );
  });
});
