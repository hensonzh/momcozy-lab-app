import React, { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  Armchair,
  Baby,
  BabyIcon,
  Banknote,
  Bath,
  BatteryCharging,
  BedSingle,
  BookOpenCheck,
  Boxes,
  Briefcase,
  Brush,
  Cable,
  CarFront,
  CircleDot,
  CircleHelp,
  CircleParking,
  ClipboardList,
  Copy,
  CreditCard,
  CupSoda,
  ChevronRight,
  Download,
  Droplets,
  FileCheck,
  FileText,
  Footprints,
  Headphones,
  Heart,
  HeartPulse,
  Hospital,
  IdCard,
  Luggage,
  Milk,
  Package,
  Pill,
  Route,
  ShieldCheck,
  Shirt,
  ShoppingBag,
  Smartphone,
  SprayCan,
  Stethoscope,
  Thermometer,
  Utensils,
  WalletCards,
  type LucideIcon,
} from "lucide-react";
import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { cn } from "@/lib/utils";
import type { ChatRichTextButtonItem, ChatRichTextPayload, ChatRichTextCardItem, UserProfileData } from "@/lib/agentApiTypes";
import { log } from "@/lib/logger";
import { ChatMarkdown } from "@/components/chat/ChatMarkdown";
import { tryOpenRichTextOpenButton } from "@/lib/richTextOpenMedia";
import { parseSwitchRouteFromValue } from "./parseSwitchRouteFromValue";
import { toPng } from "html-to-image";
import momcozyLogo from "@/assets/momcozy_logo.png";
import ibclcConsultantAvatar from "@/assets/ibclc-consultant-avatar.jpg";
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
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

/**
 * chat-messages 富文本卡片（标题、正文、结构化卡片与按钮）。
 * open / switch / 默认续聊交由回调或路由处理。
 */
type ButtonSelectOptions = { displayText?: string; assistantReply?: string };
type ButtonSelectResult = boolean | void;
const OPEN_HOSPITAL_BAG_CART_EVENT = "momcozy-open-hospital-bag-cart";

export type IbclcConsultOpenRequest = {
  consultId: string;
  threadId: string;
  userId: string;
  returnTo: string;
  chatUrl: string;
};

type FormFieldSpec = {
  id: string;
  label: string;
  type: string;
  required?: boolean;
  options?: string[];
  allow_other_input?: boolean;
  default_value?: unknown;
  placeholder?: string;
  other_placeholder?: string;
  help_text?: string;
};

type FormFieldGroup = {
  title: string;
  fields: FormFieldSpec[];
};

type BirthPrepProfileFormDefaults = Pick<
  UserProfileData,
  | "age"
  | "birth_prep_due_date_or_week"
  | "birth_prep_ivf"
  | "birth_prep_fetus_count"
  | "birth_prep_city_or_country"
  | "birth_prep_birth_hospital"
  | "birth_prep_birth_path"
  | "birth_prep_first_birth"
  | "birth_prep_feeding_intention"
  | "birth_prep_return_to_work_timing"
  | "birth_prep_support_person"
  | "birth_prep_pregnancy_history_or_notes"
  | "birth_prep_top_worries"
>;

const REMOVED_HOSPITAL_BAG_FORM_FIELD_IDS = new Set(["hospital_rules_or_notes", "existing_checklist_or_photo_note"]);
const HOSPITAL_BAG_FORM_FIELD_IDS = new Set([
  "due_date_or_week",
  "first_birth",
  "fetus_count",
  "pregnancy_history_or_notes",
  "birth_path",
  "feeding_intention",
  "return_to_work_timing",
  "support_person",
  "budget_preference",
  "top_worries",
]);
const HOSPITAL_BAG_FORM_DETECTOR_FIELD_IDS = new Set(["fetus_count", "return_to_work_timing", "budget_preference", "top_worries"]);
const HOSPITAL_BAG_REASON_SUPPRESSED_ITEM_LABELS = new Set([
  "检查报告/化验单",
  "医院预登记信息",
  "紧急联系人信息",
  "医生/医院联系电话",
  "手机充电线和充电器",
  "医院路线和停车信息",
  "夜间入口信息",
]);
const HOSPITAL_BAG_REASON_SUPPRESSED_GROUP_IDS = new Set(["support_person_bag"]);
const BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT = 20;
const HOSPITAL_BAG_FORM_GROUP_STYLES = [
  {
    section: "border-[#efd6de] bg-[#fff6f8] dark:border-[#5d3543] dark:bg-[#241a20]",
    header: "border-[#ecced8]",
    title: "text-[#743149] dark:text-[#ffd7e3]",
  },
  {
    section: "border-[#d8e8de] bg-[#f4fbf6] dark:border-[#315746] dark:bg-[#17231d]",
    header: "border-[#cfe5d7]",
    title: "text-[#27634d] dark:text-[#cceedd]",
  },
  {
    section: "border-[#d7e2f3] bg-[#f3f8ff] dark:border-[#324d70] dark:bg-[#171f2c]",
    header: "border-[#cbdcf2]",
    title: "text-[#2c5c92] dark:text-[#d4e6ff]",
  },
  {
    section: "border-[#eadcc8] bg-[#fff8ee] dark:border-[#654d2f] dark:bg-[#251d14]",
    header: "border-[#ead7bb]",
    title: "text-[#7a5425] dark:text-[#ffe4bd]",
  },
] as const;

const BIRTH_PLAN_FORM_GROUP_STYLES = [
  {
    section: "border-[#d7e8e4] bg-[#f3fbf8] dark:border-[#315e57] dark:bg-[#16231f]",
    header: "border-[#c8e2dc]",
    title: "text-[#236357] dark:text-[#cdf0e8]",
  },
  {
    section: "border-[#ead6e0] bg-[#fff5f8] dark:border-[#63384a] dark:bg-[#24181f]",
    header: "border-[#eccbd8]",
    title: "text-[#7a3150] dark:text-[#ffd5e2]",
  },
  {
    section: "border-[#d9e0f4] bg-[#f5f7ff] dark:border-[#35466f] dark:bg-[#181d2d]",
    header: "border-[#cbd6f2]",
    title: "text-[#354f95] dark:text-[#dbe4ff]",
  },
  {
    section: "border-[#eadcc8] bg-[#fff8ee] dark:border-[#654d2f] dark:bg-[#251d14]",
    header: "border-[#ead7bb]",
    title: "text-[#7a5425] dark:text-[#ffe4bd]",
  },
  {
    section: "border-[#d8e6ee] bg-[#f3faff] dark:border-[#315567] dark:bg-[#142129]",
    header: "border-[#cbe0ea]",
    title: "text-[#2b6077] dark:text-[#d3efff]",
  },
] as const;

const MOMCOZY_LOGO_SRC = momcozyLogo;

type BirthJourneyPlanCardItem = {
  title: string;
  reason: string;
};

type BirthJourneyPlanCardSection = {
  key: string;
  title: string;
  subtitle: string;
  items: BirthJourneyPlanCardItem[];
  tone?: "warm" | "plain";
};

function asObject(v: unknown): Record<string, unknown> | null {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
}

function asString(v: unknown): string {
  return typeof v === "string" ? v : "";
}

const BIRTH_JOURNEY_PLAN_ITEM_TITLE_MAX_CHARS = 22;

function truncateBirthJourneyPlanText(value: unknown, maxChars: number): string {
  const text = asString(value).trim();
  if (text.length <= maxChars) return text;
  return `${text.slice(0, Math.max(0, maxChars - 1)).replace(/[，。；、,.\s]+$/u, "")}…`;
}

