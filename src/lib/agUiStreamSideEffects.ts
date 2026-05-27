/**
 * ag-ui / Momcozy Agent 流式事件：与《web-api》2.3–2.5 对齐的非正文侧效（状态条、工具轨迹、RUN_STARTED 元信息等）。
 * 正文增量仍由 AgentHub 的 TEXT_MESSAGE_CONTENT 路径处理。
 */

import type { Dispatch, MutableRefObject, SetStateAction } from "react";
import type { AgUiToolCallRow, ChatMessage, ChatQuickReply } from "@/types/chat";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";
import type { HospitalBagCartGroup } from "@/pages/hospitalBagCartModel";

const STATUS_LABELS: Record<string, string> = {
  "Agent loop started.": "",
  "Evaluating user intent and safety context.": "正在判断需求。",
  "Requesting model response.": "正在思考。",
  "Requesting model response with tool outputs.": "",
  "Selecting an application tool.": "正在选择下一步。",
  "Executing an application tool.": "",
  "Selecting the next step.": "正在选择下一步。",
  "Loading relevant context.": "正在读取相关信息。",
  "Reading relevant information.": "正在读取相关信息。",
  "Running a processing step.": "",
  "Processing relevant information.": "正在整理相关信息。",
  "Step completed.": "当前步骤已完成。",
  "Step failed.": "这个步骤没有完成。",
  "Answer ready.": "回答已准备好。",
  "Run finished.": "已完成。",
};

const THINKING_STATUS_TEXTS = new Set(["Requesting model response.", "Thinking...", "Thinking", "正在思考。", "正在思考"]);

/** 与 AgentHub.resolveEventTag 一致：优先 `type`（大写），其次 `event`（小写） */
export function resolveAgUiEventType(data: string | object): string {
  if (typeof data !== "object" || data == null) return "";
  const rec = data as Record<string, unknown>;
  if (typeof rec.type === "string" && rec.type.trim()) return rec.type.trim().toUpperCase();
  if (typeof rec.event === "string" && rec.event.trim()) return rec.event.trim().toLowerCase();
  return "";
}

function coalesceString(v: unknown): string {
  if (typeof v === "string" && v.trim()) return v.trim();
  return "";
}

function readQuickReplies(value: unknown): ChatQuickReply[] {
  if (!Array.isArray(value) || value.length !== 3) return [];
  const replies: ChatQuickReply[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const rec = asRecord(item);
    const text = coalesceString(rec?.text);
    const sendText = coalesceString(rec?.send_text) || coalesceString(rec?.sendText) || text;
    if (!text || !sendText) return [];
    const key = sendText.toLocaleLowerCase();
    if (seen.has(key)) return [];
    seen.add(key);
    replies.push({ text, sendText });
  }
  return replies.length === 3 ? replies : [];
}

function normalizeToolName(toolName: unknown): string {
  const token = String(toolName ?? "").trim();
  if (!token) return "";
  const parts = token.split(".");
  return (parts[parts.length - 1] || "").replace(/^milk_management__/, "");
}

function labelForStatus(text: string): string {
  return Object.prototype.hasOwnProperty.call(STATUS_LABELS, text) ? STATUS_LABELS[text] : text;
}

function isThinkingStatusLine(text: string): boolean {
  const raw = coalesceString(text);
  if (!raw) return false;
  const normalized = labelForStatus(raw);
  return THINKING_STATUS_TEXTS.has(raw) || THINKING_STATUS_TEXTS.has(normalized);
}

function labelForStep(stepName: string, state: "started" | "finished"): string {
  if (stepName === "routing") {
    return state === "started" ? "正在判断需求。" : "需求判断完成。";
  }
  return state === "started" ? "正在处理当前步骤。" : "当前步骤已完成。";
}

/** CUSTOM：momcozy.agent.status → 单行状态文案 */
export function extractAgentStatusLineFromCustom(data: Record<string, unknown>): string | null {
  if (String(data.name ?? "") !== "momcozy.agent.status") return null;
  const value = data.value;
  if (typeof value === "string" && value.trim()) return value.trim();
  if (value && typeof value === "object") {
    const o = value as Record<string, unknown>;
    const from =
      coalesceString(o.label) ||
      coalesceString(o.text) ||
      coalesceString(o.message) ||
      coalesceString(o.status) ||
      coalesceString(o.phase);
    if (from) return from;
  }
  return null;
}

function readToolName(rec: Record<string, unknown>): string {
  const n =
    coalesceString(rec.tool_call_name) ||
    coalesceString(rec.toolName) ||
    coalesceString(rec.name);
  return normalizeToolName(n) || "tool";
}

