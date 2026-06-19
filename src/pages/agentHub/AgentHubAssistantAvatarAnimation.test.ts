import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const agentHubSource = readFileSync(resolve(here, "../AgentHub.tsx"), "utf8");
const appStyles = readFileSync(resolve(here, "../../index.css"), "utf8");

describe("AgentHub assistant avatar animation wiring", () => {
  it("uses Sora videos for the active assistant turn and automatic voice playback", () => {
    expect(agentHubSource).toContain(
      'import momcozyAgentSpeakingVideo from "@/assets/momcozy-agent-speaking.mp4"',
    );
    expect(agentHubSource).toContain(
      'import momcozyAgentThinkingVideo from "@/assets/momcozy-agent-thinking.mp4"',
    );
    expect(agentHubSource).toContain("const assistantAvatarVideoSrc =");
    expect(agentHubSource).toContain("isAssistantResponding");
    expect(agentHubSource).toContain(
      "voicePlaybackSnapshot.autoVoicePlayingId === msg.id",
    );
    expect(agentHubSource).toContain('assistantAvatarMode === "speaking"');
    expect(agentHubSource).toContain("momcozyAgentSpeakingVideo");
    expect(agentHubSource).toContain("momcozyAgentThinkingVideo");
    expect(agentHubSource).not.toContain(
      'agentResponseLightRailMode === "replying"\n                    ? momcozyAgentSpeakingVideo',
    );
  });

  it("tracks speaking animation from automatic voice instead of manual bubble playback", () => {
    expect(agentHubSource).toContain("agentHubVoicePlaybackRuntime.subscribe");
    expect(agentHubSource).toContain("agentHubVoicePlaybackRuntime.startAutoVoice");
    expect(agentHubSource).toContain("agentHubVoicePlaybackRuntime.finishAutoVoice");
    expect(agentHubSource).toContain("agentHubVoicePlaybackRuntime.cancelAutoVoice");
    expect(agentHubSource).toContain(
      "const isAssistantSpeaking =\n                  voicePlaybackSnapshot.autoVoicePlayingId === msg.id",
    );
    expect(agentHubSource).not.toContain(
      "const [autoVoicePlayingId, setAutoVoicePlayingId]",
    );
    expect(agentHubSource).not.toContain("setAutoVoicePlayingId(");
    expect(agentHubSource).not.toContain("agentHubVoicePlaybackRuntime.startAutoVoice(msg.id");
  });

  it("renders an autoplaying muted inline video with the static avatar as fallback", () => {
    expect(agentHubSource).toContain("<video");
    expect(agentHubSource).toContain('className="agent-hub-assistant-avatar-video"');
    expect(agentHubSource).toContain("autoPlay");
    expect(agentHubSource).toContain("loop");
    expect(agentHubSource).toContain("muted");
    expect(agentHubSource).toContain("playsInline");
    expect(agentHubSource).toContain("poster={momcozyAgentAvatar}");
    expect(agentHubSource).toContain("agent-hub-assistant-avatar-static");
  });

  it("keeps reduced-motion users on the static avatar", () => {
    expect(appStyles).toContain(".agent-hub-assistant-avatar-video");
    expect(appStyles).toContain("object-position: center 42%");
    expect(appStyles).toContain("@media (prefers-reduced-motion: reduce)");
    expect(appStyles).toContain(".agent-hub-assistant-avatar-video {\n    display: none;");
  });
});
