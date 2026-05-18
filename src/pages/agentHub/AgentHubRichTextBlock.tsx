import React, { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  Baby,
  Banknote,
  BatteryCharging,
  Cable,
  CircleHelp,
  CreditCard,
  CupSoda,
  Droplets,
  FileText,
  Footprints,
  Headphones,
  Heart,
  IdCard,
  Milk,
  Package,
  Shirt,
  Smartphone,
  Stethoscope,
  Utensils,
  type LucideIcon,
} from "lucide-react";
import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { cn } from "@/lib/utils";
import type { ChatRichTextButtonItem, ChatRichTextPayload, ChatRichTextCardItem } from "@/lib/agentApiTypes";
import { log } from "@/lib/logger";
import { ChatMarkdown } from "@/components/chat/ChatMarkdown";
import { tryOpenRichTextOpenButton } from "@/lib/richTextOpenMedia";
import { parseSwitchRouteFromValue } from "./parseSwitchRouteFromValue";
import { toPng } from "html-to-image";
import momcozyLogo from "@/assets/momcozy_logo.png";
import { getAgUiThreadIdForRequest } from "@/lib/agentConversationSession";
import {
  IBCLC_CONSULT_COMPLETED_KEY,
  IBCLC_CONSULT_COMPLETIONS_KEY,
  buildIbclcChatUrl,
  isIbclcCompletionForCard,
  rememberIbclcReturnTo,
  rememberIbclcReturnViewport,
  readStoredIbclcConsultCompletions,
  stableIbclcConsultId,
  type IbclcConsultCompletedPayload,
} from "@/lib/ibclcConsult";

/**
 * chat-messages 富文本卡片（标题、正文、结构化卡片与按钮）。
 * open / switch / 默认续聊交由回调或路由处理。
 */
type ButtonSelectOptions = { displayText?: string };

export type IbclcConsultOpenRequest = {
  consultId: string;
  threadId: string;
  returnTo: string;
  chatUrl: string;
};

type FormFieldSpec = {
  id: string;
  label: string;
  type: string;
  required?: boolean;
  options?: string[];
  default_value?: unknown;
  placeholder?: string;
  help_text?: string;
};

const MOMCOZY_LOGO_SRC = momcozyLogo;

function asObject(v: unknown): Record<string, unknown> | null {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
}

function asString(v: unknown): string {
  return typeof v === "string" ? v : "";
}

function nearestScrollableParent(node: HTMLElement | null): HTMLElement | null {
  let current = node?.parentElement ?? null;
  while (current && current !== document.body) {
    const style = window.getComputedStyle(current);
    if (/(auto|scroll)/.test(style.overflowY) && current.scrollHeight > current.clientHeight) {
      return current;
    }
    current = current.parentElement;
  }
  return null;
}

function rememberIbclcViewportForNode(node: HTMLElement | null, returnTo: string, consultId: string): void {
  const scroller = nearestScrollableParent(node);
  if (!scroller) return;
  rememberIbclcReturnViewport({
    returnTo,
    consultId,
    scrollTop: scroller.scrollTop,
    scrollHeight: scroller.scrollHeight,
  });
}

function hasDisplayValue(value: unknown): boolean {
  if (value === null || value === undefined || value === "") return false;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === "object") return Object.keys(value as Record<string, unknown>).length > 0;
  return true;
}

function normalizeList(values: unknown): unknown[] {
  if (!Array.isArray(values)) return [];
  return values.filter(hasDisplayValue);
}

function formatPlainValue(value: unknown): string {
  if (Array.isArray(value)) return value.map((x) => String(x)).join(", ");
  if (value && typeof value === "object") return JSON.stringify(value);
  return String(value ?? "");
}

