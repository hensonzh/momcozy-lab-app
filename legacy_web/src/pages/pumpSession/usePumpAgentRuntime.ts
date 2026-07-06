import { useCallback, useRef, useState } from "react";
import {
  postAgUiWebSocketStream,
  parseChatRichTextFromSseData,
} from "@/lib/agentApi";
import { extractChatAnswerChunk, mergeStreamingAnswerDelta } from "@/lib/chatStreaming";
import { pushPumpStopAgentSummaryToChat, type PumpStopSummaryOptions } from "@/lib/pumpAutoEndSession";
import { getAgUiThreadIdForRequest, persistAgUiThreadId } from "@/lib/agentConversationSession";
import type { PumpSessionEndedEvent } from "@/lib/pumpSessionLifecycle";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

function extractAgUiContentChunk(data: string | object): string {
  if (typeof data === "object" && data != null) {
    const rec = data as Record<string, unknown>;
    const type = typeof rec.type === "string" ? rec.type.toUpperCase() : "";
    if (type === "TEXT_MESSAGE_CONTENT") {
      const delta = rec.delta;
      return typeof delta === "string" ? delta : "";
    }
    if (type && type !== "MESSAGE" && type !== "REASONING") return "";
  }
  return extractChatAnswerChunk(data);
}

export function usePumpAgentRuntime() {
  const [maiAssistantContent, setMaiAssistantContent] = useState("");
  const [maiAssistantLoading, setMaiAssistantLoading] = useState(false);
  const [maiAssistantError, setMaiAssistantError] = useState("");
  const [maiAssistantRichText, setMaiAssistantRichText] = useState<ChatRichTextPayload | null>(null);
  const mergedRef = useRef("");
  const cancelRef = useRef<(() => void) | null>(null);

  const sendAgentQuery = useCallback((query: string) => {
    cancelRef.current?.();
    setMaiAssistantLoading(true);
    setMaiAssistantError("");
    setMaiAssistantRichText(null);
    mergedRef.current = "";
    setMaiAssistantContent("");
    const locale = (typeof navigator !== "undefined" && navigator.language) || "zh-CN";
    const timezone =
      (typeof Intl !== "undefined" && Intl.DateTimeFormat().resolvedOptions().timeZone) ||
      "America/Los_Angeles";

    cancelRef.current = postAgUiWebSocketStream({
      text: query,
      threadId: getAgUiThreadIdForRequest(),
      locale,
      images: [],
      forwardedProps: {
        user_id: DEFAULT_CHAT_USER_ID,
        locale,
        timezone,
        message_sent_at: new Date().toISOString(),
        user_profile: {
          user_id: DEFAULT_CHAT_USER_ID,
          language: locale,
        },
      },
      parseJSON: true,
      onMessage: (data) => {
        if (typeof data === "object" && data != null) {
          persistAgUiThreadId((data as { thread_id?: unknown }).thread_id);
        }
        const chunk = extractAgUiContentChunk(data);
        const { merged } = mergeStreamingAnswerDelta(mergedRef.current, chunk);
        mergedRef.current = merged;
        setMaiAssistantContent(merged);
        const rich = parseChatRichTextFromSseData(data);
        if (rich) setMaiAssistantRichText(rich);
      },
      onDone: () => {
        setMaiAssistantLoading(false);
      },
      onError: (error) => {
        setMaiAssistantLoading(false);
        setMaiAssistantError(error?.message || "请求失败");
      },
    });
  }, []);

  const pushStopPumpAgentSummary = useCallback(async (
    event?: PumpSessionEndedEvent | null,
    options?: PumpStopSummaryOptions | null,
  ) => {
    return pushPumpStopAgentSummaryToChat(event, options);
  }, []);

  return {
    maiAssistantContent,
    maiAssistantLoading,
    maiAssistantError,
    maiAssistantRichText,
    sendAgentQuery,
    pushStopPumpAgentSummary,
  };
}
