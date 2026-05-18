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

  it("keeps normal assistant messages that happen to mention request failure", () => {
    const normal = message({
      id: "normal",
      content: "用户说“请求失败”时，可以尝试重新连接设备。",
      chatStreamContext: "main",
    });

    expect(stripTransientAgentHubFailureMessages([normal])).toEqual([normal]);
  });
});