function formatLabel(key: string): string {
  return String(key)
    .replace(/_/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function isMultiSelectField(field: FormFieldSpec): boolean {
  return ["multi_select", "checkbox_group"].includes(field.type);
}

function defaultMultiSelectValues(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function collectFormValues(form: HTMLFormElement, fields: FormFieldSpec[]): Record<string, unknown> {
  const data = new FormData(form);
  const values: Record<string, unknown> = {};
  for (const field of fields) {
    values[field.id] = isMultiSelectField(field) ? data.getAll(field.id).map(String) : String(data.get(field.id) ?? "");
  }
  return values;
}

function buildFormConfirmationMessage(form: Record<string, unknown>, values: Record<string, unknown>): string {
  return [
    `我已确认 ${asString(form.title) || "表单"} 信息，请基于这些信息生成对应卡片。`,
    `form_id: ${asString(form.id) || "form"}`,
    "confirmed_form_data:",
    JSON.stringify(values, null, 2),
  ].join("\n");
}

function supportTicketIssueLabel(value: unknown): string {
  const labels: Record<string, string> = {
    malfunction: "设备故障",
    missing_parts: "缺少配件",
    defect: "疑似质量问题",
    warranty: "保修",
    return_or_refund: "退换货/退款",
    order_or_shipping: "订单/物流",
    usage_help: "使用帮助",
    safety_concern: "安全问题",
    other: "其他",
  };
  const key = asString(value);
  return labels[key] || "其他";
}

function supportTicketUrgencyLabel(value: unknown): string {
  const labels: Record<string, string> = { normal: "普通", high: "较急", safety: "安全相关" };
  return labels[asString(value)] || "普通";
}

function initialsForName(name: string): string {
  const parts = String(name || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length >= 2) return `${Array.from(parts[0])[0] ?? ""}${Array.from(parts[1])[0] ?? ""}`.toUpperCase();
  const compact = parts[0] || "IBCLC";
  return Array.from(compact).slice(0, 2).join("").toUpperCase();
}

function supportTicketFields(ticket: Record<string, unknown>): FormFieldSpec[] {
  return [
    {
      id: "issue_type",
      label: "问题类型",
      type: "select",
      required: true,
      default_value: supportTicketIssueLabel(ticket.issue_type),
      options: ["设备故障", "缺少配件", "疑似质量问题", "保修", "退换货/退款", "订单/物流", "使用帮助", "安全问题", "其他"],
    },
    {
      id: "issue_summary",
      label: "问题描述",
      type: "textarea",
      required: true,
      default_value: asString(ticket.issue_summary),
      placeholder: "简单描述你遇到的问题",
    },
    {
      id: "product_model",
      label: "产品型号",
      type: "text",
      default_value: asString(ticket.product_model),
      placeholder: "例如：M5、S12 Pro，或暂不确定",
    },
    {
      id: "urgency",
      label: "紧急程度",
      type: "select",
      required: true,
      default_value: supportTicketUrgencyLabel(ticket.urgency),
      options: ["普通", "较急", "安全相关"],
    },
  ];
}

function buildSupportTicketSubmittedMessage(ticket: Record<string, unknown>): string {
  const lines = [
    "客服工单已模拟提交成功。请基于以下提交信息，给用户一段简短的情绪支持。",
    ticket.issue_type ? `问题类型：${ticket.issue_type}` : "",
    ticket.issue_summary ? `问题描述：${ticket.issue_summary}` : "",
    ticket.product_model ? `产品型号：${ticket.product_model}` : "",
    ticket.urgency ? `紧急程度：${ticket.urgency}` : "",
    "回复要求：不要重复工单字段，不要继续排查；根据用户的主要售后情绪做 1-3 句贴合场景的承接，并告诉用户人工客服会在 24 小时内联系你解决问题。",
  ];
  return lines.filter(Boolean).join("\n");
}

function isConfirmPlaceholder(value: unknown): boolean {
  const text = String(value ?? "").trim().toLowerCase();
  return text === "to confirm" || text === "待确认";
}

function limitList(values: unknown, maxItems: number): unknown[] {
  return normalizeList(values).slice(0, maxItems);
}

function compactBirthPlanList(values: unknown, maxItems: number): string[] {
  const flatten = (value: unknown): string[] => {
    if (Array.isArray(value)) return value.flatMap(flatten);
    if (value && typeof value === "object") return Object.values(value).flatMap(flatten);
    if (!hasDisplayValue(value)) return [];
    return [formatPlainValue(value)];
  };
  return flatten(values)
    .map(normalizeBirthPlanValue)
    .filter((value) => value && !isConfirmPlaceholder(value))
    .filter((value, index, arr) => arr.indexOf(value) === index)
    .slice(0, maxItems);
}

function normalizeBirthPlanValue(value: unknown): string {
  const text = formatPlainValue(value).trim().replace(/^\s*\d+[.)、．]\s*/, "").replace(/\s+/g, " ");
  const labels: Record<string, string> = {
    "birth plan card": "分娩沟通卡",
    "labor room communication priority card": "产房沟通优先级卡片",
    vaginal: "顺产",
    planned_c_section: "刨腹产",
    c_section: "刨腹产",
    "c-section": "刨腹产",
    cesarean: "刨腹产",
    "计划剖宫产": "刨腹产",
    "剖腹产": "刨腹产",
    "skin-to-skin": "出生后尽早肌肤接触",
    "skin to skin": "出生后尽早肌肤接触",
  };
  return labels[text.toLowerCase()] || labels[text] || text.replace(/skin-to-skin|skin to skin/gi, "出生后尽早肌肤接触");
}

function compactPackingItems(items: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(items)) return [];
  return items.filter((it) => it && typeof it === "object") as Array<Record<string, unknown>>;
}

function compactPackingGroups(groups: unknown): Array<Record<string, unknown> & { items: Array<Record<string, unknown>> }> {
  if (!Array.isArray(groups)) return [];
  return groups
    .filter((g) => g && typeof g === "object")
    .map((group) => {
      const g = group as Record<string, unknown>;
      return {
        ...g,
        items: compactPackingItems(g.items),
      };
    })
    .filter((group) => group.items.length > 0);
}

function priorityLabel(priority: unknown): string {
  const labels: Record<string, string> = {
    must: "必带",
    recommended: "建议",
    nice_to_have: "可选",
    confirm_first: "先确认",
  };
  const key = String(priority ?? "");
  return labels[key] || formatLabel(key);
}

function priorityClassName(priority: unknown): string {
  const key = String(priority ?? "");
  if (key === "must") return "priority priority-must";
  if (key === "confirm_first" || key === "先确认") return "priority priority-confirm-first";
  return "priority";
}

function isConfirmFirstPackingItem(item: Record<string, unknown>): boolean {
  const priority = asString(item.priority);
  return priority === "confirm_first" || priority === "先确认";
}

function itemBelongsToGroup(item: Record<string, unknown>, group: Record<string, unknown>, tokens: string[]): boolean {
  const text = `${asString(group.group_id)} ${asString(group.title)} ${asString(item.label)}`.toLowerCase();
  return tokens.some((token) => text.includes(token));
}

function isDocumentPackingItem(item: Record<string, unknown>, group: Record<string, unknown>): boolean {
  return itemBelongsToGroup(item, group, ["documents", "certificate", "证件", "资料", "身份证", "医保", "产检", "准生证", "户口本"]);
}

function isCommunicationPackingItem(item: Record<string, unknown>, group: Record<string, unknown>): boolean {
  const label = asString(item.label);
  if (/(吸管杯|水杯|餐具|纸杯)/.test(label)) return false;
  return itemBelongsToGroup(item, group, ["communication", "通讯", "随身", "手机", "充电", "耳机", "power bank"]);
}

function normalizedPackingItemLabel(item: Record<string, unknown>, group: Record<string, unknown>): string {
  const label = asString(item.label) || formatPlainValue(item);
  if (isDocumentPackingItem(item, group)) {
    return label.replace(/及复印件/g, "").replace(/和复印件/g, "").replace(/\/复印件/g, "").trim();
  }
  return label;
}

function inferredCopyRequirement(item: Record<string, unknown>, group: Record<string, unknown>): string {
  if (!isDocumentPackingItem(item, group)) return "";
  const explicit = asString(item.copy_requirement);
  if (explicit) return explicit;
  const label = asString(item.label);
  const quantity = asString(item.quantity);
  if (/复印件/.test(label)) return asString(item.priority) === "confirm_first" || /按医院/.test(quantity) ? "按医院要求确认" : "原件+复印件";
  if (/(身份证|医保|产检)/.test(label)) return "原件";
  return "";
}

function packingItemMeta(item: Record<string, unknown>, group: Record<string, unknown>): string {
  if (isConfirmFirstPackingItem(item)) return "";
  if (isCommunicationPackingItem(item, group)) return "";
  return inferredCopyRequirement(item, group) || asString(item.quantity);
}

function packingItemNote(item: Record<string, unknown>): string {
  if (isConfirmFirstPackingItem(item)) return "";
  return asString(item.note);
}

function packingItemText(item: Record<string, unknown>, group: Record<string, unknown>): string {
  const label = normalizedPackingItemLabel(item, group);
  const meta = packingItemMeta(item, group);
  return meta ? `${label} ${meta}` : label;
}

function packingItemIcon(item: Record<string, unknown>, group: Record<string, unknown>): LucideIcon {
  const label = normalizedPackingItemLabel(item, group);
  const text = `${asString(group.group_id)} ${asString(group.title)} ${label}`.toLowerCase();
  if (/(身份证|准生证|户口本|证件|陪产人.*身份)/.test(text)) return IdCard;
  if (/(产检|资料|医保|医保卡|医保本|本|文件|复印)/.test(text)) return FileText;
  if (/(银行卡|现金|支付|移动支付)/.test(text)) return CreditCard;
  if (/(手机$|手机\b|smartphone)/.test(text)) return Smartphone;
  if (/(充电线|充电器|长充电线|cable)/.test(text)) return Cable;
  if (/(充电宝|电池|power bank)/.test(text)) return BatteryCharging;
  if (/(耳机|headphone)/.test(text)) return Headphones;
  if (/(吸管杯|水杯|杯)/.test(text)) return CupSoda;
  if (/(餐具|零食|水和零食|食物|能量|助产食品)/.test(text)) return Utensils;
  if (/(纸尿裤|湿巾|棉柔巾|包被|宝宝|帽子|袜子|安全座椅|安全提篮|出院衣物)/.test(text)) return Baby;
  if (/(出院外套|衣物|衣服|内裤|哺乳衣|睡衣|文胸|背心|拖鞋)/.test(text)) return Shirt;
  if (/(产褥垫|卫生巾|马桶垫|毛巾|纸巾|脸盆|洗发水|沐浴露|洗面奶|护肤|牙刷|牙膏)/.test(text)) return Droplets;
  if (/(吸奶器|储奶|初乳|乳盾|乳头霜|防溢乳垫|奶瓶|配方奶|milk|哺乳)/.test(text)) return Milk;
  if (/(胎监带|收腹带|医生|医院|产后)/.test(text)) return Stethoscope;
  if (/(常用药|药)/.test(text)) return Heart;
  if (/(停车|交通)/.test(text)) return Banknote;
  if (isConfirmFirstPackingItem(item)) return CircleHelp;
  return Package;
}

function flattenPackingGroupItems(groups: Array<Record<string, unknown> & { items: Array<Record<string, unknown>> }>): Array<Record<string, unknown>> {
  return groups.flatMap((group) => group.items.map((item) => ({ ...item, __group: group })));
}

function uniqueDisplayStrings(values: unknown[], maxItems: number): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    const text = formatPlainValue(value).trim();
    if (!text || isConfirmPlaceholder(text) || seen.has(text)) continue;
    seen.add(text);
    result.push(text);
    if (result.length >= maxItems) break;
  }
  return result;
}