function readToolCallKeys(rec: Record<string, unknown>): string[] {
  const keys: string[] = [];
  const responseId = coalesceString(rec.response_id) || coalesceString(rec.responseId);
  const outputIndex = rec.output_index ?? rec.outputIndex;
  if (responseId && outputIndex != null) keys.push(`tool:${responseId}:${String(outputIndex)}`);
  const toolCallId = coalesceString(rec.tool_call_id) || coalesceString(rec.toolCallId);
  if (toolCallId) keys.push(`tool:${toolCallId}`);
  const itemId = coalesceString(rec.item_id) || coalesceString(rec.itemId);
  if (itemId) keys.push(`tool:${itemId}`);
  return [...new Set(keys)];
}

function findToolRowIndex(
  tools: AgUiToolCallRow[],
  keys: string[],
  toolName?: string,
  onlyRunning = false,
): number {
  if (keys.length > 0) {
    const byKey = tools.findIndex((t) => keys.includes(t.id) && (!onlyRunning || t.state === "running"));
    if (byKey >= 0) return byKey;
  }
  if (toolName) {
    const normalized = normalizeToolName(toolName);
    const byName = tools.findIndex(
      (t) =>
        normalizeToolName(t.name) === normalized &&
        (!onlyRunning || t.state === "running"),
    );
    if (byName >= 0) return byName;
  }
  return -1;
}

function upsertToolRow(
  tools: AgUiToolCallRow[],
  keys: string[],
  patch: Partial<AgUiToolCallRow>,
  opts?: { mergeRunning?: boolean },
): AgUiToolCallRow[] {
  const normalizedPatchName = patch.name ? normalizeToolName(patch.name) : "";
  const idx = findToolRowIndex(tools, keys, normalizedPatchName || undefined, Boolean(opts?.mergeRunning));
  const canonicalId = keys[0] || patch.id || (normalizedPatchName ? `tool:${normalizedPatchName}` : "tool:unknown");
  if (idx < 0) {
    const toolName = normalizedPatchName || "tool";
    return [
      ...tools,
      {
        id: canonicalId,
        name: toolName,
        title: patch.title,
        argsDigest: patch.argsDigest ?? "",
        state: patch.state ?? "running",
        resultSummary: patch.resultSummary,
      },
    ];
  }
  const next = [...tools];
  const cur = next[idx];
  const nextName = patch.name !== undefined ? (normalizeToolName(patch.name) || "tool") : cur.name;
  next[idx] = {
    ...cur,
    id: keys.includes(cur.id) ? cur.id : canonicalId,
    ...patch,
    title: patch.title !== undefined ? patch.title : cur.title,
    argsDigest: patch.argsDigest !== undefined ? patch.argsDigest : cur.argsDigest,
    name: nextName,
  };
  return next;
}

