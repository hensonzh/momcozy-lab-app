import { beforeEach, describe, expect, it } from "vitest";
import {
  loadPersistedChatMessages,
  savePersistedChatMessages,
  stripTransientAgentHubFailureMessages,
} from "@/lib/chatMessagesLocalPersistence";
import type { ChatMessage } from "@/types/chat";

const STORAGE_KEY = "mai_agent_hub_chat_messages_v1";

function message(partial: Partial<ChatMessage>): ChatMessage {
  return {
    id: partial.id ?? "m1",
    role: partial.role ?? "mai",
    content: partial.content ?? "",
    timestamp: partial.timestamp ?? "",
    ...partial,
  };
}

describe("chatMessagesLocalPersistence", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("does not persist transient ag-ui transport failures", () => {
    const good = message({ id: "ok", content: "这是一条正常回复。", chatStreamContext: "main" });
    const failedUser = message({ id: "u_err", role: "user", content: "产前咨询" });
    const failure = message({
      id: "err",
      content: "请求失败：ag-ui websocket connection error url=ws://127.0.0.1:8769/api/ag-ui-ws?token=***",
      cardType: "data",
      chatStreamContext: "main",
    });

    savePersistedChatMessages([good, failedUser, failure]);

    expect(loadPersistedChatMessages().map((m) => m.id)).toEqual(["ok"]);
  });

  it("cleans legacy persisted transient failures on load", () => {
    const good = message({ id: "ok", content: "正常历史消息。", chatStreamContext: "main" });
    const failedUser = message({ id: "u_err", role: "user", content: "产前咨询" });
    const failure = message({
      id: "err",
      content: "请求失败：upstream returned status 502:",
      cardType: "data",
      chatStreamContext: "main",
    });
    localStorage.setItem(STORAGE_KEY, JSON.stringify([good, failedUser, failure]));

    expect(loadPersistedChatMessages().map((m) => m.id)).toEqual(["ok"]);
    expect(JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]").map((m: ChatMessage) => m.id)).toEqual(["ok"]);
  });

  it("cleans legacy orphaned user messages left by older failure filtering", () => {
    const good = message({ id: "ok", content: "正常历史消息。", chatStreamContext: "main" });
    const orphan1 = message({ id: "u1", role: "user", content: "产前咨询" });
    const orphan2 = message({ id: "u2", role: "user", content: "产前咨询" });
    localStorage.setItem(STORAGE_KEY, JSON.stringify([good, orphan1, orphan2]));

    expect(loadPersistedChatMessages().map((m) => m.id)).toEqual(["ok"]);
  });

  it("cleans unanswered user messages inside an older consecutive user run", () => {
    const greeting = message({ id: "m0", content: "你好呀，我在。", chatStreamContext: "main" });
    const orphan1 = message({ id: "u1", role: "user", content: "IBCLC" });
    const orphan2 = message({ id: "u2", role: "user", content: "找IBCLC" });
    const answeredUser = message({ id: "u3", role: "user", content: "hello" });
    const answer = message({ id: "m1", role: "mai", content: "Hello～你来啦。", chatStreamContext: "main" });
    localStorage.setItem(STORAGE_KEY, JSON.stringify([greeting, orphan1, orphan2, answeredUser, answer]));

    expect(loadPersistedChatMessages().map((m) => m.id)).toEqual(["m0", "u3", "m1"]);
  });

  it("keeps uploaded image staging when cleaning consecutive user runs", () => {
    const image = message({
      id: "img",
      role: "user",
      content: "",
      cardData: { kind: "uploaded-image", uploadStatus: "ready" },
    });
    const answeredUser = message({ id: "u1", role: "user", content: "帮我看看这张图" });
    const answer = message({ id: "m1", role: "mai", content: "我看到了。", chatStreamContext: "main" });

    expect(stripTransientAgentHubFailureMessages([image, answeredUser, answer]).map((m) => m.id)).toEqual(["img", "u1", "m1"]);
  });

  it("cleans stale empty main-stream placeholders with their user message", () => {
    const good = message({ id: "ok", content: "正常历史消息。", chatStreamContext: "main" });
    const failedUser = message({ id: "u_stale", role: "user", content: "IBCLC" });
    const stalePlaceholder = message({
      id: "m_stale",
      role: "mai",
      content: "",
      cardType: "encourage",
      chatStreamContext: "main",
      agentWorkStartedAtMs: Date.now(),
    });
    localStorage.setItem(STORAGE_KEY, JSON.stringify([good, failedUser, stalePlaceholder]));

    expect(loadPersistedChatMessages().map((m) => m.id)).toEqual(["ok"]);
    expect(JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]").map((m: ChatMessage) => m.id)).toEqual(["ok"]);
  });

  it("keeps assistant placeholders that already have renderable rich content", () => {
    const user = message({ id: "u_card", role: "user", content: "找 IBCLC" });
    const card = message({
      id: "m_card",
      role: "mai",
      content: "",
      cardType: "encourage",
      chatStreamContext: "main",
      richText: {
        title: "",
        content: "",
        button: [],
        card: [],
        action: [{ kind: "ag_ui_artifact", artifact_type: "ibclc_consult", card: {} }],
      },
    });

    expect(stripTransientAgentHubFailureMessages([user, card]).map((m) => m.id)).toEqual(["u_card", "m_card"]);
  });

  it("keeps normal assistant messages that happen to mention request failure", () => {
    const normal = message({
      id: "normal",
      content: "用户说“请求失败”时，可以尝试重新连接设备。",
      chatStreamContext: "main",
    });

    expect(stripTransientAgentHubFailureMessages([normal])).toEqual([normal]);
  });
});