function hospitalBagSummaryStrings(values: unknown, maxItems: number): string[] {
  if (!Array.isArray(values)) return [];
  return uniqueDisplayStrings(
    values
      .map((value) => {
        if (value && typeof value === "object" && !Array.isArray(value)) {
          const item = value as Record<string, unknown>;
          const question = asString(item.question);
          const topic = asString(item.topic) || asString(item.label) || asString(item.title);
          if (question) return topic ? `${topic}：${question}` : question;
          const text = asString(item.text) || asString(item.name) || asString(item.label) || asString(item.title);
          const meta = asString(item.copy_requirement) || asString(item.quantity);
          return meta && text ? `${text} ${meta}` : text;
        }
        return value;
      })
      .filter(hasDisplayValue),
    maxItems,
  );
}

function normalizeHospitalQuestionText(value: string): string {
  const text = value.trim();
  if (!text || text.includes("：")) return text;
  if (/准生证|户口本|入院证件/.test(text)) {
    return "准生证/户口本：确认医院是否要求携带原件和复印件，以及复印件份数。";
  }
  if (/医院是否提供.*(产褥垫|纸尿裤|宝宝衣物|毛巾|脸盆)|基础物品/.test(text)) {
    return "产褥垫/纸尿裤/宝宝衣物：确认医院是否提供，避免重复携带。";
  }
  if (/陪产|探视/.test(text)) {
    return "陪产/探视：确认陪产人入院材料、是否允许陪产或过夜。";
  }
  if (/(水|零食|吸管杯|充电宝).*(产房|允许|规则)/.test(text)) {
    return "水/零食/充电宝：确认是否允许带入产房。";
  }
  if (/(乳盾|初乳收集器|吸奶器|奶瓶|配方奶)/.test(text)) {
    return "喂养用品：确认是否允许携带或需要在哺乳指导下使用。";
  }
  const spaceSeparated = text.match(/^([^，。,.]{2,18})\s+(.+)$/);
  if (spaceSeparated) return `${spaceSeparated[1]}：${spaceSeparated[2]}`;
  return text;
}

function hospitalBagQuestionStrings(values: unknown, maxItems: number): string[] {
  return uniqueDisplayStrings(hospitalBagSummaryStrings(values, maxItems * 2).map(normalizeHospitalQuestionText), maxItems);
}

function confirmTextFromPackingItem(item: Record<string, unknown>): string {
  const group = asObject(item.__group) ?? {};
  const question = asString(item.confirm_question);
  const label = normalizedPackingItemLabel(item, group) || "待确认物品";
  if (question) return `${label}：${question}`;
  const note = asString(item.note);
  if (note) return `${label}：${note}`;
  return packingItemText(item, group);
}

function renderHospitalCardValue(value: unknown): React.ReactNode {
  const text = formatPlainValue(value);
  if (isConfirmPlaceholder(value) || isConfirmPlaceholder(text)) {
    return <span className="to-confirm">{text}</span>;
  }
  return text;
}

function hospitalBagMetaValue(value: unknown): unknown {
  const text = String(value ?? "").trim();
  const labels: Record<string, string> = {
    minimal: "极简",
    standard: "标准",
    complete: "完整",
    full: "完整",
    budget: "预算优先",
    budget_first: "预算优先",
    vaginal: "顺产",
    planned_c_section: "刨腹产",
    c_section: "刨腹产",
    "计划剖宫产": "刨腹产",
    "剖腹产": "刨腹产",
    breastfeeding: "母乳",
    formula: "配方",
    formula_feeding: "配方",
    mixed: "混合",
  };
  return labels[text.toLowerCase()] || value;
}

function normalizeBirthPlanCard(cardJsonRaw: Record<string, unknown>) {
  const owner = asObject(cardJsonRaw.owner) ?? {};
  const overview = asObject(cardJsonRaw.overview) ?? {};
  const birthPreferences = asObject(cardJsonRaw.birth_preferences) ?? {};
  return {
    title: normalizeBirthPlanValue(asString(cardJsonRaw.title)) || "分娩沟通卡",
    subtitle: normalizeBirthPlanValue(asString(cardJsonRaw.subtitle)) || "产房沟通优先级卡片",
    overview: {
      due_date_or_week: normalizeBirthPlanValue(overview.due_date_or_week ?? owner.due_date_or_week),
      birth_path: normalizeBirthPlanValue(overview.birth_path ?? birthPreferences.birth_path),
      birth_setting: normalizeBirthPlanValue(overview.birth_setting ?? owner.birth_setting),
      support_people: normalizeBirthPlanValue(overview.support_people ?? owner.support_people),
    },
    top_priorities: compactBirthPlanList(cardJsonRaw.top_priorities ?? asObject(cardJsonRaw.if_plans_change)?.what_matters_most, 3),
    communication: compactBirthPlanList(cardJsonRaw.communication ?? cardJsonRaw.communication_preferences, 3),
    pain_relief: compactBirthPlanList(cardJsonRaw.pain_relief ?? cardJsonRaw.pain_relief_preferences, 3),
    baby_after_birth: compactBirthPlanList(cardJsonRaw.baby_after_birth ?? cardJsonRaw.baby_after_birth_preferences, 3),
    if_plans_change: compactBirthPlanList(cardJsonRaw.if_plans_change, 3),
    questions_for_hospital: compactBirthPlanList(cardJsonRaw.questions_for_hospital, 3),
    medical_notes: compactBirthPlanList(cardJsonRaw.medical_notes, 3),
    personalized_notes: compactBirthPlanList(cardJsonRaw.personalized_notes, 3),
    disclaimer:
      normalizeBirthPlanValue(asString(cardJsonRaw.disclaimer)) ||
      "这张卡只用于沟通。请优先遵循医生和医院建议，尤其是因安全原因需要调整计划时。",
  };
}