function cleanIbclcConsultantBio(v: unknown): string {
  return asString(v)
    .trim()
    .replace(/^(?:IBCLC\s*)?国际认证[哺泌]乳顾问[，,、。\s]*/, "")
    .trim();
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

function hasFormDefaultValue(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(hasFormDefaultValue);
  if (value && typeof value === "object") return Object.values(value as Record<string, unknown>).some(hasFormDefaultValue);
  return hasDisplayValue(value) && !isConfirmPlaceholder(value);
}

function birthPrepProfileFormDefaultValues(profile?: BirthPrepProfileFormDefaults | null): Record<string, unknown> {
  if (!profile) return {};
  const defaults: Record<string, unknown> = {
    age: profile.age,
    due_date_or_week: profile.birth_prep_due_date_or_week,
    ivf: profile.birth_prep_ivf,
    fetus_count: profile.birth_prep_fetus_count,
    city_or_country: profile.birth_prep_city_or_country,
    birth_hospital: profile.birth_prep_birth_hospital,
    birth_setting: profile.birth_prep_birth_hospital,
    birth_path: profile.birth_prep_birth_path,
    first_birth: profile.birth_prep_first_birth,
    feeding_intention: profile.birth_prep_feeding_intention,
    return_to_work_timing: profile.birth_prep_return_to_work_timing,
    support_person: profile.birth_prep_support_person,
    pregnancy_history_or_notes: profile.birth_prep_pregnancy_history_or_notes,
    top_worries: profile.birth_prep_top_worries,
  };
  Object.keys(defaults).forEach((key) => {
    if (!hasFormDefaultValue(defaults[key])) delete defaults[key];
  });
  return defaults;
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
  if (!hasFormDefaultValue(value)) return [];
  if (Array.isArray(value)) return value.map(String);
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function isOtherOption(option: string): boolean {
  return option === "其它" || option === "其他";
}

function otherInputName(fieldId: string): string {
  return `${fieldId}__other`;
}

function splitFormFieldLabel(label: string): { groupTitle: string; fieldLabel: string } {
  const text = String(label || "");
  const separatorIndex = text.indexOf("｜");
  if (separatorIndex <= 0) return { groupTitle: "", fieldLabel: text };

  const groupTitle = text.slice(0, separatorIndex).trim();
  const fieldLabel = text.slice(separatorIndex + 1).trim();
  if (!groupTitle || !fieldLabel) return { groupTitle: "", fieldLabel: text };
  return { groupTitle, fieldLabel };
}

function groupFormFields(fields: FormFieldSpec[]): FormFieldGroup[] {
  const groups: FormFieldGroup[] = [];
  const groupByTitle = new Map<string, FormFieldGroup>();

  for (const field of fields) {
    const { groupTitle, fieldLabel } = splitFormFieldLabel(field.label);
    const key = groupTitle || "__ungrouped";
    let group = groupByTitle.get(key);
    if (!group) {
      group = { title: groupTitle, fields: [] };
      groupByTitle.set(key, group);
      groups.push(group);
    }
    group.fields.push({ ...field, label: fieldLabel });
  }

  return groups;
}

function looksLikeHospitalBagForm(fields: FormFieldSpec[]): boolean {
  const fieldIds = new Set(fields.map((field) => field.id).filter(Boolean));
  let matchedHospitalBagFields = 0;
  for (const id of fieldIds) {
    if (HOSPITAL_BAG_FORM_FIELD_IDS.has(id)) matchedHospitalBagFields += 1;
  }
  return matchedHospitalBagFields >= 2 && Array.from(HOSPITAL_BAG_FORM_DETECTOR_FIELD_IDS).some((id) => fieldIds.has(id));
}

function sanitizeHospitalBagIntakeField(field: FormFieldSpec): FormFieldSpec {
  if (field.id === "due_date_or_week") {
    return {
      ...field,
      label: field.label || "基本信息｜预产期或当前孕周",
      type: "text",
      placeholder: field.placeholder || "例如：2026-06-12 或 37 周",
    };
  }
  return field.id === "pregnancy_history_or_notes"
    ? { ...field, options: field.options?.filter((option) => option !== "计划剖宫产") ?? [] }
    : field;
}

function hospitalBagGroupStyle(groupTitle: string, groupIndex: number) {
  const titleIndexMap: Record<string, number> = {
    基本信息: 0,
    生产信息: 1,
    医院信息: 2,
    偏好信息: 3,
  };
  const styleIndex = titleIndexMap[groupTitle] ?? groupIndex;
  return HOSPITAL_BAG_FORM_GROUP_STYLES[styleIndex % HOSPITAL_BAG_FORM_GROUP_STYLES.length];
}

function birthPlanGroupStyle(groupTitle: string, groupIndex: number) {
  const titleIndexMap: Record<string, number> = {
    基本信息: 0,
    支持与沟通: 1,
    生产过程: 2,
    疼痛和舒适: 3,
    宝宝出生后: 4,
    临时变化: 5,
    提前问医院: 6,
    舒适与计划变化: 3,
    医院确认与安全: 6,
  };
  const styleIndex = titleIndexMap[groupTitle] ?? groupIndex;
  return BIRTH_PLAN_FORM_GROUP_STYLES[styleIndex % BIRTH_PLAN_FORM_GROUP_STYLES.length];
}

function birthJourneyBasicInfoGroupStyle(groupTitle: string, groupIndex: number) {
  const titleIndexMap: Record<string, number> = {
    基本信息: 0,
  };
  const styleIndex = titleIndexMap[groupTitle] ?? groupIndex;
  return HOSPITAL_BAG_FORM_GROUP_STYLES[styleIndex % HOSPITAL_BAG_FORM_GROUP_STYLES.length];
}

function collectFormValues(form: HTMLFormElement, fields: FormFieldSpec[]): Record<string, unknown> {
  const data = new FormData(form);
  const values: Record<string, unknown> = {};
  for (const field of fields) {
    let value: string | string[];
    if (isMultiSelectField(field)) {
      const selected = data.getAll(field.id).map(String).filter((item) => item.trim());
      const otherText = String(data.get(otherInputName(field.id)) ?? "").trim();
      value = field.allow_other_input && otherText
        ? selected.map((item) => (isOtherOption(item) ? `其它：${otherText}` : item))
        : selected;
    } else {
      value = String(data.get(field.id) ?? "").trim();
    }
    if (hasCompactFormValue(value)) {
      values[field.id] = value;
    }
  }
  return values;
}

function hasCompactFormValue(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(hasCompactFormValue);
  return String(value ?? "").trim().length > 0;
}

function buildFormConfirmationMessage(form: Record<string, unknown>, values: Record<string, unknown>): string {
  return [
    `我已确认 ${asString(form.title) || "表单"} 信息，请基于这些信息生成对应卡片。`,
    `form_id: ${asString(form.id) || "form"}`,
    "confirmed_form_data:",
    JSON.stringify(values),
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
  return labels[key] || (Object.values(labels).includes(key) ? key : "其他");
}

function supportTicketUrgencyLabel(value: unknown): string {
  const labels: Record<string, string> = { normal: "普通", high: "较急", safety: "安全相关" };
  const key = asString(value);
  return labels[key] || (Object.values(labels).includes(key) ? key : "普通");
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
      required: true,
      default_value: asString(ticket.product_model),
      placeholder: "例如：M5、S12 Pro，或暂不确定",
    },
    {
      id: "order_number",
      label: "订单号",
      type: "text",
      default_value: asString(ticket.order_number),
      placeholder: "没有或暂时找不到可以先留空",
    },
    {
      id: "purchase_channel",
      label: "购买渠道",
      type: "text",
      default_value: asString(ticket.purchase_channel),
      placeholder: "例如：官网、Amazon、TikTok、线下门店",
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

const SUPPORT_TICKET_SUBMITTED_REPLY =
  "已经帮你提交工单啦，我们的人工客服团队会在 24 小时内主动联系你，陪你一起跟进这个问题。很抱歉这次没能直接帮你解决，给你添麻烦了。接下来还请稍微耐心等待一下，我们会尽力协助你把问题处理好。";

function isConfirmPlaceholder(value: unknown): boolean {
  const text = String(value ?? "").trim().toLowerCase();
  return ["", "to confirm", "待确认", "未确定", "不确定", "还不确定", "还没确定", "还没想好", "none", "n/a"].includes(text);
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
    "birth plan card": "分娩沟通单",
    "labor room communication priority card": "产房沟通重点",
    vaginal: "顺产",
    planned_c_section: "剖宫产",
    c_section: "剖宫产",
    "c-section": "剖宫产",
    cesarean: "剖宫产",
    "计划剖宫产": "剖宫产",
    "剖腹产": "剖宫产",
    "刨腹产": "剖宫产",
    "skin-to-skin": "出生后尽早肌肤接触",
    "skin to skin": "出生后尽早肌肤接触",
    "我还没想好，请帮我整理成温和版本": "希望医护团队在关键步骤前先解释，并给我一点时间确认。",
  };
  return labels[text.toLowerCase()] || labels[text] || text.replace(/skin-to-skin|skin to skin/gi, "出生后尽早肌肤接触");
}

function compactPackingItems(items: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(items)) return [];
  return items.filter((it) => it && typeof it === "object") as Array<Record<string, unknown>>;
}

type HospitalBagSceneGroup = { id: string; title: string; order: number };

function hospitalBagSceneGroup(group: Record<string, unknown>, fallbackOrder: number): HospitalBagSceneGroup {
  const text = `${asString(group.group_id)} ${asString(group.title)}`.toLowerCase();
  if (/(documents|certificate|证件|资料|文件)/.test(text)) return { id: "documents", title: "证件文件包", order: 0 };
  if (/(baby|宝宝|新生儿)/.test(text)) return { id: "baby_discharge_bag", title: "宝宝出院包", order: 2 };
  if (/(support|partner|companion|陪产|支持人)/.test(text)) return { id: "support_person_bag", title: "陪产人包", order: 3 };
  if (/(car|travel|traffic|transport|车上|交通|停车|路线)/.test(text)) return { id: "car_backup_bag", title: "车上备用包", order: 4 };
  if (/(lactation|breastfeeding|feeding|postpartum|哺乳|喂养|产后回家|产后护理)/.test(text)) {
    return { id: "postpartum_home_first_week", title: "产后回家第一周用品", order: 5 };
  }
  if (/(mom|mother|communication|food|妈妈|衣物|清洁|护理|通讯|饮食|住院)/.test(text)) {
    return { id: "mom_hospital_bag", title: "妈妈住院包", order: 1 };
  }
  return { id: asString(group.group_id) || `custom_${fallbackOrder}`, title: asString(group.title) || formatLabel(asString(group.group_id) || "Group"), order: 20 + fallbackOrder };
}

function compactPackingGroups(groups: unknown): Array<Record<string, unknown> & { items: Array<Record<string, unknown>> }> {
  if (!Array.isArray(groups)) return [];
  const merged = new Map<string, Record<string, unknown> & { items: Array<Record<string, unknown>>; _order: number }>();
  groups
    .filter((g) => g && typeof g === "object")
    .forEach((group, index) => {
      const g = group as Record<string, unknown>;
      const items = compactPackingItems(g.items);
      if (!items.length) return;
      const scene = hospitalBagSceneGroup(g, index);
      const existing = merged.get(scene.id);
      if (existing) {
        existing.items.push(...items);
        existing._order = Math.min(existing._order, scene.order);
        return;
      }
      merged.set(scene.id, {
        ...g,
        group_id: scene.id,
        title: scene.title,
        items,
        _order: scene.order,
      });
    });
  return Array.from(merged.values())
    .sort((a, b) => a._order - b._order)
    .map(({ _order, ...group }) => group);
}

function priorityLabel(priority: unknown): string {
  const labels: Record<string, string> = {
    must: "必带",
    recommended: "建议",
    nice_to_have: "建议",
    confirm_first: "和医院确认",
    先确认: "和医院确认",
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
  if (/身份证件/.test(asString(item.label))) return "";
  return asString(item.note);
}

function packingItemDescription(item: Record<string, unknown>): string {
  return asString(item.explain) || inferredHospitalBagItemExplanation(item) || packingItemNote(item);
}

function packingItemPersonalizationText(item: Record<string, unknown>, group?: Record<string, unknown>): string {
  const groupId = asString(group?.group_id);
  const label = asString(item.label);
  if (HOSPITAL_BAG_REASON_SUPPRESSED_GROUP_IDS.has(groupId) || HOSPITAL_BAG_REASON_SUPPRESSED_ITEM_LABELS.has(label)) {
    return "";
  }
  const sources = asObjectList(item.personalized_by)
    .map((source) => ({
      clause: personalizationClause(source),
      effect: asString(source.effect),
    }))
    .filter((source) => source.clause);
  const clauses = uniquePersonalizationClauses(
    sources.map((source) => source.clause).filter((clause): clause is PersonalizationClause => Boolean(clause)),
    4,
  );
  if (clauses.length === 0) return "";
  const userClauses = clauses.filter((clause) => clause.subject === "user").map((clause) => clause.text);
  const externalClauses = clauses.filter((clause) => clause.subject === "external").map((clause) => clause.text);
  const reasonParts = [
    userClauses.length ? `你${userClauses.join("加上")}` : "",
    externalClauses.join("，"),
  ].filter(Boolean);
  const reasonText = reasonParts.join("，且");
  if (!reasonText) return "";
  const effects = sources.map((source) => source.effect);
  if (asString(item.priority) === "confirm_first") return `${reasonText}，建议准备`;
  if (effects.some((effect) => effect.includes("数量调整"))) return `${reasonText}，数量已按这个情况调整`;
  if (effects.some((effect) => effect.includes("降级") || effect.includes("暂缓"))) return `${reasonText}，可以按需准备`;
  return `${reasonText}，${asString(item.priority) === "must" ? "必须准备" : "建议准备"}`;
}

type PersonalizationClause = {
  text: string;
  subject: "user" | "external";
};

function uniquePersonalizationClauses(clauses: PersonalizationClause[], maxItems: number): PersonalizationClause[] {
  const seen = new Set<string>();
  const unique: PersonalizationClause[] = [];
  for (const clause of clauses) {
    const key = `${clause.subject}:${clause.text}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(clause);
    if (unique.length >= maxItems) break;
  }
  return unique;
}

function personalizationClause(source: Record<string, unknown>): PersonalizationClause | null {
  const field = asString(source.field);
  const fieldLabel = asString(source.field_label) || formatLabel(asString(source.field));
  const condition = asString(source.condition);
  if (!condition || isConfirmPlaceholder(condition)) return null;
  if (field === "first_birth" || fieldLabel === "是否第一胎") {
    if (condition === "是") return { text: "是第一胎", subject: "user" };
    if (condition === "否") return { text: "不是第一胎", subject: "user" };
  }
  if (field === "birth_path" || fieldLabel === "分娩方式") {
    if (condition.includes("剖")) return { text: "是剖宫产", subject: "user" };
    if (condition.includes("顺")) return { text: "计划顺产", subject: "user" };
    return { text: `分娩方式是${condition}`, subject: "user" };
  }
  if (field === "feeding_intention" || fieldLabel === "喂养意向") {
    if (condition.includes("母乳")) return { text: "希望母乳喂养", subject: "user" };
    if (condition.includes("混合")) return { text: "计划混合喂养", subject: "user" };
    if (condition.includes("配方")) return { text: "计划配方喂养", subject: "user" };
    if (condition.includes("泵")) return { text: "计划泵奶喂养", subject: "user" };
    return { text: "还没确定喂养方式", subject: "user" };
  }
  if (field === "fetus_count" || fieldLabel === "胎数") {
    if (condition.includes("双胎")) return { text: "是双胎", subject: "user" };
    if (condition.includes("三胎")) return { text: "是三胎及以上", subject: "user" };
    if (condition.includes("单胎")) return { text: "是单胎", subject: "user" };
  }
  if (field === "return_to_work_timing" || fieldLabel === "返工时间") {
    return { text: returnToWorkClause(condition), subject: "user" };
  }
  if (field === "budget_preference" || fieldLabel === "预算偏好") {
    return { text: `偏好${condition}`, subject: "user" };
  }
  if (field === "support_person" || fieldLabel === "支持情况") {
    if (condition.includes("支持少")) return { text: "产后支持较少", subject: "user" };
    return { text: `产后支持情况是${condition}`, subject: "user" };
  }
  if (field === "top_worries" || fieldLabel === "焦虑点") {
    return { text: worryClause(condition), subject: "user" };
  }
  if (field === "pregnancy_history_or_notes" || fieldLabel === "医生提示") {
    if (condition === "已填写医生提示") return { text: "医生有特别提示", subject: "external" };
    return { text: `医生提示${condition}`, subject: "external" };
  }
  if (field === "due_date_or_week" || fieldLabel === "孕周/预产期") {
    return { text: condition.endsWith("版") ? `处于${condition}` : `当前是${condition}`, subject: "user" };
  }
  if (!fieldLabel) return null;
  return { text: `${fieldLabel}是${condition}`, subject: "user" };
}

function returnToWorkClause(condition: string): string {
  if (condition.includes("暂不") || condition.includes("不返工")) return "暂不返工";
  if (condition.startsWith("产后")) return `${condition}返工`;
  return `产后${condition}返工`;
}

function worryClause(condition: string): string {
  if (condition.startsWith("怕")) return `担心${condition.slice(1)}`;
  if (condition.startsWith("担心")) return condition;
  return `担心${condition}`;
}

const hospitalBagItemExplanationRules: Array<[RegExp, string]> = [
  [/产褥垫|产妇卫生巾/, "产后恶露量较多，用来垫床或替代普通卫生巾。"],
  [/胎监带/, "做胎心监护时固定探头用，有些医院要求自带。"],
  [/吸管杯/, "产后或宫缩时不方便起身，躺着喝水更省力。"],
  [/哺乳文胸|哺乳背心/, "方便产后喂奶，也比普通内衣更不勒。"],
  [/防溢乳垫/, "放在内衣里吸收漏奶，避免衣服被打湿。"],
  [/便携式吸奶器|吸奶器/, "涨奶、排奶或回家后储奶时备用。"],
  [/储奶袋|储奶瓶/, "用来保存挤出的母乳，住院期少量准备即可。"],
  [/乳头霜/, "哺乳初期乳头干痛时可用，先少量准备。"],
  [/乳盾/, "套在乳头上的辅助亲喂用品，是否需要先听专业建议。"],
  [/哺乳枕/, "喂奶时托住宝宝和手臂，不是必须。"],
  [/收腹带/, "产后腹部支撑用品，剖宫产尤其要先问医生。"],
  [/安全提篮|安全座椅/, "宝宝出院坐车时使用，提前确认交通方式。"],
  [/奶瓶清洁用品/, "用来清洗奶瓶、奶嘴或吸奶配件，住院只需少量。"],
  [/消毒设备/, "回家后消毒奶瓶或吸奶配件用，住院不一定带大件。"],
  [/喂养记录工具/, "记录吃奶、排尿排便和睡眠，方便家人同步。"],
  [/分娩沟通[单卡]/, "记录生产偏好和需要提前沟通的事，入院时方便给医护看。"],
];

function inferredHospitalBagItemExplanation(item: Record<string, unknown>): string {
  const label = asString(item.label);
  if (!label) return "";
  return hospitalBagItemExplanationRules.find(([pattern]) => pattern.test(label))?.[1] || "";
}

function packingItemIcon(item: Record<string, unknown>, group: Record<string, unknown>): LucideIcon {
  const label = normalizedPackingItemLabel(item, group);
  if (isConfirmFirstPackingItem(item)) return CircleHelp;
  const labelText = label.toLowerCase();
  const text = `${asString(group.group_id)} ${asString(group.title)} ${label}`.toLowerCase();

  if (/(身份证|护照|photo id|id card|陪产人.*身份|支持人.*身份)/.test(labelText)) return IdCard;
  if (/(医保|保险|insurance)/.test(labelText)) return WalletCards;
  if (/(产检|检查|报告|b超|超声|化验|病历|手册|资料)/.test(labelText)) return ClipboardList;
  if (/(准生证|出生证明|birth certificate|证明|证书)/.test(labelText)) return FileCheck;
  if (/(户口本|户口)/.test(labelText)) return BookOpenCheck;
  if (/(复印|copy)/.test(labelText)) return Copy;
  if (/(银行卡|信用卡|bank card|credit card)/.test(labelText)) return CreditCard;
  if (/(现金|零钱|支付|移动支付|钱包)/.test(labelText)) return Banknote;
  if (/(文件|证件)/.test(labelText)) return FileText;

  if (/(手机|smartphone)/.test(labelText)) return Smartphone;
  if (/(充电线|数据线|长充电线|cable)/.test(labelText)) return Cable;
  if (/(充电器|插头|充电宝|电池|power bank)/.test(labelText)) return BatteryCharging;
  if (/(耳机|headphone)/.test(labelText)) return Headphones;

  if (/(吸管杯|水杯|保温杯|杯)/.test(labelText)) return CupSoda;
  if (/(餐具|餐盒|筷|勺|叉)/.test(labelText)) return Utensils;
  if (/(零食|食物|能量|助产食品)/.test(labelText)) return Utensils;

  if (/(安全座椅|安全提篮|car seat)/.test(labelText)) return CarFront;
  if (/(纸尿裤|尿布|尿片|diaper)/.test(labelText)) return BabyIcon;
  if (/(湿巾|棉柔巾|纸巾|wipe)/.test(labelText)) return Droplets;
  if (/(包被|襁褓|包巾|盖毯|blanket|swaddle)/.test(labelText)) return BedSingle;
  if (/(帽子|帽)/.test(labelText)) return CircleDot;
  if (/(袜子|袜|鞋)/.test(labelText)) return Footprints;
  if (/(连体衣|和尚服|新生儿衣|宝宝.*衣|出院衣物)/.test(labelText) && /(宝宝|新生儿|baby)/.test(text)) return Baby;

  if (/(拖鞋|鞋)/.test(labelText)) return Footprints;
  if (/(哺乳文胸|文胸|内衣|内裤|一次性内裤)/.test(labelText)) return Shirt;
  if (/(睡衣|哺乳衣|衣物|衣服|出院外套|外套|背心)/.test(labelText)) return Shirt;

  if (/(产褥垫|护理垫|卫生巾)/.test(labelText)) return Droplets;
  if (/(马桶垫|坐便)/.test(labelText)) return SprayCan;
  if (/(毛巾|浴巾)/.test(labelText)) return Bath;
  if (/(牙刷|牙膏|梳子)/.test(labelText)) return Brush;
  if (/(洗发|沐浴|洗面奶|护肤|冲洗瓶|脸盆|盆)/.test(labelText)) return Bath;

  if (/(吸奶器|奶瓶|奶嘴|配方奶|奶粉|初乳|milk)/.test(labelText)) return Milk;
  if (/(储奶袋|储奶瓶|储奶)/.test(labelText)) return Boxes;
  if (/(乳头霜|乳头膏|防溢乳垫|乳盾)/.test(labelText)) return Heart;
  if (/(哺乳枕)/.test(labelText)) return Armchair;

  if (/(胎监带|胎心|胎动)/.test(labelText)) return HeartPulse;
  if (/(收腹带|束腹带)/.test(labelText)) return ShieldCheck;
  if (/(体温计|温度计)/.test(labelText)) return Thermometer;
  if (/(常用药|止痛|处方|药)/.test(labelText)) return Pill;
  if (/(医生|医院|住院|产后)/.test(labelText)) return Hospital;

  if (/(停车)/.test(labelText)) return CircleParking;
  if (/(路线|交通|打车|出租|车)/.test(labelText)) return Route;
  if (/(陪产人|支持人)/.test(labelText)) return Briefcase;
  if (/(行李|包|收纳)/.test(labelText)) return Luggage;

  if (/(身份证|准生证|户口本|证件|陪产人.*身份)/.test(text)) return IdCard;
  if (/(产检|资料|医保|医保卡|医保本|本|文件|复印)/.test(text)) return ClipboardList;
  if (/(银行卡|现金|支付|移动支付)/.test(text)) return CreditCard;
  if (/(手机|充电|耳机|power bank|cable)/.test(text)) return Smartphone;
  if (/(吸管杯|水杯|杯|餐具|零食|食物|能量|助产食品)/.test(text)) return Utensils;
  if (/(纸尿裤|湿巾|棉柔巾|包被|宝宝|帽子|袜子|安全座椅|安全提篮|出院衣物)/.test(text)) return Baby;
  if (/(出院外套|衣物|衣服|内裤|哺乳衣|睡衣|文胸|背心|拖鞋)/.test(text)) return Shirt;
  if (/(产褥垫|卫生巾|马桶垫|毛巾|纸巾|脸盆|洗发水|沐浴露|洗面奶|护肤|牙刷|牙膏)/.test(text)) return Droplets;
  if (/(吸奶器|储奶|初乳|乳盾|乳头霜|防溢乳垫|奶瓶|配方奶|milk|哺乳)/.test(text)) return Milk;
  if (/(胎监带|收腹带|医生|医院|产后)/.test(text)) return Stethoscope;
  if (/(常用药|药)/.test(text)) return Heart;
  if (/(停车|交通)/.test(text)) return Banknote;
  return Package;
}

function packingItemIconTone(item: Record<string, unknown>, group: Record<string, unknown>): string {
  const label = normalizedPackingItemLabel(item, group);
  const text = `${asString(group.group_id)} ${asString(group.title)} ${label}`.toLowerCase();
  if (isConfirmFirstPackingItem(item)) return "tone-confirm";
  if (/(身份证|准生证|户口本|证件|产检|资料|医保|文件|复印|银行卡|现金|支付)/.test(text)) return "tone-documents";
  if (/(手机|充电|耳机|power bank|cable|通讯|随身)/.test(text)) return "tone-tech";
  if (/(纸尿裤|湿巾|棉柔巾|包被|宝宝|帽子|袜子|安全座椅|安全提篮|出院衣物)/.test(text)) return "tone-baby";
  if (/(出院外套|衣物|衣服|内裤|哺乳衣|睡衣|文胸|背心|拖鞋)/.test(text)) return "tone-clothes";
  if (/(产褥垫|卫生巾|马桶垫|毛巾|纸巾|脸盆|洗发水|沐浴露|洗面奶|护肤|牙刷|牙膏)/.test(text)) return "tone-care";
  if (/(吸奶器|储奶|初乳|乳盾|乳头霜|防溢乳垫|奶瓶|配方奶|milk|哺乳)/.test(text)) return "tone-feeding";
  if (/(吸管杯|水杯|杯|餐具|零食|食物|能量|助产食品)/.test(text)) return "tone-food";
  if (/(胎监带|收腹带|医生|医院|产后|常用药|药)/.test(text)) return "tone-health";
  if (/(停车|交通)/.test(text)) return "tone-travel";
  return "tone-default";
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
    planned_c_section: "剖宫产",
    c_section: "剖宫产",
    "计划剖宫产": "剖宫产",
    "剖腹产": "剖宫产",
    "刨腹产": "剖宫产",
    breastfeeding: "母乳喂养",
    "母乳": "母乳喂养",
    formula: "配方喂养",
    "配方": "配方喂养",
    formula_feeding: "配方喂养",
    mixed: "混合喂养",
    "混合": "混合喂养",
  };
  return labels[text.toLowerCase()] || value;
}

function hospitalBagProfileValue(label: string, value: unknown): unknown {
  const normalized = hospitalBagMetaValue(value);
  const text = formatPlainValue(normalized).trim();
  if (label === "孕期" && /^\d{1,2}$/.test(text)) return `${text}周`;
  return normalized;
}

function hospitalBagTitle(value: unknown): string {
  const title = asString(value).trim();
  if (!title || title === "Hospital Bag Card" || (title.includes("待产包") && title.includes("卡片"))) return "待产包";
  return title;
}

function normalizeBirthPlanCard(cardJsonRaw: Record<string, unknown>) {
  const owner = asObject(cardJsonRaw.owner) ?? {};
  const overview = asObject(cardJsonRaw.overview) ?? {};
  const birthPreferences = asObject(cardJsonRaw.birth_preferences) ?? {};
  return {
    title: normalizeBirthPlanValue(asString(cardJsonRaw.title)) || "分娩沟通单",
    subtitle: normalizeBirthPlanValue(asString(cardJsonRaw.subtitle)) || "产房沟通重点",
    overview: {
      due_date_or_week: normalizeBirthPlanValue(overview.due_date_or_week ?? owner.due_date_or_week),
      birth_path: normalizeBirthPlanValue(overview.birth_path ?? birthPreferences.birth_path),
      birth_setting: normalizeBirthPlanValue(overview.birth_setting ?? owner.birth_setting),
      support_people: normalizeBirthPlanValue(overview.support_people ?? owner.support_people),
    },
    top_priorities: compactBirthPlanList(
      cardJsonRaw.top_priorities ?? asObject(cardJsonRaw.if_plans_change)?.what_matters_most,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    communication: compactBirthPlanList(
      cardJsonRaw.communication ?? cardJsonRaw.communication_preferences,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    labor_preferences: compactBirthPlanList(cardJsonRaw.labor_preferences, BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT),
    intervention_preferences: compactBirthPlanList(
      cardJsonRaw.intervention_preferences,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    pain_relief: compactBirthPlanList(
      cardJsonRaw.pain_relief ?? cardJsonRaw.pain_relief_preferences,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    baby_after_birth: compactBirthPlanList(
      cardJsonRaw.baby_after_birth ?? cardJsonRaw.baby_after_birth_preferences,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    if_plans_change: compactBirthPlanList(cardJsonRaw.if_plans_change, BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT),
    emergency_authorization: compactBirthPlanList(
      cardJsonRaw.emergency_authorization,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    questions_for_hospital: compactBirthPlanList(
      cardJsonRaw.questions_for_hospital,
      BIRTH_PLAN_CARD_SECTION_ITEM_LIMIT,
    ),
    medical_notes: compactBirthPlanList(cardJsonRaw.medical_notes, 3),
    personalized_notes: compactBirthPlanList(cardJsonRaw.personalized_notes, 3),
    disclaimer:
      normalizeBirthPlanValue(asString(cardJsonRaw.disclaimer)) ||
      "这份沟通单只用于沟通。请优先遵循医生和医院建议，尤其是因安全原因需要调整计划时。",
  };
}

function normalizeBirthJourneyPlanCard(cardJsonRaw: Record<string, unknown>) {
  const owner = asObject(cardJsonRaw.owner) ?? {};
  const nextAction = asObject(cardJsonRaw.next_action) ?? {};
  const planningLayers = asObject(cardJsonRaw.planning_layers);
  const layeredSections = normalizeBirthJourneyPlanningLayerSections(planningLayers);
  return {
    title: asString(cardJsonRaw.title) || "孕期计划",
    subtitle: asString(cardJsonRaw.subtitle),
    owner,
    layered_sections: layeredSections,
    next_action: {
      label: asString(nextAction.label),
      send_text: asString(nextAction.send_text),
    },
    disclaimer: asString(cardJsonRaw.disclaimer),
  };
}

function normalizeBirthJourneyPlanningLayerSections(
  layers: Record<string, unknown> | null,
): BirthJourneyPlanCardSection[] {
  if (!layers) return [];
  return [
    normalizeBirthJourneyPlanningLayerSection(layers, "current_week_focus", "当前阶段目标", "warm"),
    normalizeBirthJourneyPlanningLayerSection(layers, "next_7_days", "接下来 7 天行动"),
    normalizeBirthJourneyPlanningLayerSection(layers, "next_2_4_weeks", "未来 2-4 周"),
    normalizeBirthJourneyPlanningLayerSection(layers, "later_milestones", "后续重要节点"),
  ].filter((section): section is BirthJourneyPlanCardSection => Boolean(section));
}

function normalizeBirthJourneyPlanningLayerSection(
  layers: Record<string, unknown>,
  key: string,
  fallbackTitle: string,
  tone: BirthJourneyPlanCardSection["tone"] = "plain",
): BirthJourneyPlanCardSection | null {
  const section = asObject(layers[key]) ?? {};
  const items = normalizeBirthJourneyPlanItems(section.items);
  if (items.length === 0) return null;
  return {
    key,
    title: asString(section.title).trim() || fallbackTitle,
    subtitle: asString(section.subtitle).trim(),
    items,
    tone,
  };
}

function normalizeBirthJourneyPlanItems(values: unknown): BirthJourneyPlanCardItem[] {
  const rawItems = Array.isArray(values) ? values : hasDisplayValue(values) ? [values] : [];
  return rawItems
    .map((item) => {
      if (typeof item === "string") {
        const title = truncateBirthJourneyPlanText(item, BIRTH_JOURNEY_PLAN_ITEM_TITLE_MAX_CHARS);
        return title && !isConfirmPlaceholder(title) ? { title, reason: "" } : null;
      }
      const source = asObject(item);
      if (!source) return null;
      const title = truncateBirthJourneyPlanText(source.title, BIRTH_JOURNEY_PLAN_ITEM_TITLE_MAX_CHARS);
      if (!title || isConfirmPlaceholder(title)) return null;
      return {
        title,
        reason: asString(source.reason).trim(),
      };
    })
    .filter((item): item is BirthJourneyPlanCardItem => Boolean(item));
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

function asObjectList(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.map((item) => asObject(item)).filter((item): item is Record<string, unknown> => Boolean(item))
    : [];
}

function MilkManagementStructuredCard({
  cardJson,
  cardType,
}: {
  cardJson: Record<string, unknown>;
  cardType: string;
}) {
  const isPlan = cardType === "milk_plan_card";
  const title = asString(cardJson.title) || (isPlan ? "奶量计划草稿" : "奶量分析");
  const subtitle = asString(cardJson.subtitle);
  const statusLabel = isPlan ? "" : asString(cardJson.status_label);
  const statusTone = asString(cardJson.status_tone);
  const headline = asString(cardJson.headline);
  const sections = asObjectList(cardJson.sections);
  const Icon = isPlan ? Route : Droplets;
  const toneClass =
    statusTone === "normal"
      ? "border-[#cfe3d9] bg-[#f6fbf8] text-[#2d5f51]"
      : statusTone === "insufficient"
        ? "border-[#ded9e8] bg-[#faf8ff] text-[#66557f]"
        : "border-[#ead6df] bg-[#fff8fa] text-[#7a4259]";

  return (
    <div className="grid gap-3">
      <header className="flex items-start gap-3">
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-[#eef7f6] text-[#207d83]">
          <Icon className="h-5 w-5" aria-hidden="true" />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <h3 className="text-[19px] font-black leading-tight text-[#2f1f29]">{title}</h3>
              {subtitle ? <p className="mt-1 text-[12px] leading-snug text-[#8b7581]">{subtitle}</p> : null}
            </div>
            {statusLabel ? (
              <span className={cn("shrink-0 rounded-full border px-2.5 py-1 text-[11px] font-bold", toneClass)}>
                {statusLabel}
              </span>
            ) : null}
          </div>
        </div>
      </header>
      {headline ? <p className="text-[14px] font-normal leading-relaxed text-[#3b2731]">{headline}</p> : null}

      {sections.length > 0 ? (
        <div className="grid gap-2.5">
          {sections.map((section, index) => {
            const titleText = asString(section.title);
            const metrics = asObjectList(section.metrics);
            const items = Array.isArray(section.items) ? section.items.map((item) => String(item).trim()).filter(Boolean) : [];
            const sectionTone = asString(section.tone);
            return (
              <section
                key={asString(section.id) || `${titleText}-${index}`}
                className={cn(
                  "rounded-[16px] border p-3",
                  sectionTone === "attention"
                    ? "border-[#ead6df] bg-[#fff8fa]"
                    : sectionTone === "normal"
                      ? "border-[#d8e7dd] bg-[#f7fbf8]"
                      : sectionTone === "info"
                        ? "border-[#d7e6ea] bg-[#f7fcfd]"
                        : "border-[#eadfe5] bg-white",
                )}
              >
                {titleText ? <h4 className="mb-2 text-[14px] font-black text-[#3a2530]">{titleText}</h4> : null}
                {metrics.length > 0 ? (
                  <div className="mb-2 grid grid-cols-1 gap-2 min-[390px]:grid-cols-3">
                    {metrics.map((metric, metricIndex) => (
                      <div key={`${asString(metric.label)}-${metricIndex}`} className="rounded-[12px] bg-white/80 px-2.5 py-2 shadow-[inset_0_0_0_1px_rgba(80,50,65,0.07)]">
                        <p className="text-[10px] font-semibold leading-tight text-[#917c87]">{asString(metric.label)}</p>
                        <p className="mt-1 text-[14px] font-black leading-tight text-[#33212b]">{asString(metric.value) || "—"}</p>
                        {asString(metric.detail) ? <p className="mt-1 text-[10px] leading-tight text-[#9b8791]">{asString(metric.detail)}</p> : null}
                      </div>
                    ))}
                  </div>
                ) : null}
                {items.length > 0 ? (
                  isPlan ? (
                    <ul className="grid gap-1.5">
                      {items.map((item, itemIndex) => (
                        <li key={`${item}-${itemIndex}`} className="flex gap-2 text-[12px] font-medium leading-relaxed text-[#5c4852]">
                          <span className="mt-[0.62em] h-1.5 w-1.5 shrink-0 rounded-full bg-[#b98ca1]" aria-hidden="true" />
                          <span className="min-w-0 flex-1">{item}</span>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <div className="grid gap-1.5">
                      {items.map((item, itemIndex) => (
                        <p key={`${item}-${itemIndex}`} className="text-[12px] font-medium leading-relaxed text-[#5c4852]">
                          {item}
                        </p>
                      ))}
                    </div>
                  )
                ) : null}
              </section>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

const AgentHubRichTextBlock: React.FC<{
  payload: ChatRichTextPayload;
  blockId?: string;
  birthPrepProfileDefaults?: BirthPrepProfileFormDefaults | null;
  onButtonSelect: (value: string, options?: ButtonSelectOptions) => ButtonSelectResult;
  onOpenIbclcConsult?: (request: IbclcConsultOpenRequest) => void;
}> = ({ payload, blockId = "rich", birthPrepProfileDefaults = null, onButtonSelect, onOpenIbclcConsult }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const [artifactError, setArtifactError] = useState<Record<number, string>>({});
  const [submittedArtifactMap, setSubmittedArtifactMap] = useState<Record<number, boolean>>({});
  const [downloadingCardIndex, setDownloadingCardIndex] = useState<number | null>(null);
  const submitGuardRef = useRef<Record<number, boolean>>({});
  const [ibclcCompletions, setIbclcCompletions] = useState<IbclcConsultCompletedPayload[]>(() =>
    readStoredIbclcConsultCompletions(),
  );
  const [ibclcAgreementAcceptedById, setIbclcAgreementAcceptedById] = useState<Record<string, boolean>>({});
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

  const visibleCards = useMemo(
    () => payload.card.filter((card) => card.type.trim() !== "吸奶结束"),
    [payload.card],
  );

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

  const openHospitalBagCart = () => {
    if (typeof window === "undefined") return;
    window.dispatchEvent(
      new CustomEvent(OPEN_HOSPITAL_BAG_CART_EVENT, {
        cancelable: true,
        detail: { href: "/hospital-bag-cart", source: "hospital_bag_card" },
      }),
    );
  };

  const renderFormField = (field: FormFieldSpec, variant: "default" | "monochrome" = "default") => {
    const isMonochrome = variant === "monochrome";
    const hasDefaultValue = hasFormDefaultValue(field.default_value);
    const defaultValue = hasDefaultValue ? asString(field.default_value) : "";
    const fieldKey = `${field.id}:${JSON.stringify(field.default_value ?? "")}`;
    const requiredMark = field.required ? (
      <span className="mt-[1px] shrink-0 text-[15px] font-bold leading-none text-[#d84c5f]" aria-hidden="true">
        *
      </span>
    ) : null;
    const fieldTextClass = isMonochrome ? "text-neutral-950 dark:text-neutral-50" : "text-foreground";
    const inputClassName = cn(
      "w-full min-w-0 border outline-none transition-colors",
      isMonochrome
        ? "min-h-[44px] rounded-[14px] border-neutral-200 bg-white/95 px-3 py-2.5 text-[15px] text-neutral-950 placeholder:text-neutral-400 focus:border-[#207d93] focus:ring-[3px] focus:ring-[#207d93]/10 dark:border-neutral-700 dark:bg-background dark:text-neutral-50 dark:placeholder:text-neutral-500 dark:focus:border-neutral-100 dark:focus:ring-neutral-100"
        : "rounded-lg border-border bg-background px-2 py-1.5 text-[12px]",
    );
    if (isMultiSelectField(field)) {
      const defaults = defaultMultiSelectValues(field.default_value);
      return (
        <fieldset
          key={fieldKey}
          className={cn(
            isMonochrome ? "rounded-[14px] border p-3" : "rounded-lg border p-2.5",
            "min-w-0",
            isMonochrome ? "border-neutral-200 bg-white/95 dark:border-neutral-700 dark:bg-background" : "border-border/60",
          )}
        >
          <legend className={cn("px-1 font-semibold", isMonochrome ? "text-[14px]" : "text-[12px]", fieldTextClass)}>
            <span className="inline-flex items-start gap-2">
              {requiredMark}
              <span>{field.label}</span>
            </span>
          </legend>
          <div className="grid gap-2 pt-1">
            {(field.options ?? []).map((option) => {
              const showOtherInput = Boolean(field.allow_other_input && isOtherOption(option));
              return (
                <div
                  key={option}
                  className={cn(
                    "grid gap-2",
                    showOtherInput ? "[&:has(input[type='checkbox']:checked)_.form-other-input]:block" : "",
                  )}
                >
                  <label
                    className={cn(
                      "inline-flex items-center gap-2 rounded-xl border px-3 py-2",
                      isMonochrome ? "border-neutral-200 bg-[#fbfaf9] text-[14px]" : "border-border/70 bg-background/70 text-[12px]",
                      fieldTextClass,
                    )}
                  >
                    <input type="checkbox" name={field.id} value={option} defaultChecked={defaults.includes(option)} />
                    <span className="min-w-0 break-words">{option}</span>
                  </label>
                  {showOtherInput ? (
                    <input
                      name={otherInputName(field.id)}
                      type="text"
                      placeholder={field.other_placeholder || "请补充说明"}
                      className={cn(inputClassName, "form-other-input hidden")}
                    />
                  ) : null}
                </div>
              );
            })}
          </div>
          {field.help_text ? (
            <small className={cn(isMonochrome ? "text-[12px]" : "text-[11px]", isMonochrome ? "text-neutral-600 dark:text-neutral-400" : "text-muted-foreground")}>
              {field.help_text}
            </small>
          ) : null}
        </fieldset>
      );
    }
    return (
      <label key={fieldKey} className={cn("grid min-w-0 gap-1.5", isMonochrome ? "text-[14px]" : "text-[12px]", fieldTextClass)}>
        <span className="inline-flex items-start gap-2 font-semibold leading-snug">
          {requiredMark}
          <span>{field.label}</span>
        </span>
        {field.type === "select" ? (
          <select
            key={fieldKey}
            name={field.id}
            aria-label={field.label}
            required={Boolean(field.required)}
            className={cn(inputClassName, !hasDefaultValue ? "agent-form-select-placeholder" : "")}
            defaultValue={defaultValue}
          >
            {!hasDefaultValue ? (
              <option value="" disabled className="text-neutral-400 dark:text-neutral-500">
                {field.placeholder || "请选择"}
              </option>
            ) : null}
            {(field.options ?? []).map((option) => (
              <option key={option} value={option} className={isMonochrome ? "text-neutral-950 dark:text-neutral-50" : "text-foreground"}>
                {option}
              </option>
            ))}
          </select>
        ) : field.type === "textarea" ? (
          <textarea
            key={fieldKey}
            name={field.id}
            aria-label={field.label}
            required={Boolean(field.required)}
            rows={3}
            placeholder={field.placeholder}
            defaultValue={asString(field.default_value)}
            className={inputClassName}
          />
        ) : (
          <input
            key={fieldKey}
            name={field.id}
            aria-label={field.label}
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
      <div className="w-full min-w-0 space-y-2">
        {mergedArtifacts.map((artifact, index) => {
          const isSubmitted = Boolean(submittedArtifactMap[index]);
          const errorText = artifactError[index] || "";
          if (artifact.kind === "ibclc_consult") {
            const consultant = asObject(artifact.card.consultant) ?? {};
            const chat = asObject(artifact.card.chat) ?? {};
            const title = asString(artifact.card.title) || "IBCLC 在线咨询";
            const consultantName = asString(consultant.name) || "IBCLC 顾问";
            const consultantCredentials = asString(consultant.credentials) || "IBCLC 国际认证哺乳顾问";
            const consultantExperience = asString(consultant.experience);
            const consultantBio = cleanIbclcConsultantBio(consultant.bio);
            const url = asString(chat.url) || "/ibclc-chat.html";
            const chatLabel = asString(chat.label) || "咨询 IBCLC";
            const chatNote = asString(chat.note) || "启动咨询后，会自动将你的问题同步给顾问";
            const threadId = getAgUiThreadIdForRequest();
            const consultId =
              asString(artifact.card.consult_id) ||
              asString(artifact.card.consultId) ||
              artifact.artifactId ||
              stableIbclcConsultId(JSON.stringify(artifact.card));
            const returnTo = `${location.pathname}${location.search}${location.hash}`;
            const chatUrl = buildIbclcChatUrl(url, consultId, threadId, returnTo, DEFAULT_CHAT_USER_ID);
            const consultCompleted = ibclcCompletions.some((completion) =>
              isIbclcCompletionForCard(completion, threadId, consultId),
            );
            const agreementAccepted = Boolean(ibclcAgreementAcceptedById[consultId]);
            const consultButtonDisabled = consultCompleted || !agreementAccepted;
            const openConsult = () => {
              if (consultButtonDisabled) return;
              if (onOpenIbclcConsult) {
                onOpenIbclcConsult({ consultId, threadId, userId: DEFAULT_CHAT_USER_ID, returnTo, chatUrl });
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
                className="grid w-full min-w-0 gap-[14px] rounded-[14px] border border-[#d6dde5] bg-[#fbfdfc] p-[18px] text-[#273b3a] shadow-sm"
              >
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <HeartPulse aria-hidden="true" className="h-[22px] w-[22px] shrink-0 text-[#177a89]" />
                    <h3 className="m-0 text-[22px] font-[800] leading-[1.15] text-[#142726]">{title}</h3>
                  </div>
                </div>
                <section className="grid grid-cols-[56px_minmax(0,1fr)] items-start gap-3 rounded-[12px] border border-[#d6dde5] bg-white p-3">
                  <img
                    src={ibclcConsultantAvatar}
                    alt={consultantName}
                    className="mt-[2px] h-[56px] w-[56px] rounded-full object-cover"
                    loading="lazy"
                  />
                  <div className="min-w-0">
                    <strong className="block text-[16px] font-[800] leading-[1.2] text-[#182b2a]">{consultantName}</strong>
                    <div className="mt-[6px] flex flex-wrap gap-1.5">
                      <span className="rounded-full bg-[#e9f3f1] px-2 py-1 text-[11px] font-[800] leading-none text-[#1a6863]">
                        {consultantCredentials}
                      </span>
                      {consultantExperience ? (
                        <span className="rounded-full bg-[#f4edf1] px-2 py-1 text-[11px] font-[800] leading-none text-[#7a4260]">
                          {consultantExperience}
                        </span>
                      ) : null}
                    </div>
                    {consultantBio ? <p className="mt-[7px] text-[13px] leading-[1.45] text-[#60706e]">{consultantBio}</p> : null}
                  </div>
                </section>
                {!consultCompleted ? (
                  <div className="rounded-[10px] border border-[#dbe7e4] bg-[#f6fbfa] px-3 py-2">
                    <label className="flex items-start gap-2 text-[12px] font-[700] leading-[1.45] text-[#586967]">
                      <input
                        type="checkbox"
                        checked={agreementAccepted}
                        onChange={(event) => {
                          const accepted = event.currentTarget.checked;
                          setIbclcAgreementAcceptedById((prev) => ({ ...prev, [consultId]: accepted }));
                        }}
                        className="mt-[1px] h-4 w-4 shrink-0 rounded border-[#b9cbc8] accent-[#177a89]"
                      />
                      <span>我已阅读并同意《隐私政策》和《服务协议》</span>
                    </label>
                    <p className="m-0 mt-1.5 pl-6 text-[11px] leading-[1.45] text-[#71807d]">{chatNote}</p>
                  </div>
                ) : null}
                <button
                  type="button"
                  disabled={consultButtonDisabled}
                  aria-disabled={consultButtonDisabled}
                  className={cn(
                    "inline-flex min-h-[46px] items-center justify-center rounded-xl px-3 text-[14px] font-black no-underline",
                    consultCompleted
                      ? "cursor-default bg-[#d7dfdd] text-[#778683]"
                      : agreementAccepted
                        ? "bg-[#177a89] text-white"
                        : "cursor-not-allowed bg-[#d7dfdd] text-[#778683]",
                  )}
                  onClick={openConsult}
                >
                  {consultCompleted ? "咨询结束" : chatLabel}
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
                aria-label={downloadingCardIndex === index ? "正在保存图片" : "保存卡片图片"}
              >
                {downloadingCardIndex === index ? (
                  <>
                    <span className="card-export-spinner" aria-hidden="true" />
                    <span>保存中</span>
                  </>
                ) : (
                  <>
                    <Download aria-hidden="true" />
                    <span>保存图片</span>
                  </>
                )}
              </button>
            );
            if ((cardType === "milk_analysis_card" || cardType === "milk_plan_card") && schemaVersion === "1.0") {
              const showDownloadButton = false;
              return (
                <article
                  key={`artifact-${index}`}
                  ref={(el) => {
                    cardArtifactRefs.current[index] = el;
                  }}
                  className="relative w-full min-w-0 rounded-[22px] border border-[#eadfe5] bg-[#fffdfc] p-4 text-[#33212b] shadow-[0_12px_30px_rgba(65,42,52,0.07)]"
                >
                  <MilkManagementStructuredCard cardJson={cardJson} cardType={cardType} />
                  {showDownloadButton ? <div className="mt-3 flex justify-end">{downloadButton}</div> : null}
                </article>
              );
            }
            if (cardType === "birth_journey_plan_card" && schemaVersion === "1.0") {
              const journey = normalizeBirthJourneyPlanCard(cardJson);
              const ownerChips = [
                ["孕期", journey.owner.current_week || journey.owner.due_date_or_week],
                ["预产期预计", journey.owner.estimated_due_date],
                ["方式", journey.owner.birth_path],
                ["支持", journey.owner.support_person],
                ["喂养", journey.owner.feeding_intention],
              ].filter(([, value]) => hasDisplayValue(value) && !isConfirmPlaceholder(value)).slice(0, 4);
              return (
                <article
                  key={`artifact-${index}`}
                  ref={(el) => {
                    cardArtifactRefs.current[index] = el;
                  }}
                  className="agent-card agent-card-birth_journey_plan_card"
                >
                  <header className="agent-card-header">
                    <div className="agent-card-header-text">
                      <h2>{journey.title}</h2>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <img src={MOMCOZY_LOGO_SRC} alt="Momcozy" className="agent-card-logo" />
                    </div>
                  </header>

                  {ownerChips.length > 0 ? (
                    <dl className="birth-journey-owner-strip">
                      {ownerChips.map(([label, value]) => (
                        <div key={label}>
                          <dt>{label}</dt>
                          <dd>{formatPlainValue(value)}</dd>
                        </div>
                      ))}
                    </dl>
                  ) : null}

                  {journey.layered_sections.length > 0 ? (
                    <section className="birth-journey-layered-plan" aria-label="孕期计划">
                      {journey.layered_sections.map((section, sectionIndex) => (
                        <section
                          key={section.key}
                          className={cn(
                            "birth-journey-layered-section",
                            section.tone === "warm" ? "is-warm" : "is-plain",
                          )}
                        >
                          <div className="birth-journey-layered-section-header">
                            <div>
                              <h3>{section.title}</h3>
                              {section.subtitle ? <p>{section.subtitle}</p> : null}
                            </div>
                            <span>{String(sectionIndex + 1).padStart(2, "0")}</span>
                          </div>
                          <div className="birth-journey-layered-items">
                            {section.items.map((item, itemIndex) => (
                              <div key={`${section.key}-${item.title}-${itemIndex}`} className="birth-journey-layered-item">
                                <span>{itemIndex + 1}</span>
                                <div>
                                  <p>{item.title}</p>
                                  {item.reason ? <p>{item.reason}</p> : null}
                                </div>
                              </div>
                            ))}
                          </div>
                        </section>
                      ))}
                    </section>
                  ) : null}

                  <div className="agent-card-footer birth-journey-footer">
                    <div className="birth-journey-footer-actions">
                      {downloadButton}
                    </div>
                  </div>
                </article>
              );
            }
            if (cardType === "birth_plan_card" && schemaVersion === "1.0") {
              const bp = normalizeBirthPlanCard(cardJson);
              const groups: Array<{ title: string; values: string[]; Icon: LucideIcon; tone: string }> = [
                { title: "沟通方式", values: bp.communication, Icon: Headphones, tone: "teal" },
                { title: "生产时偏好", values: bp.labor_preferences, Icon: Footprints, tone: "blue" },
                { title: "需要先沟通的操作", values: bp.intervention_preferences, Icon: ShieldCheck, tone: "mint" },
                { title: "疼痛缓解", values: bp.pain_relief, Icon: Heart, tone: "rose" },
                { title: "宝宝出生后", values: bp.baby_after_birth, Icon: Baby, tone: "gold" },
                { title: "计划变化时", values: bp.if_plans_change, Icon: Stethoscope, tone: "blue" },
                { title: "紧急情况", values: bp.emergency_authorization, Icon: HeartPulse, tone: "rose" },
                { title: "提前问医院", values: bp.questions_for_hospital, Icon: CircleHelp, tone: "mint" },
              ].filter((group) => group.values.length > 0);
              return (
                <article
                  key={`artifact-${index}`}
                    ref={(el) => {
                      cardArtifactRefs.current[index] = el;
                    }}
                    className="agent-card agent-card-birth_plan_card"
                >
                    <header className="agent-card-header">
                      <div className="agent-card-header-text">
                        <h2>{bp.title}</h2>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <img src={MOMCOZY_LOGO_SRC} alt="Momcozy" className="agent-card-logo" />
                    </div>
                  </header>
                  {groups.length > 0 ? (
                    <section className="birth-plan-preference-section">
                      <h3>沟通卡片内容</h3>
                      <div className="birth-plan-group-list">
                        {groups.map(({ title, values, Icon, tone }) => (
                          <div key={title} className={cn("birth-plan-group", `birth-plan-group-${tone}`)}>
                            <div className="birth-plan-group-title">
                              <span aria-hidden="true">
                                <Icon />
                              </span>
                              <h4>{title}</h4>
                            </div>
                            <ul className="agent-card-list">
                              {values.map((value, i) => (
                                <li key={i}>{value}</li>
                              ))}
                            </ul>
                          </div>
                        ))}
                      </div>
                    </section>
                  ) : null}
                    {bp.medical_notes.length > 0 ? (
                    <section className="birth-plan-medical-panel">
                      <h3>医疗或安全信息</h3>
                      <ul className="agent-card-list">
                        {bp.medical_notes.map((value, i) => (
                          <li key={i}>{value}</li>
                        ))}
                      </ul>
                    </section>
                    ) : null}
                    {bp.disclaimer ? <p className="agent-card-disclaimer">{bp.disclaimer}</p> : null}
                    {downloadButton}
                </article>
              );
            }
            if (cardType === "hospital_bag_card" && schemaVersion === "1.0") {
              const subtitle = "住院母婴必备用品 · 32～34周准备 · 36周完成";
              const packingGroups = compactPackingGroups(cardJson.packing_groups);
              const disclaimer = asString(cardJson.disclaimer);
              return (
                <article
                  key={`artifact-${index}`}
                  ref={(el) => {
                    cardArtifactRefs.current[index] = el;
                  }}
                  className="agent-card agent-card-hospital_bag_card"
                >
                  <header className="agent-card-header">
                    <div className="agent-card-header-text">
                      <h2>{hospitalBagTitle(cardJson.title)}</h2>
                      {subtitle ? <p className="hospital-card-subtitle">{subtitle}</p> : null}
                    </div>
                    <div className="flex items-center gap-1.5">
                      <img src={MOMCOZY_LOGO_SRC} alt="Momcozy" className="agent-card-logo" />
                    </div>
                  </header>
                  {packingGroups.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>物品清单</h3>
                      {packingGroups.map((group, gIdx) => (
                        <details key={gIdx} className="packing-group" open={gIdx === 0}>
                          <summary>
                            <span>{asString(group.title) || formatLabel(asString(group.group_id) || "Group")}</span>
                            <small>{group.items.length}项</small>
                          </summary>
                          <div>
                            {group.items.map((item, i) => {
                              const ItemIcon = packingItemIcon(item, group);
                              const description = packingItemDescription(item);
                              const personalizationText = packingItemPersonalizationText(item, group);
                              return (
                                <div key={i} className="packing-item">
                                  <span className={cn("packing-item-icon", packingItemIconTone(item, group))} aria-hidden="true">
                                    <ItemIcon />
                                  </span>
                                  <span className="packing-item-name">{renderHospitalCardValue(normalizedPackingItemLabel(item, group))}</span>
                                  {packingItemMeta(item, group) ? <strong className="packing-item-quantity">{renderHospitalCardValue(packingItemMeta(item, group))}</strong> : null}
                                  {item.priority ? (
                                    <span className={priorityClassName(item.priority)}>
                                      {priorityLabel(item.priority)}
                                    </span>
                                  ) : null}
                                  {description ? <small className="packing-item-explain">{description}</small> : null}
                                  {personalizationText ? (
                                    <small className="packing-item-reasons">{personalizationText}</small>
                                  ) : null}
                                </div>
                              );
                            })}
                          </div>
                        </details>
                      ))}
                    </section>
                  ) : null}
                  <div className="agent-card-footer">
                    {disclaimer ? <p className="agent-card-disclaimer">{disclaimer}</p> : null}
                    <div className="birth-journey-footer-actions">
                      <button
                        type="button"
                        onClick={openHospitalBagCart}
                        className="card-export-button"
                        title="打开待产包购物车"
                        aria-label="打开待产包购物车"
                      >
                        <ShoppingBag aria-hidden="true" />
                        <span>打开购物车</span>
                        <ChevronRight aria-hidden="true" />
                      </button>
                      {downloadButton}
                    </div>
                  </div>
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
                className="relative w-full min-w-0 rounded-xl border border-border bg-card p-3 space-y-2"
              >
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
                {downloadButton}
              </article>
            );
          }
          const formSpec =
            artifact.kind === "support_ticket_draft"
              ? { id: "support_ticket", title: "售后工单", fields: supportTicketFields(artifact.ticket) }
              : artifact.form;
          const isSupportTicket = artifact.kind === "support_ticket_draft";
          const formId = asString(formSpec.id);
          const profileFormDefaultValues = birthPrepProfileFormDefaultValues(birthPrepProfileDefaults);
          const formDefaultValues = { ...profileFormDefaultValues, ...(asObject(formSpec.default_values) ?? {}) };
          const fieldsRaw = Array.isArray(formSpec.fields) ? formSpec.fields : [];
          const parsedFields: FormFieldSpec[] = fieldsRaw
            .map((f) => asObject(f))
            .filter((x): x is Record<string, unknown> => Boolean(x))
            .map((f) => {
              const id = asString(f.id);
              const fieldDefaultValue = hasFormDefaultValue(f.default_value) ? f.default_value : formDefaultValues[id];
              return {
                id,
                label: asString(f.label),
                type: asString(f.type) || "text",
                required: Boolean(f.required),
                options: Array.isArray(f.options) ? f.options.map((opt) => String(opt)) : [],
                allow_other_input: Boolean(f.allow_other_input),
                default_value: fieldDefaultValue,
                placeholder: asString(f.placeholder),
                other_placeholder: asString(f.other_placeholder),
                help_text: asString(f.help_text),
              };
            })
            .filter((f) => f.id);
          const isHospitalBagIntake = formId === "hospital_bag_intake" || looksLikeHospitalBagForm(parsedFields);
          const isBirthPlanIntake = formId === "birth_plan_card_intake";
          const isBirthJourneyBasicInfoIntake = formId === "birth_journey_basic_info_intake";
          const isGroupedIntake = isHospitalBagIntake || isBirthPlanIntake;
          const isCollectionIntake = isGroupedIntake || isBirthJourneyBasicInfoIntake;
          const isMonochromeForm = isSupportTicket || isHospitalBagIntake || isBirthPlanIntake || isBirthJourneyBasicInfoIntake;
          const title = isHospitalBagIntake || isBirthPlanIntake ? "信息采集" : asString(formSpec.title) || "Confirm details";
          const normalizedFormSpec = isHospitalBagIntake
            ? { ...formSpec, id: "hospital_bag_intake", title, description: "" }
            : isBirthPlanIntake
              ? { ...formSpec, title, description: "" }
              : isBirthJourneyBasicInfoIntake
                ? { ...formSpec, title, description: asString(formSpec.description) }
                : formSpec;
          const fields: FormFieldSpec[] = parsedFields
            .filter((field) => !(isHospitalBagIntake && REMOVED_HOSPITAL_BAG_FORM_FIELD_IDS.has(field.id)))
            .map((field) => (isHospitalBagIntake ? sanitizeHospitalBagIntakeField(field) : field))
            .map((field) => {
              if (!((isHospitalBagIntake || isBirthPlanIntake) && field.id === "birth_path")) {
                return field;
              }
              const normalizedField = {
                ...field,
                label: isHospitalBagIntake
                  ? splitFormFieldLabel(field.label).groupTitle
                    ? `${splitFormFieldLabel(field.label).groupTitle}｜分娩方式`
                    : "分娩方式"
                  : splitFormFieldLabel(field.label).groupTitle
                    ? `${splitFormFieldLabel(field.label).groupTitle}｜医生目前建议的生产方式`
                    : "医生目前建议的生产方式",
                options: isHospitalBagIntake ? field.options : ["顺产", "剖宫产", "还没确定"],
                default_value: ["计划剖宫产", "剖腹产", "planned_c_section", "c_section", "c-section", "cesarean"].includes(asString(field.default_value))
                  ? "剖宫产"
                  : field.default_value,
              };
              return normalizedField;
            })
            .map((field) => (isHospitalBagIntake || isBirthPlanIntake ? { ...field, help_text: "" } : field))
            .filter((f) => f.id);
          const fieldGroups = isBirthJourneyBasicInfoIntake
            ? [{ title: "基本信息", fields }]
            : isGroupedIntake
              ? groupFormFields(fields)
              : [{ title: "", fields }];

          return (
            <form
              key={`artifact-${index}`}
              className={cn(
                "w-full min-w-0",
                isCollectionIntake ? "rounded-[24px] border p-4 space-y-4" : "rounded-xl border p-3 space-y-2.5",
                isCollectionIntake
                  ? "border-[#eadfe5] bg-[#fffdfc] text-neutral-950 shadow-[0_10px_30px_rgba(65,42,52,0.06)] dark:border-neutral-800 dark:bg-background dark:text-neutral-50"
                  : isMonochromeForm
                    ? "border-neutral-200 bg-white text-neutral-950 shadow-none dark:border-neutral-800 dark:bg-background dark:text-neutral-50"
                    : "border-border bg-card",
              )}
              onSubmit={(event) => {
                event.preventDefault();
                if (isSubmitted || submitGuardRef.current[index]) return;
                submitGuardRef.current[index] = true;
                const form = event.currentTarget;
                for (const field of fields) {
                  if (!field.required || !isMultiSelectField(field)) continue;
                  const formData = new FormData(form);
                  const selectedValues = formData.getAll(field.id).map(String);
                  if (selectedValues.length === 0) {
                    submitGuardRef.current[index] = false;
                    setArtifactError((prev) => ({ ...prev, [index]: `请选择：${splitFormFieldLabel(field.label).fieldLabel}` }));
                    return;
                  }
                  if (
                    field.allow_other_input &&
                    selectedValues.some(isOtherOption) &&
                    !String(formData.get(otherInputName(field.id)) ?? "").trim()
                  ) {
                    submitGuardRef.current[index] = false;
                    setArtifactError((prev) => ({ ...prev, [index]: `请填写：${splitFormFieldLabel(field.label).fieldLabel}的其它内容` }));
                    return;
                  }
                }
                setArtifactError((prev) => ({ ...prev, [index]: "" }));
                const values = collectFormValues(form, fields);
                if (artifact.kind === "support_ticket_draft") {
                  let accepted: ButtonSelectResult;
                  try {
                    accepted = onButtonSelect("已提交售后工单", {
                      displayText: "已提交售后工单",
                      assistantReply: SUPPORT_TICKET_SUBMITTED_REPLY,
                    });
                  } catch (err) {
                    submitGuardRef.current[index] = false;
                    throw err;
                  }
                  if (accepted === false) {
                    submitGuardRef.current[index] = false;
                    return;
                  }
                  setSubmittedArtifactMap((prev) => ({ ...prev, [index]: true }));
                  return;
                }
                let accepted: ButtonSelectResult;
                try {
                  accepted = onButtonSelect(buildFormConfirmationMessage(normalizedFormSpec, values), { displayText: `已提交：${title}` });
                } catch (err) {
                  submitGuardRef.current[index] = false;
                  throw err;
                }
                if (accepted === false) {
                  submitGuardRef.current[index] = false;
                  return;
                }
                setSubmittedArtifactMap((prev) => ({ ...prev, [index]: true }));
              }}
            >
              <fieldset disabled={isSubmitted} className={cn("grid min-w-0", isCollectionIntake ? "gap-4" : "gap-2.5")}>
                <h3 className={cn(isCollectionIntake ? "text-xl" : isMonochromeForm ? "text-base" : "text-sm", "font-semibold", isMonochromeForm ? "text-neutral-950 dark:text-neutral-50" : "text-foreground")}>
                  {title}
                </h3>
                {asString(normalizedFormSpec.description) ? (
                  <p className={cn(isCollectionIntake ? "text-[14px] leading-relaxed" : isMonochromeForm ? "text-[13px]" : "text-[12px]", isMonochromeForm ? "text-neutral-600 dark:text-neutral-400" : "text-muted-foreground")}>
                    {asString(normalizedFormSpec.description)}
                  </p>
                ) : null}
                {fieldGroups.map((group, groupIndex) => {
                  const groupStyle = isHospitalBagIntake
                    ? hospitalBagGroupStyle(group.title, groupIndex)
                    : isBirthPlanIntake
                      ? birthPlanGroupStyle(group.title, groupIndex)
                      : isBirthJourneyBasicInfoIntake
                        ? birthJourneyBasicInfoGroupStyle(group.title, groupIndex)
                        : null;
                  return group.title ? (
                    <section
                      key={`${group.title}-${groupIndex}`}
                      className={cn(
                        "grid min-w-0 gap-3 rounded-[18px] border p-3.5",
                        groupStyle?.section ?? "border-[#efe5ea] bg-white/85",
                      )}
                    >
                      <div className={cn("border-b pb-2", groupStyle?.header ?? "border-[#f1e8ec]")}>
                        <h4 className={cn("text-[15px] font-semibold", groupStyle?.title ?? "text-[#4b2638] dark:text-neutral-50")}>{group.title}</h4>
                      </div>
                      <div className="grid min-w-0 gap-3">{group.fields.map((field) => renderFormField(field, isMonochromeForm ? "monochrome" : "default"))}</div>
                    </section>
                  ) : (
                    <React.Fragment key={`ungrouped-${groupIndex}`}>
                      {group.fields.map((field) => renderFormField(field, isMonochromeForm ? "monochrome" : "default"))}
                    </React.Fragment>
                  );
                })}
                {errorText ? <p className="text-[12px] text-destructive">{errorText}</p> : null}
                <button
                  type="submit"
                  className={cn(
                    isCollectionIntake ? "rounded-[14px] px-4 py-3 font-semibold" : "rounded-lg px-3 py-2 font-medium border",
                    isMonochromeForm ? "text-[14px]" : "text-[12px]",
                    isCollectionIntake
                      ? isSubmitted
                        ? "border border-[#9db7bd] bg-white text-[#55727a] dark:bg-background dark:text-neutral-300"
                        : "border border-[#207d93] bg-[#207d93] text-white hover:bg-[#176b87]"
                      : isMonochromeForm
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
    <div className="w-full min-w-0 space-y-2">
      {renderArtifact()}
      {payload.title ? <p className="font-semibold text-sm text-foreground">{payload.title}</p> : null}
      {payload.content ? (
        <ChatMarkdown markdown={payload.content} variant="muted" className="text-[12px]" />
      ) : null}
      {visibleCards.length > 0 ? (
        <div className="space-y-2">
          {visibleCards.map((card: ChatRichTextCardItem, i) => (
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
                <div className="space-y-1">
                  {card.content.map((row, rowIdx) => (
                    <div key={`${row.title}-${rowIdx}`} className="flex items-start justify-between gap-3 text-[11px]">
                      <span className="text-muted-foreground">{row.title || "—"}</span>
                      <span className="text-right font-medium text-foreground whitespace-pre-line">{row.content || "—"}</span>
                    </div>
                  ))}
                </div>
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
