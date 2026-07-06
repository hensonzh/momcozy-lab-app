/**
 * Hub 对话消息类型（与后端 ChatMessage 展示结构对应，非 mock 专用）。
 */
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";

/** ag-ui 流式 TOOL_CALL 轨迹行（与 doc 2.5 工作面板一致） */
export interface AgUiToolCallRow {
  id: string;
  kind?: "tool" | "narration";
  name: string;
  /** 前端工作面板标题（优先于 name+state 自动拼接） */
  title?: string;
  /** narration 行展示正文 */
  content?: string;
  argsDigest: string;
  state: "running" | "completed" | "error";
  resultSummary?: string;
}

export interface ChatMessageLink {
  label: string;
  route?: string;
  action?: string; // e.g. "open-unbox", "open-measure", "open-identify"
}

export interface ChatQuickReply {
  text: string;
}

export interface ChatMessageCitation {
  index: number;
  title: string;
  url: string;
  displayText?: string;
}

export interface ChatStreamRenderItemText {
  kind: "text";
  text: string;
}

export interface ChatStreamRenderItemRich {
  kind: "rich";
  payload: ChatRichTextPayload;
}

export type ChatStreamRenderItem =
  | ChatStreamRenderItemText
  | ChatStreamRenderItemRich;

export interface ChatMessageImageAttachment {
  type: "image";
  previewUrl: string;
  fileName?: string;
  fileType?: string;
  fileSize?: number;
  uploadedFileId?: string;
}

export interface ChatMessage {
  id: string;
  role: "mai" | "user";
  content: string;
  timestamp: string;
  /** 展示语气：通知类消息用于更醒目的视觉与自动播报队列。 */
  messageTone?: "normal" | "notification";
  /** 通知类型，用于区分后台奶量分析、健康问题等来源。 */
  notificationKind?: "milk_analysis" | "health_issue";
  /** 消息被追加到对话后是否需要自动播报一次。 */
  autoVoiceOnAppend?: boolean;
  cardType?:
    | "report"
    | "data"
    | "tutorial"
    | "plan"
    | "encourage"
    | "calibration"
    | "device-flow"
    | "maternity-flow"
    | "work-flow";
  cardData?: Record<string, unknown>;
  attachments?: ChatMessageImageAttachment[];
  links?: ChatMessageLink[];
  /** chat-messages SSE 推送的富文本（event: rich_text） */
  richText?: ChatRichTextPayload;
  /** 主对话按到达先后顺序拼装的渲染片段（正文/富文本混排）。 */
  streamRenderItems?: ChatStreamRenderItem[];
  /** 当前条为 Agent 流式回复时，标记主对话、准妈妈/返工计划或设备指引流，供富文本按钮续聊 */
  chatStreamContext?: "main" | "care" | "work" | "device_instruct";
  /** event=reasoning 时的后端思考过程（流式合并后全文） */
  thinkingContent?: string;
  /** 正文（event=message）到来后默认收起，可手动展开 */
  thinkingCollapsed?: boolean;
  /** 思考状态：流式中或已完成（收到正文） */
  thinkingStatus?: "thinking" | "done";
  /** ag-ui：CUSTOM momcozy.agent.status 状态条 */
  agentStatusLine?: string;
  /** ag-ui：状态条是否已进入完成态（测试站完成态隐藏） */
  agentStatusDone?: boolean;
  /** ag-ui：TOOL_CALL_* 工作区轨迹 */
  agentToolCalls?: AgUiToolCallRow[];
  /** ag-ui：RUN_STARTED / ACTIVITY_SNAPSHOT 中的已加载技能 id */
  agentLoadedSkillIds?: string[];
  /** ag-ui：CUSTOM momcozy.agent.thinking 的临时 thinking 行标题 */
  agentThinkingTitle?: string;
  /** ag-ui work 面板开始时间（ms） */
  agentWorkStartedAtMs?: number;
  /** ag-ui work 面板结束时间（ms） */
  agentWorkFinishedAtMs?: number;
  /** ag-ui QUICK_REPLIES：仅最新一轮助手回复展示，点击后作为普通用户消息发送 */
  quickReplies?: ChatQuickReply[];
  /** Responses API web_search 引用来源，需在前端展示为可点击链接。 */
  citations?: ChatMessageCitation[];
}