function cardSubtitle(values: unknown[]): string {
  return values
    .filter((value) => hasDisplayValue(value) && !isConfirmPlaceholder(value))
    .map((value) => formatPlainValue(value))
    .join(" | ");
}

function cardDownloadFilename(card: Record<string, unknown>): string {
  const type = asString(card.card_type) || "card";
  const date = new Date().toISOString().slice(0, 10);
  return `comate-${type}-${date}.png`.replace(/[^a-z0-9._-]+/gi, "-");
}

async function dataUrlToBlob(dataUrl: string): Promise<Blob> {
  const response = await fetch(dataUrl);
  return response.blob();
}

function triggerImageDownload(dataUrl: string, filename: string): void {
  const link = document.createElement("a");
  link.href = dataUrl;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
}

function dataUrlToBase64(dataUrl: string): string {
  const marker = "base64,";
  const idx = dataUrl.indexOf(marker);
  return idx >= 0 ? dataUrl.slice(idx + marker.length) : "";
}

async function saveImageToAndroidDownloads(dataUrl: string, filename: string): Promise<boolean> {
  if (!Capacitor.isNativePlatform() || Capacitor.getPlatform() !== "android") return false;
  const base64 = dataUrlToBase64(dataUrl);
  if (!base64) return false;
  try {
    await Filesystem.requestPermissions();
  } catch {
    /* 权限弹窗被拒绝时回退到浏览器下载 */
  }
  try {
    await Filesystem.writeFile({
      path: `Download/${filename}`,
      directory: Directory.Documents,
      data: base64,
      recursive: true,
    });
    return true;
  } catch {
    return false;
  }
}

async function shareImageOnMobile(blob: Blob, filename: string): Promise<boolean> {
  const nav = navigator as Navigator & {
    share?: (data: ShareData) => Promise<void>;
    canShare?: (data: ShareData) => boolean;
  };
  const canShareFiles = Boolean(nav.share && nav.canShare && typeof File !== "undefined");
  const mobileViewport = window.matchMedia?.("(max-width: 700px)")?.matches;
  if (!canShareFiles || !mobileViewport) return false;
  const file = new File([blob], filename, { type: "image/png" });
  if (!nav.canShare?.({ files: [file] })) return false;
  try {
    await nav.share?.({ files: [file], title: "CoMate card" });
    return true;
  } catch (error: unknown) {
    const e = error as { name?: string };
    return e?.name === "AbortError";
  }
}

