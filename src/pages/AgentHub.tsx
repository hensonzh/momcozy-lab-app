import React, {
  useState,
  useRef,
  useEffect,
  useLayoutEffect,
  useCallback,
  useSyncExternalStore,
} from "react";
import { useNavigate, useLocation } from "react-router-dom";
import InlineScheduleFlow from "@/components/schedule/InlineScheduleFlow";
import type { InlineScheduleFlowHandle } from "@/components/schedule/InlineScheduleFlow";
import InlineLactationFlow from "@/components/lactation/InlineLactationFlow";
import type { InlineLactationFlowHandle } from "@/components/lactation/InlineLactationFlow";
import InlineMaternityFlow from "@/components/maternity/InlineMaternityFlow";
import type { InlineMaternityFlowHandle } from "@/components/maternity/InlineMaternityFlow";
import InlineWorkFlow from "@/components/work/InlineWorkFlow";
import type { InlineWorkFlowHandle } from "@/components/work/InlineWorkFlow";
import {
  Volume2,
  VolumeX,
  ChevronDown,
  ChevronRight,
  X,
  Loader2,
  Plus,
} from "lucide-react";
import PillGroups from "@/components/pills/PillGroups";
import MaiInputBar from "@/components/Mai/MaiInputBar";
import AgentResponseLightRail from "@/components/Mai/AgentResponseLightRail";
import { useAgentHubSpeechInput } from "@/hooks/useAgentHubSpeechInput";
import { cn } from "@/lib/utils";
import type {
  AgUiToolCallRow,
  ChatMessage,
  ChatMessageCitation,
  ChatMessageImageAttachment,
  ChatMessageLink,
  ChatStreamRenderItem,
} from "@/types/chat";
import { chatBus } from "@/lib/chatBus";
import { chatStore } from "@/lib/chatStore";
import { agentHubMainChatRuntime } from "@/lib/agentHubMainChatRuntime";
import { agentHubVoicePlaybackRuntime } from "@/lib/agentHubVoicePlaybackRuntime";
import { resolveAgentResponseLightRailMode } from "@/lib/agentResponseLightRail";
import {
  loadPersistedChatMessages,
  savePersistedChatMessages,
  stripTransientAgentHubFailureMessages,
} from "@/lib/chatMessagesLocalPersistence";
import {
  postAgUiWebSocketStream,
  prewarmAgUiThread,
  queryUserProfile,
  parseChatRichTextFromSseData,
  type AgUiPayloadImageItem,
} from "@/lib/agentApi";
import {
  clearPersistedAgentConversationId,
  clearPersistedAgUiThreadId,
  getAgUiThreadIdForRequest,
  persistAgentConversationIdFromSse,
  persistAgUiThreadId,
} from "@/lib/agentConversationSession";
import { tryRunPumpAutoEndOffPumpTeardownOnce } from "@/lib/pumpAutoEndSession";
import {
  AGENT_HUB_SYNC_CHAT_EVENT,
  appendAgentHubAnalysisMessage,
} from "@/lib/agentHubChatMessages";
import {
  buildMilkAnalysisReminderFollowupPrompt,
  completeMilkAnalysisReminderFollowup,
  markMilkAnalysisReminderFollowupAttempt,
  MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT,
  peekMilkAnalysisReminderFollowup,
  retryMilkAnalysisReminderFollowupLater,
} from "@/lib/milkAnalysisReminderFollowup";
import {
  AGENT_NOTIFICATION_VOICE_IDLE_EVENT,
  isAgentNotificationVoicePlaying,
} from "@/lib/agentNotificationVoice";
import { apiRequestRaw } from "@/lib/http";
import type {
  AgentAnalysisCard,
  ChatRichTextPayload,
  UserProfileData,
} from "@/lib/agentApiTypes";
import { log, warn } from "@/lib/logger";
import { ChatMarkdown } from "@/components/chat/ChatMarkdown";
import { ChatMarkdownImg } from "@/components/chat/ChatMarkdownImage";
import type { ChatMarkdownVariant } from "@/components/chat/ChatMarkdown";
import { splitChatContentByDataDelimiter } from "@/lib/chatContentSegments";
import { replaceCitationLinksWithIndexes } from "@/lib/chatCitationMarkdown";
import {
  extractChatAnswerChunk,
  mergeStreamingAnswer,
  mergeStreamingAnswerDelta,
} from "@/lib/chatStreaming";
import momcozyAgentAvatar from "@/assets/momcozy-agent.png";
import momcozyAgentSpeakingVideo from "@/assets/momcozy-agent-speaking.mp4";
import momcozyAgentThinkingVideo from "@/assets/momcozy-agent-thinking.mp4";
import {
  DEFAULT_CHAT_TAIL_THRESHOLD_PX,
  isChatScrollNearTail,
  shouldAutoScrollChatTail,
} from "@/lib/chatAutoScroll";
import {
  clampChatHistoryStart,
  latestChatHistoryStart,
  previousChatHistoryStart,
  scrollTopForPreservedAnchor,
} from "@/lib/chatHistoryWindow";
import {
  buildSpeakableTextForVoice,
  CHAT_BUBBLE_VOICE_MAX_CHARS,
  stopChatBubblePlayback,
  type VoiceMediaNarrationResolver,
} from "@/lib/chatBubbleTtsPlayback";
import {
  appendTextRenderItemBeforeAgUiArtifacts,
  richTextPayloadHasAgUiArtifact,
  streamItemHasAgUiArtifact,
} from "@/lib/chatStreamRenderItems";
import {
  workProgressSummary,
  type WorkProgressTone,
} from "@/lib/agUiWorkProgress";
import {
  playFocusPlainTextVoice,
  primeFocusVoicePlayback,
  startFocusRealtimePlainTextVoice,
  stopFocusVoicePlayback,
  type FocusRealtimePlainTextVoiceSession,
} from "@/lib/focusVoiceTtsPlayback";
import { toast } from "sonner";
import {
  fallbackMediaVoiceNarration,
  mediaVoiceLookupKeys,
  type MediaVoiceNarrationItem,
} from "@/lib/mediaVoiceNarration";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { deviceStore } from "@/lib/deviceStore";
import { pumpSessionLifecycle } from "@/lib/pumpSessionLifecycle";
import AgentHubRichTextBlock, {
  type IbclcConsultOpenRequest,
} from "@/pages/agentHub/AgentHubRichTextBlock";
import { IbclcChatPanel } from "@/pages/IbclcChat";
import HospitalBagCart from "@/pages/HospitalBagCart";
import {
  calculateHospitalBagCartTotals,
  cloneHospitalBagCartGroups,
  initialHospitalBagCartGroups,
  normalizeHospitalBagCartGroups,
  removeHospitalBagCartItem,
  type HospitalBagCartGroup,
} from "@/pages/hospitalBagCartModel";
import { resolveCalibrationComfortForPumpStart } from "@/pages/agentHub/resolveCalibrationComfortForPumpStart";
import {
  resolveCalibrationPromptCancelAction,
  resolveCalibrationPromptConfirmAction,
  resolvePumpStartGate,
} from "@/pages/pumpSession/pumpDeviceConnectionPrompt";
import {
  applyAgUiStreamSideEffects,
  mergePendingRichTextPayload,
} from "@/lib/agUiStreamSideEffects";
import {
  clearStoredIbclcReturnViewport,
  readStoredIbclcReturnViewport,
} from "@/lib/ibclcConsult";
import {
  markBirthJourneyPlanGeneratedNotification,
  richTextPayloadHasBirthJourneyPlanCard,
} from "@/lib/birthJourneyPlanNotification";
import {
  markPlanFeedbackNotification,
  milkPlanNotificationFromRichText,
  planNotificationFromAgUiData,
} from "@/lib/planNotification";
import {
  CALIBRATION_HUB_NOTICE_KEY,
  cardBg,
  DEFAULT_CHAT_USER_ID,
  DEVICE_INSTRUCT_QUERY_BY_FLOW,
  HUB_AUTO_VOICE_STREAM_SEGMENT_MAX_CHARS,
  HUB_AUTO_VOICE_STREAM_SEGMENT_MIN_CHARS,
  HUB_BOTTOM_INPUT_GAP,
  HUB_BOTTOM_NAV_HEIGHT,
  HUB_CHAT_HISTORY_PAGE,
} from "@/pages/agentHub/agentHubConstants";

const SCHEDULE_LINK_ACTION_MAP: Record<string, string> = {
  "open-schedule": "",
  "schedule-view-tasks": "view-tasks",
  "schedule-add-avoidance": "add-avoidance",
  "schedule-screenshot": "screenshot-schedule",
  "schedule-day-summary": "day-summary",
};

const LACTATION_LINK_ACTION_MAP: Record<string, string> = {
  "lactation-phase": "view-phase",
  "lactation-goal": "goal-adjust",
  "lactation-trend": "view-trend",
};

const HUB_TOP_ACTION_HEIGHT_PX = 48;
const HUB_MAIN_STREAM_NO_VISIBLE_RESPONSE_TIMEOUT_MS = 25_000;
type PendingHistoryAnchorRestore = { messageId: string; top: number };
const HOSPITAL_BAG_CART_FOLLOWUP_MARKER = "你的待产包已经设计好了哦～";
const PROFILE_ONBOARDING_GREETING =
  "嗨，我是 CozyMate，来自 Momcozy团队。\n\n你希望我怎么称呼你？今年多大啦？";

const DIRECT_PUMP_CART_UPDATE_MODELS: Array<{
  skuId: string;
  model: string;
  tokens: string[];
}> = [
  {
    skuId: "pump-s12-pro-quick",
    model: "S12 Pro Quick",
    tokens: ["s12proquick", "s12pro", "s12"],
  },
  { skuId: "pump-s9-pro", model: "S9 Pro", tokens: ["s9pro", "s9"] },
  { skuId: "pump-m5-smart", model: "M5 Smart", tokens: ["m5smart", "m5"] },
  { skuId: "pump-m6", model: "M6", tokens: ["m6"] },
  { skuId: "pump-v1-pro", model: "V1 Pro", tokens: ["v1pro", "v1"] },
  { skuId: "pump-v2-pro", model: "V2 Pro", tokens: ["v2pro", "v2"] },
  { skuId: "pump-m9", model: "M9", tokens: ["m9"] },
  { skuId: "pump-w1", model: "W1", tokens: ["w1"] },
  { skuId: "pump-air-1", model: "Air 1", tokens: ["air1"] },
];

interface DirectPumpCartUpdateIntent {
  skuId: string;
  model: string;
}

interface DirectHospitalBagCartUpdateResponse {
  status?: string;
  summary?: string;
  cart_update?: {
    groups?: HospitalBagCartGroup[];
    message?: string;
  };
  error?: {
    message?: string;
  };
}

function createNewConversationGreetingContent(
  profile?: UserProfileData | null,
): string {
  const name = String(profile?.display_name ?? "").trim();
  const hasAge =
    typeof profile?.age === "number" && Number.isFinite(profile.age);
  if (name && hasAge) {
    return `嗨 ${name}， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。`;
  }
  return PROFILE_ONBOARDING_GREETING;
}

