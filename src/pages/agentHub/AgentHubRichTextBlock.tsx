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

type FormFieldGroup = {
  title: string;
  fields: FormFieldSpec[];
};

const REMOVED_HOSPITAL_BAG_FORM_FIELD_IDS = new Set(["hospital_rules_or_notes", "existing_checklist_or_photo_note"]);
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

function collectFormValues(form: HTMLFormElement, fields: FormFieldSpec[]): Record<string, unknown> {
  const data = new FormData(form);
  const values: Record<string, unknown> = {};
  for (const field of fields) {
    const value = isMultiSelectField(field)
      ? data.getAll(field.id).map(String).filter((item) => item.trim())
      : String(data.get(field.id) ?? "").trim();
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

function supportTicketDisplayValues(ticket: Record<string, unknown>): Record<string, unknown> {
  return supportTicketFields(ticket).reduce<Record<string, unknown>>((values, field) => {
    values[field.id] = field.default_value;
    return values;
  }, {});
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
  return ["to confirm", "待确认", "未确定", "不确定", "还没确定", "还没想好"].includes(text);
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
  [/分娩沟通卡/, "记录生产偏好和需要提前沟通的事，入院时方便给医护看。"],
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
  if (!title || title === "待产包卡片" || title === "Hospital Bag Card") return "待产包";
  if (title.includes("待产包卡片")) return title.replaceAll("待产包卡片", "待产包");
  return title;
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
      <span className={cn("mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full", isMonochrome ? "bg-[#b8667b]" : "bg-destructive")} aria-hidden="true" />
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
          key={field.id}
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
            {(field.options ?? []).map((option) => (
              <label
                key={option}
                className={cn(
                  "inline-flex items-center gap-2 rounded-xl border px-3 py-2",
                  isMonochrome ? "border-neutral-200 bg-[#fbfaf9] text-[14px]" : "border-border/70 bg-background/70 text-[12px]",
                  fieldTextClass,
                )}
              >
                <input type="checkbox" name={field.id} value={option} defaultChecked={defaults.includes(option)} />
                <span className="min-w-0 break-words">{option}</span>
              </label>
            ))}
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
      <label key={field.id} className={cn("grid min-w-0 gap-1.5", isMonochrome ? "text-[14px]" : "text-[12px]", fieldTextClass)}>
        <span className="inline-flex items-start gap-2 font-semibold leading-snug">
          {requiredMark}
          <span>{field.label}</span>
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
      <div className="w-full min-w-0 space-y-2">
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
                className="grid w-full min-w-0 gap-3 overflow-hidden rounded-[18px] border border-[#d9e6e2] bg-[#fbfefd] p-4 text-[#253b39] shadow-[0_14px_34px_rgba(40,83,78,0.10)]"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex min-w-0 items-start gap-3">
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-[14px] bg-[#e8f6f2] text-[#177a74]">
                      <Headphones className="h-5 w-5" aria-hidden="true" />
                    </span>
                    <div className="min-w-0">
                      <p className="m-0 text-[11px] font-[800] text-[#6b827d]">IBCLC</p>
                      <h3 className="m-0 mt-1 text-[18px] font-[800] leading-[1.2] text-[#172c2a]">哺乳顾问在线咨询</h3>
                    </div>
                  </div>
                  <span
                    className={cn(
                      "shrink-0 rounded-full px-2.5 py-1 text-[12px] font-[800] leading-none",
                      consultCompleted ? "bg-[#edf1f0] text-[#778683]" : "bg-[#e7f7f3] text-[#177a74]",
                    )}
                  >
                    {consultCompleted ? "已结束" : "可咨询"}
                  </span>
                </div>
                <section className="grid grid-cols-[44px_minmax(0,1fr)] items-center gap-3 rounded-[14px] border border-[#e3eeea] bg-white/90 p-3">
                  <div className="grid h-11 w-11 place-items-center rounded-full bg-[#1b7874] text-[15px] font-black text-white">
                    {initialsForName(consultantName)}
                  </div>
                  <div className="min-w-0">
                    <strong className="block text-[15px] font-[800] leading-[1.2] text-[#182b2a]">{consultantName}</strong>
                    <p className="mt-1 text-[12px] leading-[1.45] text-[#60706e]">
                      {consultantBio || "支持乳房护理、吸奶器使用和喂养节奏问题。"}
                    </p>
                  </div>
                </section>
                <div className="flex flex-wrap gap-2">
                  <span className="inline-flex items-center gap-1.5 rounded-full border border-[#dceae6] bg-white px-2.5 py-1 text-[12px] font-[700] text-[#4f6f6b]">
                    <ShieldCheck className="h-3.5 w-3.5" aria-hidden="true" />
                    持证哺乳顾问
                  </span>
                  <span className="inline-flex items-center rounded-full border border-[#eadfe5] bg-white px-2.5 py-1 text-[12px] font-[700] text-[#6b5662]">
                    带着当前问题继续聊
                  </span>
                </div>
                <button
                  type="button"
                  disabled={consultCompleted}
                  aria-disabled={consultCompleted}
                  className={cn(
                    "inline-flex min-h-11 items-center justify-center rounded-[14px] px-4 text-[14px] font-black no-underline transition-colors",
                    consultCompleted ? "cursor-default bg-[#d7dfdd] text-[#778683]" : "bg-[#177a89] text-white hover:bg-[#126a78]",
                  )}
                  onClick={openConsult}
                >
                  {consultCompleted ? "咨询已结束" : "去咨询"}
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
              const owner = asObject(cardJson.owner) ?? {};
              const subtitle = "住院母婴必备用品 · 32～34周准备 · 36周完成";
              const profileRows = [
                { label: "孕期", value: hospitalBagProfileValue("孕期", owner.due_date_or_week) },
                { label: "生产方式", value: hospitalBagProfileValue("生产方式", owner.birth_path) },
                { label: "喂养意向", value: hospitalBagProfileValue("喂养意向", owner.feeding_intention) },
              ].filter(({ value }) => hasDisplayValue(value) && !isConfirmPlaceholder(value));
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
                  {profileRows.length > 0 ? (
                    <div className="hospital-card-profile-strip">
                      <ul className="hospital-card-profile-tags">
                        {profileRows.map((item) => (
                          <li key={item.label}>
                            <strong>{renderHospitalCardValue(item.value)}</strong>
                          </li>
                        ))}
                      </ul>
                    </div>
                  ) : null}
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
                    {downloadButton}
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
          if (artifact.kind === "support_ticket_draft") {
            const ticketValues = supportTicketDisplayValues(artifact.ticket);
            const issueType = asString(ticketValues.issue_type) || "其他";
            const issueSummary = asString(ticketValues.issue_summary) || "待补充，可以先提交给客服继续跟进。";
            const productModel = asString(ticketValues.product_model) || "暂不确定";
            const urgency = asString(ticketValues.urgency) || "普通";
            const isSafetyTicket = urgency === "安全相关";
            const ticketRows = [
              { label: "问题类型", value: issueType },
              { label: "产品型号", value: productModel },
              { label: "紧急程度", value: urgency },
            ];

            return (
              <form
                key={`artifact-${index}`}
                className="w-full min-w-0 rounded-[18px] border border-[#eadfe5] bg-[#fffdfc] p-4 text-[#2d1b25] shadow-[0_14px_34px_rgba(73,43,58,0.08)]"
                onSubmit={(event) => {
                  event.preventDefault();
                  if (isSubmitted) return;
                  setArtifactError((prev) => ({ ...prev, [index]: "" }));
                  setSubmittedArtifactMap((prev) => ({ ...prev, [index]: true }));
                  onButtonSelect(buildSupportTicketSubmittedMessage(ticketValues), { displayText: "已提交售后工单" });
                }}
              >
                <fieldset disabled={isSubmitted} className="grid min-w-0 gap-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex min-w-0 items-start gap-3">
                      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-[14px] bg-[#f7eef2] text-[#7c3755]">
                        <ClipboardList className="h-5 w-5" aria-hidden="true" />
                      </span>
                      <div className="min-w-0">
                        <p className="m-0 text-[11px] font-[800] text-[#8a6d7b]">售后工单</p>
                        <h3 className="m-0 mt-1 text-[18px] font-[800] leading-[1.2] text-[#321a27]">先把问题交给人工客服</h3>
                        <p className="m-0 mt-1 text-[12px] leading-[1.45] text-[#7b6871]">确认后会把问题类型、型号和描述一起提交。</p>
                      </div>
                    </div>
                    <span
                      className={cn(
                        "shrink-0 rounded-full px-2.5 py-1 text-[12px] font-[800] leading-none",
                        isSubmitted ? "bg-[#edf1f0] text-[#6d7d79]" : "bg-[#f6e7ee] text-[#7c3755]",
                      )}
                    >
                      {isSubmitted ? "已提交" : "草稿"}
                    </span>
                  </div>

                  <div className="grid min-w-0 gap-2 sm:grid-cols-3">
                    {ticketRows.map((row) => (
                      <div key={row.label} className="min-w-0 rounded-[13px] border border-[#eadfe5] bg-white/90 px-3 py-2">
                        <p className="m-0 text-[11px] font-[700] text-[#8c7882]">{row.label}</p>
                        <strong
                          className={cn(
                            "mt-1 block min-w-0 break-words text-[14px] font-[800] leading-[1.25] text-[#33222a]",
                            row.label === "紧急程度" && isSafetyTicket ? "text-[#a13f45]" : "",
                          )}
                        >
                          {row.value}
                        </strong>
                      </div>
                    ))}
                  </div>

                  <div className="rounded-[14px] border border-[#eadfe5] bg-white/90 p-3">
                    <p className="m-0 text-[11px] font-[700] text-[#8c7882]">问题描述</p>
                    <p className="m-0 mt-1 text-[14px] font-[650] leading-[1.55] text-[#3a2a31]">{issueSummary}</p>
                  </div>

                  {errorText ? <p className="text-[12px] text-destructive">{errorText}</p> : null}
                  <button
                    type="submit"
                    className={cn(
                      "inline-flex min-h-11 items-center justify-center gap-2 rounded-[14px] border px-4 text-[14px] font-black transition-colors",
                      isSubmitted
                        ? "border-[#d5ddd9] bg-white text-[#6d7d79]"
                        : "border-[#7c3755] bg-[#7c3755] text-white hover:bg-[#6d2e49]",
                    )}
                  >
                    <FileCheck className="h-4 w-4" aria-hidden="true" />
                    {isSubmitted ? "已提交" : artifact.submitLabel || "确认并提交"}
                  </button>
                </fieldset>
              </form>
            );
          }

          const formSpec = artifact.form;
          const formId = asString(formSpec.id);
          const isHospitalBagIntake = formId === "hospital_bag_intake";
          const isBirthPlanIntake = formId === "birth_plan_card_intake";
          const isGroupedIntake = isHospitalBagIntake || isBirthPlanIntake;
          const isMonochromeForm = isHospitalBagIntake || isBirthPlanIntake;
          const title = isHospitalBagIntake || isBirthPlanIntake ? "信息采集" : asString(formSpec.title) || "Confirm details";
          const normalizedFormSpec = isHospitalBagIntake
            ? { ...formSpec, title, description: "" }
            : isBirthPlanIntake
              ? { ...formSpec, title, description: "" }
              : formSpec;
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
            .filter((field) => !(isHospitalBagIntake && REMOVED_HOSPITAL_BAG_FORM_FIELD_IDS.has(field.id)))
            .map((field) => {
              if (!((isHospitalBagIntake || isBirthPlanIntake) && field.id === "birth_path")) {
                return field;
              }
              const normalizedField = {
                ...field,
                label: splitFormFieldLabel(field.label).groupTitle ? `${splitFormFieldLabel(field.label).groupTitle}｜医生目前建议的生产方式` : "医生目前建议的生产方式",
                options: ["顺产", "剖宫产", "还没确定"],
                default_value: ["计划剖宫产", "剖腹产", "planned_c_section", "c_section", "c-section", "cesarean"].includes(asString(field.default_value))
                  ? "剖宫产"
                  : field.default_value,
              };
              return normalizedField;
            })
            .map((field) => (isHospitalBagIntake || isBirthPlanIntake ? { ...field, help_text: "" } : field))
            .filter((f) => f.id);
          const fieldGroups = isGroupedIntake ? groupFormFields(fields) : [{ title: "", fields }];

          return (
            <form
              key={`artifact-${index}`}
              className={cn(
                "w-full min-w-0",
                isGroupedIntake ? "rounded-[24px] border p-4 space-y-4" : "rounded-xl border p-3 space-y-2.5",
                isGroupedIntake
                  ? "border-[#eadfe5] bg-[#fffdfc] text-neutral-950 shadow-[0_10px_30px_rgba(65,42,52,0.06)] dark:border-neutral-800 dark:bg-background dark:text-neutral-50"
                  : isMonochromeForm
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
                  setArtifactError((prev) => ({ ...prev, [index]: `请选择：${splitFormFieldLabel(field.label).fieldLabel}` }));
                  return;
                }
                setArtifactError((prev) => ({ ...prev, [index]: "" }));
                const values = collectFormValues(form, fields);
                setSubmittedArtifactMap((prev) => ({ ...prev, [index]: true }));
                onButtonSelect(buildFormConfirmationMessage(normalizedFormSpec, values), { displayText: `已提交：${title}` });
              }}
            >
              <fieldset disabled={isSubmitted} className={cn("grid min-w-0", isGroupedIntake ? "gap-4" : "gap-2.5")}>
                <h3 className={cn(isGroupedIntake ? "text-xl" : isMonochromeForm ? "text-base" : "text-sm", "font-semibold", isMonochromeForm ? "text-neutral-950 dark:text-neutral-50" : "text-foreground")}>
                  {title}
                </h3>
                {asString(normalizedFormSpec.description) ? (
                  <p className={cn(isGroupedIntake ? "text-[14px] leading-relaxed" : isMonochromeForm ? "text-[13px]" : "text-[12px]", isMonochromeForm ? "text-neutral-600 dark:text-neutral-400" : "text-muted-foreground")}>
                    {asString(normalizedFormSpec.description)}
                  </p>
                ) : null}
                {fieldGroups.map((group, groupIndex) => {
                  const groupStyle = isHospitalBagIntake
                    ? hospitalBagGroupStyle(group.title, groupIndex)
                    : isBirthPlanIntake
                      ? birthPlanGroupStyle(group.title, groupIndex)
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
                    isGroupedIntake ? "rounded-[14px] px-4 py-3 font-semibold" : "rounded-lg px-3 py-2 font-medium border",
                    isMonochromeForm ? "text-[14px]" : "text-[12px]",
                    isGroupedIntake
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