const AgentHubRichTextBlock: React.FC<{
  payload: ChatRichTextPayload;
  blockId?: string;
  onButtonSelect: (value: string, options?: ButtonSelectOptions) => void;
  onOpenIbclcConsult?: (request: IbclcConsultOpenRequest) => void;
}> = ({ payload, blockId = "rich", onButtonSelect, onOpenIbclcConsult }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const [artifactError, setArtifactError] = useState<Record<number, string>>({});
  const [submittedArtifactMap, setSubmittedArtifactMap] = useState<Record<number, boolean>>({});
  const [downloadingCardIndex, setDownloadingCardIndex] = useState<number | null>(null);
  const [ibclcCompletions, setIbclcCompletions] = useState<IbclcConsultCompletedPayload[]>(() =>
    readStoredIbclcConsultCompletions(),
  );
  const cardArtifactRefs = useRef<Record<number, HTMLElement | null>>({});

  useEffect(() => {
    const syncCompletion = () => {
      setIbclcCompletions(readStoredIbclcConsultCompletions());
    };
    const onStorage = (event: StorageEvent) => {
      if (event.key !== IBCLC_CONSULT_COMPLETED_KEY && event.key !== IBCLC_CONSULT_COMPLETIONS_KEY) return;
      syncCompletion();
    };
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      const payload = event.data as IbclcConsultCompletedPayload | undefined;
      if (payload?.type === "momcozy.ibclc_consult_completed") syncCompletion();
    };
    const onCustom = (event: Event) => {
      const payload = (event as CustomEvent<IbclcConsultCompletedPayload>).detail;
      if (payload?.type === "momcozy.ibclc_consult_completed") syncCompletion();
    };
    const onFocus = () => syncCompletion();
    window.addEventListener("storage", onStorage);
    window.addEventListener("message", onMessage);
    window.addEventListener("focus", onFocus);
    window.addEventListener("pageshow", onFocus);
    window.addEventListener("momcozy-ibclc-consult-completed", onCustom);
    return () => {
      window.removeEventListener("storage", onStorage);
      window.removeEventListener("message", onMessage);
      window.removeEventListener("focus", onFocus);
      window.removeEventListener("pageshow", onFocus);
      window.removeEventListener("momcozy-ibclc-consult-completed", onCustom);
    };
  }, []);

  const mergedArtifacts = useMemo(() => {
    const result: Array<
      | { kind: "form"; form: Record<string, unknown> }
      | { kind: "card"; card: Record<string, unknown> }
      | { kind: "ibclc_consult"; card: Record<string, unknown>; artifactId?: string }
      | { kind: "support_ticket_draft"; ticket: Record<string, unknown>; submitLabel?: string }
    > = [];
    const resultKeys: string[] = [];
    const upsertArtifact = (artifact: (typeof result)[number], key: string) => {
      if (!key) {
        result.push(artifact);
        resultKeys.push("");
        return;
      }
      const index = resultKeys.indexOf(key);
      if (index >= 0) result[index] = artifact;
      else {
        result.push(artifact);
        resultKeys.push(key);
      }
    };
    for (const action of payload.action) {
      const obj = asObject(action);
      if (!obj) continue;
      if (asString(obj.kind) !== "ag_ui_artifact") continue;
      const artifactType = asString(obj.artifact_type);
      const artifactId = asString(obj.artifact_id) || asString(obj.artifactId);
      if (artifactType === "form" && asObject(obj.form)) {
        const form = asObject(obj.form)!;
        upsertArtifact({ kind: "form", form }, artifactId ? `form:${artifactId}` : asString(form.id) ? `form:${asString(form.id)}` : "");
      } else if (artifactType === "card" && asObject(obj.card)) {
        const card = asObject(obj.card)!;
        upsertArtifact({ kind: "card", card }, artifactId ? `card:${artifactId}` : asString(card.id) ? `card:${asString(card.id)}` : "");
      } else if (artifactType === "ibclc_consult" && asObject(obj.card)) {
        const card = asObject(obj.card)!;
        upsertArtifact({ kind: "ibclc_consult", card, artifactId: artifactId || undefined }, artifactId ? `ibclc_consult:${artifactId}` : asString(card.id) ? `ibclc_consult:${asString(card.id)}` : "");
      } else if (artifactType === "support_ticket_draft" && asObject(obj.ticket)) {
        const ticket = asObject(obj.ticket)!;
        upsertArtifact({
          kind: "support_ticket_draft",
          ticket,
          submitLabel: asString(obj.submit_label),
        }, artifactId ? `support_ticket_draft:${artifactId}` : `support_ticket_draft:${asString(ticket.id) || "current"}`);
      }
    }
    return result;
  }, [payload.action]);

  const getCardFieldValue = (card: ChatRichTextCardItem, keyword: string): string => {
    const row = card.content.find((item) => item.title.includes(keyword));
    return row?.content?.trim() || "—";
  };

  const handleRichTextButton = (b: ChatRichTextButtonItem) => {
    const buttonType = b.type.toLowerCase();
    if (buttonType === "open") {
      tryOpenRichTextOpenButton(b.value, b.text, navigate);
      return;
    }
    if (buttonType === "switch") {
      const route = parseSwitchRouteFromValue(b.value);
      if (route) {
        log("[AgentHub][rich_text][switch] navigate", { text: b.text, route, value: b.value });
        navigate(route);
      } else {
        log("[AgentHub][rich_text][switch] invalid value", { text: b.text, value: b.value });
      }
      return;
    }
    onButtonSelect(b.value);
  };

  const exportCardAsPng = async (index: number, card: Record<string, unknown>) => {
    const node = cardArtifactRefs.current[index];
    if (!node) return;
    setDownloadingCardIndex(index);
    try {
      await document.fonts?.ready;
      const dataUrl = await toPng(node, {
        backgroundColor: "#ffffff",
        cacheBust: true,
        pixelRatio: Math.min(Math.max(window.devicePixelRatio || 2, 2), 3),
        filter: (target) => !(target instanceof HTMLElement && target.dataset.exportControl === "true"),
      });
      const filename = cardDownloadFilename(card);
      const savedToDownloads = await saveImageToAndroidDownloads(dataUrl, filename);
      if (savedToDownloads) return;
      const blob = await dataUrlToBlob(dataUrl);
      const shared = await shareImageOnMobile(blob, filename);
      if (!shared) triggerImageDownload(dataUrl, filename);
    } catch {
      /* 导出失败时静默；与 web 端行为一致（不打断对话流） */
    } finally {
      setDownloadingCardIndex((prev) => (prev === index ? null : prev));
    }
  };

  const renderFormField = (field: FormFieldSpec, variant: "default" | "monochrome" = "default") => {
    const isMonochrome = variant === "monochrome";
    const requiredMark = field.required ? (
      <span className={cn("mr-1", isMonochrome ? "text-foreground" : "text-destructive")}>*</span>
    ) : null;
    const fieldTextClass = isMonochrome ? "text-neutral-950 dark:text-neutral-50" : "text-foreground";
    const inputClassName = cn(
      "rounded-lg border px-2 py-1.5 outline-none transition-colors",
      isMonochrome ? "text-[14px]" : "text-[12px]",
      isMonochrome
        ? "border-neutral-300 bg-white text-neutral-950 placeholder:text-neutral-400 focus:border-neutral-950 focus:ring-1 focus:ring-neutral-950 dark:border-neutral-700 dark:bg-background dark:text-neutral-50 dark:placeholder:text-neutral-500 dark:focus:border-neutral-100 dark:focus:ring-neutral-100"
        : "border-border bg-background",
    );
    if (isMultiSelectField(field)) {
      const defaults = defaultMultiSelectValues(field.default_value);
      return (
        <fieldset
          key={field.id}
          className={cn(
            "rounded-lg border p-2.5",
            isMonochrome ? "border-neutral-300 bg-white dark:border-neutral-700 dark:bg-background" : "border-border/60",
          )}
        >
          <legend className={cn(isMonochrome ? "text-[14px]" : "text-[12px]", "font-medium px-1", fieldTextClass)}>
            {requiredMark}
            {field.label}
          </legend>
          <div className="grid gap-1.5">
            {(field.options ?? []).map((option) => (
              <label key={option} className={cn("inline-flex items-center gap-2", isMonochrome ? "text-[14px]" : "text-[12px]", fieldTextClass)}>
                <input type="checkbox" name={field.id} value={option} defaultChecked={defaults.includes(option)} />
                <span>{option}</span>
              </label>
            ))}
          </div>
        </fieldset>
      );
    }
    return (
      <label key={field.id} className={cn("grid gap-1", isMonochrome ? "text-[14px]" : "text-[12px]", fieldTextClass)}>
        <span className="font-medium">
          {requiredMark}
          {field.label}
        </span>
        {field.type === "select" ? (
          <select
            name={field.id}
            required={Boolean(field.required)}
            className={inputClassName}
            defaultValue={asString(field.default_value)}
          >
            {(field.options ?? []).map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        ) : field.type === "textarea" ? (
          <textarea
            name={field.id}
            required={Boolean(field.required)}
            rows={3}
            placeholder={field.placeholder}
            defaultValue={asString(field.default_value)}
            className={inputClassName}
          />
        ) : (
          <input
            name={field.id}
            required={Boolean(field.required)}
            type={field.type === "date" ? "date" : "text"}
            placeholder={field.placeholder}
            defaultValue={asString(field.default_value)}
            className={inputClassName}
          />
        )}
        {field.help_text ? (
          <small className={cn(isMonochrome ? "text-[12px]" : "text-[11px]", isMonochrome ? "text-neutral-600 dark:text-neutral-400" : "text-muted-foreground")}>
            {field.help_text}
          </small>
        ) : null}
      </label>
    );
  };

  const renderArtifact = () => {
    if (mergedArtifacts.length === 0) return null;
    return (
      <div className="space-y-2">
        {mergedArtifacts.map((artifact, index) => {
          const isSubmitted = Boolean(submittedArtifactMap[index]);
          const errorText = artifactError[index] || "";
          if (artifact.kind === "ibclc_consult") {
            const consultant = asObject(artifact.card.consultant) ?? {};
            const chat = asObject(artifact.card.chat) ?? {};
            const consultantName = asString(consultant.name) || "IBCLC 顾问";
            const consultantBio = asString(consultant.bio);
            const url = asString(chat.url) || "/ibclc-chat.html";
            const threadId = getAgUiThreadIdForRequest();
            const consultId =
              asString(artifact.card.consult_id) ||
              asString(artifact.card.consultId) ||
              artifact.artifactId ||
              stableIbclcConsultId(JSON.stringify(artifact.card));
            const returnTo = `${location.pathname}${location.search}${location.hash}`;
            const chatUrl = buildIbclcChatUrl(url, consultId, threadId, returnTo);
            const consultCompleted = ibclcCompletions.some((completion) =>
              isIbclcCompletionForCard(completion, threadId, consultId),
            );
            const openConsult = () => {
              if (consultCompleted) return;
              if (onOpenIbclcConsult) {
                onOpenIbclcConsult({ consultId, threadId, returnTo, chatUrl });
                return;
              }
              rememberIbclcReturnTo(returnTo);
              rememberIbclcViewportForNode(cardArtifactRefs.current[index], returnTo, consultId);
              if (chatUrl.startsWith("/")) {
                navigate(chatUrl);
                return;
              }
              window.location.assign(chatUrl);
            };
            return (
              <article
                key={`artifact-${index}`}
                ref={(el) => {
                  cardArtifactRefs.current[index] = el;
                }}
                data-consult-id={consultId}
                className="grid w-full gap-[14px] rounded-[14px] border border-[#d8e5e1] p-[18px] text-[#273b3a] shadow-[0_12px_30px_rgba(48,83,78,0.08)]"
                style={{
                  background:
                    "radial-gradient(circle at top right, rgba(221, 241, 234, 0.95), transparent 42%), linear-gradient(180deg, #ffffff 0%, #f8fcfb 100%)",
                }}
              >
                <div className="flex items-start justify-between gap-[10px]">
                  <h3 className="m-0 text-[22px] font-[800] leading-[1.15] text-[#142726]">IBCLC咨询</h3>
                </div>
                <section className="grid grid-cols-[52px_minmax(0,1fr)] items-center gap-3 rounded-xl border border-[#deebe8] bg-white/80 p-3">
                  <div className="grid h-[52px] w-[52px] place-items-center rounded-full bg-[#1b7874] text-[17px] font-black text-white">
                    {initialsForName(consultantName)}
                  </div>
                  <div>
                    <strong className="block text-[16px] font-[800] leading-[1.2] text-[#182b2a]">{consultantName}</strong>
                    {consultantBio ? <p className="mt-[7px] text-[13px] leading-[1.45] text-[#60706e]">{consultantBio}</p> : null}
                  </div>
                </section>
                <button
                  type="button"
                  disabled={consultCompleted}
                  aria-disabled={consultCompleted}
                  className={cn(
                    "inline-flex min-h-[46px] items-center justify-center rounded-xl px-3 text-[14px] font-black no-underline",
                    consultCompleted ? "cursor-default bg-[#d7dfdd] text-[#778683]" : "bg-[#177a89] text-white",
                  )}
                  onClick={openConsult}
                >
                  {consultCompleted ? "咨询结束" : "在线咨询"}
                </button>
              </article>
            );
          }
          if (artifact.kind === "card") {
            const card = artifact.card;
            const cardType = asString(card.card_type);
            const schemaVersion = asString(card.schema_version);
            const cardJson = asObject(card.card_json) ?? card;
            const downloadButton = (
              <button
                type="button"
                onClick={() => void exportCardAsPng(index, card)}
                disabled={downloadingCardIndex === index}
                data-export-control="true"
                className="card-export-button"
                title="下载卡片 PNG"
                aria-label={downloadingCardIndex === index ? "正在导出图片" : "下载卡片图片"}
              >
                {downloadingCardIndex === index ? (
                  <span className="card-export-spinner" aria-hidden="true" />
                ) : (
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 4v10" />
                    <path d="m7 11 5 5 5-5" />
                    <path d="M5 20h14" />
                  </svg>
                )}
              </button>
            );
            if (cardType === "birth_plan_card" && schemaVersion === "1.0") {
              const bp = normalizeBirthPlanCard(cardJson);
              const subtitle = cardSubtitle([bp.overview.due_date_or_week, bp.overview.birth_path, bp.overview.birth_setting, bp.overview.support_people]);
              const groups: Array<[string, string[]]> = [
	                ["检查、干预或计划调整时", bp.communication],
	                ["疼痛/麻醉沟通", bp.pain_relief],
	                ["宝宝出生后", bp.baby_after_birth],
	                ["计划变化时", bp.if_plans_change],
	                ["其它可沟通的问题", bp.questions_for_hospital],
	              ].filter(([, vals]) => vals.length > 0) as Array<[string, string[]]>;
              return (
                <article
                  key={`artifact-${index}`}
                  ref={(el) => {
                    cardArtifactRefs.current[index] = el;
                  }}
                  className="agent-card agent-card-birth_plan_card"
                >
                  {downloadButton}
                  <header className="agent-card-header">
                    <div className="agent-card-header-text">
                      <h2>{bp.title}</h2>
                      {subtitle ? <p>{subtitle}</p> : null}
                    </div>
                    <div className="flex items-center gap-1.5">
                      <img src={MOMCOZY_LOGO_SRC} alt="Momcozy" className="agent-card-logo" />
                    </div>
                  </header>
                  {bp.personalized_notes.length > 0 ? (
                    <section className="agent-card-section agent-card-summary-section">
                      <h3>个性化依据</h3>
                      <ul className="agent-card-note-list">
                        {bp.personalized_notes.map((item, i) => (
                          <li key={i}>{item}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {bp.top_priorities.length > 0 ? (
                    <section className="agent-card-section agent-card-summary-section">
                      <h3>最重要的沟通重点</h3>
	                      <ul className="hospital-card-focus-list">
	                        {bp.top_priorities.map((item, i) => (
	                          <li key={i}>
	                            <span aria-hidden="true" />
	                            <span className="birth-plan-focus-text">{item}</span>
	                          </li>
	                        ))}
	                      </ul>
                    </section>
                  ) : null}
                  {groups.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>沟通偏好</h3>
                      <div className="birth-plan-group-list">
                        {groups.map(([title, vals]) => (
                          <div key={title} className="birth-plan-group">
                            <h4>{title}</h4>
                            <ul className="agent-card-list">
                              {vals.map((value, i) => (
                                <li key={i}>{value}</li>
                              ))}
                            </ul>
                          </div>
                        ))}
                      </div>
                    </section>
                  ) : null}
	                  {bp.medical_notes.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>医疗或安全信息</h3>
                      <ul className="agent-card-list">
                        {bp.medical_notes.map((value, i) => (
                          <li key={i}>{value}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {bp.disclaimer ? <p className="agent-card-disclaimer">{bp.disclaimer}</p> : null}
                </article>
              );
            }
            if (cardType === "hospital_bag_card" && schemaVersion === "1.0") {
              const owner = asObject(cardJson.owner) ?? {};
              const hospital = asObject(cardJson.hospital_context) ?? {};
              const subtitle = cardSubtitle([
                hospitalBagMetaValue(owner.due_date_or_week),
                hospitalBagMetaValue(owner.birth_path),
                hospitalBagMetaValue(owner.packing_style),
                hospitalBagMetaValue(owner.feeding_intention),
                hospitalBagMetaValue(hospital.expected_stay),
              ]);
              const packingGroups = compactPackingGroups(cardJson.packing_groups);
              const packingItems = flattenPackingGroupItems(packingGroups);
              const explicitFocusItems = hospitalBagSummaryStrings(cardJson.focus_items, 7);
              const fallbackFocusItems = packingItems
                .filter((item) => asString(item.priority) === "must")
                .map((item) => packingItemText(item, asObject(item.__group) ?? {}))
                .slice(0, 6);
              const focusItems = explicitFocusItems.length > 0 ? explicitFocusItems : fallbackFocusItems;
              const explicitHospitalQuestions = hospitalBagQuestionStrings(cardJson.hospital_questions, 8);
              const fallbackConfirmItems = hospitalBagQuestionStrings(
                [
                  ...packingItems.filter(isConfirmFirstPackingItem).map(confirmTextFromPackingItem),
                  ...limitList(hospital.items_to_confirm_with_hospital, 8),
                ],
                8,
              );
              const confirmItems = explicitHospitalQuestions.length > 0 ? explicitHospitalQuestions : fallbackConfirmItems;
              const personalizedNotes = uniqueDisplayStrings(limitList(cardJson.personalized_notes, 3), 3);
              const timelineItems = limitList(cardJson.timeline, 3);
              return (
                <article
                  key={`artifact-${index}`}
                  ref={(el) => {
                    cardArtifactRefs.current[index] = el;
                  }}
                  className="agent-card agent-card-hospital_bag_card"
                >
                  {downloadButton}
                  <header className="agent-card-header">
                    <div className="agent-card-header-text">
                      <h2>{asString(cardJson.title) || "Hospital Bag Card"}</h2>
                      {subtitle ? <p>{subtitle}</p> : null}
                    </div>
                    <div className="flex items-center gap-1.5">
                      <img src={MOMCOZY_LOGO_SRC} alt="Momcozy" className="agent-card-logo" />
                    </div>
                  </header>
                  {personalizedNotes.length > 0 ? (
                    <section className="agent-card-section agent-card-summary-section">
                      <h3>个性化依据</h3>
                      <ul className="agent-card-note-list">
                        {personalizedNotes.map((value, i) => (
                          <li key={i}>{value}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {focusItems.length > 0 ? (
                    <section className="agent-card-section agent-card-summary-section">
                      <h3>必带物品</h3>
                      <ul className="hospital-card-focus-list">
                        {focusItems.map((value, i) => (
                          <li key={i}>
                            <span aria-hidden="true" />
                            <strong>{value}</strong>
                          </li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {confirmItems.length > 0 ? (
                    <section className="agent-card-section agent-card-confirm-section">
                      <h3>先和医院确认</h3>
                      <ul className="agent-card-list">
                        {confirmItems.map((value, i) => (
                          <li key={i}>{value}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {packingGroups.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>待产清单</h3>
                      {packingGroups.map((group, gIdx) => (
                        <details key={gIdx} className="packing-group" open={gIdx === 0}>
                          <summary>
                            <span>{asString(group.title) || formatLabel(asString(group.group_id) || "Group")}</span>
                            <small>{group.items.length}项</small>
                          </summary>
                          <div>
                            {group.items.map((item, i) => {
                              const ItemIcon = packingItemIcon(item, group);
                              return (
                                <div key={i} className="packing-item">
                                  <span className="packing-item-icon" aria-hidden="true">
                                    <ItemIcon />
                                  </span>
                                  <span className="packing-item-name">{renderHospitalCardValue(normalizedPackingItemLabel(item, group))}</span>
                                  {packingItemMeta(item, group) ? <strong className="packing-item-quantity">{renderHospitalCardValue(packingItemMeta(item, group))}</strong> : null}
                                  {item.priority ? (
                                    <span className={priorityClassName(item.priority)}>
                                      {priorityLabel(item.priority)}
                                    </span>
                                  ) : null}
                                  {packingItemNote(item) ? <small>{packingItemNote(item)}</small> : null}
                                </div>
                              );
                            })}
                          </div>
                        </details>
                      ))}
                    </section>
                  ) : null}
                  {timelineItems.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>准备时间线</h3>
                      <ul className="agent-card-list">
                        {timelineItems.map((value, i) => (
                          <li key={i}>{renderHospitalCardValue(value)}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {asString(cardJson.disclaimer) ? <p className="agent-card-disclaimer">{asString(cardJson.disclaimer)}</p> : null}
                </article>
              );
            }
            const rows = Object.entries(cardJson).filter(([, v]) => hasDisplayValue(v));
            return (
              <article
                key={`artifact-${index}`}
                ref={(el) => {
                  cardArtifactRefs.current[index] = el;
                }}
                className="relative rounded-xl border border-border bg-card p-3 space-y-2"
              >
                {downloadButton}
                <div className="flex items-start justify-between gap-2">
                  <h3 className="text-sm font-semibold text-foreground">
                    {asString(card.title) || cardType || "Card"}
                    {schemaVersion ? <span className="ml-2 text-[11px] text-muted-foreground">Schema {schemaVersion}</span> : null}
                  </h3>
                </div>
                {rows.length > 0 ? (
                  <dl className="grid gap-1.5">
                    {rows.slice(0, 16).map(([k, v]) => (
                      <div key={k} className="grid grid-cols-[minmax(72px,auto)_1fr] gap-2 text-[12px]">
                        <dt className="text-muted-foreground">{formatLabel(k)}</dt>
                        <dd className="text-foreground break-words">{formatPlainValue(v)}</dd>
                      </div>
                    ))}
                  </dl>
                ) : null}
              </article>
            );
          }
          const formSpec =
            artifact.kind === "support_ticket_draft"
              ? { id: "support_ticket", title: "售后工单", fields: supportTicketFields(artifact.ticket) }
              : artifact.form;
          const isSupportTicket = artifact.kind === "support_ticket_draft";
          const formId = asString(formSpec.id);
          const isHospitalBagIntake = formId === "hospital_bag_intake";
          const isBirthPlanIntake = formId === "birth_plan_card_intake";
          const isMonochromeForm = isSupportTicket || isHospitalBagIntake || isBirthPlanIntake;
          const title = isHospitalBagIntake || isBirthPlanIntake ? "信息采集" : asString(formSpec.title) || "Confirm details";
          const normalizedFormSpec = isHospitalBagIntake || isBirthPlanIntake ? { ...formSpec, title } : formSpec;
          const fieldsRaw = Array.isArray(formSpec.fields) ? formSpec.fields : [];
          const fields: FormFieldSpec[] = fieldsRaw
            .map((f) => asObject(f))
            .filter((x): x is Record<string, unknown> => Boolean(x))
            .map((f) => ({
              id: asString(f.id),
              label: asString(f.label),
              type: asString(f.type) || "text",
              required: Boolean(f.required),
              options: Array.isArray(f.options) ? f.options.map((opt) => String(opt)) : [],
              default_value: f.default_value,
              placeholder: asString(f.placeholder),
              help_text: asString(f.help_text),
            }))
            .map((field) =>
              (isHospitalBagIntake || isBirthPlanIntake) && field.id === "birth_path"
                ? {
                    ...field,
                    label: "计划分娩方式",
                    options: ["顺产", "刨腹产", "未确定"],
                    default_value: ["计划剖宫产", "剖腹产", "planned_c_section", "c_section", "c-section", "cesarean"].includes(asString(field.default_value))
                      ? "刨腹产"
                      : field.default_value,
                    help_text: "如果还没确定，可以选择“未确定”。",
                  }
                : field,
            )
            .filter((f) => f.id);

          return (
            <form
              key={`artifact-${index}`}
              className={cn(
                "rounded-xl border p-3 space-y-2.5",
                isMonochromeForm
                  ? "border-neutral-200 bg-white text-neutral-950 shadow-none dark:border-neutral-800 dark:bg-background dark:text-neutral-50"
                  : "border-border bg-card",
              )}
              onSubmit={(event) => {
                event.preventDefault();
                if (isSubmitted) return;
                const form = event.currentTarget;
                for (const field of fields) {
                  if (!field.required || !isMultiSelectField(field)) continue;
                  if (new FormData(form).getAll(field.id).length > 0) continue;
                  setArtifactError((prev) => ({ ...prev, [index]: `请选择：${field.label}` }));
                  return;
                }
                setArtifactError((prev) => ({ ...prev, [index]: "" }));
                const values = collectFormValues(form, fields);
                setSubmittedArtifactMap((prev) => ({ ...prev, [index]: true }));
                if (artifact.kind === "support_ticket_draft") {
                  onButtonSelect(buildSupportTicketSubmittedMessage(values), { displayText: "已提交售后工单" });
                  return;
                }
                onButtonSelect(buildFormConfirmationMessage(normalizedFormSpec, values), { displayText: `已提交：${title}` });
              }}
            >
              <fieldset disabled={isSubmitted} className="grid gap-2.5">
                <h3 className={cn(isMonochromeForm ? "text-base" : "text-sm", "font-semibold", isMonochromeForm ? "text-neutral-950 dark:text-neutral-50" : "text-foreground")}>
                  {title}
                </h3>
                {asString(formSpec.description) ? (
                  <p className={cn(isMonochromeForm ? "text-[13px]" : "text-[12px]", isMonochromeForm ? "text-neutral-600 dark:text-neutral-400" : "text-muted-foreground")}>
                    {asString(formSpec.description)}
                  </p>
                ) : null}
                {fields.map((field) => renderFormField(field, isMonochromeForm ? "monochrome" : "default"))}
                {errorText ? <p className="text-[12px] text-destructive">{errorText}</p> : null}
                <button
                  type="submit"
                  className={cn(
                    "rounded-lg px-3 py-2 font-medium border",
                    isMonochromeForm ? "text-[14px]" : "text-[12px]",
                    isMonochromeForm
                      ? isSubmitted
                        ? "border-neutral-400 bg-white text-neutral-600 dark:bg-background dark:text-neutral-300"
                        : "border-neutral-950 bg-neutral-950 text-white hover:bg-neutral-800 dark:border-neutral-100 dark:bg-neutral-100 dark:text-neutral-950 dark:hover:bg-neutral-200"
                      : isSubmitted
                        ? "border-emerald-600/40 bg-emerald-600/10 text-emerald-700"
                        : "border-primary/50 bg-primary/10 text-foreground",
                  )}
                >
                  {isSubmitted
                    ? "已提交"
                    : artifact.kind === "support_ticket_draft"
                      ? artifact.submitLabel || "确认并提交"
                      : asString(formSpec.submit_label) || "Confirm"}
                </button>
              </fieldset>
            </form>
          );
        })}
      </div>
    );
  };

  return (
    <div className="space-y-2">
      {renderArtifact()}
      {payload.title ? <p className="font-semibold text-sm text-foreground">{payload.title}</p> : null}
      {payload.content ? (
        <ChatMarkdown markdown={payload.content} variant="muted" className="text-[12px]" />
      ) : null}
      {payload.card.length > 0 ? (
        <div className="space-y-2">
          {payload.card.map((card: ChatRichTextCardItem, i) => (
            <div
              key={`${card.type || "card"}-${i}`}
              className={cn(
                "w-fit max-w-[220px] mr-auto rounded-xl border p-2",
                card.highlight
                  ? "border-mai-warm/30 bg-mai-warm/5"
                  : "border-border/80 bg-background/60",
              )}
            >
              {card.text ? (
                <p className="text-sm font-semibold text-foreground mb-2">{card.text}</p>
              ) : null}
              {card.content.length > 0 ? (
                <>
                  <div className="grid grid-cols-3 gap-1 w-fit">
                    <div className="min-w-[58px] rounded-lg bg-secondary/80 p-1 text-center">
                      <p className="text-[9px] text-muted-foreground">本次收集</p>
                      <p className="text-[13px] font-bold text-foreground leading-tight">{getCardFieldValue(card, "本次收集")}</p>
                    </div>
                    <div className="min-w-[58px] rounded-lg bg-secondary/80 p-1 text-center">
                      <p className="text-[9px] text-muted-foreground">左侧奶量</p>
                      <p className="text-[13px] font-bold text-foreground leading-tight">{getCardFieldValue(card, "左侧奶量")}</p>
                    </div>
                    <div className="min-w-[58px] rounded-lg bg-secondary/80 p-1 text-center">
                      <p className="text-[9px] text-muted-foreground">右侧奶量</p>
                      <p className="text-[13px] font-bold text-foreground leading-tight">{getCardFieldValue(card, "右侧奶量")}</p>
                    </div>
                  </div>
                  <div className="flex items-center justify-between rounded-lg bg-primary/10 border border-primary/20 px-2 py-1 mt-1">
                    <div>
                      <p className="text-[9px] text-muted-foreground">吸乳侧别</p>
                      <p className="text-sm font-bold text-foreground">{getCardFieldValue(card, "吸乳侧别")}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-[9px] text-muted-foreground">奶阵情况</p>
                      <p className="text-sm font-bold text-foreground">{getCardFieldValue(card, "奶阵情况")}</p>
                    </div>
                  </div>
                  {card.content.filter((row) => (
                    !row.title.includes("本次收集")
                    && !row.title.includes("左侧奶量")
                    && !row.title.includes("右侧奶量")
                    && !row.title.includes("吸乳侧别")
                    && !row.title.includes("奶阵情况")
                  )).length > 0 ? (
                    <div className="space-y-1 mt-1.5">
                      {card.content
                        .filter((row) => (
                          !row.title.includes("本次收集")
                          && !row.title.includes("左侧奶量")
                          && !row.title.includes("右侧奶量")
                          && !row.title.includes("吸乳侧别")
                          && !row.title.includes("奶阵情况")
                        ))
                        .map((row, rowIdx) => (
                          <div key={`${row.title}-${rowIdx}`} className="flex items-start justify-between gap-3 text-[11px]">
                            <span className="text-muted-foreground">{row.title || "—"}</span>
                            <span className="text-right font-medium text-foreground">{row.content || "—"}</span>
                          </div>
                        ))}
                    </div>
                  ) : null}
                </>
              ) : null}
            </div>
          ))}
        </div>
      ) : null}
      {payload.button.length > 0 ? (
        <div className="flex flex-col gap-1.5 mt-1">
          {payload.button.map((b, i) => (
            <button
              key={i}
              type="button"
              onClick={() => handleRichTextButton(b)}
              className={cn(
                "rounded-xl px-3 py-2.5 text-left text-[13px] leading-snug border transition-colors w-full",
                b.highlight
                  ? "border-primary bg-primary/10 font-medium text-foreground shadow-sm"
                  : "border-border/80 bg-background/60 hover:bg-muted/70 text-foreground",
              )}
            >
              {b.text}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
};

export default AgentHubRichTextBlock;