function createNewConversationGreetingMessage(
  profile?: UserProfileData | null,
): ChatMessage {
  return {
    id: `mai-greeting-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    role: "mai",
    content: createNewConversationGreetingContent(profile),
    timestamp: new Date().toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
    }),
    chatStreamContext: "main",
  };
}

function normalizePumpCartActionText(text: string): string {
  return text
    .toLowerCase()
    .replace(/quicko/g, "quick")
    .replace(/[^a-z0-9\u4e00-\u9fa5]/g, "");
}

function resolveDirectPumpCartUpdateIntent(
  text: string,
): DirectPumpCartUpdateIntent | null {
  const normalized = normalizePumpCartActionText(text);
  const isConfirmedReplacement = /(换成|更换|替换|改成|同步)/.test(normalized);
  const isExplicitCartAdd =
    /购物车/.test(normalized) && /(加入|加到|加进|添加)/.test(normalized);
  if (!isConfirmedReplacement && !isExplicitCartAdd) return null;
  for (const model of DIRECT_PUMP_CART_UPDATE_MODELS) {
    if (model.tokens.some((token) => normalized.includes(token))) {
      return { skuId: model.skuId, model: model.model };
    }
  }
  return null;
}

interface SentChatImagePreview {
  id: string;
  src: string;
  alt: string;
}

function extractSentChatImagePreviews(
  msg: ChatMessage,
): SentChatImagePreview[] {
  const raw = msg.cardData?.sentImages;
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item, index) => {
    if (!item || typeof item !== "object") return [];
    const rec = item as Record<string, unknown>;
    const src = typeof rec.src === "string" ? rec.src.trim() : "";
    if (!src) return [];
    const alt =
      typeof rec.alt === "string" && rec.alt.trim()
        ? rec.alt.trim()
        : `图片 ${index + 1}`;
    const id =
      typeof rec.id === "string" && rec.id.trim()
        ? rec.id.trim()
        : `${msg.id}-sent-image-${index}`;
    return [{ id, src, alt }];
  });
}

function richTextPayloadHasFormLikeAgUiArtifact(
  payload?: ChatRichTextPayload | null,
): boolean {
  if (!payload || !Array.isArray(payload.action)) return false;
  return payload.action.some((action) => {
    if (!action || typeof action !== "object" || Array.isArray(action))
      return false;
    const rec = action as Record<string, unknown>;
    if (rec.kind !== "ag_ui_artifact") return false;
    const artifactType = String(rec.artifact_type ?? "")
      .trim()
      .replace(/-/g, "_");
    return Boolean(
      rec.form ||
      rec.ticket ||
      artifactType === "form" ||
      artifactType === "support_ticket" ||
      artifactType === "support_ticket_draft",
    );
  });
}

function messageHasAgUiArtifact(msg: ChatMessage): boolean {
  return Boolean(
    richTextPayloadHasAgUiArtifact(msg.richText) ||
    msg.streamRenderItems?.some(streamItemHasAgUiArtifact),
  );
}

function agUiArtifactAnchorKey(messageId: string, slot: string): string {
  return `${messageId}__agui_artifact__${slot}`;
}

function latestAgUiArtifactAnchorKey(messages: ChatMessage[]): string | null {
  for (
    let messageIndex = messages.length - 1;
    messageIndex >= 0;
    messageIndex -= 1
  ) {
    const message = messages[messageIndex];
    const streamItems = message.streamRenderItems ?? [];
    for (
      let itemIndex = streamItems.length - 1;
      itemIndex >= 0;
      itemIndex -= 1
    ) {
      if (streamItemHasAgUiArtifact(streamItems[itemIndex])) {
        return agUiArtifactAnchorKey(message.id, `stream-${itemIndex}`);
      }
    }
    if (richTextPayloadHasAgUiArtifact(message.richText)) {
      return agUiArtifactAnchorKey(message.id, "rich");
    }
  }
  return null;
}

function clearQuickRepliesFromMessages(messages: ChatMessage[]): ChatMessage[] {
  return messages.map((message) => {
    if (!message.quickReplies) return message;
    const { quickReplies: _quickReplies, ...rest } = message;
    return rest;
  });
}

function clearQuickRepliesFromMessage(message: ChatMessage): ChatMessage {
  if (!message.quickReplies) return message;
  const { quickReplies: _quickReplies, ...rest } = message;
  return rest;
}

const AG_UI_ARTIFACT_AFTER_TEXT_CLASS = "mt-5";
const AG_UI_ARTIFACT_STACK_OFFSET_CLASS = "mt-3";

function agUiArtifactSpacingClass(
  hasAgUiArtifact: boolean,
  hasPreviousContent: boolean,
  layout: "inner" | "stack" = "inner",
): string | false {
  if (!hasAgUiArtifact || !hasPreviousContent) return false;
  return layout === "stack"
    ? AG_UI_ARTIFACT_STACK_OFFSET_CLASS
    : AG_UI_ARTIFACT_AFTER_TEXT_CLASS;
}

function AgentHubQuickReplies({
  msg,
  disabled,
  onSelect,
}: {
  msg: ChatMessage;
  disabled: boolean;
  onSelect: (text: string) => void;
}) {
  const replies = msg.quickReplies ?? [];
  if (msg.role !== "mai" || replies.length !== 3) return null;
  const hasCitations = (msg.citations ?? []).length > 0;
  return (
    <div
      className={cn(
        "max-w-full",
        hasCitations ? "mt-5" : "mt-4",
        disabled && "opacity-60",
      )}
    >
      <div className="mb-2 flex items-center gap-1.5 px-0.5 text-[11px] font-[600] text-[#9b7a84]">
        <span
          className="h-px w-4 rounded-full bg-[#dbc3cb]"
          aria-hidden="true"
        />
        <span>猜你想说</span>
      </div>
      <div className="flex flex-wrap gap-1.5">
        {replies.map((reply, index) => (
          <button
            key={`${msg.id}-quick-${index}-${reply.text}`}
            type="button"
            disabled={disabled}
            onClick={() => onSelect(reply.text)}
            className={cn(
              "group inline-flex min-h-[34px] max-w-full items-center gap-1.5 rounded-full border border-[#eadde2] bg-white/62 px-3 py-1.5 text-left text-[13px] font-[560] leading-snug text-[#4a3a40] transition-colors",
              disabled
                ? "cursor-not-allowed"
                : "hover:border-[#cf9aac] hover:bg-[#fff8fb] active:bg-[#f8edf2]",
            )}
          >
            <span className="min-w-0">{reply.text}</span>
            <ChevronRight
              className={cn(
                "h-3.5 w-3.5 shrink-0 text-[#b78294] transition-transform",
                !disabled && "group-hover:translate-x-0.5",
              )}
              aria-hidden="true"
            />
          </button>
        ))}
      </div>
    </div>
  );
}

function hostFromCitationUrl(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

function citationLabel(citation: ChatMessageCitation): string {
  const title = citation.title.trim();
  if (title && title !== "参考来源") return title;
  return hostFromCitationUrl(citation.url) || "参考来源";
}

function citationDisplayText(citation: ChatMessageCitation): string {
  const displayText = citation.displayText?.trim();
  if (displayText) return displayText;
  return `${citationDisplayTopic(citation)}：${citationShortUrl(citation.url)}`;
}

function citationDisplayTopic(citation: ChatMessageCitation): string {
  const host = hostFromCitationUrl(citation.url).toLowerCase();
  const title = citation.title.trim().replace(/\s+/g, " ");
  const lowerTitle = title.toLowerCase();
  const titleKey = lowerTitle.replace(/^www\./, "");

  if (
    title &&
    title !== "参考来源" &&
    titleKey !== host &&
    titleKey !== "protocols" &&
    /[\u4e00-\u9fff]/.test(title)
  ) {
    return title.slice(0, 48);
  }
  if (lowerTitle.includes("mastitis")) return "哺乳期乳腺炎资料";
  if (lowerTitle.includes("hand expression")) return "手挤奶指导";
  if (
    lowerTitle.includes("breastfeeding medicine") ||
    lowerTitle.includes("protocol")
  )
    return "ABM 哺乳医学临床指南";
  if (lowerTitle.includes("breastfeeding")) return "母乳喂养专业资料";
  if (lowerTitle.includes("infant and child feeding")) return "婴幼儿喂养指导";
  if (lowerTitle.includes("pregnancy") || lowerTitle.includes("obstetric"))
    return "孕产健康专业资料";
  if (lowerTitle.includes("postpartum")) return "产后健康专业资料";
  if (host.includes("bfmed.org") || host.includes("abm.memberclicks.net"))
    return "ABM 哺乳医学资料";
  if (host.includes("ncbi.nlm.nih.gov")) return "NCBI 医学资料";
  if (host.includes("cdc.gov")) return "CDC 健康指南";
  if (host.includes("who.int")) return "WHO 健康指南";
  if (host.includes("nice.org.uk")) return "NICE 临床指南";
  if (host.includes("acog.org")) return "ACOG 妇产科指南";
  if (host.includes("aap.org")) return "AAP 儿科资料";
  if (host.includes("nhc.gov.cn")) return "国家卫健委资料";
  if (host.includes("unicef.org")) return "UNICEF 母婴健康资料";
  if (
    host.includes("yiigle.com") ||
    host.includes("cmcha.org") ||
    host.includes("jundaodsj.com")
  )
    return "中文医学资料";
  return "专业资料";
}

function citationShortUrl(url: string): string {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.replace(/^www\./, "");
    const segments = parsed.pathname.split("/").filter(Boolean);
    if (segments.length === 0) return host;
    if (segments.length === 1) return `${host}/${segments[0]}`;
    return `${host}/${segments[0]}/...`;
  } catch {
    return url;
  }
}

function AgentHubCitations({ msg }: { msg: ChatMessage }) {
  const citations = msg.citations ?? [];
  if (msg.role !== "mai" || citations.length === 0) return null;
  return (
    <div className="mt-4 max-w-full px-0.5 text-[11px] leading-snug text-[#7b6671]">
      <div className="mb-1.5 flex items-center gap-1.5 text-[10px] font-[600] tracking-[0.01em] text-[#8f7a84]">
        <span
          className="h-px w-4 rounded-full bg-[#dbc3cb]"
          aria-hidden="true"
        />
        <span>专业信息源</span>
      </div>
      <ol className="space-y-1">
        {citations.map((citation) => (
          <li
            key={`${citation.index}-${citation.url}`}
            className="flex max-w-full items-baseline gap-1.5 text-[#8a7480]"
          >
            <span className="shrink-0 text-[#aa929f]">[{citation.index}]</span>
            <a
              href={citation.url}
              target="_blank"
              rel="noopener noreferrer"
              className="min-w-0 break-all text-[#3d7d85] underline decoration-[#b8d7d4] decoration-1 underline-offset-2 transition-colors hover:text-[#2f6870]"
            >
              {citationDisplayText(citation)}
            </a>
          </li>
        ))}
      </ol>
    </div>
  );
}

function markdownForMessage(msg: ChatMessage, markdown: string): string {
  if (msg.role !== "mai") return markdown;
  return replaceCitationLinksWithIndexes(markdown, msg.citations);
}

function AgentHubSentImages({ images }: { images: SentChatImagePreview[] }) {
  if (images.length === 0) return null;
  return (
    <div
      className={cn(
        "grid max-w-full gap-1.5",
        images.length > 1 ? "w-56 grid-cols-2" : "w-44 grid-cols-1",
      )}
    >
      {images.map((image) => (
        <ChatMarkdownImg
          key={image.id}
          resolvedSrc={image.src}
          alt={image.alt}
          className="w-full overflow-hidden rounded-xl bg-primary-foreground/10"
          imgClassName="h-32 w-full max-w-none object-cover sm:h-36"
        />
      ))}
    </div>
  );
}

async function compressChatImageDataUrlForBubble(
  dataUrl: string,
): Promise<string> {
  const source = dataUrl.trim();
  if (!source.startsWith("data:image/")) return source;
  if (source.startsWith("data:image/svg+xml")) return source;

  const img = new Image();
  img.decoding = "async";
  const loaded = new Promise<void>((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = () => reject(new Error("image preview load failed"));
  });
  img.src = source;
  await loaded;

  const maxSide = 360;
  const width = img.naturalWidth || img.width;
  const height = img.naturalHeight || img.height;
  if (!width || !height) return source;
  const scale = Math.min(1, maxSide / Math.max(width, height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(width * scale));
  canvas.height = Math.max(1, Math.round(height * scale));
  const ctx = canvas.getContext("2d");
  if (!ctx) return source;
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.72);
}

/**
 * 对话泡底部扬声器按钮样式：播报中含动态高亮；未播报时随气泡角色配色。
 * @param isPlaying 当前消息是否正在语音播报（手动或自动）
 * @param isUserBubble 是否为用户侧气泡
 * @returns 合并后的 className 字符串
 */
function bubbleSpeakerButtonClassName(
  isPlaying: boolean,
  isUserBubble: boolean,
): string {
  return cn(
    "p-0.5 rounded-full transition-all",
    isPlaying
      ? "text-primary bg-primary/12 ring-2 ring-primary/45 shadow-sm"
      : isUserBubble
        ? "text-primary-foreground/40 hover:text-primary-foreground/70"
        : "text-muted-foreground/50 hover:text-primary",
  );
}

function agentHubVisibleStatusText(msg: ChatMessage): string {
  const status = msg.agentStatusLine?.trim() ?? "";
  if (
    status === "开始处理请求。" ||
    status === "正在处理请求。" ||
    status === "正在处理请求"
  )
    return "";
  if (!status || msg.agentStatusDone) return "";
  return status;
}

function AgentHubThinkingNote({ msg }: { msg: ChatMessage }) {
  if (msg.role !== "mai") return null;
  if (msg.content.trim()) return null;
  const title = msg.agentThinkingTitle?.trim() ?? "";
  if (!title) return null;
  return (
    <div className="w-fit max-w-full px-0.5 text-[12px] font-[650] whitespace-nowrap bg-[linear-gradient(90deg,#98a3af_0%,#98a3af_35%,#2d3745_50%,#98a3af_65%,#98a3af_100%)] bg-[length:240%_100%] bg-clip-text text-transparent animate-[work-title-sweep_1.35s_linear_infinite]">
      {title}
    </div>
  );
}

type AgentHubReportCardData = {
  kind?: string;
  event_id?: string;
  durationStr?: string;
  leftMl?: number;
  rightMl?: number;
  totalMl?: number;
  pct?: number;
  hadLetdown?: boolean;
  analysisCard?: AgentAnalysisCard;
};

function reportKindLabel(kind?: string): string {
  if (kind === "pump-session-summary") return "吸奶小结";
  if (kind === "daily_summary") return "每日奶量总结";
  if (kind === "mom_baby") return "每日泌乳建议";
  if (kind === "milk_analysis") return "奶量分析";
  return "M.ai 报告";
}

function analysisStatusLabel(card?: AgentAnalysisCard): string {
  const explicit = card?.status_label?.trim();
  if (explicit) return explicit;
  return "";
}

function analysisStatusTone(card?: AgentAnalysisCard): string {
  const explicit = card?.status_tone?.trim();
  if (explicit) return explicit;
  if (card?.status === "normal") return "normal";
  if (card?.status === "attention") return "attention";
  return "default";
}

function analysisToneClass(tone?: string): string {
  const normalized = tone?.trim().toLowerCase();
  if (normalized && /^[a-z0-9_-]+$/.test(normalized)) return normalized;
  return "default";
}

function AgentHubReportCard({
  msg,
  onLinkPress,
}: {
  msg: ChatMessage;
  onLinkPress: (link: ChatMessageLink) => void;
}) {
  const data = (msg.cardData ?? {}) as AgentHubReportCardData;
  const analysisCard = data.analysisCard;
  const analysisSections = Array.isArray(analysisCard?.sections)
    ? analysisCard.sections.filter(
        (section) =>
          section &&
          (section.title?.trim() ||
            section.body?.trim() ||
            section.items?.length ||
            section.metrics?.length),
      )
    : [];
  const hasAnalysisCard = Boolean(
    analysisCard && (analysisCard.title?.trim() || analysisSections.length),
  );
  const hasContent = msg.content.trim().length > 0;
  const hasLinks = Boolean(msg.links?.length);
  const statusLabel = analysisStatusLabel(analysisCard);
  const statusTone = analysisStatusTone(analysisCard);
  const analysisFollowup = analysisCard?.followup?.trim() || "";
  const isPumpSessionSummaryReport =
    data.kind === "pump-session-summary" ||
    analysisCard?.kind === "pump_session_summary";
  const isNotificationMessage = msg.messageTone === "notification";
  const reportMarkdownClassName = cn(
    "text-[13px] leading-relaxed",
    isNotificationMessage ? "text-[#b64b4b]" : "text-[#35212c]",
  );

  return (
    <article
      className={cn(
        "agent-card",
        hasAnalysisCard
          ? "agent-card-analysis_report"
          : "agent-card-hospital_bag_card",
        isNotificationMessage && "agent-card-notification",
      )}
    >
      {hasAnalysisCard ? (
        <>
          <header className="analysis-card-header">
            <div>
              <h2>
                {analysisCard?.title?.trim() || reportKindLabel(data.kind)}
              </h2>
            </div>
            {statusLabel ? (
              <span
                className={cn(
                  "analysis-status-pill",
                  `is-${analysisToneClass(statusTone)}`,
                )}
              >
                {statusLabel}
              </span>
            ) : null}
          </header>

          {analysisSections.length > 0 ? (
            <section className="analysis-section-list">
              {analysisSections.map((section, index) => {
                const items = Array.isArray(section.items)
                  ? section.items.map((item) => item.trim()).filter(Boolean)
                  : [];
                const metrics = Array.isArray(section.metrics)
                  ? section.metrics.filter((metric, metricIndex) => {
                      if (
                        !metric ||
                        !(metric.label?.trim() || metric.value?.trim())
                      )
                        return false;
                      if (!isPumpSessionSummaryReport) return true;
                      return !(
                        (index === 0 && metricIndex === 0) ||
                        (index === 1 && metricIndex === 2)
                      );
                    })
                  : [];
                return (
                  <div
                    key={section.id?.trim() || `${section.title}-${index}`}
                    className={cn(
                      "analysis-section",
                      `analysis-section-${analysisToneClass(section.tone)}`,
                    )}
                  >
                    {section.title?.trim() ? (
                      <h3>{section.title.trim()}</h3>
                    ) : null}
                    {metrics.length > 0 ? (
                      <div className="analysis-metric-grid">
                        {metrics.map((metric, metricIndex) => (
                          <span key={`${metric.label}-${metricIndex}`}>
                            <small>{metric.label.trim()}</small>
                            <strong>{metric.value.trim() || "—"}</strong>
                            {metric.detail?.trim() ? (
                              <em>{metric.detail.trim()}</em>
                            ) : null}
                          </span>
                        ))}
                      </div>
                    ) : null}
                    {items.map((item, itemIndex) => (
                      <p key={`${item}-${itemIndex}`}>{item}</p>
                    ))}
                    {section.body?.trim() ? <p>{section.body.trim()}</p> : null}
                  </div>
                );
              })}
            </section>
          ) : hasContent ? (
            <section className="analysis-section-list">
              <div className="analysis-section analysis-section-default">
                <ChatMarkdown
                  markdown={markdownForMessage(msg, msg.content)}
                  variant="assistant"
                  className={reportMarkdownClassName}
                />
              </div>
            </section>
          ) : null}

          {analysisFollowup ? (
            <section className="analysis-followup">
              <ChatMarkdown
                markdown={analysisFollowup}
                variant="assistant"
                className="text-[13px] leading-relaxed text-[#3c2631]"
              />
            </section>
          ) : null}
        </>
      ) : (
        <>
          <header className="agent-card-header">
            <div className="agent-card-header-text">
              <h2>{reportKindLabel(data.kind)}</h2>
              <p>{msg.timestamp}</p>
            </div>
          </header>

          {hasContent ? (
            <section className="agent-card-section">
              <ChatMarkdown
                markdown={markdownForMessage(msg, msg.content)}
                variant="assistant"
                className={reportMarkdownClassName}
              />
            </section>
          ) : null}
        </>
      )}

      {hasLinks ? (
        <section
          className={
            hasAnalysisCard ? "analysis-action-section" : "agent-card-section"
          }
        >
          <h3>Actions</h3>
          <div className="flex flex-wrap gap-2">
            {msg.links?.map((link, i) => (
              <button
                key={i}
                type="button"
                onClick={() => onLinkPress(link)}
                className="rounded-full border border-[#e7c9d1] bg-[#fff7f8] px-3 py-1 text-[11px] font-semibold text-[#7a4259] transition-colors hover:bg-[#ffeef2]"
              >
                {link.label}
              </button>
            ))}
          </div>
        </section>
      ) : null}
    </article>
  );
}

function workProgressDotClass(tone: WorkProgressTone): string {
  if (tone === "done") return "bg-[#6aa889]";
  if (tone === "error") return "bg-[#c75b56]";
  if (tone === "waiting") return "bg-[#d59aa8]";
  return "bg-[#c98599]";
}

function workProgressTitleClass(tone: WorkProgressTone): string {
  const shimmer = "bg-[length:240%_100%] bg-clip-text text-transparent animate-[work-title-sweep_1.35s_linear_infinite]";
  if (tone === "done") {
    return cn(
      shimmer,
      "bg-[linear-gradient(90deg,#6aa889_0%,#6aa889_34%,#2f6f58_50%,#6aa889_66%,#6aa889_100%)]",
    );
  }
  if (tone === "error") {
    return cn(
      shimmer,
      "bg-[linear-gradient(90deg,#c75b56_0%,#c75b56_34%,#8f2f2b_50%,#c75b56_66%,#c75b56_100%)]",
    );
  }
  if (tone === "waiting") {
    return cn(
      shimmer,
      "bg-[linear-gradient(90deg,#d59aa8_0%,#d59aa8_34%,#9a5f70_50%,#d59aa8_66%,#d59aa8_100%)]",
    );
  }
  return cn(
    shimmer,
    "bg-[linear-gradient(90deg,#9a7a86_0%,#9a7a86_34%,#5d3f4d_50%,#9a7a86_66%,#9a7a86_100%)]",
  );
}

function isRunStartedWorkRow(row: AgUiToolCallRow): boolean {
  return row.id === "run:started-work" || row.name === "run_started";
}

function hasConcreteWorkRows(rows: AgUiToolCallRow[]): boolean {
  return rows.some(
    (row) => row.kind !== "narration" && !isRunStartedWorkRow(row),
  );
}

function AgentHubProgressNote({ msg }: { msg: ChatMessage }) {
  if (msg.role !== "mai") return null;

  const finalTextStarted = Boolean(msg.content.trim());
  const tools = msg.agentToolCalls ?? [];
  const workSummary =
    tools.length > 0
      ? workProgressSummary(
          tools,
          typeof msg.agentWorkFinishedAtMs === "number",
        )
      : null;
  const canShowWork =
    workSummary &&
    !(
      finalTextStarted &&
      (workSummary.tone === "running" || workSummary.tone === "done")
    );
  const statusTitle = !finalTextStarted ? agentHubVisibleStatusText(msg) : "";

  const progress =
    statusTitle
      ? { title: statusTitle, tone: "running" as WorkProgressTone }
      : canShowWork && hasConcreteWorkRows(tools)
        ? workSummary
        : canShowWork
          ? workSummary
          : null;

  if (!progress) return null;

  return (
    <div className="w-full max-w-full text-[12px]">
      <div className="flex w-full min-w-0 max-w-full items-start gap-2 overflow-hidden px-0.5 py-1">
        <span
          className="relative mt-[5px] flex h-2 w-2 shrink-0"
          aria-hidden="true"
        >
          {progress.tone === "running" ? (
            <span className="absolute inline-flex h-full w-full rounded-full bg-[#c98599] opacity-40 animate-ping" />
          ) : null}
          <span
            className={cn(
              "relative inline-flex h-2 w-2 rounded-full",
              workProgressDotClass(progress.tone),
            )}
          />
        </span>
        <span
          title={progress.title}
          className={cn(
            "block min-w-0 max-w-full flex-1 overflow-x-auto overscroll-x-contain whitespace-nowrap pr-2 text-[12px] font-[650] leading-[1.45] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
            workProgressTitleClass(progress.tone),
          )}
        >
          {progress.title}
        </span>
      </div>
    </div>
  );
}

function AgentHubAgUiDecor({ msg }: { msg: ChatMessage }) {
  if (msg.role !== "mai") return null;
  return (
    <>
      <AgentHubProgressNote msg={msg} />
      <AgentHubThinkingNote msg={msg} />
    </>
  );
}

function mergeHubMessagesPreserveOrder(
  base: ChatMessage[],
  incoming: ChatMessage[],
): ChatMessage[] {
  if (base.length === 0) return incoming;
  if (incoming.length === 0) return base;
  const merged = [...base];
  const idSet = new Set(base.map((m) => m.id));
  for (const msg of incoming) {
    if (idSet.has(msg.id)) continue;
    merged.push(msg);
    idSet.add(msg.id);
  }
  return merged;
}

let agentHubMessageIdCounter = 0;

function createAgentHubMessageId(prefix: string): string {
  agentHubMessageIdCounter += 1;
  return `${prefix}${Date.now()}-${agentHubMessageIdCounter}`;
}

function splitStaticAssistantReplyForStreaming(text: string): string[] {
  const normalized = String(text ?? "").trim();
  if (!normalized) return [];
  const chunks = normalized.match(/[^，。！？；,!?;]+[，。！？；,!?;]?/g) ?? [
    normalized,
  ];
  return chunks.map((chunk) => chunk.trim()).filter(Boolean);
}

const AgentHub: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  /** 首次进入 Hub：应用冷启动时开启新会话；同一 SPA 内返回时沿用内存对话。 */
  const initialHubMessagesRef = useRef<ChatMessage[] | null>(null);
  const shouldHydrateInitialGreetingRef = useRef(false);
  const latestUserProfileRef = useRef<UserProfileData | null>(null);
  const pendingGreetingVoiceIdRef = useRef<string | null>(null);
  if (initialHubMessagesRef.current === null) {
    const inMemory = stripTransientAgentHubFailureMessages(
      chatStore.get().messages,
    );
    const isColdStart = inMemory.length === 0;
    if (isColdStart) {
      clearPersistedAgentConversationId();
      clearPersistedAgUiThreadId();
      shouldHydrateInitialGreetingRef.current = true;
    }
    const merged = isColdStart ? [] : inMemory;
    chatStore.setMessages(merged);
    savePersistedChatMessages(merged);
    initialHubMessagesRef.current = merged;
  }
  const hubInitialMessages = initialHubMessagesRef.current;
  const messages = useSyncExternalStore(
    chatStore.subscribe,
    () => chatStore.get().messages,
    () => hubInitialMessages,
  );
  const [latestUserProfile, setLatestUserProfile] = useState<UserProfileData | null>(null);
  const setMessages = useCallback(
    (action: React.SetStateAction<ChatMessage[]>) => {
      chatStore.updateMessages(action);
    },
    [],
  );
  const lastAgUiArtifactAnchorKeyRef = useRef<string | null>(
    latestAgUiArtifactAnchorKey(hubInitialMessages),
  );

  const applyGreetingFromProfile = useCallback(
    (
      profile: UserProfileData | null,
      opts?: { onlyIfNoConversationStarted?: boolean },
    ) => {
      const greeting = createNewConversationGreetingMessage(profile);
      const currentMessages = chatStore.get().messages;
      if (opts?.onlyIfNoConversationStarted) {
        if (currentMessages.some((message) => message.role === "user")) return;
        const hasNonGreetingAssistant = currentMessages.some(
          (message) =>
            message.role === "mai" &&
            !String(message.id).startsWith("mai-greeting-"),
        );
        if (hasNonGreetingAssistant) return;
      }
      pendingGreetingVoiceIdRef.current = greeting.id;
      chatStore.setMessages([greeting]);
      savePersistedChatMessages([greeting]);
      setMessages([greeting]);
    },
    [setMessages],
  );

  const hydrateGreetingFromProfile = useCallback(
    async (opts?: {
      onlyIfNoConversationStarted?: boolean;
      signal?: AbortSignal;
    }) => {
      try {
        const profile = await queryUserProfile(
          { user_id: DEFAULT_CHAT_USER_ID },
          { signal: opts?.signal },
        );
        latestUserProfileRef.current = profile;
        setLatestUserProfile(profile);
        applyGreetingFromProfile(profile, opts);
      } catch (e: unknown) {
        if ((e as { name?: string })?.name === "AbortError") return;
        warn(
          "[AgentHub] 读取用户基础资料失败，使用默认新会话欢迎语",
          e instanceof Error ? e.message : String(e),
        );
        applyGreetingFromProfile(latestUserProfileRef.current, opts);
      }
    },
    [applyGreetingFromProfile],
  );

  useEffect(() => {
    if (!shouldHydrateInitialGreetingRef.current) return;
    shouldHydrateInitialGreetingRef.current = false;
    const controller = new AbortController();
    void hydrateGreetingFromProfile({
      onlyIfNoConversationStarted: true,
      signal: controller.signal,
    });
    return () => controller.abort();
  }, [hydrateGreetingFromProfile]);

  useEffect(() => {
    const controller = new AbortController();
    void queryUserProfile(
      { user_id: DEFAULT_CHAT_USER_ID },
      { signal: controller.signal },
    )
      .then((profile) => {
        latestUserProfileRef.current = profile;
        setLatestUserProfile(profile);
      })
      .catch((e: unknown) => {
        if ((e as { name?: string })?.name === "AbortError") return;
        warn(
          "[AgentHub] 读取用户基础资料失败，跳过表单预填兜底",
          e instanceof Error ? e.message : String(e),
        );
      });
    return () => controller.abort();
  }, []);
  const pendingAgUiArtifactPositionRef = useRef(false);
  const pendingAgUiArtifactFormLikeRef = useRef(false);
  const [input, setInput] = useState("");
  const inputRef = useRef(input);
  const consumedAgentPrefillKeyRef = useRef<string | null>(null);
  useEffect(() => {
    inputRef.current = input;
  }, [input]);
  useEffect(() => {
    const state = location.state as { agentPrefill?: unknown } | null;
    const agentPrefill =
      typeof state?.agentPrefill === "string" ? state.agentPrefill.trim() : "";
    if (!agentPrefill) return;
    const prefillKey = `${location.key}:${agentPrefill}`;
    if (consumedAgentPrefillKeyRef.current === prefillKey) return;
    consumedAgentPrefillKeyRef.current = prefillKey;
    setInput(agentPrefill);
    navigate(`${location.pathname}${location.search}${location.hash}`, {
      replace: true,
      state: null,
    });
  }, [
    location.hash,
    location.key,
    location.pathname,
    location.search,
    location.state,
    navigate,
  ]);
  /** 底部发送已触发 SSE：显示发送键加载直至回复结束或再次点击打断 */
  const [hubBottomSendBusy, setHubBottomSendBusy] = useState(false);
  /** 最近一次来自底部输入 handleSend 的 SSE 未完成；仅此时 onDone/onError 应清除 hubBottomSendBusy */
  const awaitingHubBottomReplyRef = useRef(false);
  const hubBottomSendActionLockRef = useRef(false);
  const lastHubBottomNewTurnAtRef = useRef(0);
  const { speechListening, speechPhase, startSpeech, stopSpeech } =
    useAgentHubSpeechInput(setInput, {
      userId: DEFAULT_CHAT_USER_ID,
    });
  const [autoVoice, setAutoVoice] = useState(true);
  /** 与打字机收尾回调解耦：收尾时读取最新「自动播报」开关，避免闭包陈旧 */
  const autoVoiceRef = useRef(autoVoice);
  useEffect(() => {
    autoVoiceRef.current = autoVoice;
  }, [autoVoice]);
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);
  const initialHistoryStart = Math.max(
    0,
    hubInitialMessages.length - HUB_CHAT_HISTORY_PAGE,
  );
  const [visibleStartIndex, setVisibleStartIndex] =
    useState(initialHistoryStart);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [showPhotoMenu, setShowPhotoMenu] = useState(false);
  type HubPumpGateDialog = "calibration" | "device";
  const [hubPumpGateDialog, setHubPumpGateDialog] =
    useState<HubPumpGateDialog | null>(null);
  const [hubStartPumpBusy, setHubStartPumpBusy] = useState(false);
  /** 全局会话状态：lifecycle 由 deviceStore 驱动，running/paused 时显示「吸奶中」 */
  const pumpSessionState = useSyncExternalStore(
    pumpSessionLifecycle.subscribe,
    pumpSessionLifecycle.getSessionState,
    pumpSessionLifecycle.getSessionState,
  );
  const pumpSessionActive =
    pumpSessionState === "running" || pumpSessionState === "paused";
  /** Hub 底部操作区真实渲染高度（按键 + 输入框），用于对话视口动态下边界 */
  const [bottomActionHeightPx, setBottomActionHeightPx] = useState(170);
  const [scheduleFlowActive, setScheduleFlowActive] = useState(() =>
    hubInitialMessages.some(
      (m) => m.cardType === "schedule-flow" && !m.cardData?.completed,
    ),
  );
  const [lactationFlowActive, setLactationFlowActive] = useState(() =>
    hubInitialMessages.some(
      (m) => m.cardType === "lactation-flow" && !m.cardData?.completed,
    ),
  );
  const [maternityFlowActive, setMaternityFlowActive] = useState(() =>
    hubInitialMessages.some(
      (m) => m.cardType === "maternity-flow" && !m.cardData?.completed,
    ),
  );
  const [activeIbclcConsult, setActiveIbclcConsult] = useState<{
    conversationId: string;
    consultId: string;
    clientUserId: string;
  } | null>(null);
  const [activeHospitalBagCart, setActiveHospitalBagCart] = useState(false);
  const [hospitalBagCartGroups, setHospitalBagCartGroups] = useState<
    HospitalBagCartGroup[]
  >(() => cloneHospitalBagCartGroups(initialHospitalBagCartGroups));
  useEffect(() => {
    setHospitalBagCartGroups((groups) =>
      normalizeHospitalBagCartGroups(groups),
    );
  }, []);
  const [workFlowActive, setWorkFlowActive] = useState(() =>
    hubInitialMessages.some(
      (m) => m.cardType === "work-flow" && !m.cardData?.completed,
    ),
  );
  const scheduleFlowRef = useRef<InlineScheduleFlowHandle>(null);
  const lactationFlowRef = useRef<InlineLactationFlowHandle>(null);
  const maternityFlowRef = useRef<InlineMaternityFlowHandle>(null);
  const workFlowRef = useRef<InlineWorkFlowHandle>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const visibleStartIndexRef = useRef(initialHistoryStart);
  const pendingHistoryScrollRestoreRef =
    useRef<PendingHistoryAnchorRestore | null>(null);
  const pendingLatestChatWindowSyncRef = useRef(false);
  const userPinnedToTailRef = useRef(true);
  /** 底部输入发送并入队回复消息后，下一次列表更新时强制滚到最后一条（即使用户之前在回看历史） */
  const scrollTailAfterHubSendRef = useRef(false);
  const lastMessageMetaRef = useRef<{ len: number; lastId: string | null }>({
    len: hubInitialMessages.length,
    lastId: hubInitialMessages.at(-1)?.id ?? null,
  });
  const showLatestChatHistoryWindow = useCallback((messageCount: number) => {
    const nextStart = latestChatHistoryStart(
      messageCount,
      HUB_CHAT_HISTORY_PAGE,
    );
    pendingLatestChatWindowSyncRef.current = false;
    visibleStartIndexRef.current = nextStart;
    setVisibleStartIndex(nextStart);
  }, []);
  const prepareLatestChatWindowForNewTurn = useCallback(() => {
    pendingLatestChatWindowSyncRef.current = true;
    userPinnedToTailRef.current = true;
    scrollTailAfterHubSendRef.current = true;
    setShowScrollToBottom(false);
  }, []);
  /** 通知进首页等场景：外部已写入 chatStore/持久化，需与首次挂载同样合并进本地 messages。 */
  useLayoutEffect(() => {
    const onExternalSync = () => {
      const inMemory = stripTransientAgentHubFailureMessages(
        chatStore.get().messages,
      );
      const loaded = loadPersistedChatMessages();
      const merged = mergeHubMessagesPreserveOrder(loaded, inMemory);
      chatStore.setMessages(merged);
      void savePersistedChatMessages(merged);
      userPinnedToTailRef.current = true;
      scrollTailAfterHubSendRef.current = true;
      showLatestChatHistoryWindow(merged.length);
      setMessages(merged);
    };
    window.addEventListener(AGENT_HUB_SYNC_CHAT_EVENT, onExternalSync);
    return () =>
      window.removeEventListener(AGENT_HUB_SYNC_CHAT_EVENT, onExternalSync);
  }, [showLatestChatHistoryWindow]);

  /** 非吸乳页自动结束后：进入智能体主页时若尚未执行「小结+BLE」，与通知点击路径共用 claim，只跑一次。 */
  useEffect(() => {
    if (location.pathname !== "/") return;
    void tryRunPumpAutoEndOffPumpTeardownOnce();
  }, [location.pathname]);

  const lastStreamingScrollAtRef = useRef(0);
  /** Hub 对话 ag-ui WebSocket 取消句柄 */
  const mainChatCancelRef = useRef<(() => void) | null>(null);
  const milkAnalysisFollowupInFlightRef = useRef<string | null>(null);
  /** 新会话隐藏预热请求：新建会话/离开页面时取消，避免旧 thread 后台请求继续占资源 */
  const agUiPrewarmAbortRef = useRef<AbortController | null>(null);
  /** 当前正在流式回复的 Mai 消息 id（用于区分“正在思考”与历史“已思考”展示） */
  const mainStreamingReplyIdRef = useRef<string | null>(null);
  const mainStreamMergedAnswerRef = useRef("");
  const mainStreamMergedThinkingRef = useRef("");
  /** 待延迟渲染的 artifact rich_text。 */
  const mainPendingRichTextRef = useRef<ChatRichTextPayload | null>(null);
  /** rich_text 快照，用于 onDone 自动播报。 */
  const mainRichTextForVoiceRef = useRef<ChatRichTextPayload | null>(null);
  const mainNoVisibleResponseTimerRef = useRef<number | null>(null);
  const mainStreamFollowTailRef = useRef(false);
  const staticAssistantReplyTimersRef = useRef<number[]>([]);
  const mainMediaVoiceByUrlRef = useRef<Map<string, string>>(new Map());
  const suppressFollowTailReleaseUntilRef = useRef(0);
  /** 对话泡语音：AbortController 与当前播放目标 id，避免快速切换气泡时误清状态 */
  const bubblePlayAbortRef = useRef<AbortController | null>(null);
  const bubblePlayingTargetIdRef = useRef<string | null>(null);
  const autoVoiceRunIdRef = useRef(0);
  const autoVoiceRealtimeSessionRef = useRef<{
    runId: number;
    replyId: string;
    session: FocusRealtimePlainTextVoiceSession;
    abortController: AbortController;
    appendedChars: number;
    receivedAudioBytes: number;
    lastMergedAnswer: string;
    lastRichText: ChatRichTextPayload | null;
  } | null>(null);
  const mainChatRuntimeSnapshot = useSyncExternalStore(
    agentHubMainChatRuntime.subscribe,
    agentHubMainChatRuntime.getSnapshot,
    agentHubMainChatRuntime.getSnapshot,
  );
  const voicePlaybackSnapshot = useSyncExternalStore(
    agentHubVoicePlaybackRuntime.subscribe,
    agentHubVoicePlaybackRuntime.getSnapshot,
    agentHubVoicePlaybackRuntime.getSnapshot,
  );
  const isMainChatRunning =
    mainChatRuntimeSnapshot.running || Boolean(mainChatCancelRef.current);

  useEffect(() => {
    if (!mainChatRuntimeSnapshot.running) return;
    mainStreamFollowTailRef.current = true;
    userPinnedToTailRef.current = true;
    setShowScrollToBottom(false);
  }, [mainChatRuntimeSnapshot.replyId, mainChatRuntimeSnapshot.running]);

  const rememberMediaVoiceItems = useCallback(
    (items: MediaVoiceNarrationItem[]) => {
      const map = mainMediaVoiceByUrlRef.current;
      items.forEach((item) => {
        if (item.voicePolicy !== "announce" && item.voicePolicy !== "read_text")
          return;
        const url = item.mediaId?.trim();
        const spoken = (item.spokenLabel || item.spokenDetail || "").trim();
        if (!url || !spoken) return;
        mediaVoiceLookupKeys(url).forEach((key) => map.set(key, spoken));
      });
    },
    [],
  );

  const resolveMediaVoiceNarration = useCallback<VoiceMediaNarrationResolver>(
    ({ url }) => {
      for (const key of mediaVoiceLookupKeys(url)) {
        const spoken = mainMediaVoiceByUrlRef.current.get(key);
        if (spoken) return spoken;
      }
      return fallbackMediaVoiceNarration(url);
    },
    [],
  );

  useEffect(() => {
    return () => {
      agUiPrewarmAbortRef.current?.abort();
      agUiPrewarmAbortRef.current = null;
    };
  }, []);

  const bottomActionRef = useRef<HTMLDivElement>(null);
  const hubStartPumpShortcutLockRef = useRef(false);
  /** 上传图片本地预览 blob URL 索引：便于删除气泡时 revoke；离开路由不要整表 revoke（同文档内 blob 仍有效） */
  const uploadedImagePreviewUrlsRef = useRef<Map<string, string>>(new Map());

  const scrollToChatTail = useCallback((behavior: ScrollBehavior = "auto") => {
    const container = scrollRef.current;
    if (!container) return;
    suppressFollowTailReleaseUntilRef.current =
      Date.now() + (behavior === "smooth" ? 900 : 120);
    container.scrollTo({ top: container.scrollHeight, behavior });
    userPinnedToTailRef.current = true;
    setShowScrollToBottom(false);
  }, []);

  const scrollAgUiArtifactTopToViewportMiddle = useCallback(
    (anchorKey: string, behavior: ScrollBehavior = "auto") => {
      const container = scrollRef.current;
      if (!container) return false;
      const anchors = Array.from(
        container.querySelectorAll<HTMLElement>("[data-ag-ui-artifact-anchor]"),
      );
      const anchor = anchors.find(
        (node) => node.dataset.agUiArtifactAnchor === anchorKey,
      );
      if (!anchor) return false;

      const containerRect = container.getBoundingClientRect();
      const anchorRect = anchor.getBoundingClientRect();
      const anchorTop =
        container.scrollTop + (anchorRect.top - containerRect.top);
      const maxTop = Math.max(
        0,
        container.scrollHeight - container.clientHeight,
      );
      const targetTop = Math.min(
        Math.max(0, anchorTop - container.clientHeight / 2),
        maxTop,
      );

      suppressFollowTailReleaseUntilRef.current =
        Date.now() + (behavior === "smooth" ? 900 : 120);
      mainStreamFollowTailRef.current = false;
      userPinnedToTailRef.current = false;
      container.scrollTo({ top: targetTop, behavior });
      setShowScrollToBottom(
        !isChatScrollNearTail(container, DEFAULT_CHAT_TAIL_THRESHOLD_PX),
      );
      return true;
    },
    [],
  );

  const findChatMessageElement = useCallback(
    (messageId: string): HTMLElement | null => {
      const container = scrollRef.current;
      if (!container) return null;
      return (
        Array.from(
          container.querySelectorAll<HTMLElement>("[data-chat-message-id]"),
        ).find((node) => node.dataset.chatMessageId === messageId) ?? null
      );
    },
    [],
  );

  const captureChatHistoryAnchor =
    useCallback((): PendingHistoryAnchorRestore | null => {
      const container = scrollRef.current;
      if (!container) return null;
      const containerRect = container.getBoundingClientRect();
      const nodes = Array.from(
        container.querySelectorAll<HTMLElement>("[data-chat-message-id]"),
      );
      const anchor =
        nodes.find(
          (node) => node.getBoundingClientRect().bottom > containerRect.top + 1,
        ) ??
        nodes[0] ??
        null;
      const messageId = anchor?.dataset.chatMessageId;
      if (!anchor || !messageId) return null;
      return { messageId, top: anchor.getBoundingClientRect().top };
    }, []);

  const restoreChatHistoryAnchor = useCallback(
    (restore: PendingHistoryAnchorRestore): boolean => {
      const container = scrollRef.current;
      const anchor = findChatMessageElement(restore.messageId);
      if (!container || !anchor) return false;
      const nextTop = anchor.getBoundingClientRect().top;
      const nextScrollTop = scrollTopForPreservedAnchor(
        container.scrollTop,
        restore.top,
        nextTop,
      );
      if (Math.abs(container.scrollTop - nextScrollTop) > 0.5) {
        container.scrollTop = nextScrollTop;
      }
      return true;
    },
    [findChatMessageElement],
  );

  /**
   * 停止当前对话气泡语音播放并清理播放状态。
   * @param opts.clearPlayingId 是否重置 UI 播放高亮；默认 true
   * @returns Promise<void> 停止播放与状态清理完成
   */
  const stopCurrentBubblePlayback = useCallback(
    async (opts?: { clearPlayingId?: boolean }): Promise<void> => {
      autoVoiceRunIdRef.current += 1;
      agentHubVoicePlaybackRuntime.cancelAutoVoice();
      autoVoiceRealtimeSessionRef.current?.abortController.abort();
      autoVoiceRealtimeSessionRef.current?.session.cancel();
      autoVoiceRealtimeSessionRef.current = null;
      bubblePlayAbortRef.current?.abort();
      await stopChatBubblePlayback();
      await stopFocusVoicePlayback();
      bubblePlayingTargetIdRef.current = null;
      bubblePlayAbortRef.current = null;
      if (opts?.clearPlayingId ?? true) {
        setPlayingId(null);
      }
    },
    [],
  );

  const clearMainNoVisibleResponseTimer = useCallback(() => {
    if (mainNoVisibleResponseTimerRef.current == null) return;
    window.clearTimeout(mainNoVisibleResponseTimerRef.current);
    mainNoVisibleResponseTimerRef.current = null;
  }, []);

  const clearStaticAssistantReplyTimers = useCallback(() => {
    staticAssistantReplyTimersRef.current.forEach((timer) =>
      window.clearTimeout(timer),
    );
    staticAssistantReplyTimersRef.current = [];
  }, []);

  useEffect(() => {
    return () => clearStaticAssistantReplyTimers();
  }, [clearStaticAssistantReplyTimers]);

  const primeAutoVoicePlayback = useCallback(
    (opts?: { disableOnFailure?: boolean }) => {
      if (!autoVoiceRef.current) return;
      void primeFocusVoicePlayback().catch((e: unknown) => {
        const err = e as { message?: string };
        toast.error(err.message || "语音模式启动失败");
        if (opts?.disableOnFailure) {
          autoVoiceRef.current = false;
          setAutoVoice(false);
        }
      });
    },
    [],
  );

  const handleToggleAutoVoice = useCallback(() => {
    const next = !autoVoiceRef.current;
    autoVoiceRef.current = next;
    setAutoVoice(next);
    if (next) {
      primeAutoVoicePlayback({ disableOnFailure: true });
      return;
    }
    void stopCurrentBubblePlayback();
  }, [primeAutoVoicePlayback, stopCurrentBubblePlayback]);

  const handleCreateNewConversation = useCallback(() => {
    clearMainNoVisibleResponseTimer();
    agentHubMainChatRuntime.cancel();
    mainChatCancelRef.current?.();
    mainChatCancelRef.current = null;
    mainStreamingReplyIdRef.current = null;
    mainStreamFollowTailRef.current = false;
    mainStreamMergedAnswerRef.current = "";
    mainStreamMergedThinkingRef.current = "";
    mainPendingRichTextRef.current = null;
    mainRichTextForVoiceRef.current = null;
    mainMediaVoiceByUrlRef.current.clear();
    pendingAgUiArtifactFormLikeRef.current = false;
    awaitingHubBottomReplyRef.current = false;
    pendingHistoryScrollRestoreRef.current = null;
    userPinnedToTailRef.current = true;
    scrollTailAfterHubSendRef.current = false;
    lastMessageMetaRef.current = { len: 0, lastId: null };

    void stopSpeech({ discardSttResult: true });
    void stopCurrentBubblePlayback();
    uploadedImagePreviewUrlsRef.current.forEach((url) => {
      try {
        URL.revokeObjectURL(url);
      } catch {
        /* ignore invalid blob urls */
      }
    });
    uploadedImagePreviewUrlsRef.current.clear();

    clearPersistedAgentConversationId();
    clearPersistedAgUiThreadId();
    const nextThreadId = getAgUiThreadIdForRequest();
    agUiPrewarmAbortRef.current?.abort();
    const prewarmAbort = new AbortController();
    agUiPrewarmAbortRef.current = prewarmAbort;
    const prewarmLocale =
      (typeof navigator !== "undefined" && navigator.language) || "zh-CN";
    const prewarmTimezone =
      (typeof Intl !== "undefined" &&
        Intl.DateTimeFormat().resolvedOptions().timeZone) ||
      "America/Los_Angeles";
    void prewarmAgUiThread(nextThreadId, {
      locale: prewarmLocale,
      signal: prewarmAbort.signal,
      forwardedProps: {
        user_id: DEFAULT_CHAT_USER_ID,
        locale: prewarmLocale,
        timezone: prewarmTimezone,
        message_sent_at: new Date().toISOString(),
        user_profile: {
          user_id: DEFAULT_CHAT_USER_ID,
          language: prewarmLocale,
        },
      },
    })
      .catch((e: unknown) => {
        const err = e as { name?: string; message?: string };
        if (prewarmAbort.signal.aborted || err.name === "AbortError") return;
        warn("[AgentHub] 新会话预热失败，已忽略", err.message || String(e));
      })
      .finally(() => {
        if (agUiPrewarmAbortRef.current === prewarmAbort) {
          agUiPrewarmAbortRef.current = null;
        }
      });
    const greeting = createNewConversationGreetingMessage(
      latestUserProfileRef.current,
    );
    chatStore.setMessages([greeting]);
    savePersistedChatMessages([greeting]);
    setMessages([greeting]);
    void hydrateGreetingFromProfile({ onlyIfNoConversationStarted: true });
    setInput("");
    setHubBottomSendBusy(false);
    setShowPhotoMenu(false);
    setShowScrollToBottom(false);
    setVisibleStartIndex(0);
    visibleStartIndexRef.current = 0;
    setScheduleFlowActive(false);
    setLactationFlowActive(false);
    setMaternityFlowActive(false);
    setWorkFlowActive(false);
    setActiveIbclcConsult(null);
    setHospitalBagCartGroups(
      cloneHospitalBagCartGroups(initialHospitalBagCartGroups),
    );
    setHubPumpGateDialog(null);
    toast.success("已新建会话");
  }, [
    clearMainNoVisibleResponseTimer,
    hydrateGreetingFromProfile,
    stopCurrentBubblePlayback,
    stopSpeech,
  ]);

  /** 自动播报兜底：只在流式会话没有启动时，对完整回复做一次播放。 */
  const runHubDecoupledAutoVoice = useCallback(
    (
      replyId: string,
      msgForVoice: ChatMessage,
      opts?: { expectedRunId?: number },
    ) => {
      const matchesExpectedRun = () =>
        opts?.expectedRunId == null ||
        autoVoiceRunIdRef.current === opts.expectedRunId;
      if (msgForVoice.role !== "mai") return;
      if (!autoVoiceRef.current) return;
      if (!matchesExpectedRun()) return;
      const speakable = buildSpeakableTextForVoice(msgForVoice)
        .trim()
        .slice(0, CHAT_BUBBLE_VOICE_MAX_CHARS);
      if (!speakable) return;

      void (async () => {
        if (!autoVoiceRef.current || !matchesExpectedRun()) return;
        if (opts?.expectedRunId == null) {
          await stopCurrentBubblePlayback();
        } else {
          const currentSession = autoVoiceRealtimeSessionRef.current;
          if (currentSession && currentSession.runId !== opts.expectedRunId)
            return;
          if (currentSession) {
            currentSession.abortController.abort();
            currentSession.session.cancel();
            autoVoiceRealtimeSessionRef.current = null;
          }
        }
        if (!autoVoiceRef.current || !matchesExpectedRun()) return;
        const ac = new AbortController();
        bubblePlayAbortRef.current = ac;
        bubblePlayingTargetIdRef.current = replyId;
        setPlayingId(replyId);
        let session: FocusRealtimePlainTextVoiceSession | null = null;
        const voicePlaybackHandle =
          agentHubVoicePlaybackRuntime.startAutoVoice(replyId, () => {
            ac.abort();
            session?.cancel();
          });
        try {
          session = startFocusRealtimePlainTextVoice({
            userId: DEFAULT_CHAT_USER_ID,
            signal: ac.signal,
            mediaNarrationResolver: resolveMediaVoiceNarration,
            maxSegmentChars: HUB_AUTO_VOICE_STREAM_SEGMENT_MAX_CHARS,
            minSegmentChars: HUB_AUTO_VOICE_STREAM_SEGMENT_MIN_CHARS,
            eagerSegmenting: true,
            resetPlaybackOnStart: false,
            onSubtitle: () => {},
            syncSubtitle: false,
          });
          session.append(speakable);
          session.finish();
          await session.done;
        } catch (e: unknown) {
          const err = e as { name?: string; message?: string };
          if (err.name !== "AbortError") {
            toast.error(err.message || "自动语音播报失败");
          }
        } finally {
          if (
            bubblePlayAbortRef.current === ac &&
            bubblePlayingTargetIdRef.current === replyId
          ) {
            setPlayingId(null);
            bubblePlayingTargetIdRef.current = null;
          }
          agentHubVoicePlaybackRuntime.finishAutoVoice(voicePlaybackHandle);
          if (bubblePlayAbortRef.current === ac) {
            bubblePlayAbortRef.current = null;
          }
        }
      })();
    },
    [resolveMediaVoiceNarration, stopCurrentBubblePlayback],
  );

  const startHubRealtimeAutoVoice = useCallback(
    (replyId: string) => {
      if (!autoVoiceRef.current) return null;
      void primeFocusVoicePlayback().catch((e: unknown) => {
        const err = e as { message?: string };
        toast.error(err.message || "语音模式启动失败");
      });
      const ac = new AbortController();
      const runId = autoVoiceRunIdRef.current + 1;
      autoVoiceRunIdRef.current = runId;
      bubblePlayAbortRef.current = ac;
      bubblePlayingTargetIdRef.current = replyId;
      setPlayingId(replyId);

      const sessionState: NonNullable<
        typeof autoVoiceRealtimeSessionRef.current
      > = {
        runId,
        replyId,
        session: null as unknown as FocusRealtimePlainTextVoiceSession,
        abortController: ac,
        appendedChars: 0,
        receivedAudioBytes: 0,
        lastMergedAnswer: "",
        lastRichText: null,
      };
      const session = startFocusRealtimePlainTextVoice({
        userId: DEFAULT_CHAT_USER_ID,
        signal: ac.signal,
        mediaNarrationResolver: resolveMediaVoiceNarration,
        maxSegmentChars: HUB_AUTO_VOICE_STREAM_SEGMENT_MAX_CHARS,
        minSegmentChars: HUB_AUTO_VOICE_STREAM_SEGMENT_MIN_CHARS,
        eagerSegmenting: true,
        resetPlaybackOnStart: false,
        onAudioFrame: (byteLength) => {
          sessionState.receivedAudioBytes += byteLength;
        },
        onSubtitle: () => {},
        syncSubtitle: false,
      });
      sessionState.session = session;
      autoVoiceRealtimeSessionRef.current = sessionState;
      const voicePlaybackHandle = agentHubVoicePlaybackRuntime.startAutoVoice(
        replyId,
        () => {
          ac.abort();
          session.cancel();
        },
      );
      void session.done
        .catch((e: unknown) => {
          const err = e as { name?: string; message?: string };
          if (err.name !== "AbortError" && autoVoiceRef.current) {
            toast.error(err.message || "自动语音播报失败");
          }
        })
        .finally(() => {
          const isCurrentSession =
            autoVoiceRealtimeSessionRef.current?.session === session;
          const fallbackMsg: ChatMessage = {
            id: replyId,
            role: "mai",
            content: sessionState.lastMergedAnswer,
            timestamp: "",
            richText: sessionState.lastRichText ?? undefined,
          };
          const shouldFallback =
            isCurrentSession &&
            autoVoiceRef.current &&
            !ac.signal.aborted &&
            sessionState.appendedChars > 0 &&
            sessionState.receivedAudioBytes <= 0 &&
            Boolean(buildSpeakableTextForVoice(fallbackMsg).trim());
          if (isCurrentSession) {
            autoVoiceRealtimeSessionRef.current = null;
          }
          if (
            bubblePlayAbortRef.current === ac &&
            bubblePlayingTargetIdRef.current === replyId
          ) {
            setPlayingId(null);
            bubblePlayingTargetIdRef.current = null;
          }
          agentHubVoicePlaybackRuntime.finishAutoVoice(voicePlaybackHandle);
          if (bubblePlayAbortRef.current === ac) {
            bubblePlayAbortRef.current = null;
          }
          if (shouldFallback) {
            void runHubDecoupledAutoVoice(replyId, fallbackMsg, {
              expectedRunId: sessionState.runId,
            });
          }
        });
      return sessionState;
    },
    [resolveMediaVoiceNarration, runHubDecoupledAutoVoice],
  );

  /**
   * 自动播报开关关闭时，若正在播报则立即停止，避免继续播放到结束。
   * @returns void
   */
  useEffect(() => {
    if (autoVoice) return;
    void stopCurrentBubblePlayback();
  }, [autoVoice, stopCurrentBubblePlayback]);

  useEffect(() => {
    visibleStartIndexRef.current = visibleStartIndex;
  }, [visibleStartIndex]);

  useLayoutEffect(() => {
    setVisibleStartIndex((s) => {
      const nextStart = pendingLatestChatWindowSyncRef.current
        ? latestChatHistoryStart(messages.length, HUB_CHAT_HISTORY_PAGE)
        : clampChatHistoryStart(messages.length, HUB_CHAT_HISTORY_PAGE, s);
      pendingLatestChatWindowSyncRef.current = false;
      visibleStartIndexRef.current = nextStart;
      return nextStart;
    });
  }, [messages.length]);

  useLayoutEffect(() => {
    const restore = pendingHistoryScrollRestoreRef.current;
    if (!restore) return;
    restoreChatHistoryAnchor(restore);
    const frame = window.requestAnimationFrame(() => {
      restoreChatHistoryAnchor(restore);
      if (pendingHistoryScrollRestoreRef.current === restore) {
        pendingHistoryScrollRestoreRef.current = null;
      }
    });
    return () => window.cancelAnimationFrame(frame);
  }, [visibleStartIndex, restoreChatHistoryAnchor]);

  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el || messages.length === 0) return;
    const returnTo = `${location.pathname}${location.search}${location.hash}`;
    const ibclcReturnViewport = readStoredIbclcReturnViewport(returnTo);
    if (ibclcReturnViewport) {
      const restoreScrollTop = () => {
        const maxTop = Math.max(0, el.scrollHeight - el.clientHeight);
        el.scrollTop = Math.min(ibclcReturnViewport.scroll_top, maxTop);
        const isNearBottom = isChatScrollNearTail(
          el,
          DEFAULT_CHAT_TAIL_THRESHOLD_PX,
        );
        userPinnedToTailRef.current = isNearBottom;
        setShowScrollToBottom(!isNearBottom);
      };
      restoreScrollTop();
      window.requestAnimationFrame(() =>
        window.requestAnimationFrame(restoreScrollTop),
      );
      const clearTimer = window.setTimeout(clearStoredIbclcReturnViewport, 800);
      return () => window.clearTimeout(clearTimer);
    }
    el.scrollTop = el.scrollHeight;
    userPinnedToTailRef.current = true;
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 仅在进入 Hub 首帧把尾部窗口锚到最新消息
  }, []);

  /** 非 Hook：abort 不传 onDone，由再次点击发送打断侧清除 awaiting */
  const clearAwaitingBottomSendBarLoading = () => {
    if (!awaitingHubBottomReplyRef.current) return;
    awaitingHubBottomReplyRef.current = false;
    setHubBottomSendBusy(false);
  };

  /**
   * 主对话：ag-ui WebSocket 结束后同步最终正文，并清空当前流句柄。
   * @param replyId 当前 Mai 回复 id
   */
  const tryFinalizeMainReply = (replyId: string) => {
    clearMainNoVisibleResponseTimer();
    mainPendingRichTextRef.current = null;
    mainRichTextForVoiceRef.current = null;
    pendingAgUiArtifactFormLikeRef.current = false;
    mainChatCancelRef.current = null;
    mainStreamingReplyIdRef.current = null;
    agentHubMainChatRuntime.finish(replyId);
    window.setTimeout(() => {
      mainStreamFollowTailRef.current = false;
    }, 300);
    setMessages((prev) => {
      const next = prev.map((m) => {
        if (m.id !== replyId) return m;
        const mergedFull = mainStreamMergedAnswerRef.current;
        const compactedFull = compactHospitalBagCartFollowupText(mergedFull);
        const compactedStreamItems = compactHospitalBagCartStreamItems(
          m.streamRenderItems,
        );
        const synced =
          typeof compactedFull === "string" && compactedFull.length > 0
            ? {
                ...m,
                content: compactedFull,
                streamRenderItems: compactedStreamItems,
              }
            : m;
        const hasRenderableStream = (synced.streamRenderItems?.length ?? 0) > 0;
        if (
          !synced.content.trim() &&
          !synced.richText &&
          !hasRenderableStream
        ) {
          return { ...synced, content: "（无回复内容）" };
        }
        return synced;
      });
      return next;
    });
    clearAwaitingBottomSendBarLoading();
  };

  useEffect(
    () => () => {
      mainStreamFollowTailRef.current = false;
      // Do not stop global TTS here: users may switch pages while listening to a reply.
      // Playback is still stopped by explicit user actions, new turns, errors, or disabling voice.
      // 暂存图 blob URL 保留到用户删除图、发送并成功附带、或整页卸载，避免路由切换后主界面预览丢失
    },
    [],
  );

  useEffect(() => {
    const el = bottomActionRef.current;
    if (!el) return;

    const measure = () => {
      const h = Math.ceil(el.getBoundingClientRect().height);
      if (Number.isFinite(h) && h > 0) setBottomActionHeightPx(h);
    };

    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    window.addEventListener("resize", measure);

    return () => {
      ro.disconnect();
      window.removeEventListener("resize", measure);
    };
  }, []);

  const isUploadedImageBubble = (msg: ChatMessage): boolean =>
    msg.role === "user" &&
    String(msg.cardData?.kind ?? "") === "uploaded-image";

  /** 重进主界面后 ref 可能为空，仍用 cardData 里的 blob URL 做 revoke */
  useLayoutEffect(() => {
    for (const m of messages) {
      if (!isUploadedImageBubble(m)) continue;
      const url = String(m.cardData?.previewUrl ?? "");
      if (url.startsWith("blob:"))
        uploadedImagePreviewUrlsRef.current.set(m.id, url);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 仅首帧用当前 messages 回填；避免随流式更新反复执行
  }, []);

  const handleDeleteUploadedImageBubble = useCallback(
    (messageId: string) => {
      const target = messages.find((m) => m.id === messageId);
      const uploadFileId = String(
        target?.cardData?.uploadedFileId ?? "",
      ).trim();
      const fromRef = uploadedImagePreviewUrlsRef.current.get(messageId);
      const fromCard = String(target?.cardData?.previewUrl ?? "");
      const previewUrl =
        fromRef ?? (fromCard.startsWith("blob:") ? fromCard : "");
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
        uploadedImagePreviewUrlsRef.current.delete(messageId);
      }
      setMessages((prev) => prev.filter((m) => m.id !== messageId));
      if (uploadFileId)
        log("[AG_UI_IMAGE] 从暂存图移除 legacy upload_file_id", {
          uploadFileId,
        });
    },
    [messages],
  );

  /** 底部输入发送后丢弃暂存图：预览条与本地 blob URL。 */
  const purgeHubStagedUploadedImages = useCallback(() => {
    setMessages((prev) => {
      for (const m of prev) {
        if (!isUploadedImageBubble(m)) continue;
        const fromRef = uploadedImagePreviewUrlsRef.current.get(m.id);
        const fromCard = String(m.cardData?.previewUrl ?? "");
        const url = fromRef ?? (fromCard.startsWith("blob:") ? fromCard : "");
        if (url) URL.revokeObjectURL(url);
        uploadedImagePreviewUrlsRef.current.delete(m.id);
      }
      return prev.filter((m) => !isUploadedImageBubble(m));
    });
  }, []);

  const resolveEventTag = (data: string | object): string => {
    if (typeof data !== "object" || data == null) return "";
    const rec = data as Record<string, unknown>;
    if (typeof rec.type === "string" && rec.type.trim())
      return rec.type.trim().toUpperCase();
    if (typeof rec.event === "string" && rec.event.trim())
      return rec.event.trim().toLowerCase();
    return "";
  };

  const compactHospitalBagCartFollowupText = (text: string): string => {
    const markerIndex = text.lastIndexOf(HOSPITAL_BAG_CART_FOLLOWUP_MARKER);
    if (markerIndex < 0) return text;
    return text.slice(markerIndex).trimStart();
  };

  const compactHospitalBagCartStreamItems = (
    items: ChatStreamRenderItem[] | undefined,
  ): ChatStreamRenderItem[] | undefined => {
    if (!items?.length) return items;
    if (
      !items.some(
        (item) =>
          item.kind === "text" &&
          item.text.includes(HOSPITAL_BAG_CART_FOLLOWUP_MARKER),
      )
    )
      return items;
    let foundFollowup = false;
    const compacted: ChatStreamRenderItem[] = [];
    for (const item of items) {
      if (item.kind === "rich") {
        compacted.push(item);
        continue;
      }
      if (item.text.includes(HOSPITAL_BAG_CART_FOLLOWUP_MARKER)) {
        foundFollowup = true;
        compacted.push({
          kind: "text",
          text: compactHospitalBagCartFollowupText(item.text),
        });
        continue;
      }
      if (foundFollowup) compacted.push(item);
    }
    return compacted;
  };

  const appendRichRenderItem = (
    items: ChatStreamRenderItem[] | undefined,
    payload: ChatRichTextPayload,
  ): ChatStreamRenderItem[] => {
    const list = [...(items ?? [])];
    const last = list.at(-1);
    if (last?.kind === "rich") {
      list[list.length - 1] = {
        kind: "rich",
        payload: mergePendingRichTextPayload(last.payload, payload),
      };
      return list;
    }
    list.push({ kind: "rich", payload });
    return list;
  };

  const extractMainAnswerChunk = (data: string | object): string => {
    const tag = resolveEventTag(data);
    // ag-ui 仅 TEXT_MESSAGE_CONTENT 可视作正文增量，避免误吃 TOOL_CALL_ARGS.delta
    if (tag) {
      if (tag === "reasoning" || tag === "message")
        return extractChatAnswerChunk(data);
      if (tag !== "TEXT_MESSAGE_CONTENT") return "";
      if (typeof data === "object" && data != null) {
        const delta = (data as { delta?: unknown }).delta;
        if (typeof delta === "string" && delta) return delta;
      }
    }
    return extractChatAnswerChunk(data);
  };

  const applyThinkingStatusFromCustomEvent = (
    replyId: string,
    data: Record<string, unknown>,
    mergedThinkingRef: React.MutableRefObject<string>,
  ) => {
    if (String(data.name ?? "") !== "momcozy.agent.thinking") return false;
    const value =
      data.value && typeof data.value === "object"
        ? (data.value as Record<string, unknown>)
        : null;
    const status = String(value?.status ?? "").toLowerCase();
    if (!status) return true;
    const metadata =
      value?.metadata && typeof value.metadata === "object"
        ? (value.metadata as Record<string, unknown>)
        : null;
    const thinkingText =
      metadata?.after_output_text === true ? "我接着处理下一步" : "我想一下";
    if (status === "started" || status === "running") {
      mergedThinkingRef.current = thinkingText;
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId
            ? {
                ...m,
                agentThinkingTitle: thinkingText,
              }
            : m,
        ),
      );
    } else if (status === "completed" || status === "failed") {
      mergedThinkingRef.current = "";
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId
            ? {
                ...m,
                agentThinkingTitle: undefined,
              }
            : m,
        ),
      );
    }
    return true;
  };

  const collectAgUiReadyImages = (msgs: ChatMessage[]): ChatMessage[] =>
    msgs.filter((m) => {
      if (
        m.role !== "user" ||
        String(m.cardData?.kind ?? "") !== "uploaded-image"
      )
        return false;
      return String(m.cardData?.uploadStatus ?? "") === "ready";
    });

  const fileToDataUrl = (file: File | Blob): Promise<string> =>
    new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result ?? ""));
      reader.onerror = () =>
        reject(reader.error ?? new Error("read image failed"));
      reader.readAsDataURL(file);
    });

  const clientMessageSentAt = (date = new Date()): string => {
    const pad = (value: number, length = 2) =>
      String(Math.trunc(Math.abs(value))).padStart(length, "0");
    const offsetMinutes = -date.getTimezoneOffset();
    const sign = offsetMinutes >= 0 ? "+" : "-";
    const offsetHours = Math.floor(Math.abs(offsetMinutes) / 60);
    const offsetRemainder = Math.abs(offsetMinutes) % 60;
    return [
      `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`,
      "T",
      `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`,
      ".",
      pad(date.getMilliseconds(), 3),
      `${sign}${pad(offsetHours)}:${pad(offsetRemainder)}`,
    ].join("");
  };

  const shouldForwardHospitalBagCart = (): boolean => {
    if (activeHospitalBagCart) return true;
    return messages.some((message) => {
      if (message.content.includes("/hospital-bag-cart")) return true;
      return (
        message.streamRenderItems?.some(
          (item) =>
            item.kind === "text" && item.text.includes("/hospital-bag-cart"),
        ) ?? false
      );
    });
  };

  const buildAgUiForwardedProps = (locale: string): Record<string, unknown> => {
    const timezone =
      (typeof Intl !== "undefined" &&
        Intl.DateTimeFormat().resolvedOptions().timeZone) ||
      "America/Los_Angeles";
    const forwardedProps: Record<string, unknown> = {
      user_id: DEFAULT_CHAT_USER_ID,
      locale,
      timezone,
      message_sent_at: clientMessageSentAt(),
      user_profile: {
        user_id: DEFAULT_CHAT_USER_ID,
        language: locale,
      },
    };
    if (shouldForwardHospitalBagCart()) {
      forwardedProps.hospital_bag_cart = {
        groups: hospitalBagCartGroups,
        totals: calculateHospitalBagCartTotals(hospitalBagCartGroups),
      };
    }
    return forwardedProps;
  };

  const resolveAgUiImagePayload = async (
    msgs: ChatMessage[],
  ): Promise<AgUiPayloadImageItem[]> => {
    const list = collectAgUiReadyImages(msgs);
    const payload: AgUiPayloadImageItem[] = [];
    for (const m of list) {
      const preview = String(m.cardData?.previewUrl ?? "").trim();
      if (!preview) continue;
      try {
        if (!preview.startsWith("blob:") && !preview.startsWith("data:image/"))
          continue;
        const dataUrl = preview.startsWith("data:image/")
          ? preview
          : await (async () => {
              const res = await fetch(preview);
              const blob = await res.blob();
              return fileToDataUrl(blob);
            })();
        const mime = String(m.cardData?.fileType ?? "").trim() || "image/png";
        const name = String(m.cardData?.fileName ?? "").trim() || "photo.png";
        const size = Number(m.cardData?.fileSize ?? 0) || 0;
        payload.push({ dataUrl, mimeType: mime, name, size, detail: "auto" });
      } catch (e: unknown) {
        warn(
          "[AgentHub] 图片转 data-url 失败，已跳过该图片",
          e instanceof Error ? e.message : String(e),
        );
      }
    }
    return payload;
  };

  const buildSentImagePreviews = async (
    images: AgUiPayloadImageItem[],
  ): Promise<SentChatImagePreview[]> => {
    const previews: SentChatImagePreview[] = [];
    for (let i = 0; i < images.length; i += 1) {
      const image = images[i];
      try {
        const src = await compressChatImageDataUrlForBubble(image.dataUrl);
        previews.push({
          id: `sent-image-${Date.now()}-${i}`,
          src,
          alt: image.name?.trim() || `图片 ${i + 1}`,
        });
      } catch (e: unknown) {
        warn(
          "[AgentHub] 图片气泡缩略图生成失败，使用原图展示",
          e instanceof Error ? e.message : String(e),
        );
        previews.push({
          id: `sent-image-${Date.now()}-${i}`,
          src: image.dataUrl,
          alt: image.name?.trim() || `图片 ${i + 1}`,
        });
      }
    }
    return previews;
  };

  /**
   * ag-ui WebSocket 流：正文即时写入，artifact 等最终文本开始后再追加。
   */
  const handleLiveMainStreamMessage = (
    replyId: string,
    mergedAnswerRef: React.MutableRefObject<string>,
    mergedThinkingRef: React.MutableRefObject<string>,
    pendingRichTextRef: React.MutableRefObject<ChatRichTextPayload | null>,
  ) => {
    return (data: string | object) => {
      persistAgentConversationIdFromSse(data);
      if (typeof data === "object" && data != null) {
        const thread = (data as { thread_id?: unknown }).thread_id;
        persistAgUiThreadId(thread);
      }
      const planNotification = planNotificationFromAgUiData(data);
      if (planNotification) {
        markPlanFeedbackNotification(planNotification);
      }
      const eventType = resolveEventTag(data);
      const rich = parseChatRichTextFromSseData(data);
      const richHasAgUiArtifact = richTextPayloadHasAgUiArtifact(rich);
      const incomingAgUiArtifact =
        eventType === "ARTIFACT_CREATED" ||
        eventType === "artifact_created" ||
        richHasAgUiArtifact;
      if (incomingAgUiArtifact) {
        pendingAgUiArtifactPositionRef.current = true;
        mainStreamFollowTailRef.current = false;
        userPinnedToTailRef.current = false;
        scrollTailAfterHubSendRef.current = false;
      }
      const rememberRichTextForVoice = (payload: ChatRichTextPayload) => {
        const merged = mainRichTextForVoiceRef.current
          ? mergePendingRichTextPayload(
              mainRichTextForVoiceRef.current,
              payload,
            )
          : payload;
        mainRichTextForVoiceRef.current = merged;
        if (autoVoiceRealtimeSessionRef.current?.replyId === replyId) {
          autoVoiceRealtimeSessionRef.current.lastRichText = merged;
        }
      };
      const maybeMarkBirthJourneyNotification = (
        payload: ChatRichTextPayload,
      ) => {
        if (richTextPayloadHasBirthJourneyPlanCard(payload)) {
          markBirthJourneyPlanGeneratedNotification();
        }
      };
      const maybeMarkMilkPlanNotification = (payload: ChatRichTextPayload) => {
        const notification = milkPlanNotificationFromRichText(payload);
        if (notification) {
          markPlanFeedbackNotification(notification);
        }
      };
      const stagePendingAgUiArtifactRichText = (
        payload: ChatRichTextPayload,
        formLike: boolean,
      ) => {
        maybeMarkBirthJourneyNotification(payload);
        maybeMarkMilkPlanNotification(payload);
        pendingRichTextRef.current = pendingRichTextRef.current
          ? mergePendingRichTextPayload(pendingRichTextRef.current, payload)
          : payload;
        pendingAgUiArtifactFormLikeRef.current =
          pendingAgUiArtifactFormLikeRef.current ||
          formLike ||
          richTextPayloadHasFormLikeAgUiArtifact(payload);
        rememberRichTextForVoice(payload);
      };
      const flushPendingAgUiArtifactRichText = () => {
        const pendingRichText = pendingRichTextRef.current;
        if (!pendingRichText) return false;
        const formLike =
          pendingAgUiArtifactFormLikeRef.current ||
          richTextPayloadHasFormLikeAgUiArtifact(pendingRichText);
        pendingAgUiArtifactPositionRef.current = true;
        setMessages((prev) =>
          prev.map((m) => {
            if (m.id !== replyId) return m;
            const next: ChatMessage = {
              ...m,
              richText: m.richText
                ? mergePendingRichTextPayload(m.richText, pendingRichText)
                : pendingRichText,
              streamRenderItems: appendRichRenderItem(
                m.streamRenderItems,
                pendingRichText,
              ),
            };
            return formLike ? clearQuickRepliesFromMessage(next) : next;
          }),
        );
        pendingRichTextRef.current = null;
        pendingAgUiArtifactFormLikeRef.current = false;
        return true;
      };
      const side = applyAgUiStreamSideEffects(replyId, data, setMessages, {
        pendingRichTextRef,
        deferAgUiArtifacts: true,
        onAgUiArtifactRichText: (payload, meta) => {
          stagePendingAgUiArtifactRichText(payload, meta.formLike);
        },
        onMediaVoice: rememberMediaVoiceItems,
        onHospitalBagCartUpdate: (groups) => {
          setHospitalBagCartGroups(cloneHospitalBagCartGroups(groups));
        },
      });
      if (rich || side.didUpdate) clearMainNoVisibleResponseTimer();
      if (rich) {
        if (richHasAgUiArtifact) {
          stagePendingAgUiArtifactRichText(
            rich,
            richTextPayloadHasFormLikeAgUiArtifact(rich),
          );
        } else {
          maybeMarkBirthJourneyNotification(rich);
          maybeMarkMilkPlanNotification(rich);
          rememberRichTextForVoice(rich);
          setMessages((prev) =>
            prev.map((m) =>
              m.id === replyId
                ? {
                    ...m,
                    richText: m.richText
                      ? mergePendingRichTextPayload(m.richText, rich)
                      : rich,
                    streamRenderItems: appendRichRenderItem(
                      m.streamRenderItems,
                      rich,
                    ),
                  }
                : m,
            ),
          );
        }
      }
      if (eventType === "CUSTOM" && typeof data === "object" && data != null) {
        if (
          applyThinkingStatusFromCustomEvent(
            replyId,
            data as Record<string, unknown>,
            mergedThinkingRef,
          )
        ) {
          clearMainNoVisibleResponseTimer();
          return;
        }
      }
      const chunk = extractMainAnswerChunk(data);
      if (eventType === "reasoning") {
        if (!chunk) return;
        clearMainNoVisibleResponseTimer();
        const mergedThinking = mergeStreamingAnswer(
          mergedThinkingRef.current,
          chunk,
        );
        mergedThinkingRef.current = mergedThinking;
        setMessages((prev) =>
          prev.map((m) =>
            m.id === replyId
              ? {
                  ...m,
                  thinkingContent: mergedThinking,
                  thinkingCollapsed: false,
                  thinkingStatus: "thinking",
                }
              : m,
          ),
        );
        return;
      }
      if (!chunk && !rich && !side.didUpdate) return;
      clearMainNoVisibleResponseTimer();

      let merged = mergedAnswerRef.current;
      let delta = "";
      if (chunk) {
        const nextAnswer = mergeStreamingAnswerDelta(merged, chunk);
        merged = nextAnswer.merged;
        delta = nextAnswer.delta;
        mergedAnswerRef.current = merged;
        if (delta && autoVoiceRef.current) {
          let realtimeVoice = autoVoiceRealtimeSessionRef.current;
          if (!realtimeVoice || realtimeVoice.replyId !== replyId) {
            realtimeVoice = startHubRealtimeAutoVoice(replyId);
          }
          if (realtimeVoice?.replyId === replyId) {
            realtimeVoice.appendedChars += delta.length;
            realtimeVoice.lastMergedAnswer = merged;
            realtimeVoice.session.append(delta);
          }
        }
      }

      setMessages((prev) =>
        prev.map((m) => {
          if (m.id !== replyId) return m;
          let next: ChatMessage = { ...m, content: merged };
          if (
            (eventType === "message" ||
              eventType === "TEXT_MESSAGE_CONTENT" ||
              eventType === "TEXT_MESSAGE_END") &&
            (next.thinkingContent?.trim() ?? "")
          ) {
            next = { ...next, thinkingCollapsed: true, thinkingStatus: "done" };
          }
          if (delta) {
            next = {
              ...next,
              streamRenderItems: appendTextRenderItemBeforeAgUiArtifacts(
                next.streamRenderItems,
                delta,
              ),
            };
          }
          return next;
        }),
      );
      if (mergedAnswerRef.current.trim()) {
        flushPendingAgUiArtifactRichText();
      }
    };
  };

  const toggleThinkingCollapsed = (messageId: string) => {
    setMessages((prev) =>
      prev.map((m) =>
        m.id === messageId
          ? { ...m, thinkingCollapsed: !(m.thinkingCollapsed ?? false) }
          : m,
      ),
    );
  };

  const resolveThinkingStatusText = (msg: ChatMessage): string => {
    if (msg.thinkingStatus === "done") return "我想好啦";
    const isStreamingThisMessage =
      (mainStreamingReplyIdRef.current === msg.id &&
        mainChatCancelRef.current != null) ||
      mainChatRuntimeSnapshot.replyId === msg.id;
    return isStreamingThisMessage ? "我想一下" : "我想好啦";
  };

  /** 发起 Hub ag-ui WebSocket 对话流（主接口，含富文本解析）。 */
  const startMainChatStream = async (
    query: string,
    opts?: {
      showUserMessage?: boolean;
      purgeStagedImagesAfterAttach?: boolean;
      userDisplayText?: string;
      onStreamDone?: () => void;
      onStreamError?: (error?: Error) => void;
    },
  ) => {
    prepareLatestChatWindowForNewTurn();
    const showUserMessage = opts?.showUserMessage ?? true;
    const replyTs = new Date().toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const workTimerStartMs = Date.now();
    const stagedImageMessages = collectAgUiReadyImages(messages);
    const agUiImages = await resolveAgUiImagePayload(stagedImageMessages);
    const sentImagePreviews = showUserMessage
      ? await buildSentImagePreviews(agUiImages)
      : [];
    const userVisibleText =
      opts?.userDisplayText !== undefined ? opts.userDisplayText.trim() : query;
    const userMsg: ChatMessage = {
      id: createAgentHubMessageId("u"),
      role: "user",
      content: userVisibleText,
      timestamp: replyTs,
      cardData:
        sentImagePreviews.length > 0
          ? { sentImages: sentImagePreviews }
          : undefined,
    };
    const replyId = createAgentHubMessageId("m");
    const replyPlaceholder: ChatMessage = {
      id: replyId,
      role: "mai",
      content: "",
      timestamp: replyTs,
      cardType: "encourage",
      chatStreamContext: "main",
      // Timer starts when user sends the message; panel still stays hidden until work steps appear.
      agentWorkStartedAtMs: workTimerStartMs,
    };
    setMessages((prev) => [
      ...clearQuickRepliesFromMessages(prev),
      ...(showUserMessage ? [userMsg] : []),
      replyPlaceholder,
    ]);
    if (opts?.purgeStagedImagesAfterAttach) purgeHubStagedUploadedImages();
    mainPendingRichTextRef.current = null;
    mainRichTextForVoiceRef.current = null;
    pendingAgUiArtifactFormLikeRef.current = false;
    clearMainNoVisibleResponseTimer();
    agentHubMainChatRuntime.cancel();
    mainChatCancelRef.current?.();
    mainStreamingReplyIdRef.current = null;
    await stopCurrentBubblePlayback();
    mainStreamMergedAnswerRef.current = "";
    mainStreamMergedThinkingRef.current = "";
    mainStreamingReplyIdRef.current = replyId;
    mainStreamFollowTailRef.current = true;
    primeAutoVoicePlayback();
    const onMessageHandler = handleLiveMainStreamMessage(
      replyId,
      mainStreamMergedAnswerRef,
      mainStreamMergedThinkingRef,
      mainPendingRichTextRef,
    );
    mainNoVisibleResponseTimerRef.current = window.setTimeout(() => {
      if (mainStreamingReplyIdRef.current !== replyId) return;
      mainNoVisibleResponseTimerRef.current = null;
      opts?.onStreamError?.(new Error("no visible response"));
      agentHubMainChatRuntime.cancel();
      mainChatCancelRef.current?.();
      void stopCurrentBubblePlayback();
      mainChatCancelRef.current = null;
      mainStreamingReplyIdRef.current = null;
      agentHubMainChatRuntime.finish(replyId);
      window.setTimeout(() => {
        mainStreamFollowTailRef.current = false;
      }, 300);
      mainPendingRichTextRef.current = null;
      mainRichTextForVoiceRef.current = null;
      pendingAgUiArtifactFormLikeRef.current = false;
      mainStreamMergedAnswerRef.current = "";
      mainStreamMergedThinkingRef.current = "";
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId
            ? {
                ...m,
                content: "这次没有拿到回复，可能是连接中断了。你再发一次就好。",
                cardType: "data" as const,
                agentThinkingTitle: undefined,
                agentStatusDone: true,
                agentWorkFinishedAtMs: Date.now(),
              }
            : m,
        ),
      );
      clearAwaitingBottomSendBarLoading();
    }, HUB_MAIN_STREAM_NO_VISIBLE_RESPONSE_TIMEOUT_MS);
    const onDoneHandler = () => {
      opts?.onStreamDone?.();
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId && (m.thinkingContent?.trim() ?? "")
            ? { ...m, thinkingCollapsed: true, thinkingStatus: "done" }
            : m,
        ),
      );
      const mergedSnap = mainStreamMergedAnswerRef.current;
      const richSnap =
        mainRichTextForVoiceRef.current ?? mainPendingRichTextRef.current;
      window.setTimeout(() => {
        tryFinalizeMainReply(replyId);
        mainStreamingReplyIdRef.current = null;
        const realtimeVoice = autoVoiceRealtimeSessionRef.current;
        if (realtimeVoice?.replyId === replyId) {
          const expectedRunId = realtimeVoice.runId;
          if (realtimeVoice.appendedChars > 0) {
            realtimeVoice.session.finish();
          } else {
            realtimeVoice.session.cancel();
          }
          if (realtimeVoice.appendedChars <= 0 && autoVoiceRef.current) {
            const dummy: ChatMessage = {
              id: replyId,
              role: "mai",
              content: mergedSnap,
              timestamp: "",
              richText: richSnap ?? undefined,
            };
            if (buildSpeakableTextForVoice(dummy).trim()) {
              void runHubDecoupledAutoVoice(replyId, dummy, { expectedRunId });
            }
          }
        } else if (autoVoiceRef.current) {
          const expectedRunId = autoVoiceRunIdRef.current;
          const dummy: ChatMessage = {
            id: replyId,
            role: "mai",
            content: mergedSnap,
            timestamp: "",
            richText: richSnap ?? undefined,
          };
          if (buildSpeakableTextForVoice(dummy).trim()) {
            void runHubDecoupledAutoVoice(replyId, dummy, { expectedRunId });
          }
        }
      }, 0);
    };
    const onErrorHandler = (err: Error) => {
      opts?.onStreamError?.(err);
      clearMainNoVisibleResponseTimer();
      void stopCurrentBubblePlayback();
      mainPendingRichTextRef.current = null;
      mainRichTextForVoiceRef.current = null;
      pendingAgUiArtifactFormLikeRef.current = false;
      mainStreamMergedAnswerRef.current = "";
      mainStreamMergedThinkingRef.current = "";
      mainChatCancelRef.current = null;
      mainStreamingReplyIdRef.current = null;
      agentHubMainChatRuntime.finish(replyId);
      window.setTimeout(() => {
        mainStreamFollowTailRef.current = false;
      }, 300);
      log("[CHAT_MESSAGE] 主对话错误", err?.message ?? err);
      const msg = err?.message ?? String(err);
      const isNetworkError =
        /failed to fetch|networkerror|load failed/i.test(msg) ||
        msg === "Failed to fetch";
      const hint = isNetworkError
        ? "请求失败：无法连接后端。请确认服务地址、VITE_API_BASE_URL / VITE_API_TOKEN 及网络。"
        : `请求失败：${msg}`;
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId
            ? {
                ...m,
                content: hint,
                cardType: "data" as const,
                agentThinkingTitle: undefined,
                agentStatusDone: true,
                agentWorkFinishedAtMs: Date.now(),
              }
            : m,
        ),
      );
      clearAwaitingBottomSendBarLoading();
    };
    const agUiLocale =
      (typeof navigator !== "undefined" && navigator.language) || "zh-CN";
    let wsCancel: (() => void) | null = null;
    const cancelRuntimeStream = () => {
      clearMainNoVisibleResponseTimer();
      wsCancel?.();
      wsCancel = null;
      if (mainStreamingReplyIdRef.current === replyId) {
        mainStreamingReplyIdRef.current = null;
        mainStreamMergedAnswerRef.current = "";
        mainStreamMergedThinkingRef.current = "";
        mainPendingRichTextRef.current = null;
        mainRichTextForVoiceRef.current = null;
        pendingAgUiArtifactFormLikeRef.current = false;
        mainStreamFollowTailRef.current = false;
      }
      if (mainChatCancelRef.current === cancelRuntimeStream) {
        mainChatCancelRef.current = null;
      }
      clearAwaitingBottomSendBarLoading();
      setHubBottomSendBusy(false);
      agentHubMainChatRuntime.finish(replyId);
    };
    mainChatCancelRef.current = cancelRuntimeStream;
    agentHubMainChatRuntime.start(replyId, cancelRuntimeStream);
    wsCancel = postAgUiWebSocketStream({
      text: query,
      threadId: getAgUiThreadIdForRequest(),
      locale: agUiLocale,
      images: agUiImages,
      forwardedProps: buildAgUiForwardedProps(agUiLocale),
      parseJSON: true,
      onMessage: onMessageHandler,
      onDone: onDoneHandler,
      onError: onErrorHandler,
    });
  };

  const tryStartMilkAnalysisReminderFollowup = useCallback(() => {
    if (mainChatRuntimeSnapshot.running || mainChatCancelRef.current) return;
    if (isAgentNotificationVoicePlaying()) return;
    if (milkAnalysisFollowupInFlightRef.current) return;
    const pending = peekMilkAnalysisReminderFollowup();
    if (!pending) return;
    const claimed = markMilkAnalysisReminderFollowupAttempt(pending.taskId);
    if (!claimed) return;
    milkAnalysisFollowupInFlightRef.current = claimed.taskId;
    const clearInFlight = () => {
      if (milkAnalysisFollowupInFlightRef.current === claimed.taskId) {
        milkAnalysisFollowupInFlightRef.current = null;
      }
    };
    const prompt = buildMilkAnalysisReminderFollowupPrompt(claimed);
    void startMainChatStream(prompt, {
      showUserMessage: false,
      onStreamDone: () => {
        completeMilkAnalysisReminderFollowup(claimed.taskId);
        clearInFlight();
      },
      onStreamError: () => {
        clearInFlight();
        retryMilkAnalysisReminderFollowupLater(claimed.taskId);
      },
    }).catch(() => {
      clearInFlight();
      retryMilkAnalysisReminderFollowupLater(claimed.taskId);
    });
  }, [mainChatRuntimeSnapshot.running]);

  useEffect(() => {
    const timer = window.setTimeout(tryStartMilkAnalysisReminderFollowup, 0);
    return () => window.clearTimeout(timer);
  }, [messages.length, tryStartMilkAnalysisReminderFollowup]);

  useEffect(() => {
    const timers: number[] = [];
    const schedule = (delayMs: number) => {
      const timer = window.setTimeout(
        tryStartMilkAnalysisReminderFollowup,
        delayMs,
      );
      timers.push(timer);
    };
    const handler = () => {
      schedule(0);
      schedule(800);
      schedule(1800);
      schedule(3200);
    };
    window.addEventListener(MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT, handler);
    return () => {
      timers.forEach((timer) => window.clearTimeout(timer));
      window.removeEventListener(
        MILK_ANALYSIS_REMINDER_FOLLOWUP_EVENT,
        handler,
      );
    };
  }, [tryStartMilkAnalysisReminderFollowup]);

  useEffect(() => {
    const handler = () => {
      window.setTimeout(tryStartMilkAnalysisReminderFollowup, 0);
    };
    window.addEventListener(AGENT_NOTIFICATION_VOICE_IDLE_EVENT, handler);
    return () =>
      window.removeEventListener(AGENT_NOTIFICATION_VOICE_IDLE_EVENT, handler);
  }, [tryStartMilkAnalysisReminderFollowup]);

  useEffect(() => {
    const handler = () => {
      if (document.visibilityState && document.visibilityState !== "visible") {
        return;
      }
      window.setTimeout(tryStartMilkAnalysisReminderFollowup, 0);
    };
    window.addEventListener("focus", handler);
    document.addEventListener("visibilitychange", handler);
    return () => {
      window.removeEventListener("focus", handler);
      document.removeEventListener("visibilitychange", handler);
    };
  }, [tryStartMilkAnalysisReminderFollowup]);

  const startDirectHospitalBagPumpCartUpdate = async (
    query: string,
    opts?: { userDisplayText?: string },
  ): Promise<boolean> => {
    const intent = resolveDirectPumpCartUpdateIntent(query);
    if (!intent) return false;

    prepareLatestChatWindowForNewTurn();
    setHubBottomSendBusy(true);

    const replyTs = new Date().toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const userVisibleText =
      opts?.userDisplayText !== undefined
        ? opts.userDisplayText.trim()
        : query.trim();
    const replyId = createAgentHubMessageId("m-direct-cart-");
    const userMsg: ChatMessage = {
      id: createAgentHubMessageId("u-direct-cart-"),
      role: "user",
      content: userVisibleText || query,
      timestamp: replyTs,
    };
    const workStartedAtMs = Date.now();
    const replyPlaceholder: ChatMessage = {
      id: replyId,
      role: "mai",
      content: "",
      timestamp: replyTs,
      cardType: "encourage",
      chatStreamContext: "main",
      agentWorkStartedAtMs: workStartedAtMs,
      agentToolCalls: [
        {
          id: `direct-cart-${workStartedAtMs}`,
          name: "hospital_bag_cart_update",
          title: "我先帮你调整待产包购物车～",
          argsDigest: intent.model,
          state: "running",
        },
      ],
    };
    setMessages((prev) => [
      ...clearQuickRepliesFromMessages(prev),
      userMsg,
      replyPlaceholder,
    ]);

    try {
      const locale =
        (typeof navigator !== "undefined" && navigator.language) || "zh-CN";
      const response = await apiRequestRaw<DirectHospitalBagCartUpdateResponse>(
        "/api/hospital-bag/cart-update",
        {
          method: "POST",
          body: {
            user_message: query,
            locale,
            hospital_bag_cart: { groups: hospitalBagCartGroups },
            args: {
              action: "replace_pump_model",
              product_sku_id: intent.skuId,
            },
          },
        },
      );
      const nextGroups = response.cart_update?.groups;
      if (Array.isArray(nextGroups)) {
        setHospitalBagCartGroups(
          cloneHospitalBagCartGroups(
            normalizeHospitalBagCartGroups(nextGroups),
          ),
        );
      }
      const message =
        response.cart_update?.message ||
        response.summary ||
        `好，已经帮你把购物车里的吸奶器换成 ${intent.model} 了。`;
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId
            ? {
                ...m,
                content: message,
                cardType: "data" as const,
                agentStatusDone: true,
                agentWorkFinishedAtMs: Date.now(),
                agentToolCalls: (m.agentToolCalls ?? []).map((row) => ({
                  ...row,
                  title: "我已经帮你更新好待产包购物车啦",
                  state: "completed" as const,
                })),
              }
            : m,
        ),
      );
    } catch (e: unknown) {
      warn(
        "[AgentHub] 直接更新待产包购物车失败",
        e instanceof Error ? e.message : String(e),
      );
      setMessages((prev) =>
        prev.map((m) =>
          m.id === replyId
            ? {
                ...m,
                content:
                  "这次本地购物车更新没有完成，可能是服务暂时不可用。请再点一次。",
                cardType: "data" as const,
                agentStatusDone: true,
                agentWorkFinishedAtMs: Date.now(),
                agentToolCalls: (m.agentToolCalls ?? []).map((row) => ({
                  ...row,
                  title: "这次购物车暂时没更新",
                  state: "error" as const,
                })),
              }
            : m,
        ),
      );
    } finally {
      clearAwaitingBottomSendBarLoading();
      setHubBottomSendBusy(false);
    }
    return true;
  };

  const appendStaticAssistantReply = (
    value: string,
    options: { displayText?: string; assistantReply: string },
  ) => {
    const replyTs = new Date().toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const userVisibleText = options.displayText?.trim() || value.trim();
    const replyId = createAgentHubMessageId("m-static-");
    const chunks = splitStaticAssistantReplyForStreaming(
      options.assistantReply,
    );
    const finalReply = options.assistantReply.trim();
    const userMsg: ChatMessage = {
      id: createAgentHubMessageId("u-static-"),
      role: "user",
      content: userVisibleText,
      timestamp: replyTs,
    };
    const replyMsg: ChatMessage = {
      id: replyId,
      role: "mai",
      content: "",
      timestamp: replyTs,
      cardType: "encourage",
      chatStreamContext: "main",
    };
    const completeStaticReply = (content: string) => {
      clearStaticAssistantReplyTimers();
      const realtimeVoice = autoVoiceRealtimeSessionRef.current;
      if (realtimeVoice?.replyId === replyId) {
        if (realtimeVoice.appendedChars > 0) {
          realtimeVoice.session.finish();
        } else {
          realtimeVoice.session.cancel();
        }
      }
      mainChatCancelRef.current = null;
      if (mainStreamingReplyIdRef.current === replyId) {
        mainStreamingReplyIdRef.current = null;
      }
      setHubBottomSendBusy(false);
      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === replyId
            ? {
                ...msg,
                content,
                agentStatusDone: true,
                agentWorkFinishedAtMs: Date.now(),
              }
            : msg,
        ),
      );
    };
    mainChatCancelRef.current?.();
    clearStaticAssistantReplyTimers();
    mainChatCancelRef.current = null;
    mainStreamingReplyIdRef.current = replyId;
    mainStreamFollowTailRef.current = true;
    clearAwaitingBottomSendBarLoading();
    setHubBottomSendBusy(true);
    setMessages((prev) => [
      ...clearQuickRepliesFromMessages(prev),
      userMsg,
      replyMsg,
    ]);
    if (!chunks.length) {
      completeStaticReply(finalReply);
      return;
    }
    mainChatCancelRef.current = () => completeStaticReply(finalReply);
    let merged = "";
    chunks.forEach((chunk, index) => {
      const timer = window.setTimeout(
        () => {
          merged += chunk;
          if (chunk && autoVoiceRef.current) {
            let realtimeVoice = autoVoiceRealtimeSessionRef.current;
            if (!realtimeVoice || realtimeVoice.replyId !== replyId) {
              realtimeVoice = startHubRealtimeAutoVoice(replyId);
            }
            if (realtimeVoice?.replyId === replyId) {
              realtimeVoice.appendedChars += chunk.length;
              realtimeVoice.lastMergedAnswer = merged;
              realtimeVoice.session.append(chunk);
            }
          }
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === replyId
                ? {
                    ...msg,
                    content: merged,
                    agentStatusDone: false,
                  }
                : msg,
            ),
          );
          if (index === chunks.length - 1) {
            completeStaticReply(finalReply);
          }
        },
        120 + index * 180,
      );
      staticAssistantReplyTimersRef.current.push(timer);
    });
  };

  const handleAgentRichTextButtonSelect = (
    value: string,
    options?: { displayText?: string; assistantReply?: string },
  ) => {
    primeAutoVoicePlayback();
    prepareLatestChatWindowForNewTurn();
    if (options?.assistantReply) {
      appendStaticAssistantReply(value, {
        displayText: options.displayText,
        assistantReply: options.assistantReply,
      });
      return;
    }
    void (async () => {
      if (
        await startDirectHospitalBagPumpCartUpdate(value, {
          userDisplayText: options?.displayText,
        })
      )
        return;
      void startMainChatStream(value, {
        userDisplayText: options?.displayText,
      });
    })();
  };

  const handleQuickReplySelect = (replyText: string) => {
    const text = replyText.trim();
    if (!text) return;
    if (hubBottomSendBusy || isMainChatRunning) return;
    primeAutoVoicePlayback();
    prepareLatestChatWindowForNewTurn();
    setMessages((prev) => clearQuickRepliesFromMessages(prev));
    void (async () => {
      if (
        await startDirectHospitalBagPumpCartUpdate(text, {
          userDisplayText: text,
        })
      )
        return;
      awaitingHubBottomReplyRef.current = true;
      setHubBottomSendBusy(true);
      void startMainChatStream(text, { userDisplayText: text });
    })();
  };

  const handleStartPumpShortcut = useCallback(async () => {
    if (hubStartPumpShortcutLockRef.current) return;
    hubStartPumpShortcutLockRef.current = true;
    setHubStartPumpBusy(true);
    try {
      const cal =
        await resolveCalibrationComfortForPumpStart(DEFAULT_CHAT_USER_ID);
      log("[AgentHub][开始吸奶] 力度滴定", {
        ok: cal.ok,
        source: cal.source,
        comfortSides: cal.comfortSides,
        remoteThreshold: cal.remoteThreshold,
        remoteFetchError: cal.remoteFetchError,
      });

      const snap = deviceStore.get();
      const leftOk = Boolean(snap.L?.connected && snap.L.deviceId);
      const rightOk = Boolean(snap.R?.connected && snap.R.deviceId);
      const gate = resolvePumpStartGate(cal.ok, snap);
      log("[AgentHub][开始吸奶] 设备连接", {
        left: {
          connected: leftOk,
          deviceId: snap.L?.deviceId ?? null,
          deviceName: snap.L?.deviceName ?? null,
        },
        right: {
          connected: rightOk,
          deviceId: snap.R?.deviceId ?? null,
          deviceName: snap.R?.deviceName ?? null,
        },
        gate,
      });

      if (gate === "device") {
        setHubPumpGateDialog("device");
        return;
      }
      if (gate === "calibration") {
        setHubPumpGateDialog("calibration");
        return;
      }
      navigate("/pump");
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      toast.error(msg ? `检查失败：${msg}` : "检查失败，请稍后重试");
    } finally {
      hubStartPumpShortcutLockRef.current = false;
      setHubStartPumpBusy(false);
    }
  }, [navigate]);

  const handlePumpPillClick = useCallback(() => {
    if (pumpSessionLifecycle.isActive()) {
      navigate("/pump");
      return;
    }
    void handleStartPumpShortcut();
  }, [navigate, handleStartPumpShortcut]);

  /**
   * 消息内设备类 link（open-unbox / open-measure / open-identify）：统一进入智能体设备指导对话。
   * @param action 来自 ChatMessageLink.action
   */
  const openDeviceFlowFromLinkAction = (action: string | undefined) => {
    const actionTopicMap: Record<string, string> = {
      "open-unbox": "unbox",
      "open-measure": "measurement",
      "open-identify": "photo-identify",
    };
    const flowType = actionTopicMap[action ?? ""] as
      | "unbox"
      | "measurement"
      | "photo-identify"
      | "maintenance"
      | undefined;
    if (!flowType) return;
    const instructQuery = DEVICE_INSTRUCT_QUERY_BY_FLOW[flowType];
    if (instructQuery) {
      void startMainChatStream(instructQuery);
    }
  };

  const appendScheduleFlowFromLink = (actionKey: string): ChatMessage => {
    const initialAction = SCHEDULE_LINK_ACTION_MAP[actionKey] || undefined;
    return {
      id: `sf-${Date.now()}`,
      role: "mai",
      content: "",
      timestamp: new Date().toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
      }),
      cardType: "schedule-flow",
      cardData: { initialAction },
    };
  };

  const appendLactationFlowFromLink = (actionKey: string): ChatMessage => {
    const initialAction = LACTATION_LINK_ACTION_MAP[actionKey] || undefined;
    return {
      id: `lf-${Date.now()}`,
      role: "mai",
      content: "",
      timestamp: new Date().toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
      }),
      cardType: "lactation-flow",
      cardData: { initialAction },
    };
  };

  /** IBCLC 咨询在 Hub 内打开全屏覆盖层，避免跳出后丢失原对话位置。 */
  const handleOpenIbclcConsult = useCallback(
    (request: IbclcConsultOpenRequest) => {
      setActiveIbclcConsult({
        conversationId: request.threadId || getAgUiThreadIdForRequest(),
        consultId: request.consultId,
        clientUserId: request.userId || DEFAULT_CHAT_USER_ID,
      });
    },
    [],
  );

  const handleHospitalBagCartRemoveItem = useCallback(
    (itemId: string, itemName: string) => {
      setHospitalBagCartGroups((groups) =>
        removeHospitalBagCartItem(groups, itemId),
      );
      toast.success(`已删除「${itemName}」`);
    },
    [],
  );

  const handleHospitalBagCartReset = useCallback(() => {
    setHospitalBagCartGroups(
      cloneHospitalBagCartGroups(initialHospitalBagCartGroups),
    );
    toast.success("已恢复默认待产包购物车");
  }, []);

  useEffect(() => {
    const openHospitalBagCart = (event: Event) => {
      event.preventDefault();
      setActiveHospitalBagCart(true);
    };
    window.addEventListener(
      "momcozy-open-hospital-bag-cart",
      openHospitalBagCart,
    );
    return () =>
      window.removeEventListener(
        "momcozy-open-hospital-bag-cart",
        openHospitalBagCart,
      );
  }, []);

  useLayoutEffect(() => {
    const latestArtifactAnchor = latestAgUiArtifactAnchorKey(messages);
    if (!latestArtifactAnchor) {
      pendingAgUiArtifactPositionRef.current = false;
      lastAgUiArtifactAnchorKeyRef.current = null;
      return;
    }
    if (!pendingAgUiArtifactPositionRef.current) return;

    const isNewArtifactAnchor =
      latestArtifactAnchor !== lastAgUiArtifactAnchorKeyRef.current;
    if (!isNewArtifactAnchor) {
      pendingAgUiArtifactPositionRef.current = false;
      return;
    }

    mainStreamFollowTailRef.current = false;
    userPinnedToTailRef.current = false;
    scrollTailAfterHubSendRef.current = false;
    if (scrollAgUiArtifactTopToViewportMiddle(latestArtifactAnchor, "auto")) {
      pendingAgUiArtifactPositionRef.current = false;
      lastAgUiArtifactAnchorKeyRef.current = latestArtifactAnchor;
    }
  }, [messages, scrollAgUiArtifactTopToViewportMiddle]);

  /** 吸乳报告与普通气泡底部的业务链接（日程 / 泌乳 / 设备 / 路由） */
  const handleBubbleLinkPress = (link: ChatMessageLink) => {
    const userMsg: ChatMessage = {
      id: createAgentHubMessageId("u"),
      role: "user",
      content: link.label.replace(/→$/, "").trim(),
      timestamp: new Date().toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
      }),
    };
    prepareLatestChatWindowForNewTurn();
    setMessages((prev) => [...prev, userMsg]);
    if (link.action) {
      if (
        link.action === "open-schedule" ||
        link.action.startsWith("schedule-")
      ) {
        setMessages((prev) => [
          ...prev,
          appendScheduleFlowFromLink(link.action),
        ]);
        setScheduleFlowActive(true);
      } else if (link.action.startsWith("lactation-")) {
        setMessages((prev) => [
          ...prev,
          appendLactationFlowFromLink(link.action),
        ]);
        setLactationFlowActive(true);
      } else {
        openDeviceFlowFromLinkAction(link.action);
      }
    } else if (link.route) {
      setTimeout(() => navigate(link.route), 600);
    }
  };

  useEffect(() => {
    const durableMessages = stripTransientAgentHubFailureMessages(messages);
    savePersistedChatMessages(durableMessages);
    const container = scrollRef.current;
    if (!container) return;

    const prevMeta = lastMessageMetaRef.current;
    const nextLastId = messages.at(-1)?.id ?? null;
    const isNewBubble =
      messages.length !== prevMeta.len || nextLastId !== prevMeta.lastId;
    const latestArtifactAnchor = latestAgUiArtifactAnchorKey(messages);
    const awaitingArtifactPosition = pendingAgUiArtifactPositionRef.current;
    const forceTailAfterSend =
      !awaitingArtifactPosition &&
      isNewBubble &&
      scrollTailAfterHubSendRef.current;
    const forceTailDuringMainStream =
      !awaitingArtifactPosition &&
      mainStreamFollowTailRef.current &&
      mainChatRuntimeSnapshot.replyId != null;
    const shouldForceTail = forceTailAfterSend || forceTailDuringMainStream;
    const wasPinnedToTail = userPinnedToTailRef.current || shouldForceTail;
    const isNearTailAfterUpdate = isChatScrollNearTail(
      container,
      DEFAULT_CHAT_TAIL_THRESHOLD_PX,
    );

    if (forceTailAfterSend) {
      scrollTailAfterHubSendRef.current = false;
    }

    if (!latestArtifactAnchor) {
      lastAgUiArtifactAnchorKeyRef.current = null;
    } else if (!awaitingArtifactPosition) {
      lastAgUiArtifactAnchorKeyRef.current = latestArtifactAnchor;
    }

    if (
      shouldAutoScrollChatTail({
        isNewBubble,
        forceTailAfterSend: shouldForceTail,
        wasPinnedToTail,
        isNearTailAfterUpdate,
      })
    ) {
      if (isNewBubble) {
        window.requestAnimationFrame(() =>
          window.requestAnimationFrame(() => scrollToChatTail("smooth")),
        );
      } else {
        const now = Date.now();
        const cardHeightLikelyChanged =
          wasPinnedToTail && !isNearTailAfterUpdate;
        if (
          cardHeightLikelyChanged ||
          now - lastStreamingScrollAtRef.current > 120
        ) {
          scrollToChatTail("auto");
          window.requestAnimationFrame(() => scrollToChatTail("auto"));
          lastStreamingScrollAtRef.current = now;
        }
      }
    } else {
      setShowScrollToBottom(!isNearTailAfterUpdate);
    }

    lastMessageMetaRef.current = { len: messages.length, lastId: nextLastId };
  }, [messages, scrollToChatTail]);

  useEffect(() => {
    const notice = localStorage.getItem(CALIBRATION_HUB_NOTICE_KEY);
    if (!notice) return;
    localStorage.removeItem(CALIBRATION_HUB_NOTICE_KEY);
    const ts = new Date().toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const tipMsg: ChatMessage = {
      id: `calibration-hub-tip-${Date.now()}`,
      role: "mai",
      content:
        notice === "completed"
          ? "舒适负压滴定已完成，您可以直接开始吸乳。"
          : "检测到上次舒适负压滴定未完成，可点击“力度滴定”继续。",
      timestamp: ts,
    };
    setMessages((prev) => [...prev, tipMsg]);
  }, []);

  useEffect(() => {
    const appendLegacySummary = (body: string, id?: string) => {
      const appendedId = appendAgentHubAnalysisMessage(body, {
        kind: "daily_summary",
        id,
      });
      if (!appendedId) return;
      scrollTailAfterHubSendRef.current = true;
      userPinnedToTailRef.current = true;
    };
    let raw: string | null = null;
    try {
      raw = sessionStorage.getItem("mmc_native_summary_body");
    } catch {
      /* ignore */
    }
    if (raw && raw.trim()) {
      try {
        sessionStorage.removeItem("mmc_native_summary_body");
      } catch {
        /* ignore */
      }
      appendLegacySummary(raw);
    }
    const onEvt = (e: Event) => {
      const detail = (
        e as CustomEvent<{ body?: string; chatMessageId?: string }>
      ).detail;
      const d = detail?.body;
      if (typeof d === "string" && d.trim())
        appendLegacySummary(d, detail?.chatMessageId);
    };
    window.addEventListener("mmc-native-daily-summary", onEvt);
    return () => window.removeEventListener("mmc-native-daily-summary", onEvt);
  }, []);

  useEffect(() => {
    return chatBus.subscribe((msg) => {
      setMessages((prev) => [...prev, msg]);

      // Auto-trigger lactation assessment flow when chat pushes a lactation-flow card
      if (
        msg.cardData?.triggerFlow === "lactation" &&
        msg.cardData?.initialAction
      ) {
        const flowMsg: ChatMessage = {
          id: `lf-auto-${Date.now()}`,
          role: "mai",
          content: "",
          timestamp: new Date().toLocaleTimeString("zh-CN", {
            hour: "2-digit",
            minute: "2-digit",
          }),
          cardType: "lactation-flow",
          cardData: {
            initialAction: msg.cardData.initialAction,
            assessContext: msg.cardData.assessContext,
          },
        };
        setTimeout(() => {
          setMessages((prev) => [...prev, flowMsg]);
          setLactationFlowActive(true);
        }, 800);
      }
    });
  }, []);

  // Listen for navigate-to events from child flows
  useEffect(() => {
    const handler = (e: Event) => {
      const route = (e as CustomEvent).detail;
      if (route) navigate(route);
    };
    window.addEventListener("navigate-to", handler);

    // Listen for work flow trigger from Schedule's goal sheet
    const workHandler = () => {
      void startMainChatStream("我想制定返工计划");
    };
    window.addEventListener("hub-start-work-flow", workHandler);

    return () => {
      window.removeEventListener("navigate-to", handler);
      window.removeEventListener("hub-start-work-flow", workHandler);
    };
  }, [navigate]);

  const interruptMainChatStream = () => {
    const replyId =
      mainStreamingReplyIdRef.current ??
      agentHubMainChatRuntime.getSnapshot().replyId;
    const cancelCurrentStream = mainChatCancelRef.current;
    const runtimeRunning = agentHubMainChatRuntime.getSnapshot().running;
    if (
      !cancelCurrentStream &&
      !replyId &&
      !hubBottomSendBusy &&
      !runtimeRunning
    )
      return false;

    awaitingHubBottomReplyRef.current = false;
    clearMainNoVisibleResponseTimer();
    if (!agentHubMainChatRuntime.cancel()) {
      cancelCurrentStream?.();
    }
    mainChatCancelRef.current = null;
    mainStreamingReplyIdRef.current = null;
    mainStreamFollowTailRef.current = false;
    mainPendingRichTextRef.current = null;
    mainRichTextForVoiceRef.current = null;
    pendingAgUiArtifactFormLikeRef.current = false;
    mainStreamMergedAnswerRef.current = "";
    mainStreamMergedThinkingRef.current = "";
    void stopCurrentBubblePlayback();
    setHubBottomSendBusy(false);

    if (replyId) {
      const finishedAt = Date.now();
      setMessages((prev) =>
        prev.map((m) => {
          if (m.id !== replyId) return m;
          const hasVisibleAnswer = Boolean(
            m.content.trim() ||
            m.richText ||
            (m.streamRenderItems?.length ?? 0) > 0,
          );
          return {
            ...m,
            content: hasVisibleAnswer ? m.content : "已停止本轮回复。",
            cardType: hasVisibleAnswer ? m.cardType : "data",
            agentThinkingTitle: undefined,
            agentStatusDone: true,
            agentWorkFinishedAtMs: finishedAt,
            thinkingCollapsed: m.thinkingContent?.trim()
              ? true
              : m.thinkingCollapsed,
            thinkingStatus: m.thinkingContent?.trim()
              ? "done"
              : m.thinkingStatus,
          };
        }),
      );
    }

    return true;
  };

  /**
   * 发送主输入框内容：普通发送会丢弃听写收尾；语音转写结束只回填输入框，需用户主动发送。
   */
  const handleSend = async (textOverride?: string) => {
    if (hubBottomSendActionLockRef.current) return;
    hubBottomSendActionLockRef.current = true;
    try {
      const pendingText = (textOverride ?? input).trim();
      const hasReadyStagedImages = collectAgUiReadyImages(messages).length > 0;
      if (
        !hubBottomSendBusy &&
        !isMainChatRunning &&
        (pendingText || hasReadyStagedImages)
      ) {
        primeAutoVoicePlayback();
      }

      await stopSpeech({ discardSttResult: true });

      const hasNewTurnContent = Boolean(pendingText || hasReadyStagedImages);
      if (hubBottomSendBusy || isMainChatRunning) {
        const isLikelyDuplicateStop =
          !hasNewTurnContent &&
          Date.now() - lastHubBottomNewTurnAtRef.current < 700;
        if (isLikelyDuplicateStop) return;
        interruptMainChatStream();
        if (!hasNewTurnContent) return;
      }

      if (!hasNewTurnContent) return;
      lastHubBottomNewTurnAtRef.current = Date.now();
      const text = pendingText || "请看这张图片";
      setMessages((prev) => clearQuickRepliesFromMessages(prev));

      // If a schedule flow is active, forward input to it
      if (pendingText && scheduleFlowActive && scheduleFlowRef.current) {
        const consumed = scheduleFlowRef.current.handleExternalInput(text);
        if (consumed) {
          setInput("");
          return;
        }
      }

      // If a lactation flow is active, forward input to it
      if (pendingText && lactationFlowActive && lactationFlowRef.current) {
        const consumed = lactationFlowRef.current.handleExternalInput(text);
        if (consumed) {
          setInput("");
          return;
        }
      }

      // If a maternity flow is active, forward input to it
      if (pendingText && maternityFlowActive && maternityFlowRef.current) {
        const consumed = maternityFlowRef.current.handleExternalInput(text);
        if (consumed) {
          setInput("");
          return;
        }
      }

      // If a work flow is active, forward input to it
      if (pendingText && workFlowActive && workFlowRef.current) {
        const consumed = workFlowRef.current.handleExternalInput(text);
        if (consumed) {
          setInput("");
          return;
        }
      }

      prepareLatestChatWindowForNewTurn();

      if (pendingText && !hasReadyStagedImages) {
        const handledDirectly = await startDirectHospitalBagPumpCartUpdate(
          text,
          { userDisplayText: pendingText },
        );
        if (handledDirectly) {
          setInput("");
          return;
        }
      }

      awaitingHubBottomReplyRef.current = true;
      setHubBottomSendBusy(true);

      setInput("");
      void startMainChatStream(text, {
        purgeStagedImagesAfterAttach: true,
        userDisplayText: pendingText,
      });
    } finally {
      window.setTimeout(() => {
        hubBottomSendActionLockRef.current = false;
      }, 120);
    }
  };

  const handleVoiceEnd = async (opts?: { submit?: boolean }) => {
    if (!opts?.submit) {
      await stopSpeech({ discardSttResult: true });
      return;
    }
    const finalText = await stopSpeech();
    const text = finalText.trim() || inputRef.current.trim();
    if (!text) return;
    setInput(text);
  };

  /** 暂存图片文件（拍照或本地选择）：ag-ui 发送时会把预览 blob 转成 data URL。 */
  const handlePhotoUpload = useCallback(async (file: File) => {
    const imageMessageId = `img-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
    const previewUrl = URL.createObjectURL(file);
    uploadedImagePreviewUrlsRef.current.set(imageMessageId, previewUrl);
    const ts = new Date().toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const pendingMsg: ChatMessage = {
      id: imageMessageId,
      role: "user",
      content: "",
      timestamp: ts,
      cardData: {
        kind: "uploaded-image",
        fileName: file.name,
        fileType: file.type,
        fileSize: file.size,
        previewUrl,
        uploadStatus: "ready",
      },
    };
    setMessages((prev) => [...prev, pendingMsg]);
    setShowPhotoMenu(false);
    log("[AG_UI_IMAGE] 图片已暂存，发送时转 data-url", {
      fileName: file.name,
      size: file.size,
      type: file.type,
    });
  }, []);

  /**
   * 点击气泡喇叭：与全局自动播报一致，使用火山实时语音流播放；再次点击同一气泡则停止。
   * @param msg 当前消息
   */
  const handlePlayBubble = useCallback(
    async (msg: ChatMessage) => {
      if (playingId === msg.id) {
        await stopCurrentBubblePlayback();
        return;
      }
      await stopCurrentBubblePlayback();
      const ac = new AbortController();
      bubblePlayAbortRef.current = ac;
      bubblePlayingTargetIdRef.current = msg.id;
      setPlayingId(msg.id);
      try {
        const speakable = buildSpeakableTextForVoice(msg)
          .trim()
          .slice(0, CHAT_BUBBLE_VOICE_MAX_CHARS);
        if (!speakable) {
          toast.error("暂无可播报的文字");
          return;
        }
        await playFocusPlainTextVoice({
          userId: DEFAULT_CHAT_USER_ID,
          text: speakable,
          signal: ac.signal,
          onSubtitle: () => {},
          syncSubtitle: false,
        });
      } catch (e: unknown) {
        const err = e as { name?: string; message?: string };
        if (err.name !== "AbortError") {
          toast.error(err.message || "语音播报失败");
        }
      } finally {
        if (bubblePlayingTargetIdRef.current === msg.id) {
          setPlayingId(null);
          bubblePlayingTargetIdRef.current = null;
          bubblePlayAbortRef.current = null;
        }
      }
    },
    [playingId, stopCurrentBubblePlayback],
  );

  useEffect(() => {
    const pendingGreetingVoiceId = pendingGreetingVoiceIdRef.current;
    if (!pendingGreetingVoiceId) return;
    const greeting = messages.find(
      (message) =>
        message.id === pendingGreetingVoiceId && message.role === "mai",
    );
    if (!greeting) return;
    pendingGreetingVoiceIdRef.current = null;
    if (!autoVoiceRef.current) return;
    void handlePlayBubble(greeting);
  }, [handlePlayBubble, messages]);

  const visibleMessages = messages
    .slice(visibleStartIndex)
    .filter((m) => !isUploadedImageBubble(m));

  /** 上传图仍保留在 messages 中（用于 files payload 与删除），仅在列表外以底部悬浮条展示 */
  const hubUploadedImages = messages.filter(isUploadedImageBubble);
  const hasReadyHubUploadedImages = hubUploadedImages.some(
    (m) => String(m.cardData?.uploadStatus ?? "") === "ready",
  );

  const chatViewportTop = `calc(var(--top-safe) + ${HUB_TOP_ACTION_HEIGHT_PX}px)`;
  const chatViewportBottom = `calc(${HUB_BOTTOM_NAV_HEIGHT} + env(safe-area-inset-bottom) + ${bottomActionHeightPx}px)`;
  const agentResponseLightRailMode = resolveAgentResponseLightRailMode(
    mainChatRuntimeSnapshot,
    messages,
  );
  const handleScrollToLatest = () => {
    const container = scrollRef.current;
    if (!container) return;
    userPinnedToTailRef.current = true;
    setShowScrollToBottom(false);
    scrollToChatTail("smooth");
  };
  const historyLoadTemporarilyDisabled = hubBottomSendBusy || isMainChatRunning;
  const handleLoadOlderMessages = () => {
    if (historyLoadTemporarilyDisabled || visibleStartIndexRef.current <= 0)
      return;
    const restore = captureChatHistoryAnchor();
    if (!restore) return;
    pendingHistoryScrollRestoreRef.current = restore;
    userPinnedToTailRef.current = false;
    mainStreamFollowTailRef.current = false;
    setVisibleStartIndex((s) =>
      previousChatHistoryStart(s, HUB_CHAT_HISTORY_PAGE),
    );
  };

  useEffect(() => {
    const container = scrollRef.current;
    if (!container) return;
    const compute = () => {
      const isNearBottom = isChatScrollNearTail(
        container,
        DEFAULT_CHAT_TAIL_THRESHOLD_PX,
      );
      if (
        !isNearBottom &&
        Date.now() > suppressFollowTailReleaseUntilRef.current
      ) {
        mainStreamFollowTailRef.current = false;
      }
      userPinnedToTailRef.current = isNearBottom;
      setShowScrollToBottom(!isNearBottom);
    };
    compute();
    container.addEventListener("scroll", compute, { passive: true });
    window.addEventListener("resize", compute);
    return () => {
      container.removeEventListener("scroll", compute);
      window.removeEventListener("resize", compute);
    };
  }, [messages.length, visibleStartIndex]);

  useEffect(() => {
    const container = scrollRef.current;
    if (!container || typeof ResizeObserver === "undefined") return;

    let frame = 0;
    const followTailAfterResize = () => {
      if (!userPinnedToTailRef.current) return;
      if (frame) window.cancelAnimationFrame(frame);
      frame = window.requestAnimationFrame(() => {
        frame = 0;
        if (userPinnedToTailRef.current) scrollToChatTail("auto");
      });
    };

    const observer = new ResizeObserver(followTailAfterResize);
    Array.from(container.children).forEach((child) => observer.observe(child));
    return () => {
      if (frame) window.cancelAnimationFrame(frame);
      observer.disconnect();
    };
  }, [messages, visibleStartIndex, scrollToChatTail]);

  return (
    <div className="relative">
      <AgentResponseLightRail mode={agentResponseLightRailMode} />
      <div
        className="fixed left-0 right-0 z-40"
        style={{
          top: "var(--top-safe)",
          height: HUB_TOP_ACTION_HEIGHT_PX,
        }}
      >
        <div className="mx-auto flex h-full max-w-lg items-center justify-end gap-2 bg-background/90 px-3 backdrop-blur-md">
          <button
            type="button"
            onClick={handleToggleAutoVoice}
            className={cn(
              "relative inline-flex h-9 w-9 items-center justify-center rounded-full border-0 p-0 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
              autoVoice
                ? "bg-transparent text-black hover:bg-transparent"
                : "bg-[#7a6670] text-white hover:bg-[#6a5660] shadow-[0_8px_18px_rgba(99,55,72,0.12)]",
            )}
            aria-pressed={autoVoice}
            aria-label={autoVoice ? "关闭语音模式" : "开启语音模式"}
            title={autoVoice ? "关闭语音模式" : "开启语音模式"}
          >
            {autoVoice ? (
              <Volume2 className="h-4 w-4" />
            ) : (
              <VolumeX className="h-4 w-4" />
            )}
          </button>
          <button
            type="button"
            onClick={handleCreateNewConversation}
            className="inline-flex h-9 w-9 items-center justify-center rounded-full border-0 bg-transparent p-0 text-[#3b2f36] transition-colors hover:text-[#8f586d] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
            aria-label="新建会话"
            title="新建会话"
          >
            <Plus className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Chat page: dedicated viewport, only this area scrolls */}
      <div
        className="fixed left-0 right-0 z-20"
        style={{
          top: chatViewportTop,
          bottom: chatViewportBottom,
        }}
      >
        <div className="max-w-lg mx-auto h-full">
          <div className="relative h-full">
            {/* Top fade */}
            <div className="absolute top-0 left-0 right-0 h-6 bg-gradient-to-b from-background to-transparent z-10 pointer-events-none" />
            {showScrollToBottom && (
              <div className="absolute bottom-3 left-0 right-0 z-20 flex justify-center pointer-events-none">
                <button
                  type="button"
                  onClick={handleScrollToLatest}
                  className="pointer-events-auto flex items-center justify-center rounded-full w-9 h-9 bg-background/70 backdrop-blur-sm border border-border/70 text-foreground/90 shadow-sm hover:bg-background/85 transition-colors"
                  title="回到最新消息"
                >
                  <ChevronDown className="w-4 h-4" />
                </button>
              </div>
            )}

            <div
              ref={scrollRef}
              className="h-full overflow-y-auto px-3 pt-4 pb-6"
            >
              {visibleStartIndex > 0 && (
                <div className="flex justify-center pb-3 pt-1">
                  <button
                    type="button"
                    onClick={handleLoadOlderMessages}
                    disabled={historyLoadTemporarilyDisabled}
                    className={cn(
                      "rounded-full border border-border/70 bg-background/80 px-3 py-1.5 text-[12px] font-medium text-muted-foreground shadow-sm transition-colors",
                      "hover:border-primary/30 hover:bg-primary/5 hover:text-primary",
                      "disabled:cursor-not-allowed disabled:border-border/50 disabled:bg-muted/50 disabled:text-muted-foreground/60",
                    )}
                  >
                    {historyLoadTemporarilyDisabled
                      ? "回复结束后可查看更早对话"
                      : "查看更早对话"}
                  </button>
                </div>
              )}

              {visibleMessages.map((msg, index) => {
                const isPlainMilkAnalysisReminder =
                  msg.role === "mai" &&
                  !msg.cardType &&
                  !msg.richText &&
                  msg.id.startsWith("analysis-milk_analysis-");
                const isMainAssistantBubble =
                  msg.role === "mai" &&
                  (msg.chatStreamContext === "main" ||
                    isPlainMilkAnalysisReminder);
                const isNotificationMessage =
                  msg.messageTone === "notification";
                const containsAgUiArtifact =
                  msg.role === "mai" && messageHasAgUiArtifact(msg);
                const richTextHasAgUiArtifactForMsg =
                  richTextPayloadHasAgUiArtifact(msg.richText);
                const mainAssistantTextBubbleBase = cn(
                  "rounded-none border-0 bg-transparent px-0 py-0 text-[15px] leading-[1.58] shadow-none",
                  isNotificationMessage ? "text-[#b64b4b]" : "text-[#3f3038]",
                );
                const mainAssistantArtifactShellBase =
                  "min-h-0 rounded-none border-0 bg-transparent px-0 py-0 text-[15px] leading-[1.45] text-[#33404d] shadow-none";
                const bubbleShell = cn(
                  "relative group w-full break-words",
                  msg.role === "user"
                    ? "rounded-2xl rounded-br-[7px] border border-[#eadde2]/45 bg-[#f8f0f1] px-3 py-2.5 text-[15px] leading-[1.45] text-[#75545f] shadow-none"
                    : isMainAssistantBubble
                      ? cn("w-fit max-w-full", mainAssistantTextBubbleBase)
                      : cn(
                          "rounded-2xl rounded-bl-md border bg-card px-3.5 py-2.5 text-[13px] leading-relaxed shadow-[0_8px_20px_-18px_rgba(83,47,64,0.36)]",
                          msg.cardType ? cardBg[msg.cardType] : "border-border",
                        ),
                );
                const artifactBubbleShell = cn(
                  "relative group w-full min-w-0 max-w-full break-words",
                  msg.role === "user"
                    ? "rounded-2xl rounded-br-[7px] border border-[#eadde2]/45 bg-[#f8f0f1] px-3 py-2.5 text-[15px] leading-[1.45] text-[#75545f] shadow-none"
                    : isMainAssistantBubble
                      ? mainAssistantArtifactShellBase
                      : cn(
                          "rounded-2xl rounded-bl-md border bg-card px-3.5 py-2.5 text-[13px] leading-relaxed shadow-[0_8px_20px_-18px_rgba(83,47,64,0.36)]",
                          msg.cardType ? cardBg[msg.cardType] : "border-border",
                        ),
                );
                const segments = splitChatContentByDataDelimiter(msg.content);
                const multiBubble = segments.length > 1;
                const mdVariant: ChatMarkdownVariant =
                  msg.role === "user" ? "user" : "assistant";
                const mdClassName =
                  msg.role === "user" || isMainAssistantBubble
                    ? cn(
                        "text-[15px] leading-[1.45]",
                        isNotificationMessage && "text-[#b64b4b]",
                      )
                    : undefined;
                const orderedMainItems = isMainAssistantBubble
                  ? (msg.streamRenderItems ?? [])
                  : [];
                const hasOrderedMainItems = orderedMainItems.length > 0;
                const orderedMainHasRich =
                  hasOrderedMainItems &&
                  orderedMainItems.some((item) => item.kind === "rich");
                const sentImagePreviews =
                  msg.role === "user" ? extractSentChatImagePreviews(msg) : [];
                const hasSentImagePreviews = sentImagePreviews.length > 0;
                const previousMsg =
                  index > 0 ? visibleMessages[index - 1] : undefined;
                const isConsecutiveAssistantMessage =
                  msg.role === "mai" && previousMsg?.role === "mai";
                const showAssistantAvatar = msg.role === "mai";
                const isAssistantResponding =
                  msg.role === "mai" &&
                  ((mainStreamingReplyIdRef.current === msg.id &&
                    mainChatCancelRef.current != null) ||
                    mainChatRuntimeSnapshot.replyId === msg.id);
                const isAssistantSpeaking =
                  voicePlaybackSnapshot.autoVoicePlayingId === msg.id;
                const assistantAvatarMode = isAssistantSpeaking
                  ? "speaking"
                  : isAssistantResponding
                    ? "thinking"
                    : null;
                const assistantAvatarVideoSrc = assistantAvatarMode
                  ? assistantAvatarMode === "speaking"
                    ? momcozyAgentSpeakingVideo
                    : momcozyAgentThinkingVideo
                  : null;
                const messageSpacingClass =
                  index === 0
                    ? "mt-0"
                    : isConsecutiveAssistantMessage
                      ? "mt-7"
                      : "mt-5";

                return (
                  <div
                    key={msg.id}
                    data-chat-message-id={msg.id}
                    className={messageSpacingClass}
                  >
                    {msg.cardType === "schedule-flow" ? (
                      <div key={msg.id} className="animate-slide-up w-full">
                        {msg.cardData?.completed ? (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed">
                              ✅ 日程规划已完成
                            </div>
                          </div>
                        ) : (
                          <InlineScheduleFlow
                            ref={scheduleFlowRef}
                            initialAction={
                              msg.cardData?.initialAction as string | undefined
                            }
                            onComplete={() => {
                              setScheduleFlowActive(false);
                              const updated = chatStore
                                .get()
                                .messages.map((m) =>
                                  m.id === msg.id
                                    ? {
                                        ...m,
                                        cardData: {
                                          ...m.cardData,
                                          completed: true,
                                        },
                                      }
                                    : m,
                                );
                              chatStore.setMessages(updated);
                              setMessages(updated);
                            }}
                          />
                        )}
                      </div>
                    ) : msg.cardType === "lactation-flow" ? (
                      <div key={msg.id} className="animate-slide-up w-full">
                        {msg.cardData?.completed ? (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-primary/20 bg-primary/5 px-3 py-2 text-[13px] leading-relaxed">
                              ✅ 泌乳管理已完成
                            </div>
                          </div>
                        ) : (
                          <InlineLactationFlow
                            ref={lactationFlowRef}
                            initialAction={
                              msg.cardData?.initialAction as string | undefined
                            }
                            assessContext={
                              msg.cardData?.assessContext as
                                | {
                                    totalAvailable: number;
                                    feedP50: number;
                                    bfCount: number;
                                    bfTotalMin: number;
                                    babyName: string;
                                  }
                                | undefined
                            }
                            onComplete={() => {
                              setLactationFlowActive(false);
                              const updated = chatStore
                                .get()
                                .messages.map((m) =>
                                  m.id === msg.id
                                    ? {
                                        ...m,
                                        cardData: {
                                          ...m.cardData,
                                          completed: true,
                                        },
                                      }
                                    : m,
                                );
                              chatStore.setMessages(updated);
                              setMessages(updated);
                            }}
                          />
                        )}
                      </div>
                    ) : msg.cardType === "maternity-flow" ? (
                      <div key={msg.id} className="animate-slide-up w-full">
                        {msg.cardData?.completed ? (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-pink-200 dark:border-pink-800 bg-pink-50/50 dark:bg-pink-900/10 px-3 py-2 text-[13px] leading-relaxed">
                              ✅ 准妈妈计划已完成
                            </div>
                          </div>
                        ) : (
                          <InlineMaternityFlow
                            ref={maternityFlowRef}
                            onComplete={() => {
                              setMaternityFlowActive(false);
                              const updated = chatStore
                                .get()
                                .messages.map((m) =>
                                  m.id === msg.id
                                    ? {
                                        ...m,
                                        cardData: {
                                          ...m.cardData,
                                          completed: true,
                                        },
                                      }
                                    : m,
                                );
                              chatStore.setMessages(updated);
                              setMessages(updated);
                            }}
                          />
                        )}
                      </div>
                    ) : msg.cardType === "work-flow" ? (
                      <div key={msg.id} className="animate-slide-up w-full">
                        {msg.cardData?.completed ? (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-violet-200 dark:border-violet-800 bg-violet-50/50 dark:bg-violet-900/10 px-3 py-2 text-[13px] leading-relaxed">
                              ✅ 返工计划已完成
                            </div>
                          </div>
                        ) : (
                          <InlineWorkFlow
                            ref={workFlowRef}
                            onComplete={() => {
                              setWorkFlowActive(false);
                              const updated = chatStore
                                .get()
                                .messages.map((m) =>
                                  m.id === msg.id
                                    ? {
                                        ...m,
                                        cardData: {
                                          ...m.cardData,
                                          completed: true,
                                        },
                                      }
                                    : m,
                                );
                              chatStore.setMessages(updated);
                              setMessages(updated);
                            }}
                          />
                        )}
                      </div>
                    ) : msg.cardType === "device-flow" ? (
                      <div key={msg.id} className="animate-slide-up w-full">
                        {msg.cardData?.completed ? (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed">
                              ✅{" "}
                              {msg.cardData.flowType === "unbox"
                                ? "开箱指引已完成"
                                : msg.cardData.flowType === "measurement"
                                  ? "法兰/硅胶塞调整已完成"
                                  : msg.cardData.flowType === "maintenance"
                                    ? "设备保养已完成"
                                    : msg.cardData.flowType === "wearing-guide"
                                      ? "上身指引已完成"
                                      : "设备使用帮助已完成"}
                            </div>
                          </div>
                        ) : (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed space-y-2">
                              <p>
                                设备指导已改为<strong>对话模式</strong>
                                ，不再使用本步骤向导。
                              </p>
                              <button
                                type="button"
                                className="text-[11px] font-semibold text-primary"
                                onClick={() => {
                                  const flowType = String(
                                    msg.cardData?.flowType ?? "",
                                  );
                                  const instructQuery =
                                    DEVICE_INSTRUCT_QUERY_BY_FLOW[flowType] ||
                                    "设备使用帮助";
                                  void startMainChatStream(instructQuery);
                                }}
                              >
                                打开设备指导
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    ) : msg.cardType === "calibration" ? (
                      <div key={msg.id} className="animate-slide-up w-full">
                        {msg.cardData?.completed ? (
                          <div className="flex gap-2 items-start">
                            <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed">
                              ✅ 舒适负压滴定已完成
                            </div>
                          </div>
                        ) : (
                          <div className="space-y-3">
                            <div className="flex gap-2 items-start">
                              <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-border px-3 py-2 text-[13px] leading-relaxed">
                                已改为独立页面进行舒适负压滴定，请点击下方按钮继续。
                              </div>
                            </div>
                            <button
                              onClick={() => navigate("/calibration")}
                              className="rounded-full bg-primary px-3 py-1.5 text-[12px] font-semibold text-primary-foreground hover:bg-primary/90 transition-colors"
                            >
                              去滴定页面
                            </button>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div
                        key={msg.id}
                        className={cn(
                          "animate-slide-up flex",
                          msg.role === "user" ? "justify-end" : "justify-start",
                          showAssistantAvatar && "items-start gap-2.5",
                        )}
                      >
                        {showAssistantAvatar ? (
                          <span
                            className={cn(
                              "agent-hub-assistant-avatar -mt-1 h-8 w-8 shrink-0",
                              assistantAvatarVideoSrc &&
                                "agent-hub-assistant-avatar-active",
                              assistantAvatarVideoSrc &&
                                (assistantAvatarMode === "speaking"
                                  ? "agent-hub-assistant-avatar-speaking"
                                  : "agent-hub-assistant-avatar-thinking"),
                            )}
                          >
                            {assistantAvatarVideoSrc ? (
                              <video
                                key={`${msg.id}-${assistantAvatarMode}`}
                                className="agent-hub-assistant-avatar-video"
                                src={assistantAvatarVideoSrc}
                                aria-hidden="true"
                                autoPlay
                                loop
                                muted
                                playsInline
                                preload="auto"
                                poster={momcozyAgentAvatar}
                                onError={(event) => {
                                  event.currentTarget.style.display = "none";
                                }}
                              />
                            ) : null}
                            <img
                              src={momcozyAgentAvatar}
                              alt="CozyMate"
                              className="agent-hub-assistant-avatar-static h-8 w-8 rounded-full object-cover shadow-sm ring-1 ring-[#eadde2]/80"
                            />
                          </span>
                        ) : null}
                        <div
                          className={cn(
                            "flex flex-col gap-1.5 min-w-0",
                            msg.role === "user"
                              ? "max-w-[82%]"
                              : containsAgUiArtifact
                                ? "w-full max-w-[calc(100%-42px)]"
                                : "max-w-[calc(92%-42px)]",
                          )}
                        >
                          {msg.cardType === "report" && msg.cardData ? (
                            <AgentHubReportCard
                              msg={msg}
                              onLinkPress={handleBubbleLinkPress}
                            />
                          ) : multiBubble ? (
                            <>
                              <AgentHubAgUiDecor msg={msg} />
                              {msg.role === "mai" &&
                              (msg.thinkingContent?.trim() ?? "") ? (
                                <div className={bubbleShell}>
                                  <div className="rounded-xl border border-border/50 bg-muted/30 px-2.5 py-2">
                                    <button
                                      type="button"
                                      className="inline-flex items-center gap-1 text-[11px] text-muted-foreground/80 hover:text-muted-foreground transition-colors"
                                      onClick={() =>
                                        toggleThinkingCollapsed(msg.id)
                                      }
                                    >
                                      {msg.thinkingCollapsed ? (
                                        <ChevronRight className="h-3 w-3" />
                                      ) : (
                                        <ChevronDown className="h-3 w-3" />
                                      )}
                                      <span>
                                        {resolveThinkingStatusText(msg)}
                                      </span>
                                    </button>
                                    {!msg.thinkingCollapsed ? (
                                      <div className="mt-1 text-[12px] leading-relaxed text-muted-foreground/70 whitespace-pre-wrap">
                                        {msg.thinkingContent?.trim() ?? ""}
                                      </div>
                                    ) : null}
                                  </div>
                                </div>
                              ) : null}
                              {hasOrderedMainItems ? (
                                <>
                                  {orderedMainItems.map((item, i) => {
                                    const itemHasAgUiArtifact =
                                      streamItemHasAgUiArtifact(item);
                                    return (
                                      <div
                                        key={`${msg.id}-stream-${i}`}
                                        className={cn(
                                          itemHasAgUiArtifact
                                            ? artifactBubbleShell
                                            : bubbleShell,
                                          agUiArtifactSpacingClass(
                                            itemHasAgUiArtifact,
                                            i > 0,
                                            "stack",
                                          ),
                                        )}
                                        data-ag-ui-artifact-anchor={
                                          itemHasAgUiArtifact
                                            ? agUiArtifactAnchorKey(
                                                msg.id,
                                                `stream-${i}`,
                                              )
                                            : undefined
                                        }
                                      >
                                        {item.kind === "text" ? (
                                          <ChatMarkdown
                                            markdown={markdownForMessage(
                                              msg,
                                              item.text,
                                            )}
                                            variant={mdVariant}
                                            className={mdClassName}
                                          />
                                        ) : (
                                          <AgentHubRichTextBlock
                                            payload={item.payload}
                                            blockId={`${msg.id}-stream-${i}`}
                                            birthPrepProfileDefaults={latestUserProfile}
                                            onButtonSelect={
                                              handleAgentRichTextButtonSelect
                                            }
                                            onOpenIbclcConsult={
                                              handleOpenIbclcConsult
                                            }
                                          />
                                        )}
                                      </div>
                                    );
                                  })}
                                  {msg.richText && !orderedMainHasRich ? (
                                    <div
                                      className={cn(
                                        richTextHasAgUiArtifactForMsg
                                          ? artifactBubbleShell
                                          : bubbleShell,
                                        agUiArtifactSpacingClass(
                                          richTextHasAgUiArtifactForMsg,
                                          orderedMainItems.length > 0,
                                          "stack",
                                        ),
                                      )}
                                      data-ag-ui-artifact-anchor={
                                        richTextHasAgUiArtifactForMsg
                                          ? agUiArtifactAnchorKey(
                                              msg.id,
                                              "rich",
                                            )
                                          : undefined
                                      }
                                    >
                                      <AgentHubRichTextBlock
                                        payload={msg.richText}
                                        blockId={`${msg.id}-rich`}
                                        birthPrepProfileDefaults={latestUserProfile}
                                        onButtonSelect={
                                          handleAgentRichTextButtonSelect
                                        }
                                        onOpenIbclcConsult={
                                          handleOpenIbclcConsult
                                        }
                                      />
                                    </div>
                                  ) : null}
                                </>
                              ) : (
                                <>
                                  {segments.map((seg, i) => (
                                    <div key={i} className={bubbleShell}>
                                      {i === 0 && hasSentImagePreviews ? (
                                        <div
                                          className={cn(seg.trim() && "mb-2")}
                                        >
                                          <AgentHubSentImages
                                            images={sentImagePreviews}
                                          />
                                        </div>
                                      ) : null}
                                      <ChatMarkdown
                                        markdown={markdownForMessage(msg, seg)}
                                        variant={mdVariant}
                                        className={mdClassName}
                                      />
                                    </div>
                                  ))}
                                  {msg.richText ? (
                                    <div
                                      className={cn(
                                        richTextHasAgUiArtifactForMsg
                                          ? artifactBubbleShell
                                          : bubbleShell,
                                        agUiArtifactSpacingClass(
                                          richTextHasAgUiArtifactForMsg,
                                          segments.length > 0,
                                          "stack",
                                        ),
                                      )}
                                      data-ag-ui-artifact-anchor={
                                        richTextHasAgUiArtifactForMsg
                                          ? agUiArtifactAnchorKey(
                                              msg.id,
                                              "rich",
                                            )
                                          : undefined
                                      }
                                    >
                                      <AgentHubRichTextBlock
                                        payload={msg.richText}
                                        blockId={`${msg.id}-rich`}
                                        birthPrepProfileDefaults={latestUserProfile}
                                        onButtonSelect={
                                          handleAgentRichTextButtonSelect
                                        }
                                        onOpenIbclcConsult={
                                          handleOpenIbclcConsult
                                        }
                                      />
                                    </div>
                                  ) : null}
                                </>
                              )}
                              {(msg.links?.length ?? 0) > 0 ||
                              (msg.role === "mai" && !isMainAssistantBubble) ? (
                                <div
                                  className={
                                    containsAgUiArtifact
                                      ? artifactBubbleShell
                                      : bubbleShell
                                  }
                                >
                                  {msg.links && msg.links.length > 0 && (
                                    <div className="flex flex-wrap justify-end gap-x-3 gap-y-1">
                                      {msg.links.map((link, i) => (
                                        <button
                                          key={i}
                                          onClick={() =>
                                            handleBubbleLinkPress(link)
                                          }
                                          className="text-[11px] font-semibold text-primary hover:text-primary/80 transition-colors"
                                        >
                                          {link.label}
                                        </button>
                                      ))}
                                    </div>
                                  )}
                                  {msg.role === "mai" &&
                                  !isMainAssistantBubble ? (
                                    <div className="flex items-center justify-between mt-1.5 gap-2">
                                      <span className="text-[10px] text-muted-foreground">
                                        {msg.timestamp}
                                      </span>
                                      <button
                                        type="button"
                                        onClick={() => handlePlayBubble(msg)}
                                        className={bubbleSpeakerButtonClassName(
                                          playingId === msg.id,
                                          false,
                                        )}
                                        title={
                                          playingId === msg.id
                                            ? "点击停止播报"
                                            : "播报此条消息"
                                        }
                                      >
                                        <Volume2
                                          className={cn(
                                            "w-3.5 h-3.5",
                                            playingId === msg.id &&
                                              "animate-mai-speaker-play",
                                          )}
                                        />
                                      </button>
                                    </div>
                                  ) : null}
                                </div>
                              ) : null}
                            </>
                          ) : (
                            <>
                              <AgentHubAgUiDecor msg={msg} />
                              <div
                                className={
                                  containsAgUiArtifact
                                    ? artifactBubbleShell
                                    : bubbleShell
                                }
                              >
                                {msg.role === "mai" &&
                                (msg.thinkingContent?.trim() ?? "") ? (
                                  <div
                                    className={cn(
                                      "mb-2 rounded-xl border border-border/50 bg-muted/30 px-2.5 py-2",
                                    )}
                                  >
                                    <button
                                      type="button"
                                      className="inline-flex items-center gap-1 text-[11px] text-muted-foreground/80 hover:text-muted-foreground transition-colors"
                                      onClick={() =>
                                        toggleThinkingCollapsed(msg.id)
                                      }
                                    >
                                      {msg.thinkingCollapsed ? (
                                        <ChevronRight className="h-3 w-3" />
                                      ) : (
                                        <ChevronDown className="h-3 w-3" />
                                      )}
                                      <span>
                                        {resolveThinkingStatusText(msg)}
                                      </span>
                                    </button>
                                    {!msg.thinkingCollapsed ? (
                                      <div className="mt-1 text-[12px] leading-relaxed text-muted-foreground/70 whitespace-pre-wrap">
                                        {msg.thinkingContent?.trim() ?? ""}
                                      </div>
                                    ) : null}
                                  </div>
                                ) : null}
                                {hasOrderedMainItems ? (
                                  <>
                                    {orderedMainItems.map((item, i) => {
                                      const itemHasAgUiArtifact =
                                        streamItemHasAgUiArtifact(item);
                                      return (
                                        <div
                                          key={`${msg.id}-ordered-${i}`}
                                          className={cn(
                                            itemHasAgUiArtifact
                                              ? agUiArtifactSpacingClass(
                                                  itemHasAgUiArtifact,
                                                  i > 0,
                                                )
                                              : i > 0 && "mt-2",
                                          )}
                                          data-ag-ui-artifact-anchor={
                                            itemHasAgUiArtifact
                                              ? agUiArtifactAnchorKey(
                                                  msg.id,
                                                  `stream-${i}`,
                                                )
                                              : undefined
                                          }
                                        >
                                          {item.kind === "text" ? (
                                            <ChatMarkdown
                                              markdown={markdownForMessage(
                                                msg,
                                                item.text,
                                              )}
                                              variant={mdVariant}
                                              className={mdClassName}
                                            />
                                          ) : (
                                            <AgentHubRichTextBlock
                                              payload={item.payload}
                                              blockId={`${msg.id}-ordered-${i}`}
                                              birthPrepProfileDefaults={latestUserProfile}
                                              onButtonSelect={
                                                handleAgentRichTextButtonSelect
                                              }
                                              onOpenIbclcConsult={
                                                handleOpenIbclcConsult
                                              }
                                            />
                                          )}
                                        </div>
                                      );
                                    })}
                                    {msg.richText && !orderedMainHasRich ? (
                                      <div
                                        className={cn(
                                          richTextHasAgUiArtifactForMsg
                                            ? agUiArtifactSpacingClass(
                                                richTextHasAgUiArtifactForMsg,
                                                orderedMainItems.length > 0,
                                              )
                                            : orderedMainItems.length > 0 &&
                                                "mt-2",
                                        )}
                                        data-ag-ui-artifact-anchor={
                                          richTextHasAgUiArtifactForMsg
                                            ? agUiArtifactAnchorKey(
                                                msg.id,
                                                "rich",
                                              )
                                            : undefined
                                        }
                                      >
                                        <AgentHubRichTextBlock
                                          payload={msg.richText}
                                          blockId={`${msg.id}-rich`}
                                          birthPrepProfileDefaults={latestUserProfile}
                                          onButtonSelect={
                                            handleAgentRichTextButtonSelect
                                          }
                                          onOpenIbclcConsult={
                                            handleOpenIbclcConsult
                                          }
                                        />
                                      </div>
                                    ) : null}
                                  </>
                                ) : (
                                  <>
                                    {hasSentImagePreviews ? (
                                      <div
                                        className={cn(
                                          msg.content.trim() && "mb-2",
                                        )}
                                      >
                                        <AgentHubSentImages
                                          images={sentImagePreviews}
                                        />
                                      </div>
                                    ) : null}
                                    {msg.content.trim() ? (
                                      <ChatMarkdown
                                        markdown={markdownForMessage(
                                          msg,
                                          msg.content,
                                        )}
                                        variant={mdVariant}
                                        className={mdClassName}
                                      />
                                    ) : null}
                                    {msg.richText ? (
                                      <div
                                        className={cn(
                                          richTextHasAgUiArtifactForMsg
                                            ? agUiArtifactSpacingClass(
                                                richTextHasAgUiArtifactForMsg,
                                                Boolean(msg.content.trim()),
                                              )
                                            : msg.content.trim() && "mt-2",
                                        )}
                                        data-ag-ui-artifact-anchor={
                                          richTextHasAgUiArtifactForMsg
                                            ? agUiArtifactAnchorKey(
                                                msg.id,
                                                "rich",
                                              )
                                            : undefined
                                        }
                                      >
                                        <AgentHubRichTextBlock
                                          payload={msg.richText}
                                          blockId={`${msg.id}-rich`}
                                          birthPrepProfileDefaults={latestUserProfile}
                                          onButtonSelect={
                                            handleAgentRichTextButtonSelect
                                          }
                                          onOpenIbclcConsult={
                                            handleOpenIbclcConsult
                                          }
                                        />
                                      </div>
                                    ) : null}
                                    {!msg.content.trim() && !msg.richText ? (
                                      <ChatMarkdown
                                        markdown={markdownForMessage(
                                          msg,
                                          msg.content,
                                        )}
                                        variant={mdVariant}
                                        className={mdClassName}
                                      />
                                    ) : null}
                                  </>
                                )}
                                {msg.links && msg.links.length > 0 && (
                                  <div className="flex flex-wrap justify-end gap-x-3 gap-y-1 mt-2">
                                    {msg.links.map((link, i) => (
                                      <button
                                        key={i}
                                        onClick={() =>
                                          handleBubbleLinkPress(link)
                                        }
                                        className="text-[11px] font-semibold text-primary hover:text-primary/80 transition-colors"
                                      >
                                        {link.label}
                                      </button>
                                    ))}
                                  </div>
                                )}
                                {msg.role === "mai" &&
                                !isMainAssistantBubble ? (
                                  <div className="flex items-center justify-between mt-1.5 gap-2">
                                    <span className="text-[10px] text-muted-foreground">
                                      {msg.timestamp}
                                    </span>
                                    <button
                                      type="button"
                                      onClick={() => handlePlayBubble(msg)}
                                      className={bubbleSpeakerButtonClassName(
                                        playingId === msg.id,
                                        false,
                                      )}
                                      title={
                                        playingId === msg.id
                                          ? "点击停止播报"
                                          : "播报此条消息"
                                      }
                                    >
                                      <Volume2
                                        className={cn(
                                          "w-3.5 h-3.5",
                                          playingId === msg.id &&
                                            "animate-mai-speaker-play",
                                        )}
                                      />
                                    </button>
                                  </div>
                                ) : null}
                              </div>
                            </>
                          )}
                          <AgentHubCitations msg={msg} />
                          <AgentHubQuickReplies
                            msg={msg}
                            disabled={hubBottomSendBusy || isMainChatRunning}
                            onSelect={handleQuickReplySelect}
                          />
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {activeIbclcConsult ? (
        <div className="fixed inset-0 z-[90] bg-background">
          <IbclcChatPanel
            conversationId={activeIbclcConsult.conversationId}
            consultId={activeIbclcConsult.consultId}
            clientUserId={activeIbclcConsult.clientUserId}
            onClose={() => setActiveIbclcConsult(null)}
          />
        </div>
      ) : null}

      {activeHospitalBagCart ? (
        <div className="fixed inset-0 z-[92] bg-[#fff9fb] sm:bg-black/20">
          <HospitalBagCart
            cartGroups={hospitalBagCartGroups}
            onClose={() => setActiveHospitalBagCart(false)}
            onRemoveItem={handleHospitalBagCartRemoveItem}
            onResetCart={handleHospitalBagCartReset}
          />
        </div>
      ) : null}

      {/* Bottom input/action page: fixed layer independent from chat scroll */}
      <div
        className="fixed left-0 right-0 z-30"
        style={{
          bottom: `calc(${HUB_BOTTOM_NAV_HEIGHT} + env(safe-area-inset-bottom) + ${HUB_BOTTOM_INPUT_GAP})`,
        }}
      >
        <div ref={bottomActionRef} className="max-w-lg mx-auto bg-background">
          {/* Pills: Grouped collapsible rows */}
          <PillGroups
            startPumpBusy={hubStartPumpBusy}
            pumpSessionActive={pumpSessionActive}
            onFillInput={setInput}
            onStartPump={() => void handlePumpPillClick()}
          />

          {hubUploadedImages.length > 0 && (
            <div className="relative z-[1] px-3 pt-1 pb-1 pointer-events-none">
              <div
                role="region"
                aria-label="图片预览与上传状态"
                className="pointer-events-auto flex gap-2 overflow-x-auto max-w-full rounded-2xl border border-border/60 bg-card/85 backdrop-blur-md px-2 py-2 shadow-lg [scrollbar-width:thin]"
              >
                {hubUploadedImages.map((im) => {
                  const label = String(im.cardData?.fileName ?? "图片");
                  const status = String(im.cardData?.uploadStatus ?? "ready");
                  return (
                    <div
                      key={im.id}
                      className="relative h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-muted ring-2 ring-background"
                    >
                      {status === "uploading" ? (
                        <div
                          className="flex h-full w-full flex-col items-center justify-center gap-0.5 bg-muted px-0.5"
                          aria-busy
                          aria-label="图片上传中"
                        >
                          <Loader2 className="h-5 w-5 shrink-0 animate-spin text-primary" />
                          <span className="text-[8px] font-medium text-muted-foreground leading-none text-center">
                            上传中
                          </span>
                        </div>
                      ) : status === "failed" ? (
                        <div
                          className="flex h-full w-full flex-col items-center justify-center bg-destructive/10 px-0.5"
                          aria-label="图片上传失败"
                        >
                          <span className="text-[9px] font-bold text-destructive leading-tight text-center">
                            失败
                          </span>
                        </div>
                      ) : (
                        <img
                          src={String(im.cardData?.previewUrl ?? "")}
                          alt={label}
                          className="h-full w-full object-cover"
                        />
                      )}
                      <button
                        type="button"
                        onClick={() => handleDeleteUploadedImageBubble(im.id)}
                        className="absolute right-0.5 top-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-background/90 text-foreground shadow-sm border border-border/50 hover:bg-destructive hover:text-destructive-foreground transition-colors"
                        title="移除"
                      >
                        <X className="h-3 w-3" strokeWidth={2.5} />
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Input Bar */}
          <MaiInputBar
            value={input}
            onChange={setInput}
            onSend={() => void handleSend()}
            sendLoading={hubBottomSendBusy}
            canSendWithoutText={hasReadyHubUploadedImages}
            onVoiceStart={() => void startSpeech()}
            onVoiceEnd={(opts) => void handleVoiceEnd(opts)}
            speechListening={speechListening}
            speechPhase={speechPhase}
            showPhotoMenu={showPhotoMenu}
            onTogglePhotoMenu={setShowPhotoMenu}
            onPhotoFile={(file) => {
              void handlePhotoUpload(file);
            }}
            className="px-3"
            variant="fixed"
          />
        </div>
      </div>

      <AlertDialog
        open={hubPumpGateDialog !== null}
        onOpenChange={(open) => {
          if (!open) setHubPumpGateDialog(null);
        }}
      >
        <AlertDialogContent className="z-[70] max-w-[min(100vw-2rem,22rem)] rounded-2xl border-border/60 p-5 gap-3 shadow-xl">
          <AlertDialogHeader className="text-left space-y-2.5">
            <AlertDialogTitle className="text-base font-bold text-black dark:text-white leading-snug pr-8">
              {hubPumpGateDialog === "calibration"
                ? "需要先完成首次力度调节"
                : "吸奶器设备未连接"}
            </AlertDialogTitle>
            <AlertDialogDescription className="text-[13px] leading-relaxed text-muted-foreground">
              {hubPumpGateDialog === "calibration"
                ? "首次吸奶前需要先找到你的舒适吸力档位。完成后，M.ai 会按你的舒适档位启动吸奶。"
                : "开始吸奶前需要确认左右吸奶器已连接。请先进入设备页完成连接后再开始。"}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-row justify-end gap-2 sm:flex-row sm:justify-end sm:space-x-0">
            <AlertDialogCancel
              type="button"
              className="m-0 rounded-full border-border/80 bg-background"
              onClick={(event) => {
                if (!hubPumpGateDialog) return;
                const action = resolveCalibrationPromptCancelAction(
                  hubPumpGateDialog,
                  deviceStore.get(),
                );
                if (action.type === "showDevicePrompt") {
                  event.preventDefault();
                  setHubPumpGateDialog("device");
                  return;
                }
                if (action.type === "navigate") {
                  setHubPumpGateDialog(null);
                  navigate(action.route);
                }
              }}
            >
              稍后再说
            </AlertDialogCancel>
            <AlertDialogAction
              type="button"
              className="m-0 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 focus-visible:ring-ring"
              onClick={(event) => {
                if (!hubPumpGateDialog) return;
                const action = resolveCalibrationPromptConfirmAction(
                  hubPumpGateDialog,
                  deviceStore.get(),
                );
                if (action.type === "showDevicePrompt") {
                  event.preventDefault();
                  setHubPumpGateDialog("device");
                  return;
                }
                setHubPumpGateDialog(null);
                navigate(action.route);
              }}
            >
              {hubPumpGateDialog === "calibration"
                ? "去力度调节"
                : "去连接设备"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default AgentHub;
