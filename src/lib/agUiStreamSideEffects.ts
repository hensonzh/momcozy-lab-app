/**
 * ag-ui / Momcozy Agent 流式事件：与《web-api》2.3–2.5 对齐的非正文侧效（状态条、工具轨迹、RUN_STARTED 元信息等）。
 * 正文增量仍由 AgentHub 的 TEXT_MESSAGE_CONTENT 路径处理。
 */

import type { Dispatch, MutableRefObject, SetStateAction } from "react";
import type { AgUiToolCallRow, ChatMessage, ChatMessageCitation, ChatQuickReply } from "@/types/chat";
import type { ChatRichTextPayload } from "@/lib/agentApiTypes";
import { notifyBirthJourneyPlanDeleted } from "@/lib/birthJourneyPlanNotification";
import { normalizeMediaVoiceNarrationItems, type MediaVoiceNarrationItem } from "@/lib/mediaVoiceNarration";
import { notifyPregnancyDiaryChanged } from "@/lib/pregnancyDiaryEvents";
import type { HospitalBagCartGroup } from "@/pages/hospitalBagCartModel";

const STATUS_LABELS: Record<string, string> = {
  "Agent loop started.": "",
  "Evaluating user intent and safety context.": "我先理解一下你的需求～",
  "Requesting model response.": "我想一下",
  "Requesting model response with tool outputs.": "",
  "Selecting an application tool.": "我来判断下一步怎么做～",
  "Executing an application tool.": "",
  "Selecting the next step.": "我来判断下一步怎么做～",
  "Loading relevant context.": "我去看一下相关信息～",
  "Reading relevant information.": "我去看一下相关信息～",
  "Running a processing step.": "",
  "Processing relevant information.": "我把刚看到的信息整理一下～",
  "Step completed.": "这一步处理好啦",
  "Step failed.": "这一步暂时没处理好",
  "Answer ready.": "我整理好回复啦",
  "Run finished.": "我处理好啦",
};

const THINKING_STATUS_TEXTS = new Set([
  "Requesting model response.",
  "Thinking...",
  "Thinking",
  "正在思考。",
  "正在思考",
  "我正在想怎么帮你处理。",
  "我正在想怎么帮你处理",
  "我想一下",
  "我想一想怎么帮你～",
  "我想一想怎么帮你",
]);

const RUN_STARTED_WORK_ROW_ID = "run:started-work";
const RUN_STARTED_WORK_ROW_NAME = "run_started";
const RUN_STARTED_WORK_ROW_TITLE = "我已经收到你的消息啦～";
const WEB_SEARCH_STATUS_CUSTOM_NAME = "momcozy.agent.web_search";
const WEB_SEARCH_CITATIONS_CUSTOM_NAME = "momcozy.web_search.citations";

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