function truncate(s: string, max: number): string {
  const t = s.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max)}…`;
}

function nowMs(): number {
  return Date.now();
}

function readProvisionalText(msg: ChatMessage): string {
  const fromContent = msg.content.trim();
  if (fromContent) return fromContent;
  const fromStream =
    msg.streamRenderItems
      ?.filter((item) => item.kind === "text")
      .map((item) => item.text)
      .join("")
      .trim() ?? "";
  return fromStream;
}

function moveProvisionalTextToWork(msg: ChatMessage): ChatMessage {
  const provisional = readProvisionalText(msg);
  if (!provisional) return msg;
  if ((msg.agentToolCalls ?? []).some((row) => row.kind === "narration" && (row.content ?? "").trim() === provisional)) {
    return {
      ...msg,
      content: "",
      streamRenderItems: (msg.streamRenderItems ?? []).filter((item) => item.kind !== "text"),
    };
  }
  const narration: AgUiToolCallRow = {
    id: `narration:${Date.now()}:${Math.random().toString(36).slice(2, 7)}`,
    kind: "narration",
    name: "narration",
    title: "",
    content: provisional,
    argsDigest: "",
    state: "completed",
  };
  return {
    ...msg,
    content: "",
    streamRenderItems: (msg.streamRenderItems ?? []).filter((item) => item.kind !== "text"),
    agentToolCalls: [...(msg.agentToolCalls ?? []), narration],
  };
}

/** TOOL_CALL_RESULT：content 为 JSON 字符串（文档 2.3） */
function parseToolResultPayload(content: unknown): Record<string, unknown> | null {
  if (content == null) return null;
  if (typeof content === "object" && !Array.isArray(content)) {
    return content as Record<string, unknown>;
  }
  if (typeof content === "string" && content.trim()) {
    try {
      const o = JSON.parse(content) as unknown;
      if (typeof o === "object" && o != null && !Array.isArray(o)) return o as Record<string, unknown>;
    } catch {
      return null;
    }
  }
  return null;
}

function summarizeToolResult(parsed: Record<string, unknown>): string {
  const ok = parsed.ok;
  const base = typeof ok === "boolean" ? (ok ? "已完成" : "没有完成") : "";
  const extraKeys = ["form", "card", "ticket", "skill_id", "message", "error"];
  for (const k of extraKeys) {
    const v = parsed[k];
    if (v != null) {
      const hint =
        typeof v === "string"
          ? truncate(v, 120)
          : truncate(JSON.stringify(v), 160);
      return [base || "结果", hint]
        .filter(Boolean)
        .join(" — ");
    }
  }
  return truncate(JSON.stringify(parsed), 200);
}

function milkMutationResultTitle(result: Record<string, unknown> | null, fallbackTitle: string): string {
  const status = coalesceString(result?.status);
  if (status.includes("deleted")) return "修改已删除";
  if (status.includes("updated") || status.includes("patched") || status.includes("shifted")) return "修改已保存";
  if (status.includes("created") || status.includes("applied")) return fallbackTitle;
  if (status.includes("idempotent_replay")) return "已复用已有修改";
  return fallbackTitle;
}

function milkTaskResultTitle(result: Record<string, unknown> | null): string {
  const status = coalesceString(result?.status);
  if (status === "milk_task_completed") return "任务已完成";
  if (status === "milk_task_completion_cancelled") return "修改已取消";
  if (status === "milk_task_skipped") return "任务已跳过";
  return "任务状态已保存";
}

function toolWorkPhase(toolName: string): "select" | "read" | "evaluate" | "prepare_result" | "preview" | "save" | "process" | "work" {
  const name = normalizeToolName(toolName);
  if (name === "tool_search" || name === "tool_search_call") return "select";
  if (
    [
      "load_skill",
      "list_skills",
      "read_skill_file",
      "search_skill_assets",
      "profile_get",
      "memory_search",
      "milk_snapshot_get",
      "milk_status_query",
      "milk_records_query",
      "milk_plan_query",
      "milk_calendar_query",
      "device_manual_search",
      "knowledge_search",
      "reminder_list",
    ].includes(name)
  ) {
    return "read";
  }
  if (["milk_assessment_evaluate", "infant_growth_evaluate", "risk_evaluate"].includes(name)) return "evaluate";
  if (["ui_form_create", "ui_card_create", "ibclc_consult_card_create", "support_ticket_draft_create"].includes(name)) {
    return "prepare_result";
  }
  if (["milk_plan_preview", "milk_calendar_change_preview"].includes(name)) return "preview";
  if (
    [
      "milk_record_mutate",
      "milk_plan_mutate",
      "milk_calendar_mutate",
      "milk_task_complete",
      "infant_growth_mutate",
      "hospital_bag_cart_update",
      "reminder_create",
      "reminder_update",
      "reminder_delete",
    ].includes(name)
  ) {
    return "save";
  }
  if (name === "run_approved_skill_script") return "process";
  return "work";
}

function toolStartCopy(toolName: string): { title: string } {
  const normalizedToolName = normalizeToolName(toolName);
  if (normalizedToolName === "hospital_bag_pump_recommend") return { title: "正在读取吸奶器型号目录" };
  if (normalizedToolName === "hospital_bag_cart_update") return { title: "正在更新待产包购物车" };
  if (normalizedToolName === "device_manual_search") return { title: "正在读取设备说明资料" };
  if (normalizedToolName === "support_ticket_draft_create") return { title: "正在准备售后工单" };

  switch (toolWorkPhase(toolName)) {
    case "select":
      return { title: "正在选择合适能力" };
    case "read":
      return { title: "正在读取相关信息" };
    case "evaluate":
      return { title: "正在评估情况" };
    case "prepare_result":
      return { title: "正在准备结果" };
    case "preview":
      return { title: "正在生成预览" };
    case "save":
      return { title: "正在准备保存修改" };
    case "process":
      return { title: "正在执行处理流程" };
    default:
      return { title: "正在执行当前步骤" };
  }
}

function toolArgsCopy(toolName: string): { title: string; detail?: string } {
  return toolStartCopy(toolName);
}

function toolEndCopy(toolName: string): { title: string; detail?: string } {
  const normalizedToolName = normalizeToolName(toolName);
  if (normalizedToolName === "hospital_bag_pump_recommend") return { title: "正在整理吸奶器推荐" };
  if (normalizedToolName === "hospital_bag_cart_update") return { title: "正在保存购物车修改" };
  if (normalizedToolName === "device_manual_search") return { title: "正在整理设备资料" };
  if (normalizedToolName === "support_ticket_draft_create") return { title: "正在生成售后工单草稿" };

  switch (toolWorkPhase(toolName)) {
    case "select":
      return { title: "正在确认可用能力" };
    case "read":
      return { title: "正在整理相关信息" };
    case "evaluate":
      return { title: "正在计算评估结果" };
    case "prepare_result":
      return { title: "正在生成结果" };
    case "preview":
      return { title: "正在生成预览" };
    case "save":
      return { title: "正在保存修改" };
    case "process":
      return { title: "正在执行处理流程" };
    default:
      return { title: "正在执行当前步骤" };
  }
}

function toolResultCopy(toolName: string, result: Record<string, unknown> | null): { title: string; detail?: string } {
  const normalizedToolName = normalizeToolName(toolName);
  const errObj = result?.error && typeof result.error === "object" ? (result.error as Record<string, unknown>) : null;
  const errorMessage = coalesceString(errObj?.message) || "这个步骤没有成功完成。";
  if (result?.ok === false) {
    return { title: "步骤没有完成", detail: errorMessage };
  }
  const status = coalesceString(result?.status);
  if (status === "plan_preview_needs_revision") {
    return { title: "结果需要调整", detail: "保存前校验未通过，暂不能确认。" };
  }
  if (status === "plan_preview_not_recommended") {
    return { title: "当前方案暂不建议继续" };
  }
  if (status === "plan_preview_needs_medical_confirmation") {
    return { title: "需要先确认健康边界" };
  }
  if (result?.requires_confirmation === true) {
    return { title: "预览已准备好", detail: "确认后才会生效。" };
  }
  if (normalizedToolName === "milk_record_mutate") return { title: milkMutationResultTitle(result, "修改已保存") };
  if (normalizedToolName === "milk_plan_mutate") return { title: milkMutationResultTitle(result, "计划修改已保存") };
  if (normalizedToolName === "milk_calendar_mutate") return { title: milkMutationResultTitle(result, "日程修改已保存") };
  if (normalizedToolName === "milk_task_complete") return { title: milkTaskResultTitle(result) };
  if (normalizedToolName === "infant_growth_mutate") return { title: milkMutationResultTitle(result, "记录已保存") };
  if (normalizedToolName === "hospital_bag_pump_recommend") return { title: "已完成吸奶器推荐" };
  if (normalizedToolName === "hospital_bag_cart_update") {
    const status = coalesceString(result?.status);
    if (status === "needs_clarification" || status === "cart_unchanged") return { title: "购物车暂未修改" };
    return { title: "购物车已更新" };
  }
  if (normalizedToolName === "device_manual_search") return { title: "设备资料已读取" };
  if (normalizedToolName === "support_ticket_draft_create") return { title: "售后工单草稿已准备好" };

  switch (toolWorkPhase(toolName)) {
    case "select":
      return { title: "可用能力已准备好" };
    case "read":
      return { title: "相关信息已读取" };
    case "evaluate":
      return { title: "评估已完成" };
    case "prepare_result":
    case "preview":
      return { title: "结果已准备好" };
    case "save":
      return { title: "修改已保存" };
    case "process":
      return { title: "处理流程已完成" };
    default:
      return { title: "步骤已完成" };
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function normalizeArtifactType(value: unknown): string {
  const token = String(value ?? "").trim();
  if (!token) return "";
  if (token === "support-ticket") return "support_ticket";
  return token;
}

function artifactActionFromEvent(rec: Record<string, unknown>): Record<string, unknown> | null {
  const artifact = asRecord(rec.artifact);
  if (!artifact) return null;
  const artifactType = normalizeArtifactType(rec.artifact_type);
  const toolName = normalizeToolName(rec.tool_call_name);
  const artifactId =
    coalesceString(rec.artifact_id) ||
    coalesceString(rec.artifactId) ||
    coalesceString(artifact.id);
  const identity = artifactId ? { artifact_id: artifactId } : {};

  if (artifactType === "form") {
    return { kind: "ag_ui_artifact", artifact_type: "form", ...identity, form: artifact };
  }
  if (artifactType === "support_ticket" || artifactType === "support_ticket_draft") {
    return {
      kind: "ag_ui_artifact",
      artifact_type: "support_ticket_draft",
      ...identity,
      ticket: artifact,
      submit_label: coalesceString(rec.submit_label) || "确认并提交",
    };
  }
  if (artifactType === "ibclc_consult" || toolName === "ibclc_consult_card_create") {
    return { kind: "ag_ui_artifact", artifact_type: "ibclc_consult", ...identity, card: artifact };
  }
  return { kind: "ag_ui_artifact", artifact_type: "card", ...identity, card: artifact };
}

function richTextPayloadForArtifactAction(action: Record<string, unknown>): ChatRichTextPayload {
  return { title: "", content: "", button: [], card: [], action: [action] };
}

function richTextPayloadFromRecord(payload: Record<string, unknown>): ChatRichTextPayload | null {
  const button = Array.isArray(payload.button) ? payload.button : [];
  const card = Array.isArray(payload.card) ? payload.card : [];
  const action = Array.isArray(payload.action) ? payload.action : [];
  if (!coalesceString(payload.title) && !coalesceString(payload.content) && button.length === 0 && card.length === 0 && action.length === 0) {
    return null;
  }
  return {
    title: coalesceString(payload.title),
    content: coalesceString(payload.content),
    button: button as ChatRichTextPayload["button"],
    card: card as ChatRichTextPayload["card"],
    action,
  };
}

function artifactActionFromToolResultPayload(parsed: Record<string, unknown>): Record<string, unknown> | null {
  const toolName = normalizeToolName(coalesceString(parsed.tool_name) || coalesceString(parsed.toolName));
  const form = asRecord(parsed.form);
  const artifactId = coalesceString(parsed.artifact_id) || coalesceString(parsed.artifactId);
  const identity = artifactId ? { artifact_id: artifactId } : {};
  if (toolName === "ui_form_create" && form) {
    return { kind: "ag_ui_artifact", artifact_type: "form", ...identity, form };
  }

  const card = asRecord(parsed.card);
  if (toolName === "ui_card_create" && card) {
    return { kind: "ag_ui_artifact", artifact_type: "card", ...identity, card };
  }
  if (toolName === "ibclc_consult_card_create") {
    return { kind: "ag_ui_artifact", artifact_type: "ibclc_consult", ...identity, card: card ?? parsed };
  }

  const ticket = asRecord(parsed.ticket);
  if (toolName === "support_ticket_draft_create") {
    return {
      kind: "ag_ui_artifact",
      artifact_type: "support_ticket_draft",
      ...identity,
      ticket: ticket ?? parsed,
      submit_label: coalesceString(parsed.submit_label) || "确认并提交",
    };
  }

  return null;
}

/**
 * 兼容吸奶结束小结等独立链路中的旧 TOOL_CALL_RESULT 富文本载荷。
 * 主智能体会话的结构化 UI 仍以 ARTIFACT_CREATED 为唯一入口。
 */
export function richTextFromToolResultPayload(parsed: Record<string, unknown>): ChatRichTextPayload | null {
  const direct = asRecord(parsed.rich_text) ?? asRecord(parsed.richText);
  const directRich = direct ? richTextPayloadFromRecord(direct) : null;
  if (directRich) return directRich;

  const maybeRichCard = asRecord(parsed.card);
  if (maybeRichCard && Array.isArray(maybeRichCard.content) && coalesceString(maybeRichCard.type)) {
    return { title: "", content: "", button: [], card: [maybeRichCard as ChatRichTextPayload["card"][number]], action: [] };
  }

  const action = artifactActionFromToolResultPayload(parsed);
  return action ? richTextPayloadForArtifactAction(action) : null;
}

function richArtifactActionKey(action: unknown): string {
  const obj = asRecord(action);
  if (!obj || coalesceString(obj.kind) !== "ag_ui_artifact") return "";
  const artifactType = normalizeArtifactType(obj.artifact_type);
  const artifactId = coalesceString(obj.artifact_id) || coalesceString(obj.artifactId);
  if (artifactId) return `artifact:${artifactId}`;

  const form = asRecord(obj.form);
  const card = asRecord(obj.card);
  const ticket = asRecord(obj.ticket);
  const embeddedId =
    coalesceString(form?.id) ||
    coalesceString(card?.id) ||
    coalesceString(ticket?.id);
  if (artifactType && embeddedId) return `${artifactType}:${embeddedId}`;

  return artifactType === "support_ticket_draft" ? "support_ticket_draft:current" : "";
}

function mergeRichActions(prev: unknown[], next: unknown[]): unknown[] {
  const merged = [...prev];
  for (const action of next) {
    const key = richArtifactActionKey(action);
    if (key) {
      const existingIndex = merged.findIndex((item) => richArtifactActionKey(item) === key);
      if (existingIndex >= 0) {
        merged[existingIndex] = action;
        continue;
      }
    }
    merged.push(action);
  }
  return merged;
}

function milkPlanCardUpdateFromToolResult(parsed: Record<string, unknown> | null): { artifactId: string; card: Record<string, unknown> } | null {
  if (!parsed || normalizeToolName(parsed.tool_name) !== "milk_plan_mutate" || parsed.ok !== true) return null;
  const card = asRecord(parsed.card);
  if (!card || coalesceString(card.card_type) !== "milk_plan_card") return null;
  const artifactId = coalesceString(parsed.artifact_id) || coalesceString(parsed.artifactId) || coalesceString(card.id);
  if (!artifactId) return null;
  return { artifactId, card };
}

function replaceMilkPlanCardAction(action: unknown, artifactId: string, card: Record<string, unknown>): { action: unknown; changed: boolean } {
  const obj = asRecord(action);
  if (!obj) return { action, changed: false };
  const existingCard = asRecord(obj.card);
  const actionArtifactId = coalesceString(obj.artifact_id) || coalesceString(obj.artifactId) || coalesceString(existingCard?.id);
  const artifactType = normalizeArtifactType(obj.artifact_type);
  const isCardArtifact = artifactType === "card" || artifactType === "milk_plan_card";
  if (!isCardArtifact || actionArtifactId !== artifactId || coalesceString(existingCard?.card_type) !== "milk_plan_card") {
    return { action, changed: false };
  }
  return {
    action: {
      ...obj,
      artifact_id: artifactId,
      artifact_type: "card",
      card,
    },
    changed: true,
  };
}

function replaceMilkPlanCardInRichText(
  payload: ChatRichTextPayload | undefined,
  artifactId: string,
  card: Record<string, unknown>,
): { payload?: ChatRichTextPayload; changed: boolean } {
  if (!payload) return { payload, changed: false };
  let changed = false;
  const action = payload.action.map((item) => {
    const replaced = replaceMilkPlanCardAction(item, artifactId, card);
    if (replaced.changed) changed = true;
    return replaced.action;
  });
  return changed ? { payload: { ...payload, action }, changed: true } : { payload, changed: false };
}

function replaceMilkPlanCardInMessage(message: ChatMessage, artifactId: string, card: Record<string, unknown>): { message: ChatMessage; changed: boolean } {
  const richText = replaceMilkPlanCardInRichText(message.richText, artifactId, card);
  let streamChanged = false;
  const streamRenderItems = message.streamRenderItems?.map((item) => {
    if (item.kind !== "rich") return item;
    const replaced = replaceMilkPlanCardInRichText(item.payload, artifactId, card);
    if (replaced.changed && replaced.payload) {
      streamChanged = true;
      return { ...item, payload: replaced.payload };
    }
    return item;
  });
  if (!richText.changed && !streamChanged) return { message, changed: false };
  return {
    message: {
      ...message,
      ...(richText.changed ? { richText: richText.payload } : {}),
      ...(streamChanged ? { streamRenderItems } : {}),
    },
    changed: true,
  };
}

function extractLoadedSkillIds(rec: Record<string, unknown>): string[] {
  const direct = rec.loaded_skill_ids;
  if (Array.isArray(direct)) {
    return direct.map((x) => (typeof x === "string" ? x.trim() : String(x))).filter(Boolean);
  }
  const input = rec.input;
  if (input && typeof input === "object") {
    const ls = (input as Record<string, unknown>).loaded_skill_ids;
    if (Array.isArray(ls)) {
      return ls.map((x) => (typeof x === "string" ? x.trim() : String(x))).filter(Boolean);
    }
  }
  return [];
}

function extractStatusLineFromMetadata(metadata: unknown): string {
  if (!metadata || typeof metadata !== "object") return "";
  const meta = metadata as Record<string, unknown>;
  return (
    coalesceString(meta.status_label) ||
    coalesceString(meta.statusLabel) ||
    coalesceString(meta.status) ||
    coalesceString(meta.phase) ||
    coalesceString(meta.message)
  );
}

function readHospitalBagCartUpdate(parsed: Record<string, unknown> | null): { groups: HospitalBagCartGroup[]; message?: string } | null {
  const update = asRecord(parsed?.cart_update);
  if (!update) return null;
  const groups = update.groups;
  if (!Array.isArray(groups)) return null;
  return {
    groups: groups as HospitalBagCartGroup[],
    message: coalesceString(update.message),
  };
}

export type ApplyAgUiSideEffectResult = {
  /** 若非正文事件，至少更新了一项元信息 / 工具轨迹时为 true，用于避免「仅工具帧」被 `!chunk && !rich` 丢弃 */
  didUpdate: boolean;
};

/** 合并多次 rich_text / 工具卡片，避免后一次覆盖前一次 */
export function mergePendingRichTextPayload(
  prev: ChatRichTextPayload | null,
  next: ChatRichTextPayload,
): ChatRichTextPayload {
  if (!prev) return next;
  const parts = [prev.content, next.content].filter((s) => typeof s === "string" && s.trim());
  return {
    title: next.title?.trim() ? next.title : prev.title,
    content: parts.join("\n\n"),
    button: [...prev.button, ...next.button],
    card: [...prev.card, ...next.card],
    action: mergeRichActions(prev.action, next.action),
  };
}

function appendRichRenderItem(
  items: ChatMessage["streamRenderItems"],
  payload: ChatRichTextPayload,
): ChatMessage["streamRenderItems"] {
  const list = [...(items ?? [])];
  const last = list.at(-1);
  if (last?.kind === "rich") {
    list[list.length - 1] = { kind: "rich", payload: mergePendingRichTextPayload(last.payload, payload) };
    return list;
  }
  list.push({ kind: "rich", payload });
  return list;
}

/**
 * 处理单条解析后的流事件：更新会话元信息、状态条、工作面板；必要时合并 ARTIFACT_CREATED 产生的 richText。
 */
export function applyAgUiStreamSideEffects(
  replyId: string,
  data: string | object,
  setMessages: Dispatch<SetStateAction<ChatMessage[]>>,
  opts?: {
    pendingRichTextRef?: MutableRefObject<ChatRichTextPayload | null>;
    onHospitalBagCartUpdate?: (groups: HospitalBagCartGroup[], message?: string) => void;
  },
): ApplyAgUiSideEffectResult {
  if (typeof data !== "object" || data == null) return { didUpdate: false };
  const rec = data as Record<string, unknown>;
  const eventType = resolveAgUiEventType(data);
  let didUpdate = false;

  const patchMsg = (fn: (m: ChatMessage) => ChatMessage) => {
    didUpdate = true;
    setMessages((prev) => prev.map((m) => (m.id === replyId ? fn(m) : m)));
  };

  if (eventType === "QUICK_REPLIES") {
    const replies = readQuickReplies(rec.replies);
    if (replies.length === 3) {
      didUpdate = true;
      setMessages((prev) =>
        prev.map((m) => ({
          ...m,
          quickReplies: m.id === replyId ? replies : undefined,
        })),
      );
    }
  }

  if (eventType === "RUN_STARTED") {
    const skills = extractLoadedSkillIds(rec);
    const statusLine = extractStatusLineFromMetadata(rec.metadata) || "Agent loop started.";
    patchMsg((m) => ({
      ...m,
      ...(skills.length > 0 ? { agentLoadedSkillIds: skills } : {}),
      agentStatusLine: labelForStatus(statusLine),
      agentStatusDone: false,
    }));
  }

  if (eventType === "CUSTOM") {
    const statusLine = extractAgentStatusLineFromCustom(rec);
    if (statusLine && !isThinkingStatusLine(statusLine)) {
      patchMsg((m) => ({ ...m, agentStatusLine: labelForStatus(statusLine), agentStatusDone: false }));
    }
  }

  if (eventType === "TEXT_MESSAGE_CONTENT") {
    patchMsg((m) => ({
      ...m,
      agentThinkingTitle: undefined,
      agentStatusDone: false,
      ...(isThinkingStatusLine(m.agentStatusLine ?? "") ? { agentStatusLine: "" } : {}),
    }));
  }

  if (eventType === "TEXT_MESSAGE_END") {
    patchMsg((m) => ({
      ...m,
      agentThinkingTitle: undefined,
      agentStatusLine: labelForStatus("Answer ready."),
      agentStatusDone: true,
    }));
  }

  if (eventType === "RUN_FINISHED") {
    const finishedAt = nowMs();
    patchMsg((m) => ({
      ...m,
      agentThinkingTitle: undefined,
      agentStatusLine: labelForStatus("Run finished."),
      agentStatusDone: true,
      agentWorkFinishedAtMs: finishedAt,
      agentToolCalls: (m.agentToolCalls ?? []).map((t) => (t.state === "running" ? { ...t, state: "completed" } : t)),
    }));
  }

  if (eventType === "ACTIVITY_SNAPSHOT") {
    const content = rec.content;
    if (content && typeof content === "object") {
      const meta = (content as Record<string, unknown>).metadata;
      if (meta && typeof meta === "object") {
        const skills = (meta as Record<string, unknown>).loaded_skill_ids;
        if (Array.isArray(skills) && skills.length > 0) {
          const ids = skills.map((x) => (typeof x === "string" ? x.trim() : String(x))).filter(Boolean);
          if (ids.length > 0) {
            patchMsg((m) => ({ ...m, agentLoadedSkillIds: ids }));
          }
        }
        const statusLine = extractStatusLineFromMetadata(meta);
        if (statusLine && !isThinkingStatusLine(statusLine)) {
          patchMsg((m) => ({ ...m, agentStatusLine: labelForStatus(statusLine), agentStatusDone: false }));
        }
      }
    }
  }

  if (eventType === "STEP_STARTED" || eventType === "STEP_FINISHED") {
    const stepName = coalesceString(rec.step_name) || coalesceString(rec.stepName) || coalesceString(rec.name) || "step";
    const text = labelForStep(stepName, eventType === "STEP_STARTED" ? "started" : "finished");
    patchMsg((m) => ({ ...m, agentStatusLine: text, agentStatusDone: false }));
  }

  const toolKeys = readToolCallKeys(rec);
  if (toolKeys.length > 0 && eventType === "TOOL_CALL_START") {
    const startedAt = nowMs();
    const toolName = readToolName(rec);
    const copy = toolStartCopy(toolName);
    patchMsg((m) => {
      const moved = moveProvisionalTextToWork(m);
      return {
        ...moved,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: moved.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(moved.agentToolCalls ?? [], toolKeys, {
          kind: "tool",
          name: toolName,
          title: copy.title,
          state: "running",
          argsDigest: "",
        }),
      };
    });
  } else if (toolKeys.length > 0 && eventType === "TOOL_CALL_ARGS") {
    const startedAt = nowMs();
    const toolName = readToolName(rec);
    patchMsg((m) => {
      const moved = moveProvisionalTextToWork(m);
      const baseTools = moved.agentToolCalls ?? [];
      const curIdx = findToolRowIndex(baseTools, toolKeys, toolName, true);
      if (curIdx >= 0) {
        return {
          ...moved,
          agentThinkingTitle: undefined,
          agentWorkStartedAtMs: moved.agentWorkStartedAtMs ?? startedAt,
          agentWorkFinishedAtMs: undefined,
        };
      }
      const copy = toolArgsCopy(toolName);
      return {
        ...moved,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: moved.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          baseTools,
          toolKeys,
          {
            kind: "tool",
            name: toolName,
            title: copy.title,
            argsDigest: copy.detail ?? "",
            state: "running",
          },
          { mergeRunning: true },
        ),
      };
    });
  } else if (toolKeys.length > 0 && eventType === "TOOL_CALL_END") {
    const startedAt = nowMs();
    const toolName = readToolName(rec);
    const copy = toolEndCopy(toolName);
    patchMsg((m) => {
      const moved = moveProvisionalTextToWork(m);
      return {
        ...moved,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: moved.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          moved.agentToolCalls ?? [],
          toolKeys,
          {
            kind: "tool",
            name: toolName,
            title: copy.title,
            argsDigest: copy.detail ?? undefined,
          },
          { mergeRunning: true },
        ),
      };
    });
  } else if (toolKeys.length > 0 && eventType === "TOOL_CALL_RESULT") {
    const parsed = parseToolResultPayload(rec.content);
    const hospitalBagCartUpdate = readHospitalBagCartUpdate(parsed);
    if (hospitalBagCartUpdate) {
      opts?.onHospitalBagCartUpdate?.(hospitalBagCartUpdate.groups, hospitalBagCartUpdate.message);
    }
    const milkPlanCardUpdate = milkPlanCardUpdateFromToolResult(parsed);
    if (milkPlanCardUpdate) {
      didUpdate = true;
      setMessages((prev) => {
        let changed = false;
        const next = prev.map((message) => {
          const replaced = replaceMilkPlanCardInMessage(message, milkPlanCardUpdate.artifactId, milkPlanCardUpdate.card);
          if (replaced.changed) changed = true;
          return replaced.message;
        });
        return changed ? next : prev;
      });
    }
    const normalizedToolName = parsed
      ? normalizeToolName(parsed.tool_name) || readToolName(rec)
      : readToolName(rec);
    const copy = toolResultCopy(normalizedToolName, parsed);
    const summary = copy.detail || (parsed ? summarizeToolResult(parsed) : coalesceString(rec.content) || "Result");
    const ok = parsed?.ok;
    const startedAt = nowMs();
    patchMsg((m) => {
      const moved = moveProvisionalTextToWork(m);
      return {
        ...moved,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: moved.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          moved.agentToolCalls ?? [],
          toolKeys,
          {
            kind: "tool",
            name: normalizedToolName,
            title: copy.title,
            state: typeof ok === "boolean" ? (ok ? "completed" : "error") : "completed",
            resultSummary: summary,
          },
          { mergeRunning: true },
        ),
      };
    });

  }

  if (eventType === "ARTIFACT_CREATED") {
    const action = artifactActionFromEvent(rec);
    if (action) {
      const rich = richTextPayloadForArtifactAction(action);
      patchMsg((m) => {
        const moved = moveProvisionalTextToWork(m);
        return {
          ...moved,
          richText: moved.richText ? mergePendingRichTextPayload(moved.richText, rich) : rich,
          streamRenderItems: appendRichRenderItem(moved.streamRenderItems, rich),
        };
      });
    }
  }

  if (eventType === "CONFIRMATION_REQUIRED") {
    const startedAt = nowMs();
    const confirmationId = coalesceString(rec.confirmation_id) || coalesceString(rec.confirmationId);
    const artifactId = coalesceString(rec.artifact_id) || coalesceString(rec.artifactId);
    const keys = [...new Set([...toolKeys, confirmationId ? `confirmation:${confirmationId}` : "", artifactId ? `artifact:${artifactId}` : ""].filter(Boolean))];
    const toolName = readToolName(rec);
    patchMsg((m) => {
      const moved = moveProvisionalTextToWork(m);
      return {
        ...moved,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: moved.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          moved.agentToolCalls ?? [],
          keys,
          {
            kind: "tool",
            name: toolName,
            title: "请确认后继续",
            argsDigest: "相关内容已准备好，等待你确认。",
            state: "completed",
          },
          { mergeRunning: true },
        ),
      };
    });
  }

  return { didUpdate };
}
