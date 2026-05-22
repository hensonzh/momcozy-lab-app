import React, { useState, useRef, useEffect, useLayoutEffect, useCallback, useSyncExternalStore } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import InlineDeviceFlow from "@/components/device/InlineDeviceFlow";
import type { InlineDeviceFlowHandle } from "@/components/device/InlineDeviceFlow";
import InlineScheduleFlow from "@/components/schedule/InlineScheduleFlow";
import type { InlineScheduleFlowHandle } from "@/components/schedule/InlineScheduleFlow";
import InlineLactationFlow from "@/components/lactation/InlineLactationFlow";
import type { InlineLactationFlowHandle } from "@/components/lactation/InlineLactationFlow";
import InlineMaternityFlow from "@/components/maternity/InlineMaternityFlow";
import type { InlineMaternityFlowHandle } from "@/components/maternity/InlineMaternityFlow";
import InlineWorkFlow from "@/components/work/InlineWorkFlow";
import type { InlineWorkFlowHandle } from "@/components/work/InlineWorkFlow";
import { Volume2, ChevronDown, ChevronRight, X, Loader2, Plus } from "lucide-react";
import PillGroups from "@/components/pills/PillGroups";
import MaiInputBar from "@/components/Mai/MaiInputBar";
import { useAgentHubSpeechInput } from "@/hooks/useAgentHubSpeechInput";
import { cn } from "@/lib/utils";
import type { AgUiToolCallRow, ChatMessage, ChatMessageImageAttachment, ChatMessageLink, ChatStreamRenderItem } from "@/types/chat";
import { chatBus } from "@/lib/chatBus";
import { chatStore } from "@/lib/chatStore";
import {
  loadPersistedChatMessages,
  savePersistedChatMessages,
  stripTransientAgentHubFailureMessages,
} from "@/lib/chatMessagesLocalPersistence";
import {
  postAgUiWebSocketStream,
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
import { AGENT_HUB_SYNC_CHAT_EVENT, appendAgentHubAnalysisMessage } from "@/lib/agentHubChatMessages";
import type { AgentAnalysisCard, ChatRichTextPayload } from "@/lib/agentApiTypes";
import { log, warn } from "@/lib/logger";
import { ChatMarkdown } from "@/components/chat/ChatMarkdown";
import { ChatMarkdownImg } from "@/components/chat/ChatMarkdownImage";
import type { ChatMarkdownVariant } from "@/components/chat/ChatMarkdown";
import { splitChatContentByDataDelimiter } from "@/lib/chatContentSegments";
import { extractChatAnswerChunk, mergeStreamingAnswer, mergeStreamingAnswerDelta } from "@/lib/chatStreaming";
import {
  buildSpeakableTextForTts,
  CHAT_BUBBLE_TTS_MAX_CHARS,
  stopChatBubblePlayback,
} from "@/lib/chatBubbleTtsPlayback";
import { playFocusPlainTextTts, stopFocusVoicePlayback } from "@/lib/focusVoiceTtsPlayback";
import { toast } from "sonner";
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
import AgentHubRichTextBlock, { type IbclcConsultOpenRequest } from "@/pages/agentHub/AgentHubRichTextBlock";
import { IbclcChatPanel } from "@/pages/IbclcChat";
import HospitalBagCart from "@/pages/HospitalBagCart";
import { resolveCalibrationComfortForPumpStart } from "@/pages/agentHub/resolveCalibrationComfortForPumpStart";
import {
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
  CALIBRATION_HUB_NOTICE_KEY,
  cardBg,
  DEFAULT_CHAT_USER_ID,
  DEVICE_INSTRUCT_QUERY_BY_FLOW,
  HUB_AUTO_VOICE_FIRST_TTS_MAX_CHARS,
  HUB_BOTTOM_INPUT_GAP,
  HUB_BOTTOM_NAV_HEIGHT,
  HUB_CHAT_HISTORY_PAGE,
  HUB_CHAT_LOAD_OLDER_COOLDOWN_MS,
  HUB_CHAT_TOP_EPS,
  HUB_CHAT_TOUCH_PULL_TO_LOAD,
  HUB_CHAT_WHEEL_OVERSCROLL_TO_LOAD,
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
const NEW_CONVERSATION_GREETING =
  "你好呀，我在。\n\n这次想先聊哪件事？你可以直接说现在最困扰你的情况，不管是孕期准备、产后恢复、喂养奶量，还是设备使用，我都会陪你一步步理清楚。";

function createNewConversationGreetingMessage(): ChatMessage {
  return {
    id: `mai-greeting-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    role: "mai",
    content: NEW_CONVERSATION_GREETING,
    timestamp: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
    chatStreamContext: "main",
  };
}

interface SentChatImagePreview {
  id: string;
  src: string;
  alt: string;
}

function extractSentChatImagePreviews(msg: ChatMessage): SentChatImagePreview[] {
  const raw = msg.cardData?.sentImages;
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item, index) => {
    if (!item || typeof item !== "object") return [];
    const rec = item as Record<string, unknown>;
    const src = typeof rec.src === "string" ? rec.src.trim() : "";
    if (!src) return [];
    const alt = typeof rec.alt === "string" && rec.alt.trim() ? rec.alt.trim() : `图片 ${index + 1}`;
    const id = typeof rec.id === "string" && rec.id.trim() ? rec.id.trim() : `${msg.id}-sent-image-${index}`;
    return [{ id, src, alt }];
  });
}

function AgentHubSentImages({ images }: { images: SentChatImagePreview[] }) {
  if (images.length === 0) return null;
  return (
    <div className={cn("grid max-w-full gap-1.5", images.length > 1 ? "w-56 grid-cols-2" : "w-44 grid-cols-1")}>
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

async function compressChatImageDataUrlForBubble(dataUrl: string): Promise<string> {
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
 * @param isPlaying 当前消息是否正在 TTS（手动或自动）
 * @param isUserBubble 是否为用户侧气泡
 * @returns 合并后的 className 字符串
 */
function bubbleSpeakerButtonClassName(isPlaying: boolean, isUserBubble: boolean): string {
  return cn(
    "p-0.5 rounded-full transition-all",
    isPlaying
      ? "text-primary bg-primary/12 ring-2 ring-primary/45 shadow-sm"
      : isUserBubble
        ? "text-primary-foreground/40 hover:text-primary-foreground/70"
        : "text-muted-foreground/50 hover:text-primary",
  );
}

function AgentHubThinkingNote({ title }: { title: string }) {
  return (
    <div className="w-fit max-w-full px-0.5 text-[12px] font-[650] whitespace-nowrap bg-[linear-gradient(90deg,#98a3af_0%,#98a3af_35%,#2d3745_50%,#98a3af_65%,#98a3af_100%)] bg-[length:240%_100%] bg-clip-text text-transparent animate-[work-title-sweep_1.35s_linear_infinite]">
      {title || "正在思考"}
    </div>
  );
}

function AgentHubStatusNote({ msg }: { msg: ChatMessage }) {
  if (msg.role !== "mai") return null;
  if (msg.agentThinkingTitle?.trim()) return null;
  const status = msg.agentStatusLine?.trim() ?? "";
  if (status === "开始处理请求。" || status === "正在处理请求。" || status === "正在处理请求") return null;
  if (!status || msg.agentStatusDone) return null;
  return (
    <div className="w-[88%] px-0.5 text-[12px] leading-[1.45] text-[#687384] whitespace-nowrap">
      {status}
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
  if (kind === "mom_baby") return "每日泌乳/喂养建议";
  return "M.ai 报告";
}

function analysisStatusLabel(card?: AgentAnalysisCard): string {
  const explicit = card?.status_label?.trim();
  if (explicit) return explicit;
  if (card?.status === "normal") return "暂无明显异常";
  if (card?.status === "attention") return "需要留意";
  return card?.status?.trim() || "";
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
    ? analysisCard.sections.filter((section) => section && (
      section.title?.trim()
      || section.body?.trim()
      || section.items?.length
      || section.metrics?.length
    ))
    : [];
  const hasAnalysisCard = Boolean(analysisCard && (analysisCard.title?.trim() || analysisSections.length));
  const hasContent = msg.content.trim().length > 0;
  const hasLinks = Boolean(msg.links?.length);
  const statusLabel = analysisStatusLabel(analysisCard);
  const statusTone = analysisStatusTone(analysisCard);

  return (
    <article className={cn("agent-card", hasAnalysisCard ? "agent-card-analysis_report" : "agent-card-hospital_bag_card")}>
      {hasAnalysisCard ? (
        <>
          <header className="analysis-card-header">
            <div>
              <h2>{analysisCard?.title?.trim() || reportKindLabel(data.kind)}</h2>
            </div>
            {statusLabel ? (
              <span className={cn("analysis-status-pill", `is-${analysisToneClass(statusTone)}`)}>
                {statusLabel}
              </span>
            ) : null}
          </header>

          {analysisSections.length > 0 ? (
            <section className="analysis-section-list">
              {analysisSections.map((section, index) => {
                const items = Array.isArray(section.items) ? section.items.map((item) => item.trim()).filter(Boolean) : [];
                const metrics = Array.isArray(section.metrics)
                  ? section.metrics.filter((metric) => metric && (metric.label?.trim() || metric.value?.trim()))
                  : [];
                return (
                  <div
                    key={section.id?.trim() || `${section.title}-${index}`}
                    className={cn("analysis-section", `analysis-section-${analysisToneClass(section.tone)}`)}
                  >
                    {section.title?.trim() ? <h3>{section.title.trim()}</h3> : null}
                    {metrics.length > 0 ? (
                      <div className="analysis-metric-grid">
                        {metrics.map((metric, metricIndex) => (
                          <span key={`${metric.label}-${metricIndex}`}>
                            <small>{metric.label.trim()}</small>
                            <strong>{metric.value.trim() || "—"}</strong>
                            {metric.detail?.trim() ? <em>{metric.detail.trim()}</em> : null}
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
                <ChatMarkdown markdown={msg.content} variant="assistant" className="text-[13px] leading-relaxed text-[#35212c]" />
              </div>
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
              <ChatMarkdown markdown={msg.content} variant="assistant" className="text-[13px] leading-relaxed text-[#35212c]" />
            </section>
          ) : null}
        </>
      )}

      {hasLinks ? (
        <section className={hasAnalysisCard ? "analysis-action-section" : "agent-card-section"}>
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

function workItemTitle(tool: AgUiToolCallRow): string {
  if (tool.kind === "narration") return "";
  if (tool.title?.trim()) return tool.title.trim();
  if (tool.state === "running") return "正在执行当前步骤";
  if (tool.state === "error") return "步骤没有完成";
  return "步骤已完成";
}

function AgentHubWorkPanel({
  tools,
  finishedAtMs,
}: {
  tools: AgUiToolCallRow[];
  finishedAtMs?: number;
}) {
  const [collapsed, setCollapsed] = useState(false);
  const hasRunning = tools.some((tool) => tool.state === "running");
  const isWorkFinished = typeof finishedAtMs === "number";
  useEffect(() => {
    // Align with web flow: auto-fold work steps after run is finished.
    if (tools.length > 0 && !hasRunning && typeof finishedAtMs === "number") {
      setCollapsed(true);
    }
  }, [tools.length, hasRunning, finishedAtMs]);
  if (tools.length === 0) return null;
  const title = isWorkFinished ? "已处理" : "处理中";
  return (
    <div className="w-[88%] text-[#4f5b68] text-[12px]">
      <button
        type="button"
        aria-expanded={!collapsed}
        onClick={() => setCollapsed((v) => !v)}
        className="inline-flex items-center gap-[7px] p-0 border-0 rounded-none bg-transparent text-[#687384] hover:text-[#2d3745] text-[12px] font-[650] leading-[1.35] whitespace-nowrap"
      >
        <span
          className={cn(
            "w-0 h-0 border-y-[5px] border-y-transparent border-l-[6px] border-l-current transition-transform [transition-duration:160ms] ease-in-out",
            collapsed ? "rotate-0" : "rotate-90",
          )}
          aria-hidden="true"
        />
        <span className="whitespace-nowrap">{title}</span>
      </button>
      {!collapsed ? (
        <div className="mt-[6px] border-l-2 border-[#c8d6df] pl-3">
          <ol className="grid gap-[10px] m-0 p-0 list-none">
            {tools.map((tool) => (
              <li key={tool.id} className="grid grid-cols-[auto_1fr] gap-2">
                {tool.kind === "narration" ? (
                  <span className="w-[7px] h-[7px] mt-[5px]" aria-hidden="true" />
                ) : (
                  <span
                    className={cn(
                      "w-[7px] h-[7px] mt-[5px] rounded-full",
                      tool.state === "completed"
                        ? "bg-[#2f7d5c]"
                        : tool.state === "error"
                          ? "bg-[#b42318]"
                          : "bg-[#9aa8b5]",
                    )}
                    aria-hidden="true"
                  />
                )}
                <div className="grid gap-0.5">
                  {tool.kind !== "narration" ? (
                    <div
                      className={cn(
                        "text-[11px] font-[650] text-[#687384] whitespace-nowrap",
                        tool.state === "running" &&
                          "w-fit min-w-max bg-[linear-gradient(90deg,#98a3af_0%,#98a3af_35%,#2d3745_50%,#98a3af_65%,#98a3af_100%)] bg-[length:240%_100%] bg-clip-text text-transparent animate-[work-title-sweep_1.35s_linear_infinite]",
                      )}
                    >
                      {workItemTitle(tool)}
                    </div>
                  ) : null}
                  {tool.kind === "narration" && (tool.content?.trim() ?? "") ? (
                    <ChatMarkdown
                      markdown={tool.content?.trim() ?? ""}
                      variant="assistant"
                      className="text-[12px] leading-[1.45] text-[#2d3745] [overflow-wrap:anywhere] [&>:first-child]:mt-0 [&>:last-child]:mb-0 [&_p]:mb-[6px] [&_ul]:mb-[6px] [&_ol]:mb-[6px] [&_ul]:pl-[18px] [&_ol]:pl-[18px]"
                    />
                  ) : null}
                  {tool.argsDigest ? (
                    <div className="text-[#2d3745] leading-[1.4] break-words whitespace-pre-wrap">{tool.argsDigest}</div>
                  ) : null}
                </div>
              </li>
            ))}
          </ol>
        </div>
      ) : null}
    </div>
  );
}

function AgentHubAgUiDecor({ msg }: { msg: ChatMessage }) {
  if (msg.role !== "mai") return null;
  return (
    <>
      <AgentHubWorkPanel
        tools={msg.agentToolCalls ?? []}
        finishedAtMs={msg.agentWorkFinishedAtMs}
      />
      {msg.agentThinkingTitle ? <AgentHubThinkingNote title={msg.agentThinkingTitle} /> : null}
      <AgentHubStatusNote msg={msg} />
    </>
  );
}

/** Navigation Timing API：当前页是否为完整刷新（reload） */
function isNavigationReload(): boolean {
  if (typeof performance === "undefined") return false;
  try {
    const entries = performance.getEntriesByType("navigation") as PerformanceNavigationTiming[];
    if (entries.length > 0) return entries[0].type === "reload";
  } catch {
    /* ignore */
  }
  const legacy = performance as Performance & { navigation?: { type?: number } };
  return legacy.navigation?.type === 1;
}

/** 刷新后进页：移除无效本地预览 blob，以及未完成/失败的上传占位 */
function stripPersistedBlobUploadStagingMessages(msgs: ChatMessage[]): ChatMessage[] {
  const withoutInvalidStaging = msgs.filter((m) => {
    if (m.role !== "user" || String(m.cardData?.kind ?? "") !== "uploaded-image") return true;
    const st = String(m.cardData?.uploadStatus ?? "ready");
    if (st === "uploading" || st === "failed") return false;
    const preview = String(m.cardData?.previewUrl ?? "");
    return !preview.startsWith("blob:");
  });
  return withoutInvalidStaging.map((m) => {
    const attachments = (m.attachments ?? []).filter(
      (item) => item.type !== "image" || !item.previewUrl.startsWith("blob:"),
    );
    return attachments.length === (m.attachments ?? []).length
      ? m
      : { ...m, attachments: attachments.length > 0 ? attachments : undefined };
  });
}

function mergeHubMessagesPreserveOrder(base: ChatMessage[], incoming: ChatMessage[]): ChatMessage[] {
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

const AgentHub: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  /** 首次进入 Hub 从 localStorage 恢复对话并写入 chatStore（同次挂载内各 useState 共享） */
  const initialHubMessagesRef = useRef<ChatMessage[] | null>(null);
  if (initialHubMessagesRef.current === null) {
    const inMemory = stripTransientAgentHubFailureMessages(chatStore.get().messages);
    let loaded = loadPersistedChatMessages();
    if (isNavigationReload()) {
      const sanitized = stripPersistedBlobUploadStagingMessages(loaded);
      if (sanitized.length !== loaded.length) {
        savePersistedChatMessages(sanitized);
        log("[AgentHub] 页面刷新后移除失效 blob 预览暂存", {
          removed: loaded.length - sanitized.length,
        });
        loaded = sanitized;
      }
    }
    const merged = mergeHubMessagesPreserveOrder(loaded, inMemory);
    chatStore.setMessages(merged);
    savePersistedChatMessages(merged);
    initialHubMessagesRef.current = merged;
  }
  const hubInitialMessages = initialHubMessagesRef.current;
  const [messages, setMessages] = useState<ChatMessage[]>(hubInitialMessages);
  const [input, setInput] = useState("");
  /** 底部发送已触发 SSE：显示发送键加载直至回复结束或再次点击打断 */
  const [hubBottomSendBusy, setHubBottomSendBusy] = useState(false);
  /** 最近一次来自底部输入 handleSend 的 SSE 未完成；仅此时 onDone/onError 应清除 hubBottomSendBusy */
  const awaitingHubBottomReplyRef = useRef(false);
  const { speechListening, onMicClick, stopSpeech } = useAgentHubSpeechInput(setInput, {
    userId: DEFAULT_CHAT_USER_ID,
  });
  const [autoVoice, setAutoVoice] = useState(false);
  /** 与打字机收尾回调解耦：收尾时读取最新「自动播报」开关，避免闭包陈旧 */
  const autoVoiceRef = useRef(autoVoice);
  useEffect(() => {
    autoVoiceRef.current = autoVoice;
  }, [autoVoice]);
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);
  const initialHistoryStart = Math.max(0, hubInitialMessages.length - HUB_CHAT_HISTORY_PAGE);
  const [visibleStartIndex, setVisibleStartIndex] = useState(initialHistoryStart);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [showPhotoMenu, setShowPhotoMenu] = useState(false);
  type HubPumpGateDialog = "calibration" | "device";
  const [hubPumpGateDialog, setHubPumpGateDialog] = useState<HubPumpGateDialog | null>(null);
  const [hubStartPumpBusy, setHubStartPumpBusy] = useState(false);
  /** 全局会话状态：lifecycle 由 deviceStore 驱动，running/paused 时显示「吸奶中」 */
  const pumpSessionState = useSyncExternalStore(
    pumpSessionLifecycle.subscribe,
    pumpSessionLifecycle.getSessionState,
    pumpSessionLifecycle.getSessionState,
  );
  const pumpSessionActive = pumpSessionState === "running" || pumpSessionState === "paused";
  /** Hub 底部操作区真实渲染高度（按键 + 输入框），用于对话视口动态下边界 */
  const [bottomActionHeightPx, setBottomActionHeightPx] = useState(170);
  const [deviceFlowActive, setDeviceFlowActive] = useState(() =>
    hubInitialMessages.some(m => m.cardType === "device-flow" && !m.cardData?.completed)
  );
  const [scheduleFlowActive, setScheduleFlowActive] = useState(() =>
    hubInitialMessages.some(m => m.cardType === "schedule-flow" && !m.cardData?.completed)
  );
  const [lactationFlowActive, setLactationFlowActive] = useState(() =>
    hubInitialMessages.some(m => m.cardType === "lactation-flow" && !m.cardData?.completed)
  );
  const [maternityFlowActive, setMaternityFlowActive] = useState(() =>
    hubInitialMessages.some(m => m.cardType === "maternity-flow" && !m.cardData?.completed)
  );
  const [activeIbclcConsult, setActiveIbclcConsult] = useState<{
    conversationId: string;
    consultId: string;
  } | null>(null);
  const [activeHospitalBagCart, setActiveHospitalBagCart] = useState(false);
  const [workFlowActive, setWorkFlowActive] = useState(() =>
    hubInitialMessages.some(m => m.cardType === "work-flow" && !m.cardData?.completed)
  );
  const deviceFlowRef = useRef<InlineDeviceFlowHandle>(null);
  const scheduleFlowRef = useRef<InlineScheduleFlowHandle>(null);
  const lactationFlowRef = useRef<InlineLactationFlowHandle>(null);
  const maternityFlowRef = useRef<InlineMaternityFlowHandle>(null);
  const workFlowRef = useRef<InlineWorkFlowHandle>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const visibleStartIndexRef = useRef(initialHistoryStart);
  const pendingHistoryScrollRestoreRef = useRef<{ prevH: number; prevTop: number } | null>(null);
  const loadOlderCooldownRef = useRef(0);
  const userPinnedToTailRef = useRef(true);
  /** 底部输入发送并入队回复消息后，下一次列表更新时强制滚到最后一条（即使用户之前在回看历史） */
  const scrollTailAfterHubSendRef = useRef(false);
  const lastMessageMetaRef = useRef<{ len: number; lastId: string | null }>({
    len: hubInitialMessages.length,
    lastId: hubInitialMessages.at(-1)?.id ?? null,
  });
  /** 通知进首页等场景：外部已写入 chatStore/持久化，需与首次挂载同样合并进本地 messages。 */
  useLayoutEffect(() => {
    const onExternalSync = () => {
      const inMemory = stripTransientAgentHubFailureMessages(chatStore.get().messages);
      const loaded = loadPersistedChatMessages();
      const merged = mergeHubMessagesPreserveOrder(loaded, inMemory);
      chatStore.setMessages(merged);
      void savePersistedChatMessages(merged);
      userPinnedToTailRef.current = true;
      scrollTailAfterHubSendRef.current = true;
      setMessages(merged);
    };
    window.addEventListener(AGENT_HUB_SYNC_CHAT_EVENT, onExternalSync);
    return () => window.removeEventListener(AGENT_HUB_SYNC_CHAT_EVENT, onExternalSync);
  }, []);

  /** 非吸乳页自动结束后：进入智能体主页时若尚未执行「小结+BLE」，与通知点击路径共用 claim，只跑一次。 */
  useEffect(() => {
    if (location.pathname !== "/") return;
    void tryRunPumpAutoEndOffPumpTeardownOnce();
  }, [location.pathname]);

  const lastStreamingScrollAtRef = useRef(0);
  /** Hub 对话 ag-ui WebSocket 取消句柄 */
  const mainChatCancelRef = useRef<(() => void) | null>(null);
  /** 当前正在流式回复的 Mai 消息 id（用于区分“正在思考”与历史“已思考”展示） */
  const mainStreamingReplyIdRef = useRef<string | null>(null);
  const mainStreamMergedAnswerRef = useRef("");
  const mainStreamMergedThinkingRef = useRef("");
  /** rich_text 暂存，用于 onDone 自动播报快照 */
  const mainPendingRichTextRef = useRef<ChatRichTextPayload | null>(null);
  /** 对话泡 TTS：AbortController 与当前播放目标 id，避免快速切换气泡时误清状态 */
  const bubblePlayAbortRef = useRef<AbortController | null>(null);
  const bubblePlayingTargetIdRef = useRef<string | null>(null);
  const bottomActionRef = useRef<HTMLDivElement>(null);
  const hubStartPumpShortcutLockRef = useRef(false);
  /** 上传图片本地预览 blob URL 索引：便于删除气泡时 revoke；离开路由不要整表 revoke（同文档内 blob 仍有效） */
  const uploadedImagePreviewUrlsRef = useRef<Map<string, string>>(new Map());

  /**
   * 停止当前对话气泡语音播放并清理播放状态。
   * @param opts.clearPlayingId 是否重置 UI 播放高亮；默认 true
   * @returns Promise<void> 停止播放与状态清理完成
   */
  const stopCurrentBubblePlayback = useCallback(async (opts?: { clearPlayingId?: boolean }): Promise<void> => {
    bubblePlayAbortRef.current?.abort();
    await stopChatBubblePlayback();
    await stopFocusVoicePlayback();
    bubblePlayingTargetIdRef.current = null;
    bubblePlayAbortRef.current = null;
    if (opts?.clearPlayingId ?? true) {
      setPlayingId(null);
    }
  }, []);

  const handleCreateNewConversation = useCallback(() => {
    mainChatCancelRef.current?.();
    mainChatCancelRef.current = null;
    mainStreamingReplyIdRef.current = null;
    mainStreamMergedAnswerRef.current = "";
    mainStreamMergedThinkingRef.current = "";
    mainPendingRichTextRef.current = null;
    awaitingHubBottomReplyRef.current = false;
    pendingHistoryScrollRestoreRef.current = null;
    loadOlderCooldownRef.current = 0;
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
    getAgUiThreadIdForRequest();
    const greeting = createNewConversationGreetingMessage();
    chatStore.setMessages([greeting]);
    savePersistedChatMessages([greeting]);
    setMessages([greeting]);
    setInput("");
    setHubBottomSendBusy(false);
    setShowPhotoMenu(false);
    setShowScrollToBottom(false);
    setVisibleStartIndex(0);
    visibleStartIndexRef.current = 0;
    setDeviceFlowActive(false);
    setScheduleFlowActive(false);
    setLactationFlowActive(false);
    setMaternityFlowActive(false);
    setWorkFlowActive(false);
    setActiveIbclcConsult(null);
    setHubPumpGateDialog(null);
    toast.success("已新建会话");
  }, [stopCurrentBubblePlayback, stopSpeech]);

  /**
   * 自动播报（流式回复等）：HTMLAudio TTS，不修改气泡正文；通过 playingId 驱动扬声器动态态。
   * @param replyId 当前 Mai 回复气泡 id
   * @param msgForTts 已定稿或 onDone 快照，用于 buildSpeakableTextForTts
   * @returns void（内部异步播放）
   */
  const runHubDecoupledAutoVoice = useCallback((replyId: string, msgForTts: ChatMessage) => {
    if (msgForTts.role !== "mai") return;
    if (!autoVoiceRef.current) return;
    const speakable = buildSpeakableTextForTts(msgForTts).trim();
    if (!speakable) return;

    void (async () => {
      await stopCurrentBubblePlayback();
      const ac = new AbortController();
      bubblePlayAbortRef.current = ac;
      bubblePlayingTargetIdRef.current = replyId;
      setPlayingId(replyId);
      try {
        await playFocusPlainTextTts({
          userId: DEFAULT_CHAT_USER_ID,
          text: speakable,
          signal: ac.signal,
          onSubtitle: () => {},
          syncSubtitle: false,
          firstSegmentMaxChars: HUB_AUTO_VOICE_FIRST_TTS_MAX_CHARS,
        });
      } catch (e: unknown) {
        const err = e as { name?: string; message?: string };
        if (err.name !== "AbortError") {
          toast.error(err.message || "自动语音播报失败");
        }
      } finally {
        if (bubblePlayingTargetIdRef.current === replyId) {
          setPlayingId(null);
          bubblePlayingTargetIdRef.current = null;
        }
        if (bubblePlayAbortRef.current === ac) {
          bubblePlayAbortRef.current = null;
        }
      }
    })();
  }, [stopCurrentBubblePlayback]);

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

  useEffect(() => {
    setVisibleStartIndex((s) => {
      if (messages.length === 0) return 0;
      const upper = Math.max(0, messages.length - HUB_CHAT_HISTORY_PAGE);
      return Math.min(Math.max(0, s), upper);
    });
  }, [messages.length]);

  useLayoutEffect(() => {
    const restore = pendingHistoryScrollRestoreRef.current;
    if (!restore) return;
    pendingHistoryScrollRestoreRef.current = null;
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTop = restore.prevTop + (el.scrollHeight - restore.prevH);
  }, [visibleStartIndex]);

  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el || messages.length === 0) return;
    const returnTo = `${location.pathname}${location.search}${location.hash}`;
    const ibclcReturnViewport = readStoredIbclcReturnViewport(returnTo);
    if (ibclcReturnViewport) {
      const restoreScrollTop = () => {
        const maxTop = Math.max(0, el.scrollHeight - el.clientHeight);
        el.scrollTop = Math.min(ibclcReturnViewport.scroll_top, maxTop);
        const isNearBottom = el.scrollHeight - (el.scrollTop + el.clientHeight) < 80;
        userPinnedToTailRef.current = isNearBottom;
        setShowScrollToBottom(!isNearBottom);
      };
      restoreScrollTop();
      window.requestAnimationFrame(() => window.requestAnimationFrame(restoreScrollTop));
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
    mainPendingRichTextRef.current = null;
    mainChatCancelRef.current = null;
    mainStreamingReplyIdRef.current = null;
    setMessages((prev) => {
      const next = prev.map((m) => {
        if (m.id !== replyId) return m;
        const mergedFull = mainStreamMergedAnswerRef.current;
        const synced =
          typeof mergedFull === "string" && mergedFull.length > m.content.length
            ? { ...m, content: mergedFull }
            : m;
        const hasRenderableStream = (synced.streamRenderItems?.length ?? 0) > 0;
        if (!synced.content.trim() && !synced.richText && !hasRenderableStream) {
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
      mainChatCancelRef.current?.();
      void stopCurrentBubblePlayback();
      // 暂存图 blob URL 保留到用户删除图、发送并成功附带、或整页卸载，避免路由切换后主界面预览丢失
    },
    [stopCurrentBubblePlayback],
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
    msg.role === "user" && String(msg.cardData?.kind ?? "") === "uploaded-image";

  /** 重进主界面后 ref 可能为空，仍用 cardData 里的 blob URL 做 revoke */
  useLayoutEffect(() => {
    for (const m of messages) {
      if (!isUploadedImageBubble(m)) continue;
      const url = String(m.cardData?.previewUrl ?? "");
      if (url.startsWith("blob:")) uploadedImagePreviewUrlsRef.current.set(m.id, url);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 仅首帧用当前 messages 回填；避免随流式更新反复执行
  }, []);

  const handleDeleteUploadedImageBubble = useCallback((messageId: string) => {
    const target = messages.find((m) => m.id === messageId);
    const uploadFileId = String(target?.cardData?.uploadedFileId ?? "").trim();
    const fromRef = uploadedImagePreviewUrlsRef.current.get(messageId);
    const fromCard = String(target?.cardData?.previewUrl ?? "");
    const previewUrl =
      fromRef ?? (fromCard.startsWith("blob:") ? fromCard : "");
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
      uploadedImagePreviewUrlsRef.current.delete(messageId);
    }
    setMessages((prev) => prev.filter((m) => m.id !== messageId));
    if (uploadFileId) log("[AG_UI_IMAGE] 从暂存图移除 legacy upload_file_id", { uploadFileId });
  }, [messages]);

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
    if (typeof rec.type === "string" && rec.type.trim()) return rec.type.trim().toUpperCase();
    if (typeof rec.event === "string" && rec.event.trim()) return rec.event.trim().toLowerCase();
    return "";
  };

  const appendTextRenderItem = (items: ChatStreamRenderItem[] | undefined, text: string): ChatStreamRenderItem[] => {
    if (!text) return items ?? [];
    const list = [...(items ?? [])];
    const last = list.at(-1);
    if (last?.kind === "text") {
      list[list.length - 1] = { kind: "text", text: last.text + text };
      return list;
    }
    list.push({ kind: "text", text });
    return list;
  };

  const appendRichRenderItem = (
    items: ChatStreamRenderItem[] | undefined,
    payload: ChatRichTextPayload,
  ): ChatStreamRenderItem[] => {
    const list = [...(items ?? [])];
    const last = list.at(-1);
    if (last?.kind === "rich") {
      list[list.length - 1] = { kind: "rich", payload: mergePendingRichTextPayload(last.payload, payload) };
      return list;
    }
    list.push({ kind: "rich", payload });
    return list;
  };

  const extractMainAnswerChunk = (data: string | object): string => {
    const tag = resolveEventTag(data);
    // ag-ui 仅 TEXT_MESSAGE_CONTENT 可视作正文增量，避免误吃 TOOL_CALL_ARGS.delta
    if (tag) {
      if (tag === "reasoning" || tag === "message") return extractChatAnswerChunk(data);
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
    const value = data.value && typeof data.value === "object" ? (data.value as Record<string, unknown>) : null;
    const status = String(value?.status ?? "").toLowerCase();
    if (!status) return true;
    const metadata =
      value?.metadata && typeof value.metadata === "object"
        ? (value.metadata as Record<string, unknown>)
        : null;
    const thinkingText =
      metadata?.after_output_text === true ? "正在准备下一步" : "正在思考";
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
      if (m.role !== "user" || String(m.cardData?.kind ?? "") !== "uploaded-image") return false;
      return String(m.cardData?.uploadStatus ?? "") === "ready";
    });

  const fileToDataUrl = (file: File | Blob): Promise<string> =>
    new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result ?? ""));
      reader.onerror = () => reject(reader.error ?? new Error("read image failed"));
      reader.readAsDataURL(file);
    });

  const clientMessageSentAt = (date = new Date()): string => {
    const pad = (value: number, length = 2) => String(Math.trunc(Math.abs(value))).padStart(length, "0");
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

  const buildAgUiForwardedProps = (locale: string): Record<string, unknown> => {
    const timezone =
      (typeof Intl !== "undefined" && Intl.DateTimeFormat().resolvedOptions().timeZone) ||
      "America/Los_Angeles";
    return {
      user_id: DEFAULT_CHAT_USER_ID,
      locale,
      timezone,
      message_sent_at: clientMessageSentAt(),
      user_profile: {
        user_id: DEFAULT_CHAT_USER_ID,
        language: locale,
      },
    };
  };

  const resolveAgUiImagePayload = async (msgs: ChatMessage[]): Promise<AgUiPayloadImageItem[]> => {
    const list = collectAgUiReadyImages(msgs);
    const payload: AgUiPayloadImageItem[] = [];
    for (const m of list) {
      const preview = String(m.cardData?.previewUrl ?? "").trim();
      if (!preview) continue;
      try {
        if (!preview.startsWith("blob:") && !preview.startsWith("data:image/")) continue;
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
        warn("[AgentHub] 图片转 data-url 失败，已跳过该图片", e instanceof Error ? e.message : String(e));
      }
    }
    return payload;
  };

  const buildSentImagePreviews = async (images: AgUiPayloadImageItem[]): Promise<SentChatImagePreview[]> => {
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
        warn("[AgentHub] 图片气泡缩略图生成失败，使用原图展示", e instanceof Error ? e.message : String(e));
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
   * ag-ui WebSocket 流：按协议合并正文并立刻写入对话泡。
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
      const side = applyAgUiStreamSideEffects(replyId, data, setMessages, {
        pendingRichTextRef,
      });
      const eventType = resolveEventTag(data);
      const rich = parseChatRichTextFromSseData(data);
      if (rich) {
        setMessages((prev) =>
          prev.map((m) =>
            m.id === replyId
              ? {
                  ...m,
                  richText: m.richText ? mergePendingRichTextPayload(m.richText, rich) : rich,
                  streamRenderItems: appendRichRenderItem(m.streamRenderItems, rich),
                }
              : m,
          ),
        );
      }
      if (eventType === "CUSTOM" && typeof data === "object" && data != null) {
        if (applyThinkingStatusFromCustomEvent(replyId, data as Record<string, unknown>, mergedThinkingRef)) return;
      }
      const chunk = extractMainAnswerChunk(data);
      if (eventType === "reasoning") {
        if (!chunk) return;
        const mergedThinking = mergeStreamingAnswer(mergedThinkingRef.current, chunk);
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

      let merged = mergedAnswerRef.current;
      let delta = "";
      if (chunk) {
        const nextAnswer = mergeStreamingAnswerDelta(merged, chunk);
        merged = nextAnswer.merged;
        delta = nextAnswer.delta;
        mergedAnswerRef.current = merged;
      }

      setMessages((prev) =>
        prev.map((m) => {
          if (m.id !== replyId) return m;
          let next: ChatMessage = { ...m, content: merged };
          if (
            (eventType === "message" || eventType === "TEXT_MESSAGE_CONTENT" || eventType === "TEXT_MESSAGE_END") &&
            (next.thinkingContent?.trim() ?? "")
          ) {
            next = { ...next, thinkingCollapsed: true, thinkingStatus: "done" };
          }
          if (delta) {
            next = {
              ...next,
              streamRenderItems: appendTextRenderItem(next.streamRenderItems, delta),
            };
          }
          return next;
        }),
      );
    };
  };

  const toggleThinkingCollapsed = (messageId: string) => {
    setMessages((prev) =>
      prev.map((m) =>
        m.id === messageId ? { ...m, thinkingCollapsed: !(m.thinkingCollapsed ?? false) } : m,
      ),
    );
  };

  const resolveThinkingStatusText = (msg: ChatMessage): string => {
    if (msg.thinkingStatus === "done") return "已思考";
    const isStreamingThisMessage =
      mainStreamingReplyIdRef.current === msg.id && mainChatCancelRef.current != null;
    return isStreamingThisMessage ? "正在思考" : "已思考";
  };

  /** 发起 Hub ag-ui WebSocket 对话流（主接口，含富文本解析）。 */
  const startMainChatStream = async (
    query: string,
    opts?: { showUserMessage?: boolean; purgeStagedImagesAfterAttach?: boolean; userDisplayText?: string },
  ) => {
    const showUserMessage = opts?.showUserMessage ?? true;
    const replyTs = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
    const workTimerStartMs = Date.now();
    const stagedImageMessages = collectAgUiReadyImages(messages);
    const agUiImages = await resolveAgUiImagePayload(stagedImageMessages);
    const sentImagePreviews = showUserMessage ? await buildSentImagePreviews(agUiImages) : [];
    const userVisibleText = opts?.userDisplayText !== undefined ? opts.userDisplayText.trim() : query;
    const userMsg: ChatMessage = {
      id: `u${Date.now()}`,
      role: "user",
      content: userVisibleText,
      timestamp: replyTs,
      cardData: sentImagePreviews.length > 0 ? { sentImages: sentImagePreviews } : undefined,
    };
    const replyId = `m${Date.now()}`;
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
    setMessages((prev) => [...prev, ...(showUserMessage ? [userMsg] : []), replyPlaceholder]);
    if (opts?.purgeStagedImagesAfterAttach) purgeHubStagedUploadedImages();
    mainPendingRichTextRef.current = null;
    mainChatCancelRef.current?.();
    mainStreamingReplyIdRef.current = null;
    void stopCurrentBubblePlayback();
    mainStreamMergedAnswerRef.current = "";
    mainStreamMergedThinkingRef.current = "";
    mainStreamingReplyIdRef.current = replyId;
    const onMessageHandler = handleLiveMainStreamMessage(
      replyId,
      mainStreamMergedAnswerRef,
      mainStreamMergedThinkingRef,
      mainPendingRichTextRef,
    );
    const onDoneHandler = () => {
        setMessages((prev) =>
          prev.map((m) =>
            m.id === replyId && (m.thinkingContent?.trim() ?? "")
              ? { ...m, thinkingCollapsed: true, thinkingStatus: "done" }
              : m,
          ),
        );
        const mergedSnap = mainStreamMergedAnswerRef.current;
        const richSnap = mainPendingRichTextRef.current;
        window.setTimeout(() => {
          tryFinalizeMainReply(replyId);
          mainStreamingReplyIdRef.current = null;
          if (autoVoiceRef.current) {
            const dummy: ChatMessage = {
              id: replyId,
              role: "mai",
              content: mergedSnap,
              timestamp: "",
              richText: richSnap ?? undefined,
            };
            if (buildSpeakableTextForTts(dummy).trim()) {
              void runHubDecoupledAutoVoice(replyId, dummy);
            }
          }
        }, 0);
      };
    const onErrorHandler = (err: Error) => {
        void stopCurrentBubblePlayback();
        mainPendingRichTextRef.current = null;
        mainStreamMergedAnswerRef.current = "";
        mainStreamMergedThinkingRef.current = "";
        mainChatCancelRef.current = null;
        mainStreamingReplyIdRef.current = null;
        log("[CHAT_MESSAGE] 主对话错误", err?.message ?? err);
        const msg = err?.message ?? String(err);
        const isNetworkError = /failed to fetch|networkerror|load failed/i.test(msg) || msg === "Failed to fetch";
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
    const agUiLocale = (typeof navigator !== "undefined" && navigator.language) || "zh-CN";
    mainChatCancelRef.current = postAgUiWebSocketStream({
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

  const handleStartPumpShortcut = useCallback(async () => {
    if (hubStartPumpShortcutLockRef.current) return;
    hubStartPumpShortcutLockRef.current = true;
    setHubStartPumpBusy(true);
    try {
      const cal = await resolveCalibrationComfortForPumpStart(DEFAULT_CHAT_USER_ID);
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
        left: { connected: leftOk, deviceId: snap.L?.deviceId ?? null, deviceName: snap.L?.deviceName ?? null },
        right: { connected: rightOk, deviceId: snap.R?.deviceId ?? null, deviceName: snap.R?.deviceName ?? null },
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
   * 消息内设备类 link（open-unbox / open-measure / open-identify）：开箱与法兰/硅胶塞调整仅发对话 SSE，识别仍走内联流程。
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
      return;
    }
    const flowMsg: ChatMessage = {
      id: `df-${Date.now()}`,
      role: "mai",
      content: "",
      timestamp: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
      cardType: "device-flow",
      cardData: { flowType },
    };
    setMessages((prev) => [...prev, flowMsg]);
    setDeviceFlowActive(true);
  };

  const appendScheduleFlowFromLink = (actionKey: string): ChatMessage => {
    const initialAction = SCHEDULE_LINK_ACTION_MAP[actionKey] || undefined;
    return {
      id: `sf-${Date.now()}`,
      role: "mai",
      content: "",
      timestamp: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
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
      timestamp: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
      cardType: "lactation-flow",
      cardData: { initialAction },
    };
  };
  
  /** IBCLC 咨询在 Hub 内打开全屏覆盖层，避免跳出后丢失原对话位置。 */
  const handleOpenIbclcConsult = useCallback((request: IbclcConsultOpenRequest) => {
    setActiveIbclcConsult({
      conversationId: request.threadId || getAgUiThreadIdForRequest(),
      consultId: request.consultId,
    });
  }, []);

  useEffect(() => {
    const openHospitalBagCart = (event: Event) => {
      event.preventDefault();
      setActiveHospitalBagCart(true);
    };
    window.addEventListener("momcozy-open-hospital-bag-cart", openHospitalBagCart);
    return () => window.removeEventListener("momcozy-open-hospital-bag-cart", openHospitalBagCart);
  }, []);

  /** 吸乳报告与普通气泡底部的业务链接（日程 / 泌乳 / 设备 / 路由） */
  const handleBubbleLinkPress = (link: ChatMessageLink) => {
    const userMsg: ChatMessage = {
      id: `u${Date.now()}`,
      role: "user",
      content: link.label.replace(/→$/, "").trim(),
      timestamp: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
    };
    setMessages((prev) => [...prev, userMsg]);
    if (link.action) {
      if (link.action === "open-schedule" || link.action.startsWith("schedule-")) {
        setMessages((prev) => [...prev, appendScheduleFlowFromLink(link.action)]);
        setScheduleFlowActive(true);
      } else if (link.action.startsWith("lactation-")) {
        setMessages((prev) => [...prev, appendLactationFlowFromLink(link.action)]);
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
    chatStore.setMessages(durableMessages);
    savePersistedChatMessages(durableMessages);
    const container = scrollRef.current;
    if (!container) return;

    const prevMeta = lastMessageMetaRef.current;
    const nextLastId = messages.at(-1)?.id ?? null;
    const isNewBubble = messages.length !== prevMeta.len || nextLastId !== prevMeta.lastId;

    if (isNewBubble) {
      if (scrollTailAfterHubSendRef.current) {
        scrollTailAfterHubSendRef.current = false;
        userPinnedToTailRef.current = true;
        setShowScrollToBottom(false);
      }
      if (userPinnedToTailRef.current) {
        const el = container;
        const scrollToEnd = () => el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
        window.requestAnimationFrame(() => window.requestAnimationFrame(scrollToEnd));
      }
    } else {
      const now = Date.now();
      const isNearBottom =
        container.scrollHeight - (container.scrollTop + container.clientHeight) < 80;
      if (isNearBottom && now - lastStreamingScrollAtRef.current > 120) {
        container.scrollTo({ top: container.scrollHeight, behavior: "auto" });
        lastStreamingScrollAtRef.current = now;
      }
    }

    lastMessageMetaRef.current = { len: messages.length, lastId: nextLastId };
  }, [messages]);

  // 回到 Hub 时尚有未结束的设备向导：扫一遍持久化消息，收敛滴定卡与设备卡状态并解锁
  useEffect(() => {
    if (!deviceFlowActive) return;
    
    // 检查是否有未完成的滴定
    const calibrationInProgress = localStorage.getItem('calibrationInProgress');
    
    const source = chatStore.get().messages;
    const refreshed = source.map((m) => {
      // 对于calibration类型，如果滴定未完成（有calibrationInProgress标志），则不标记为completed
      if (m.cardType === "calibration" && !m.cardData?.completed) {
        if (calibrationInProgress === 'true') {
          // 滴定未完成，保留未完成状态
          return m;
        }
        // 滴定已完成，标记为completed
        return { ...m, cardData: { ...m.cardData, completed: true } };
      }
      // 对于device-flow类型，直接标记为completed
      if (m.cardType === "device-flow" && !m.cardData?.completed) {
        return { ...m, cardData: { ...m.cardData, completed: true } };
      }
      return m;
    });
    chatStore.setMessages(refreshed);
    setMessages(refreshed);
    setDeviceFlowActive(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 仅在挂载时读取「恢复会话后的」deviceFlowActive，不重跑后续状态变化
  }, []);

  useEffect(() => {
    const notice = localStorage.getItem(CALIBRATION_HUB_NOTICE_KEY);
    if (!notice) return;
    localStorage.removeItem(CALIBRATION_HUB_NOTICE_KEY);
    const ts = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
    const tipMsg: ChatMessage = {
      id: `calibration-hub-tip-${Date.now()}`,
      role: "mai",
      content: notice === "completed"
        ? "舒适负压滴定已完成，您可以直接开始吸乳。"
        : "检测到上次舒适负压滴定未完成，可点击“力度滴定”继续。",
      timestamp: ts,
    };
    setMessages((prev) => [...prev, tipMsg]);
  }, []);

  useEffect(() => {
    const appendLegacySummary = (body: string, id?: string) => {
      const appendedId = appendAgentHubAnalysisMessage(body, { kind: "daily_summary", id });
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
      const detail = (e as CustomEvent<{ body?: string; chatMessageId?: string }>).detail;
      const d = detail?.body;
      if (typeof d === "string" && d.trim()) appendLegacySummary(d, detail?.chatMessageId);
    };
    window.addEventListener("mmc-native-daily-summary", onEvt);
    return () => window.removeEventListener("mmc-native-daily-summary", onEvt);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 兼容旧版原生每日奶量总结桥接：仍统一写入 Hub 持久化消息
  }, []);

  useEffect(() => {
    return chatBus.subscribe((msg) => {
      setMessages((prev) => [...prev, msg]);

      // Auto-trigger lactation assessment flow when chat pushes a lactation-flow card
      if (msg.cardData?.triggerFlow === "lactation" && msg.cardData?.initialAction) {
        const flowMsg: ChatMessage = {
          id: `lf-auto-${Date.now()}`,
          role: "mai",
          content: "",
          timestamp: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
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

  /**
   * 发送主输入框内容：先结束听写并丢弃转写异步收尾对输入框的写入，再清空并送出。
   */
  const handleSend = async () => {
    await stopSpeech({ discardSttResult: true });
    const pendingText = input.trim();
    const hasReadyStagedImages = collectAgUiReadyImages(messages).length > 0;

    if (hubBottomSendBusy) {
      awaitingHubBottomReplyRef.current = false;
      mainChatCancelRef.current?.();
      setHubBottomSendBusy(false);
      if (!pendingText && !hasReadyStagedImages) return;
    }

    if (!pendingText && !hasReadyStagedImages) return;
    const text = pendingText || "请看这张图片";

    // If a device flow is active, forward input to it first
    if (pendingText && deviceFlowActive && deviceFlowRef.current) {
      const consumed = deviceFlowRef.current.handleExternalInput(text);
      if (consumed) {
        setInput("");
        return;
      }
    }

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

    scrollTailAfterHubSendRef.current = true;
    userPinnedToTailRef.current = true;
    setShowScrollToBottom(false);

    awaitingHubBottomReplyRef.current = true;
    setHubBottomSendBusy(true);

    setInput("");
    void startMainChatStream(text, { purgeStagedImagesAfterAttach: true, userDisplayText: pendingText });
  };

  /** 暂存图片文件（拍照或本地选择）：ag-ui 发送时会把预览 blob 转成 data URL。 */
  const handlePhotoUpload = useCallback(async (file: File) => {
    const imageMessageId = `img-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
    const previewUrl = URL.createObjectURL(file);
    uploadedImagePreviewUrlsRef.current.set(imageMessageId, previewUrl);
    const ts = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
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
   * 点击气泡喇叭：与全局自动播报一致，分段拉流 TTS（首段先播、尾段并行请求后接播），HTMLAudio 播放；再次点击同一气泡则停止。
   * @param msg 当前消息
   */
  const handlePlayBubble = async (msg: ChatMessage) => {
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
      const speakable = buildSpeakableTextForTts(msg).trim().slice(0, CHAT_BUBBLE_TTS_MAX_CHARS);
      if (!speakable) {
        toast.error("暂无可播报的文字");
        return;
      }
      await playFocusPlainTextTts({
        userId: DEFAULT_CHAT_USER_ID,
        text: speakable,
        signal: ac.signal,
        onSubtitle: () => {},
        syncSubtitle: false,
        firstSegmentMaxChars: HUB_AUTO_VOICE_FIRST_TTS_MAX_CHARS,
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
  };

  const visibleMessages = messages
    .slice(visibleStartIndex)
    .filter((m) => !isUploadedImageBubble(m));

  /** 上传图仍保留在 messages 中（用于 files payload 与删除），仅在列表外以底部悬浮条展示 */
  const hubUploadedImages = messages.filter(isUploadedImageBubble);

  const chatViewportTop = `calc(var(--top-safe) + ${HUB_TOP_ACTION_HEIGHT_PX}px)`;
  const chatViewportBottom = `calc(${HUB_BOTTOM_NAV_HEIGHT} + env(safe-area-inset-bottom) + ${bottomActionHeightPx}px)`;
  const handleScrollToLatest = () => {
    const container = scrollRef.current;
    if (!container) return;
    userPinnedToTailRef.current = true;
    setShowScrollToBottom(false);
    container.scrollTo({ top: container.scrollHeight, behavior: "smooth" });
  };

  useEffect(() => {
    const container = scrollRef.current;
    if (!container) return;
    const compute = () => {
      const isNearBottom =
        container.scrollHeight - (container.scrollTop + container.clientHeight) < 80;
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
    const el = scrollRef.current;
    if (!el) return;

    let wheelTowardOlderAccum = 0;
    let touchPullAccum = 0;
    let lastTouchClientY: number | null = null;

    const resetAccumAwayFromTop = () => {
      if (el.scrollTop > HUB_CHAT_TOP_EPS + 24) {
        wheelTowardOlderAccum = 0;
        touchPullAccum = 0;
      }
    };

    const attemptLoadOlder = () => {
      if (visibleStartIndexRef.current <= 0) {
        wheelTowardOlderAccum = 0;
        touchPullAccum = 0;
        return false;
      }
      const now = Date.now();
      if (now - loadOlderCooldownRef.current < HUB_CHAT_LOAD_OLDER_COOLDOWN_MS) {
        return false;
      }
      loadOlderCooldownRef.current = now;
      wheelTowardOlderAccum = 0;
      touchPullAccum = 0;
      pendingHistoryScrollRestoreRef.current = {
        prevH: el.scrollHeight,
        prevTop: el.scrollTop,
      };
      setVisibleStartIndex((s) => Math.max(0, s - HUB_CHAT_HISTORY_PAGE));
      return true;
    };

    const onWheel = (e: WheelEvent) => {
      resetAccumAwayFromTop();
      if (visibleStartIndexRef.current <= 0 || el.scrollTop > HUB_CHAT_TOP_EPS) return;
      if (e.deltaY >= -0.5) return;
      wheelTowardOlderAccum += -e.deltaY;
      if (wheelTowardOlderAccum >= HUB_CHAT_WHEEL_OVERSCROLL_TO_LOAD && attemptLoadOlder()) {
        e.preventDefault();
      }
    };

    const onTouchStart = (e: TouchEvent) => {
      if (e.touches.length !== 1) {
        lastTouchClientY = null;
        return;
      }
      lastTouchClientY = e.touches[0].clientY;
      touchPullAccum = 0;
    };

    const onTouchMove = (e: TouchEvent) => {
      if (lastTouchClientY === null || e.touches.length !== 1) return;
      resetAccumAwayFromTop();
      if (visibleStartIndexRef.current <= 0) return;
      if (el.scrollTop > HUB_CHAT_TOP_EPS) {
        lastTouchClientY = e.touches[0].clientY;
        touchPullAccum = 0;
        return;
      }
      const y = e.touches[0].clientY;
      const dy = y - lastTouchClientY;
      lastTouchClientY = y;
      if (dy > 1) {
        touchPullAccum += dy;
        if (touchPullAccum >= HUB_CHAT_TOUCH_PULL_TO_LOAD && attemptLoadOlder()) {
          touchPullAccum = 0;
          e.preventDefault();
        }
      }
    };

    const onTouchEndReset = () => {
      lastTouchClientY = null;
      touchPullAccum = 0;
    };

    el.addEventListener("wheel", onWheel, { passive: false });
    el.addEventListener("touchstart", onTouchStart, { passive: true });
    el.addEventListener("touchmove", onTouchMove, { passive: false });
    el.addEventListener("touchend", onTouchEndReset, { passive: true });
    el.addEventListener("touchcancel", onTouchEndReset, { passive: true });

    return () => {
      el.removeEventListener("wheel", onWheel);
      el.removeEventListener("touchstart", onTouchStart);
      el.removeEventListener("touchmove", onTouchMove);
      el.removeEventListener("touchend", onTouchEndReset);
      el.removeEventListener("touchcancel", onTouchEndReset);
    };
  }, []);

  return (
    <div className="relative">
      <div
        className="fixed left-0 right-0 z-40"
        style={{
          top: "var(--top-safe)",
          height: HUB_TOP_ACTION_HEIGHT_PX,
        }}
      >
        <div className="mx-auto flex h-full max-w-lg items-center justify-end bg-background/90 px-3 backdrop-blur-md">
          <button
            type="button"
            onClick={handleCreateNewConversation}
            className="inline-flex h-9 items-center gap-1.5 rounded-full border border-border/70 bg-background px-3 text-[13px] font-medium text-foreground shadow-sm transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
            aria-label="新建会话"
            title="新建会话"
          >
            <Plus className="h-4 w-4" />
            <span>新建会话</span>
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

            <div ref={scrollRef} className="h-full overflow-y-auto px-3 pt-4 pb-6">

          {visibleMessages.map((msg, index) => {
            const isMainAssistantBubble = msg.role === "mai" && msg.chatStreamContext === "main";
            const bubbleShell = cn(
              "relative group w-full break-words",
              msg.role === "user"
                ? "rounded-2xl rounded-br-[5px] bg-[#176b87] text-white px-3 py-2.5 text-[15px] leading-[1.45] shadow-sm"
                : isMainAssistantBubble
                  ? "w-fit max-w-full min-h-0 rounded-none border-0 bg-transparent px-0.5 py-[3px] text-[15px] leading-[1.45] text-[#33404d] shadow-none"
                  : cn(
                      "rounded-2xl rounded-bl-md border bg-card px-3.5 py-2.5 text-[13px] leading-relaxed shadow-sm",
                      msg.cardType ? cardBg[msg.cardType] : "border-border",
                    ),
            );
            const segments = splitChatContentByDataDelimiter(msg.content);
            const multiBubble = segments.length > 1;
            const mdVariant: ChatMarkdownVariant = msg.role === "user" ? "user" : "assistant";
            const mdClassName = msg.role === "user" || isMainAssistantBubble ? "text-[15px] leading-[1.45]" : undefined;
            const orderedMainItems = isMainAssistantBubble ? (msg.streamRenderItems ?? []) : [];
            const hasOrderedMainItems = orderedMainItems.length > 0;
            const orderedMainHasRich = hasOrderedMainItems && orderedMainItems.some((item) => item.kind === "rich");
            const sentImagePreviews = msg.role === "user" ? extractSentChatImagePreviews(msg) : [];
            const hasSentImagePreviews = sentImagePreviews.length > 0;
            const previousMsg = index > 0 ? visibleMessages[index - 1] : undefined;
            const isConsecutiveAssistantMessage = msg.role === "mai" && previousMsg?.role === "mai";
            const messageSpacingClass = index === 0 ? "mt-0" : isConsecutiveAssistantMessage ? "mt-8" : "mt-2.5";

            return (
              <div key={msg.id} className={messageSpacingClass}>
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
                    initialAction={msg.cardData?.initialAction as string | undefined}
                    onComplete={() => {
                      setScheduleFlowActive(false);
                      const updated = chatStore.get().messages.map(m =>
                        m.id === msg.id ? { ...m, cardData: { ...m.cardData, completed: true } } : m
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
                    initialAction={msg.cardData?.initialAction as string | undefined}
                    assessContext={msg.cardData?.assessContext as { totalAvailable: number; feedP50: number; bfCount: number; bfTotalMin: number; babyName: string } | undefined}
                    onComplete={() => {
                      setLactationFlowActive(false);
                      const updated = chatStore.get().messages.map(m =>
                        m.id === msg.id ? { ...m, cardData: { ...m.cardData, completed: true } } : m
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
                      const updated = chatStore.get().messages.map(m =>
                        m.id === msg.id ? { ...m, cardData: { ...m.cardData, completed: true } } : m
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
                      const updated = chatStore.get().messages.map(m =>
                        m.id === msg.id ? { ...m, cardData: { ...m.cardData, completed: true } } : m
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
                      ✅ {msg.cardData.flowType === "unbox" ? "开箱指引已完成" : msg.cardData.flowType === "measurement" ? "法兰/硅胶塞调整已完成" : msg.cardData.flowType === "maintenance" ? "设备保养已完成" : msg.cardData.flowType === "wearing-guide" ? "上身指引已完成" : "设备使用帮助已完成"}
                    </div>
                  </div>
                ) : msg.cardData?.flowType === "unbox" ? (
                  // 开箱指引已改为仅对话 SSE，历史里未完成的 unbox 卡片不再渲染 InlineDeviceFlow
                  <div className="flex gap-2 items-start">
                    <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed space-y-2">
                      <p>
                        开箱指引已改为<strong>对话模式</strong>，不再使用本步骤向导。请在下方点击「设备使用 → 开箱指引」或通过助手回复获取指引。
                      </p>
                      <button
                        type="button"
                        className="text-[11px] font-semibold text-primary"
                        onClick={() => {
                          setDeviceFlowActive(false);
                          const updated = chatStore.get().messages.map((m) =>
                            m.id === msg.id ? { ...m, cardData: { ...m.cardData, completed: true } } : m,
                          );
                          chatStore.setMessages(updated);
                          setMessages(updated);
                        }}
                      >
                        知道了
                      </button>
                    </div>
                  </div>
                ) : (
                  <InlineDeviceFlow
                    ref={deviceFlowRef}
                    flowType={msg.cardData?.flowType as "unbox" | "measurement" | "photo-identify" | "maintenance"}
                    onComplete={() => {
                      setDeviceFlowActive(false);
                      const updated = chatStore.get().messages.map(m =>
                        m.id === msg.id ? { ...m, cardData: { ...m.cardData, completed: true } } : m
                      );
                      chatStore.setMessages(updated);
                      setMessages(updated);
                    }}
                  />
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
                msg.role === "user" ? "justify-end" : "justify-start"
              )}
            >
              <div className={cn("flex flex-col gap-1.5", msg.role === "user" ? "max-w-[82%]" : "max-w-[92%]")}>
                {msg.cardType === "report" && msg.cardData ? (
                  <AgentHubReportCard
                    msg={msg}
                    onLinkPress={handleBubbleLinkPress}
                  />
                ) : multiBubble ? (
                  <>
                    <AgentHubAgUiDecor msg={msg} />
                    {msg.role === "mai" && (msg.thinkingContent?.trim() ?? "") ? (
                      <div className={bubbleShell}>
                        <div className="rounded-xl border border-border/50 bg-muted/30 px-2.5 py-2">
                          <button
                            type="button"
                            className="inline-flex items-center gap-1 text-[11px] text-muted-foreground/80 hover:text-muted-foreground transition-colors"
                            onClick={() => toggleThinkingCollapsed(msg.id)}
                          >
                            {msg.thinkingCollapsed ? <ChevronRight className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
                            <span>{resolveThinkingStatusText(msg)}</span>
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
                        {orderedMainItems.map((item, i) => (
                          <div key={`${msg.id}-stream-${i}`} className={bubbleShell}>
                            {item.kind === "text" ? (
                              <ChatMarkdown markdown={item.text} variant={mdVariant} className={mdClassName} />
                            ) : (
                              <AgentHubRichTextBlock
                                payload={item.payload}
                                blockId={`${msg.id}-stream-${i}`}
                                onButtonSelect={(value, options?) => {
                                  void startMainChatStream(value, { userDisplayText: options?.displayText });
                                }}
                                onOpenIbclcConsult={handleOpenIbclcConsult}
                              />
                            )}
                          </div>
                        ))}
                        {msg.richText && !orderedMainHasRich ? (
                          <div className={bubbleShell}>
                            <AgentHubRichTextBlock
                              payload={msg.richText}
                              blockId={`${msg.id}-rich`}
                              onButtonSelect={(value, options?) => {
                                void startMainChatStream(value, { userDisplayText: options?.displayText });
                              }}
                              onOpenIbclcConsult={handleOpenIbclcConsult}
                            />
                          </div>
                        ) : null}
                      </>
                    ) : (
                      <>
                        {msg.richText?.card?.some((card) => card.type.trim() === "吸奶结束") ? (
                          <div className={bubbleShell}>
                            <AgentHubRichTextBlock
                              payload={msg.richText}
                              blockId={`${msg.id}-rich-pump-summary`}
                              onButtonSelect={(value, options?) => {
                                void startMainChatStream(value, { userDisplayText: options?.displayText });
                              }}
                              onOpenIbclcConsult={handleOpenIbclcConsult}
                            />
                          </div>
                        ) : null}
                        {segments.map((seg, i) => (
                          <div key={i} className={bubbleShell}>
                            {i === 0 && hasSentImagePreviews ? (
                              <div className={cn(seg.trim() && "mb-2")}>
                                <AgentHubSentImages images={sentImagePreviews} />
                              </div>
                            ) : null}
                            <ChatMarkdown markdown={seg} variant={mdVariant} className={mdClassName} />
                          </div>
                        ))}
                        {msg.richText && !msg.richText?.card?.some((card) => card.type.trim() === "吸奶结束") ? (
                          <div className={bubbleShell}>
                            <AgentHubRichTextBlock
                              payload={msg.richText}
                              blockId={`${msg.id}-rich`}
                              onButtonSelect={(value, options?) => {
                                void startMainChatStream(value, { userDisplayText: options?.displayText });
                              }}
                              onOpenIbclcConsult={handleOpenIbclcConsult}
                            />
                          </div>
                        ) : null}
                      </>
                    )}
                    {((msg.links?.length ?? 0) > 0 || (msg.role === "mai" && !isMainAssistantBubble)) ? (
                    <div className={bubbleShell}>
                      {msg.links && msg.links.length > 0 && (
                        <div className="flex flex-wrap justify-end gap-x-3 gap-y-1">
                          {msg.links.map((link, i) => (
                            <button
                              key={i}
                              onClick={() => handleBubbleLinkPress(link)}
                              className="text-[11px] font-semibold text-primary hover:text-primary/80 transition-colors"
                            >
                              {link.label}
                            </button>
                          ))}
                        </div>
                      )}
                      {msg.role === "mai" && !isMainAssistantBubble ? (
                        <div className="flex items-center justify-between mt-1.5 gap-2">
                          <span className="text-[10px] text-muted-foreground">{msg.timestamp}</span>
                          <button
                            type="button"
                            onClick={() => handlePlayBubble(msg)}
                            className={bubbleSpeakerButtonClassName(playingId === msg.id, false)}
                            title={playingId === msg.id ? "点击停止播报" : "播报此条消息"}
                          >
                            <Volume2
                              className={cn(
                                "w-3.5 h-3.5",
                                playingId === msg.id && "animate-mai-speaker-play",
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
                    <div className={bubbleShell}>
                    {msg.role === "mai" && (msg.thinkingContent?.trim() ?? "") ? (
                      <div className={cn("mb-2 rounded-xl border border-border/50 bg-muted/30 px-2.5 py-2")}>
                        <button
                          type="button"
                            className="inline-flex items-center gap-1 text-[11px] text-muted-foreground/80 hover:text-muted-foreground transition-colors"
                          onClick={() => toggleThinkingCollapsed(msg.id)}
                        >
                            {msg.thinkingCollapsed ? <ChevronRight className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
                            <span>{resolveThinkingStatusText(msg)}</span>
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
                        {orderedMainItems.map((item, i) => (
                          <div key={`${msg.id}-ordered-${i}`} className={cn(i > 0 && "mt-2")}>
                            {item.kind === "text" ? (
                              <ChatMarkdown markdown={item.text} variant={mdVariant} className={mdClassName} />
                            ) : (
                              <AgentHubRichTextBlock
                                payload={item.payload}
                                blockId={`${msg.id}-ordered-${i}`}
                                onButtonSelect={(value, options?) => {
                                  void startMainChatStream(value, { userDisplayText: options?.displayText });
                                }}
                                onOpenIbclcConsult={handleOpenIbclcConsult}
                              />
                            )}
                          </div>
                        ))}
                        {msg.richText && !orderedMainHasRich ? (
                          <div className={cn(orderedMainItems.length > 0 && "mt-2")}>
                            <AgentHubRichTextBlock
                              payload={msg.richText}
                              blockId={`${msg.id}-rich`}
                              onButtonSelect={(value, options?) => {
                                void startMainChatStream(value, { userDisplayText: options?.displayText });
                              }}
                              onOpenIbclcConsult={handleOpenIbclcConsult}
                            />
                          </div>
                        ) : null}
                      </>
                    ) : (
                      <>
                        {/* 兼容历史消息：无顺序片段时沿用旧渲染 */}
                        {msg.richText?.card?.some((card) => card.type.trim() === "吸奶结束") && msg.richText ? (
                          <div className={cn(msg.content.trim() && "mb-2")}>
                            <AgentHubRichTextBlock
                              payload={msg.richText}
                              blockId={`${msg.id}-rich-pump-summary`}
                              onButtonSelect={(value, options?) => {
                                void startMainChatStream(value, { userDisplayText: options?.displayText });
                              }}
                              onOpenIbclcConsult={handleOpenIbclcConsult}
                            />
                          </div>
                        ) : null}
                        {hasSentImagePreviews ? (
                          <div className={cn(msg.content.trim() && "mb-2")}>
                            <AgentHubSentImages images={sentImagePreviews} />
                          </div>
                        ) : null}
                        {msg.content.trim() ? (
                          <ChatMarkdown markdown={msg.content} variant={mdVariant} className={mdClassName} />
                        ) : null}
                        {msg.richText && !msg.richText?.card?.some((card) => card.type.trim() === "吸奶结束") ? (
                          <div className={cn(msg.content.trim() && "mt-2")}>
                            <AgentHubRichTextBlock
                              payload={msg.richText}
                              blockId={`${msg.id}-rich`}
                              onButtonSelect={(value, options?) => {
                                void startMainChatStream(value, { userDisplayText: options?.displayText });
                              }}
                              onOpenIbclcConsult={handleOpenIbclcConsult}
                            />
                          </div>
                        ) : null}
                        {!msg.content.trim() && !msg.richText ? (
                          <ChatMarkdown markdown={msg.content} variant={mdVariant} className={mdClassName} />
                        ) : null}
                      </>
                    )}
                    {msg.links && msg.links.length > 0 && (
                      <div className="flex flex-wrap justify-end gap-x-3 gap-y-1 mt-2">
                        {msg.links.map((link, i) => (
                          <button
                            key={i}
                            onClick={() => handleBubbleLinkPress(link)}
                            className="text-[11px] font-semibold text-primary hover:text-primary/80 transition-colors"
                          >
                            {link.label}
                          </button>
                        ))}
                      </div>
                    )}
                    {msg.role === "mai" && !isMainAssistantBubble ? (
                      <div className="flex items-center justify-between mt-1.5 gap-2">
                        <span className="text-[10px] text-muted-foreground">{msg.timestamp}</span>
                        <button
                          type="button"
                          onClick={() => handlePlayBubble(msg)}
                          className={bubbleSpeakerButtonClassName(playingId === msg.id, false)}
                          title={playingId === msg.id ? "点击停止播报" : "播报此条消息"}
                        >
                          <Volume2
                            className={cn(
                              "w-3.5 h-3.5",
                              playingId === msg.id && "animate-mai-speaker-play",
                            )}
                          />
                        </button>
                      </div>
                    ) : null}
                    </div>
                  </>
                )}
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
            onClose={() => setActiveIbclcConsult(null)}
          />
        </div>
      ) : null}

      {activeHospitalBagCart ? (
        <div className="fixed inset-0 z-[92] bg-[#fff9fb] sm:bg-black/20">
          <HospitalBagCart onClose={() => setActiveHospitalBagCart(false)} />
        </div>
      ) : null}

      {/* Bottom input/action page: fixed layer independent from chat scroll */}
      <div
        className="fixed left-0 right-0 z-30"
        style={{ bottom: `calc(${HUB_BOTTOM_NAV_HEIGHT} + env(safe-area-inset-bottom) + ${HUB_BOTTOM_INPUT_GAP})` }}
      >
        <div ref={bottomActionRef} className="max-w-lg mx-auto bg-background border-t border-border/50">
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
            onVoice={() => void onMicClick()}
            speechListening={speechListening}
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
            <AlertDialogCancel type="button" className="m-0 rounded-full border-border/80 bg-background">
              稍后再说
            </AlertDialogCancel>
            <AlertDialogAction
              type="button"
              className="m-0 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 focus-visible:ring-ring"
              onClick={(event) => {
                if (!hubPumpGateDialog) return;
                const action = resolveCalibrationPromptConfirmAction(hubPumpGateDialog, deviceStore.get());
                if (action.type === "showDevicePrompt") {
                  event.preventDefault();
                  setHubPumpGateDialog("device");
                  return;
                }
                setHubPumpGateDialog(null);
                navigate(action.route);
              }}
            >
              {hubPumpGateDialog === "calibration" ? "去力度调节" : "去连接设备"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default AgentHub;