function readWebSearchCitations(value: unknown): ChatMessageCitation[] {
  const rec = asRecord(value);
  const raw = Array.isArray(rec?.citations) ? rec.citations : Array.isArray(value) ? value : [];
  const citations: ChatMessageCitation[] = [];
  const seenUrls = new Set<string>();
  const seenKeys = new Set<string>();
  const hostCounts = new Map<string, number>();
  raw.forEach((item) => {
    const citation = asRecord(item);
    const url = coalesceString(citation?.url);
    if (!/^https?:\/\//i.test(url)) return;
    const normalizedUrl = url.trim().replace(/#.*$/, "").replace(/\/$/, "");
    if (seenUrls.has(normalizedUrl)) return;
    let host = "";
    try {
      host = new URL(url).hostname.replace(/^www\./, "").toLowerCase();
    } catch {
      host = "";
    }
    const fallbackTitle = host || "参考来源";
    const title = coalesceString(citation?.title) || fallbackTitle;
    const titleKey = citationTitleKey(title, host);
    const dedupeKey = `${host}:${titleKey}`;
    if (seenKeys.has(dedupeKey)) return;
    if (host && (hostCounts.get(host) ?? 0) >= 2) return;
    seenUrls.add(normalizedUrl);
    seenKeys.add(dedupeKey);
    if (host) hostCounts.set(host, (hostCounts.get(host) ?? 0) + 1);
    citations.push({
      index: citations.length + 1,
      title,
      url,
    });
  });
  return citations.slice(0, 4);
}

function citationTitleKey(title: string, host: string): string {
  const normalized = title.trim().toLowerCase().replace(/\s+/g, " ").replace(/^www\./, "");
  if (!normalized || normalized === "参考来源" || normalized === host || normalized === `www.${host}` || normalized === "protocols") {
    return host || normalized;
  }
  return normalized;
}

function readWebSearchStatus(value: unknown): { status: "searching" | "completed" | "failed"; label: string } {
  const rec = asRecord(value);
  const rawStatus = coalesceString(rec?.status).toLowerCase();
  const status =
    rawStatus === "completed" || rawStatus === "done" || rawStatus === "finished"
      ? "completed"
      : rawStatus === "failed" || rawStatus === "error"
        ? "failed"
        : "searching";
  const fallback =
    status === "completed"
      ? "我查好专业资料啦"
      : status === "failed"
        ? "专业资料暂时没查好"
        : "我在查专业资料～";
  return { status, label: coalesceString(rec?.label) || fallback };
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
    return state === "started" ? "我先理解一下你的需求～" : "我判断好你的需求啦";
  }
  return state === "started" ? "我先处理这一步～" : "这一步处理好啦";
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

function isRunStartedWorkRow(row: AgUiToolCallRow): boolean {
  return row.id === RUN_STARTED_WORK_ROW_ID || normalizeToolName(row.name) === RUN_STARTED_WORK_ROW_NAME;
}

function withoutRunStartedWorkRow(tools: AgUiToolCallRow[]): AgUiToolCallRow[] {
  return tools.filter((row) => !isRunStartedWorkRow(row));
}

function withRunStartedWorkRow(tools: AgUiToolCallRow[], title: string): AgUiToolCallRow[] {
  if (tools.some(isRunStartedWorkRow)) return tools;
  if (tools.some((row) => row.kind !== "narration")) return tools;
  return [
    ...tools,
    {
      id: RUN_STARTED_WORK_ROW_ID,
      kind: "tool",
      name: RUN_STARTED_WORK_ROW_NAME,
      title: title.trim() || RUN_STARTED_WORK_ROW_TITLE,
      argsDigest: "",
      state: "running",
    },
  ];
}

function upsertWebSearchWorkRow(
  tools: AgUiToolCallRow[],
  search: { status: "searching" | "completed" | "failed"; label: string },
): AgUiToolCallRow[] {
  const baseTools = withoutRunStartedWorkRow(tools);
  return upsertToolRow(
    baseTools,
    ["web_search:current"],
    {
      kind: "tool",
      name: "web_search",
      title: search.label,
      argsDigest: "",
      state: search.status === "failed" ? "error" : search.status === "completed" ? "completed" : "running",
    },
    { mergeRunning: true },
  );
}

function truncate(s: string, max: number): string {
  const t = s.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max)}…`;
}

function nowMs(): number {
  return Date.now();
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

function maybeNotifyBirthJourneyPlanDeleted(parsed: Record<string, unknown> | null): void {
  if (!parsed) return;
  const toolName = normalizeToolName(parsed.tool_name);
  if (toolName !== "birth_journey_plan_delete") return;
  if (coalesceString(parsed.status) !== "plan_deleted") return;
  if (parsed.side_effect_performed === false) return;
  notifyBirthJourneyPlanDeleted();
}

function maybeNotifyPregnancyDiaryChanged(parsed: Record<string, unknown> | null): void {
  if (!parsed) return;
  const toolName = normalizeToolName(parsed.tool_name);
  if (toolName !== "pregnancy_diary_manage") return;
  const status = coalesceString(parsed.status);
  if (!["diary_entry_created", "diary_entry_updated", "diary_entry_deleted"].includes(status)) return;
  if (parsed.side_effect_performed === false) return;
  notifyPregnancyDiaryChanged();
}

function summarizeToolResult(parsed: Record<string, unknown>): string {
  const ok = parsed.ok;
  const base = typeof ok === "boolean" ? (ok ? "这一步处理好啦" : "这一步暂时没处理好") : "";
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
  if (status.includes("deleted")) return "我已经删除相关修改啦";
  if (status.includes("updated") || status.includes("patched") || status.includes("shifted")) return "我已经保存好修改啦";
  if (status.includes("created") || status.includes("applied")) return fallbackTitle;
  if (status.includes("idempotent_replay")) return "我已经用上之前保存的修改啦";
  return fallbackTitle;
}

function milkTaskResultTitle(result: Record<string, unknown> | null): string {
  const status = coalesceString(result?.status);
  if (status === "milk_task_completed") return "我已经记录好任务完成啦";
  if (status === "milk_task_completion_cancelled") return "我已经取消这次修改啦";
  if (status === "milk_task_skipped") return "我已经记录为跳过啦";
  return "我已经记录好任务状态啦";
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
      "pregnancy_diary_manage",
      "device_manual_search",
      "knowledge_search",
      "reminder_list",
    ].includes(name)
  ) {
    return "read";
  }
  if (["milk_assessment_evaluate", "infant_growth_evaluate", "risk_evaluate"].includes(name)) return "evaluate";
  if (
    [
      "ui_form_create",
      "birth_plan_form_create",
      "hospital_bag_form_create",
      "labor_communication_card_create",
      "birth_journey_plan_card_create",
      "hospital_bag_card_create",
      "ibclc_consult_card_create",
      "support_ticket_draft_create",
    ].includes(name)
  ) {
    return "prepare_result";
  }
  if (["milk_plan_preview", "milk_calendar_change_preview", "milk_calendar_reschedule_preview"].includes(name)) return "preview";
  if (
    [
      "milk_record_mutate",
      "milk_plan_mutate",
      "milk_calendar_mutate",
      "milk_task_complete",
      "infant_growth_mutate",
      "hospital_bag_cart_update",
      "birth_journey_plan_delete",
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
  if (normalizedToolName === "tool_search" || normalizedToolName === "tool_search_call") return { title: "让我看看如何处理～" };
  if (normalizedToolName === "load_skill") return { title: "我先准备一下这个场景～" };
  if (normalizedToolName === "list_skills") return { title: "我看看可以怎么帮你～" };
  if (normalizedToolName === "search_skill_assets") return { title: "我去找找相关资料～" };
  if (normalizedToolName === "read_skill_file") return { title: "我先看一下相关说明～" };
  if (normalizedToolName === "profile_get") return { title: "我先看一下你的基础信息～" };
  if (normalizedToolName === "milk_snapshot_get") return { title: "我先看看你的奶量情况～" };
  if (normalizedToolName === "milk_status_query") return { title: "我先看看今天的奶量状态～" };
  if (normalizedToolName === "milk_records_query") return { title: "我先看看吸奶和喂养记录～" };
  if (normalizedToolName === "milk_plan_query") return { title: "我先看看之前保存的奶量计划～" };
  if (normalizedToolName === "milk_calendar_query") return { title: "我先看看计划和日程任务～" };
  if (normalizedToolName === "milk_assessment_evaluate") return { title: "我来看看奶量趋势和执行情况～" };
  if (normalizedToolName === "infant_growth_evaluate") return { title: "我来看看宝宝的生长信号～" };
  if (normalizedToolName === "risk_evaluate") return { title: "我先确认一下安全边界～" };
  if (normalizedToolName === "milk_plan_preview") return { title: "我先帮你拟一版奶量计划～" };
  if (normalizedToolName === "milk_calendar_change_preview" || normalizedToolName === "milk_calendar_reschedule_preview") return { title: "我先帮你排一下日程调整～" };
  if (normalizedToolName === "milk_record_mutate") return { title: "我先帮你处理这条记录～" };
  if (normalizedToolName === "milk_task_complete") return { title: "我先帮你记录任务完成情况～" };
  if (normalizedToolName === "milk_plan_mutate") return { title: "我先帮你保存奶量计划～" };
  if (normalizedToolName === "milk_calendar_mutate") return { title: "我先帮你保存日程调整～" };
  if (normalizedToolName === "infant_growth_mutate") return { title: "我先帮你保存宝宝成长记录～" };
  if (["ui_form_create", "birth_plan_form_create", "hospital_bag_form_create"].includes(normalizedToolName)) return { title: "我先帮你准备确认内容～" };
  if (normalizedToolName === "labor_communication_card_create") return { title: "我先帮你整理分娩沟通单～" };
  if (normalizedToolName === "birth_journey_plan_card_create") return { title: "我先帮你整理生产全过程计划～" };
  if (normalizedToolName === "birth_journey_plan_delete") return { title: "我先帮你删除生产全过程计划～" };
  if (normalizedToolName === "pregnancy_diary_manage") return { title: "我先看看孕期日记～" };
  if (normalizedToolName === "hospital_bag_card_create") return { title: "我先帮你整理待产包清单～" };
  if (normalizedToolName === "ibclc_consult_card_create") return { title: "我先帮你准备 IBCLC 咨询入口～" };
  if (normalizedToolName === "hospital_bag_pump_recommend") return { title: "我先看看适合你的吸奶器型号～" };
  if (normalizedToolName === "hospital_bag_cart_update") return { title: "我先帮你调整待产包购物车～" };
  if (normalizedToolName === "device_manual_search") return { title: "我先看看设备说明～" };
  if (normalizedToolName === "knowledge_search") return { title: "我去找找相关资料～" };
  if (normalizedToolName === "memory_search") return { title: "我去找一下之前的信息～" };
  if (normalizedToolName === "reminder_list") return { title: "我先看看你的提醒～" };
  if (normalizedToolName === "support_ticket_draft_create") return { title: "我先帮你准备售后信息表～" };

  switch (toolWorkPhase(toolName)) {
    case "select":
      return { title: "让我看看如何处理～" };
    case "read":
      return { title: "我去看一下相关信息～" };
    case "evaluate":
      return { title: "我来评估一下情况～" };
    case "prepare_result":
      return { title: "我先帮你准备结果～" };
    case "preview":
      return { title: "我先生成一版预览～" };
    case "save":
      return { title: "我先准备保存修改～" };
    case "process":
      return { title: "我先处理这一步～" };
    default:
      return { title: "我先处理这一步～" };
  }
}

function toolArgsCopy(toolName: string): { title: string; detail?: string } {
  return toolStartCopy(toolName);
}

function toolEndCopy(toolName: string): { title: string; detail?: string } {
  const normalizedToolName = normalizeToolName(toolName);
  if (normalizedToolName === "tool_search" || normalizedToolName === "tool_search_call") return { title: "我找到合适的方案啦" };
  if (["milk_records_query", "milk_status_query", "milk_snapshot_get", "milk_plan_query", "milk_calendar_query"].includes(normalizedToolName)) return { title: "我把奶量和日程信息整理一下～" };
  if (["milk_assessment_evaluate", "infant_growth_evaluate", "risk_evaluate"].includes(normalizedToolName)) return { title: "我把评估结果整理一下～" };
  if (normalizedToolName === "milk_plan_preview") return { title: "我再完善一下计划草稿～" };
  if (normalizedToolName === "milk_calendar_change_preview" || normalizedToolName === "milk_calendar_reschedule_preview") return { title: "我把调整后的安排整理一下～" };
  if (["milk_record_mutate", "milk_task_complete", "milk_plan_mutate", "milk_calendar_mutate", "infant_growth_mutate"].includes(normalizedToolName)) return { title: "我在保存这次修改～" };
  if (normalizedToolName === "hospital_bag_pump_recommend") return { title: "我把推荐结果整理一下～" };
  if (normalizedToolName === "hospital_bag_cart_update") return { title: "我在保存购物车修改～" };
  if (normalizedToolName === "device_manual_search") return { title: "我把设备内容整理一下～" };
  if (normalizedToolName === "support_ticket_draft_create") return { title: "我在准备售后信息表～" };

  switch (toolWorkPhase(toolName)) {
    case "select":
      return { title: "我找到合适的方案啦" };
    case "read":
      return { title: "我把相关信息整理一下～" };
    case "evaluate":
      return { title: "我把评估结果整理一下～" };
    case "prepare_result":
      return { title: "我在把结果整理出来～" };
    case "preview":
      return { title: "我在生成预览～" };
    case "save":
      return { title: "我在保存这次修改～" };
    case "process":
      return { title: "我继续处理一下～" };
    default:
      return { title: "我继续处理一下～" };
  }
}

function toolResultCopy(toolName: string, result: Record<string, unknown> | null): { title: string; detail?: string } {
  const normalizedToolName = normalizeToolName(toolName);
  const errObj = result?.error && typeof result.error === "object" ? (result.error as Record<string, unknown>) : null;
  const errorMessage = coalesceString(errObj?.message) || "这个步骤没有成功完成。";
  if (result?.ok === false) {
    return { title: "这一步暂时没处理好", detail: errorMessage };
  }
  const status = coalesceString(result?.status);
  if (status.startsWith("needs_")) {
    return { title: "我还需要先确认几件事～" };
  }
  if (status === "plan_preview_needs_revision") {
    return { title: "这版结果还需要再调一下", detail: "保存前我还不能确认。" };
  }
  if (status === "plan_preview_not_recommended") {
    return { title: "这版方案我不建议继续用" };
  }
  if (status === "plan_preview_needs_medical_confirmation") {
    return { title: "我需要先确认健康边界～" };
  }
  if (result?.requires_confirmation === true) {
    return { title: "我已经准备好预览，等你确认～", detail: "确认后才会生效。" };
  }
  if (normalizedToolName === "milk_record_mutate") return { title: milkMutationResultTitle(result, "我已经保存好这条记录啦") };
  if (normalizedToolName === "milk_plan_mutate") return { title: milkMutationResultTitle(result, "我已经保存好奶量计划啦") };
  if (normalizedToolName === "milk_calendar_mutate") return { title: milkMutationResultTitle(result, "我已经保存好日程调整啦") };
  if (normalizedToolName === "milk_task_complete") return { title: milkTaskResultTitle(result) };
  if (normalizedToolName === "infant_growth_mutate") return { title: milkMutationResultTitle(result, "我已经保存好宝宝成长记录啦") };
  if (normalizedToolName === "tool_search" || normalizedToolName === "tool_search_call") return { title: "我在执行这个方案啦～" };
  if (normalizedToolName === "load_skill") return { title: "我准备好继续处理啦" };
  if (normalizedToolName === "profile_get") return { title: "我看过你的基础信息啦" };
  if (normalizedToolName === "milk_records_query") return { title: "我把吸奶和喂养记录整理好啦" };
  if (normalizedToolName === "milk_status_query") return { title: "我看好今天的奶量状态啦" };
  if (normalizedToolName === "milk_snapshot_get") return { title: "我把奶量情况整理好啦" };
  if (normalizedToolName === "milk_calendar_query") return { title: "我把计划和日程整理好啦" };
  if (normalizedToolName === "milk_plan_query") return { title: "我看好之前的奶量计划啦" };
  if (normalizedToolName === "milk_assessment_evaluate") return { title: "我完成奶量评估啦" };
  if (normalizedToolName === "infant_growth_evaluate") return { title: "我完成宝宝生长评估啦" };
  if (normalizedToolName === "risk_evaluate") return { title: "我确认好安全边界啦" };
  if (normalizedToolName === "milk_plan_preview") return { title: "我拟好奶量计划草稿啦" };
  if (normalizedToolName === "milk_calendar_change_preview" || normalizedToolName === "milk_calendar_reschedule_preview") return { title: "我整理好日程调整预览啦" };
  if (["ui_form_create", "birth_plan_form_create", "hospital_bag_form_create"].includes(normalizedToolName)) return { title: "我已经准备好确认内容啦" };
  if (normalizedToolName === "labor_communication_card_create") return { title: "我已经帮你整理好分娩沟通单啦" };
  if (normalizedToolName === "birth_journey_plan_card_create") return { title: "我已经帮你整理好生产全过程计划啦" };
  if (normalizedToolName === "birth_journey_plan_delete") {
    if (status === "needs_delete_confirmation") return { title: "删除前还需要你确认一下" };
    if (status === "plan_not_found") return { title: "当前没有生产全过程计划可删除" };
    if (status === "plan_deleted") return { title: "我已经删除生产全过程计划啦" };
    return { title: "删除生产全过程计划暂时没成功" };
  }
  if (normalizedToolName === "pregnancy_diary_manage") {
    if (status === "needs_delete_confirmation") return { title: "删除前还需要你确认一下" };
    if (status === "entry_not_found") return { title: "没有找到这条孕期日记" };
    if (status === "diary_entry_deleted") return { title: "我已经删除这条孕期日记啦" };
    if (status === "diary_entry_created" || status === "diary_entry_updated") return { title: "我已经保存好孕期日记啦" };
    if (status === "diary_list_read" || status === "diary_entry_read") return { title: "我看好孕期日记啦" };
    return { title: "孕期日记这一步处理好了" };
  }
  if (normalizedToolName === "hospital_bag_card_create") return { title: "我已经帮你生成好待产包清单啦" };
  if (normalizedToolName === "ibclc_consult_card_create") return { title: "我已经准备好 IBCLC 咨询入口啦" };
  if (normalizedToolName === "hospital_bag_pump_recommend") return { title: "我已经帮你整理好吸奶器推荐啦" };
  if (normalizedToolName === "hospital_bag_cart_update") {
    const status = coalesceString(result?.status);
    if (status === "needs_clarification" || status === "cart_unchanged") return { title: "这次购物车先不改" };
    return { title: "我已经帮你更新好待产包购物车啦" };
  }
  if (normalizedToolName === "device_manual_search") return { title: "我把设备资料整理好啦" };
  if (normalizedToolName === "support_ticket_draft_create") return { title: "请确认售后信息" };
  if (["read_skill_file", "search_skill_assets", "knowledge_search", "memory_search"].includes(normalizedToolName)) return { title: "我找到相关资料啦" };
  if (normalizedToolName === "reminder_list") return { title: "我看好提醒啦" };
  if (normalizedToolName === "run_approved_skill_script") return { title: "这一步处理好啦" };

  switch (toolWorkPhase(toolName)) {
    case "select":
      return { title: "我在执行这个方案啦～" };
    case "read":
      return { title: "我看好相关信息啦" };
    case "evaluate":
      return { title: "我完成评估啦" };
    case "prepare_result":
    case "preview":
      return { title: "我准备好结果啦" };
    case "save":
      return { title: "我保存好修改啦" };
    case "process":
      return { title: "这一步处理好啦" };
    default:
      return { title: "这一步处理好啦" };
  }
}

export type AgUiSemanticPhase =
  | "thinking"
  | "reading"
  | "evaluating"
  | "planning"
  | "saving"
  | "confirming"
  | "replying"
  | "done"
  | "error"
  | "working";

export type AgUiSemanticVisibility = "hidden" | "status" | "work_item" | "artifact" | "action";

export type AgUiEventSemantic = {
  phase: AgUiSemanticPhase;
  label: string;
  visibility: AgUiSemanticVisibility;
  mergeKey: string;
  priority: number;
};

const AG_UI_SEMANTIC_PHASES = new Set<AgUiSemanticPhase>([
  "thinking",
  "reading",
  "evaluating",
  "planning",
  "saving",
  "confirming",
  "replying",
  "done",
  "error",
  "working",
]);

const AG_UI_SEMANTIC_VISIBILITIES = new Set<AgUiSemanticVisibility>([
  "hidden",
  "status",
  "work_item",
  "artifact",
  "action",
]);

function semanticPayload(
  phase: AgUiSemanticPhase,
  label: string,
  visibility: AgUiSemanticVisibility,
  mergeKey: string,
  priority = 0,
): AgUiEventSemantic {
  return { phase, label, visibility, mergeKey, priority };
}

function normalizeSemanticPhase(value: unknown): AgUiSemanticPhase {
  const token = coalesceString(value) as AgUiSemanticPhase;
  return AG_UI_SEMANTIC_PHASES.has(token) ? token : "working";
}

function normalizeSemanticVisibility(value: unknown): AgUiSemanticVisibility {
  const token = coalesceString(value) as AgUiSemanticVisibility;
  return AG_UI_SEMANTIC_VISIBILITIES.has(token) ? token : "hidden";
}

function readExplicitSemantic(rec: Record<string, unknown>): AgUiEventSemantic | null {
  const raw = asRecord(rec.semantic);
  if (!raw) return null;
  const phase = normalizeSemanticPhase(raw.phase);
  const visibility = normalizeSemanticVisibility(raw.visibility);
  const label = typeof raw.label === "string" ? raw.label.trim() : "";
  const mergeKey =
    coalesceString(raw.merge_key) ||
    coalesceString(raw.mergeKey) ||
    coalesceString(rec.tool_call_id) ||
    coalesceString(rec.run_id) ||
    coalesceString(rec.message_id) ||
    "event:current";
  const priority = typeof raw.priority === "number" && Number.isFinite(raw.priority) ? raw.priority : 0;
  return { phase, label, visibility, mergeKey, priority };
}

function toolSemanticPhase(toolName: string): AgUiSemanticPhase {
  switch (toolWorkPhase(toolName)) {
    case "select":
      return "thinking";
    case "read":
      return "reading";
    case "evaluate":
      return "evaluating";
    case "prepare_result":
    case "preview":
      return "planning";
    case "save":
      return "saving";
    case "process":
      return "working";
    default:
      return "working";
  }
}

function toolSemanticForEvent(
  eventType: string,
  toolName: string,
  parsedResult: Record<string, unknown> | null,
): AgUiEventSemantic {
  const phase = eventType === "TOOL_CALL_RESULT" && parsedResult?.ok === false ? "error" : toolSemanticPhase(toolName);
  if (eventType === "TOOL_CALL_RESULT") {
    return semanticPayload(phase, toolResultCopy(toolName, parsedResult).title, "work_item", `tool:${normalizeToolName(toolName) || "current"}`, 50);
  }
  if (eventType === "TOOL_CALL_END") {
    return semanticPayload(phase, toolEndCopy(toolName).title, "work_item", `tool:${normalizeToolName(toolName) || "current"}`, 50);
  }
  return semanticPayload(phase, toolStartCopy(toolName).title, "work_item", `tool:${normalizeToolName(toolName) || "current"}`, 50);
}

function statusSemanticFromText(raw: string): AgUiEventSemantic {
  const label = labelForStatus(raw);
  const visibility = label && !isThinkingStatusLine(raw) ? "status" : "hidden";
  const phase: AgUiSemanticPhase = raw.includes("failed") || raw.includes("失败") ? "error" : "thinking";
  return semanticPayload(phase, label, visibility, `status:${raw || "current"}`, 20);
}

function artifactSemanticFromEvent(rec: Record<string, unknown>): AgUiEventSemantic {
  const artifactType = normalizeArtifactType(rec.artifact_type);
  const artifactId = coalesceString(rec.artifact_id) || coalesceString(rec.artifactId) || "current";
  if (artifactType === "form") {
    return semanticPayload("done", "我已经准备好确认内容啦", "artifact", `artifact:${artifactId}`, 70);
  }
  if (artifactType === "support_ticket" || artifactType === "support_ticket_draft") {
    return semanticPayload("done", "请确认售后信息", "artifact", `artifact:${artifactId}`, 70);
  }
  if (artifactType === "milk_plan_card" || artifactType === "milk_analysis_card") {
    return semanticPayload("done", "我已经整理好奶量计划啦", "artifact", `artifact:${artifactId}`, 70);
  }
  return semanticPayload("done", "我已经整理好结果啦", "artifact", `artifact:${artifactId}`, 70);
}

function conversationalConfirmationTitle(title: string): string {
  const t = title.trim();
  if (!t) return "我需要你确认一下，再继续处理";
  if (t === "请确认后继续" || t === "需要你确认后再继续") return "我需要你确认一下，再继续处理";
  if (t.startsWith("请确认")) return `我需要你确认${t.slice("请确认".length) || "一下"}`;
  if (t.startsWith("需要先确认")) return `我需要先确认${t.slice("需要先确认".length)}`;
  return t;
}

export function semanticForAgUiEvent(
  data: Record<string, unknown>,
  eventType = resolveAgUiEventType(data),
  parsedResult: Record<string, unknown> | null = null,
): AgUiEventSemantic {
  const explicit = readExplicitSemantic(data);
  if (explicit) return explicit;

  if (eventType === "RUN_STARTED") {
    return semanticPayload("thinking", RUN_STARTED_WORK_ROW_TITLE, "status", `run:${coalesceString(data.run_id) || "current"}`, 10);
  }
  if (eventType === "RUN_FINISHED") {
    return semanticPayload("done", "我处理好啦", "hidden", `run:${coalesceString(data.run_id) || "current"}`, 100);
  }
  if (eventType === "RUN_ERROR") {
    return semanticPayload("error", "这轮暂时没处理好", "status", `run_error:${coalesceString(data.code) || "current"}`, 100);
  }
  if (eventType === "QUICK_REPLIES") {
    return semanticPayload("done", "我准备好几个下一步选项啦", "hidden", `quick_replies:${coalesceString(data.message_id) || "current"}`, 80);
  }
  if (eventType === "TEXT_MESSAGE_START") {
    return semanticPayload("replying", "我在组织回复～", "hidden", `text:${coalesceString(data.message_id) || "current"}`, 40);
  }
  if (eventType === "TEXT_MESSAGE_CONTENT") {
    return semanticPayload("replying", "我在回复你～", "hidden", `text:${coalesceString(data.message_id) || "current"}`, 40);
  }
  if (eventType === "TEXT_MESSAGE_END") {
    return semanticPayload("done", "我整理好回复啦", "hidden", `text:${coalesceString(data.message_id) || "current"}`, 80);
  }
  if (eventType === "CUSTOM") {
    const name = coalesceString(data.name);
    if (name === "momcozy.agent.thinking") {
      const value = asRecord(data.value);
      const status = coalesceString(value?.status).toLowerCase();
      const metadata = asRecord(value?.metadata);
      if (status === "started" || status === "running") {
        const label = metadata?.after_output_text === true ? "我在准备下一步～" : "我想一下";
        return semanticPayload("thinking", label, "status", "thinking:current", 40);
      }
      return semanticPayload(status === "failed" ? "error" : "done", status === "failed" ? "这一步我还没想清楚" : "我想好啦", "hidden", "thinking:current", 40);
    }
    const statusLine = extractAgentStatusLineFromCustom(data) ?? "";
    return statusSemanticFromText(statusLine);
  }
  if (eventType === "ACTIVITY_SNAPSHOT") {
    const content = asRecord(data.content);
    const meta = asRecord(content?.metadata);
    const statusLine = extractStatusLineFromMetadata(meta);
    return statusSemanticFromText(statusLine);
  }
  if (eventType === "STEP_STARTED" || eventType === "STEP_FINISHED") {
    const stepName = coalesceString(data.step_name) || coalesceString(data.stepName) || coalesceString(data.name) || "step";
    const started = eventType === "STEP_STARTED";
    if (stepName === "routing") {
      return semanticPayload(started ? "thinking" : "done", started ? "我先理解一下你的需求～" : "我判断好你的需求啦", "status", `step:${stepName}`, 30);
    }
    return semanticPayload(started ? "working" : "done", started ? "我先处理这一步～" : "这一步处理好啦", "status", `step:${stepName}`, 30);
  }
  if (eventType.startsWith("TOOL_CALL")) {
    return toolSemanticForEvent(eventType, readToolName(data), parsedResult);
  }
  if (eventType === "ARTIFACT_CREATED" || eventType === "artifact_created") {
    return artifactSemanticFromEvent(data);
  }
  if (eventType === "CONFIRMATION_REQUIRED") {
    const confirmationId = coalesceString(data.confirmation_id) || coalesceString(data.confirmationId) || "current";
    return semanticPayload("confirming", conversationalConfirmationTitle(coalesceString(data.title)), "action", `confirmation:${confirmationId}`, 90);
  }
  return semanticPayload("working", "", "hidden", `event:${eventType || "unknown"}`, 0);
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
  const voice = normalizeMediaVoiceNarrationItems(payload.voice ?? payload.media_voice ?? payload.mediaVoice);
  if (
    !coalesceString(payload.title) &&
    !coalesceString(payload.content) &&
    button.length === 0 &&
    card.length === 0 &&
    action.length === 0 &&
    voice.length === 0
  ) {
    return null;
  }
  return {
    title: coalesceString(payload.title),
    content: coalesceString(payload.content),
    button: button as ChatRichTextPayload["button"],
    card: card as ChatRichTextPayload["card"],
    action,
    ...(voice.length > 0 ? { voice } : {}),
  };
}

function artifactActionFromToolResultPayload(parsed: Record<string, unknown>): Record<string, unknown> | null {
  const toolName = normalizeToolName(coalesceString(parsed.tool_name) || coalesceString(parsed.toolName));
  const form = asRecord(parsed.form);
  const artifactId = coalesceString(parsed.artifact_id) || coalesceString(parsed.artifactId);
  const identity = artifactId ? { artifact_id: artifactId } : {};
  if (["ui_form_create", "birth_plan_form_create", "hospital_bag_form_create"].includes(toolName) && form) {
    return { kind: "ag_ui_artifact", artifact_type: "form", ...identity, form };
  }

  const card = asRecord(parsed.card);
  if (["labor_communication_card_create", "birth_journey_plan_card_create", "hospital_bag_card_create"].includes(toolName) && card) {
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

function isAgUiArtifactAction(action: unknown): boolean {
  const obj = asRecord(action);
  if (!obj || coalesceString(obj.kind) !== "ag_ui_artifact") return false;
  return Boolean(normalizeArtifactType(obj.artifact_type));
}

function isFormLikeArtifactAction(action: unknown): boolean {
  const obj = asRecord(action);
  if (!obj || coalesceString(obj.kind) !== "ag_ui_artifact") return false;
  const artifactType = normalizeArtifactType(obj.artifact_type);
  return artifactType === "form" || artifactType === "support_ticket" || artifactType === "support_ticket_draft";
}

function richTextPayloadHasAgUiArtifact(payload: ChatRichTextPayload | undefined): boolean {
  return Boolean(payload?.action?.some(isAgUiArtifactAction));
}

function messageHasAgUiArtifact(message: ChatMessage): boolean {
  if (richTextPayloadHasAgUiArtifact(message.richText)) return true;
  return Boolean(
    message.streamRenderItems?.some((item) =>
      item.kind === "rich" && richTextPayloadHasAgUiArtifact(item.payload)
    ),
  );
}

function withoutQuickReplies(message: ChatMessage): ChatMessage {
  if (!message.quickReplies) return message;
  const { quickReplies: _quickReplies, ...rest } = message;
  return rest;
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
    voice: mergeRichVoice(prev.voice, next.voice),
  };
}

function mergeRichVoice(
  prev: ChatRichTextPayload["voice"] | undefined,
  next: ChatRichTextPayload["voice"] | undefined,
): ChatRichTextPayload["voice"] | undefined {
  const merged = normalizeMediaVoiceNarrationItems([...(prev ?? []), ...(next ?? [])]);
  return merged.length > 0 ? merged : undefined;
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
    onMediaVoice?: (items: MediaVoiceNarrationItem[]) => void;
    deferAgUiArtifacts?: boolean;
    onAgUiArtifactRichText?: (payload: ChatRichTextPayload, meta: { formLike: boolean }) => void;
  },
): ApplyAgUiSideEffectResult {
  if (typeof data !== "object" || data == null) return { didUpdate: false };
  const rec = data as Record<string, unknown>;
  const eventType = resolveAgUiEventType(data);
  const parsedToolResult = eventType === "TOOL_CALL_RESULT" ? parseToolResultPayload(rec.content) : null;
  maybeNotifyBirthJourneyPlanDeleted(parsedToolResult);
  maybeNotifyPregnancyDiaryChanged(parsedToolResult);
  if (eventType === "TOOL_CALL_RESULT") {
    const mediaVoice = normalizeMediaVoiceNarrationItems(
      parsedToolResult?.media_voice ?? parsedToolResult?.mediaVoice ?? parsedToolResult?.voice,
    );
    if (mediaVoice.length > 0) {
      opts?.onMediaVoice?.(mediaVoice);
    }
  }
  const semantic = semanticForAgUiEvent(rec, eventType, parsedToolResult);
  let didUpdate = false;

  const patchMsg = (fn: (m: ChatMessage) => ChatMessage) => {
    didUpdate = true;
    setMessages((prev) => prev.map((m) => (m.id === replyId ? fn(m) : m)));
  };

  if (eventType === "QUICK_REPLIES") {
    const replies = readQuickReplies(rec.replies);
    if (replies.length === 3) {
      didUpdate = true;
      setMessages((prev) => {
        const latestMessage = prev.at(-1);
        const canAttachToReply = latestMessage?.id === replyId && latestMessage.role === "mai";
        return prev.map((m) => ({
          ...withoutQuickReplies(m),
          ...(canAttachToReply && m.id === replyId && !messageHasAgUiArtifact(m) ? { quickReplies: replies } : {}),
        }));
      });
    }
  }

  if (eventType === "RUN_STARTED") {
    const startedAt = nowMs();
    const skills = extractLoadedSkillIds(rec);
    const statusLine = extractStatusLineFromMetadata(rec.metadata) || "Agent loop started.";
    patchMsg((m) => ({
      ...m,
      ...(skills.length > 0 ? { agentLoadedSkillIds: skills } : {}),
      agentStatusLine: labelForStatus(statusLine),
      agentStatusDone: false,
      agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
      agentWorkFinishedAtMs: undefined,
      agentToolCalls: withRunStartedWorkRow(
        m.agentToolCalls ?? [],
        RUN_STARTED_WORK_ROW_TITLE,
      ),
    }));
  }

  if (eventType === "CUSTOM") {
    if (String(rec.name ?? "") === WEB_SEARCH_STATUS_CUSTOM_NAME) {
      const search = readWebSearchStatus(rec.value);
      const startedAt = nowMs();
      patchMsg((m) => ({
        ...m,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertWebSearchWorkRow(m.agentToolCalls ?? [], search),
      }));
      return { didUpdate };
    }
    if (String(rec.name ?? "") === WEB_SEARCH_CITATIONS_CUSTOM_NAME) {
      const citations = readWebSearchCitations(rec.value);
      if (citations.length > 0) {
        patchMsg((m) => ({ ...m, citations }));
      }
      return { didUpdate };
    }
    const statusLine = extractAgentStatusLineFromCustom(rec);
    if (statusLine && !isThinkingStatusLine(statusLine)) {
      const nextStatusLine = semantic.visibility === "hidden" ? "" : semantic.visibility === "status" ? semantic.label : labelForStatus(statusLine);
      patchMsg((m) => ({ ...m, agentStatusLine: nextStatusLine, agentStatusDone: false }));
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
      agentStatusLine: semantic.visibility === "status" ? semantic.label : labelForStatus("Answer ready."),
      agentStatusDone: true,
    }));
  }

  if (eventType === "RUN_FINISHED") {
    const finishedAt = nowMs();
    patchMsg((m) => ({
      ...m,
      agentThinkingTitle: undefined,
      agentStatusLine: semantic.visibility === "status" ? semantic.label : labelForStatus("Run finished."),
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
          const nextStatusLine = semantic.visibility === "hidden" ? "" : semantic.visibility === "status" ? semantic.label : labelForStatus(statusLine);
          patchMsg((m) => ({ ...m, agentStatusLine: nextStatusLine, agentStatusDone: false }));
        }
      }
    }
  }

  if (eventType === "STEP_STARTED" || eventType === "STEP_FINISHED") {
    const stepName = coalesceString(rec.step_name) || coalesceString(rec.stepName) || coalesceString(rec.name) || "step";
    const text = semantic.visibility === "status" ? semantic.label : labelForStep(stepName, eventType === "STEP_STARTED" ? "started" : "finished");
    patchMsg((m) => ({ ...m, agentStatusLine: text, agentStatusDone: false }));
  }

  const toolKeys = readToolCallKeys(rec);
  if (toolKeys.length > 0 && eventType === "TOOL_CALL_START") {
    const startedAt = nowMs();
    const toolName = readToolName(rec);
    const copy = toolStartCopy(toolName);
    const title = semantic.visibility === "work_item" && semantic.label ? semantic.label : copy.title;
    patchMsg((m) => {
      const baseTools = withoutRunStartedWorkRow(m.agentToolCalls ?? []);
      return {
        ...m,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(baseTools, toolKeys, {
          kind: "tool",
          name: toolName,
          title,
          state: "running",
          argsDigest: "",
        }),
      };
    });
  } else if (toolKeys.length > 0 && eventType === "TOOL_CALL_ARGS") {
    const startedAt = nowMs();
    const toolName = readToolName(rec);
    patchMsg((m) => {
      const baseTools = withoutRunStartedWorkRow(m.agentToolCalls ?? []);
      const curIdx = findToolRowIndex(baseTools, toolKeys, toolName, true);
      if (curIdx >= 0) {
        return {
          ...m,
          agentThinkingTitle: undefined,
          agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
          agentWorkFinishedAtMs: undefined,
        };
      }
      const copy = toolArgsCopy(toolName);
      const title = semantic.visibility === "work_item" && semantic.label ? semantic.label : copy.title;
      return {
        ...m,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          baseTools,
          toolKeys,
          {
            kind: "tool",
            name: toolName,
            title,
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
    const title = semantic.visibility === "work_item" && semantic.label ? semantic.label : copy.title;
    patchMsg((m) => {
      const baseTools = withoutRunStartedWorkRow(m.agentToolCalls ?? []);
      return {
        ...m,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          baseTools,
          toolKeys,
          {
            kind: "tool",
            name: toolName,
            title,
            argsDigest: copy.detail ?? undefined,
          },
          { mergeRunning: true },
        ),
      };
    });
  } else if (toolKeys.length > 0 && eventType === "TOOL_CALL_RESULT") {
    const parsed = parsedToolResult;
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
    const title = semantic.visibility === "work_item" && semantic.label ? semantic.label : copy.title;
    const summary = copy.detail || (parsed ? summarizeToolResult(parsed) : coalesceString(rec.content) || "Result");
    const ok = parsed?.ok;
    const startedAt = nowMs();
    patchMsg((m) => {
      const baseTools = withoutRunStartedWorkRow(m.agentToolCalls ?? []);
      return {
        ...m,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          baseTools,
          toolKeys,
          {
            kind: "tool",
            name: normalizedToolName,
            title,
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
      if (opts?.deferAgUiArtifacts) {
        didUpdate = true;
        opts.onAgUiArtifactRichText?.(rich, { formLike: isFormLikeArtifactAction(action) });
        return { didUpdate };
      }
      patchMsg((m) => {
        const next = {
          ...m,
          richText: m.richText ? mergePendingRichTextPayload(m.richText, rich) : rich,
          streamRenderItems: appendRichRenderItem(m.streamRenderItems, rich),
        };
        return isAgUiArtifactAction(action) ? withoutQuickReplies(next) : next;
      });
    }
  }

  if (eventType === "CONFIRMATION_REQUIRED") {
    const startedAt = nowMs();
    const confirmationId = coalesceString(rec.confirmation_id) || coalesceString(rec.confirmationId);
    const artifactId = coalesceString(rec.artifact_id) || coalesceString(rec.artifactId);
    const keys = [...new Set([...toolKeys, confirmationId ? `confirmation:${confirmationId}` : "", artifactId ? `artifact:${artifactId}` : ""].filter(Boolean))];
    const toolName = readToolName(rec);
    const title = semantic.visibility === "action" && semantic.label ? semantic.label : "我需要你确认一下，再继续处理";
    patchMsg((m) => {
      const baseTools = withoutRunStartedWorkRow(m.agentToolCalls ?? []);
      return {
        ...m,
        agentThinkingTitle: undefined,
        agentWorkStartedAtMs: m.agentWorkStartedAtMs ?? startedAt,
        agentWorkFinishedAtMs: undefined,
        agentToolCalls: upsertToolRow(
          baseTools,
          keys,
          {
            kind: "tool",
            name: toolName,
            title,
            argsDigest: "我已经准备好相关内容，等你确认。",
            state: "completed",
          },
          { mergeRunning: true },
        ),
      };
    });
  }

  return { didUpdate };
}
