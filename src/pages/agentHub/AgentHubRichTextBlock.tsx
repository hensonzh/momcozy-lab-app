import React, { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
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
  buildIbclcChatUrl,
  isIbclcCompletionForCard,
  readStoredIbclcConsultCompletion,
  stableIbclcConsultId,
  type IbclcConsultCompletedPayload,
} from "@/lib/ibclcConsult";

/**
 * chat-messages 富文本卡片（标题、正文、结构化卡片与按钮）。
 * open / switch / 默认续聊交由回调或路由处理。
 */
type ButtonSelectOptions = { displayText?: string };

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
  return String(value ?? "").trim().toLowerCase() === "to confirm";
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
  return flatten(values).filter((value) => !isConfirmPlaceholder(value)).slice(0, maxItems);
}

function compactPackingItems(items: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(items)) return [];
  const rows = items.filter((it) => it && typeof it === "object") as Array<Record<string, unknown>>;
  if (rows.length <= 4) return rows;
  const pumpIndex = rows.findIndex((item) => {
    const text = JSON.stringify(item ?? {}).toLowerCase();
    return text.includes("吸奶") || text.includes("breast pump") || text.includes("pump");
  });
  if (pumpIndex < 0 || pumpIndex < 4) return rows.slice(0, 4);
  const visible = rows.slice(0, 4);
  visible[3] = rows[pumpIndex];
  return visible;
}

function compactPackingGroups(groups: unknown): Array<Record<string, unknown> & { items: Array<Record<string, unknown>> }> {
  if (!Array.isArray(groups)) return [];
  return groups
    .filter((g) => g && typeof g === "object")
    .slice(0, 3)
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
    must: "Essential",
    recommended: "Helpful",
    nice_to_have: "Optional",
    confirm_first: "Confirm",
  };
  const key = String(priority ?? "");
  return labels[key] || formatLabel(key);
}

function priorityClassName(priority: unknown): string {
  const key = String(priority ?? "");
  if (key === "must") return "priority priority-must";
  if (key === "confirm_first") return "priority priority-confirm-first";
  return "priority";
}

function renderHospitalCardValue(value: unknown): React.ReactNode {
  const text = formatPlainValue(value);
  if (isConfirmPlaceholder(value) || isConfirmPlaceholder(text)) {
    return <span className="to-confirm">{text}</span>;
  }
  return text;
}

function normalizeBirthPlanCard(cardJsonRaw: Record<string, unknown>) {
  const owner = asObject(cardJsonRaw.owner) ?? {};
  const overview = asObject(cardJsonRaw.overview) ?? {};
  const birthPreferences = asObject(cardJsonRaw.birth_preferences) ?? {};
  return {
    title: asString(cardJsonRaw.title) || "Birth Plan Card",
    subtitle: asString(cardJsonRaw.subtitle) || "Labor room communication priority card",
    overview: {
      due_date_or_week: overview.due_date_or_week ?? owner.due_date_or_week,
      birth_path: overview.birth_path ?? birthPreferences.birth_path,
      support_people: overview.support_people ?? owner.support_people,
    },
    top_priorities: compactBirthPlanList(cardJsonRaw.top_priorities ?? asObject(cardJsonRaw.if_plans_change)?.what_matters_most, 3),
    communication: compactBirthPlanList(cardJsonRaw.communication ?? cardJsonRaw.communication_preferences, 3),
    pain_relief: compactBirthPlanList(cardJsonRaw.pain_relief ?? cardJsonRaw.pain_relief_preferences, 3),
    baby_after_birth: compactBirthPlanList(cardJsonRaw.baby_after_birth ?? cardJsonRaw.baby_after_birth_preferences, 3),
    if_plans_change: compactBirthPlanList(cardJsonRaw.if_plans_change, 3),
    questions_for_hospital: compactBirthPlanList(cardJsonRaw.questions_for_hospital, 3),
    medical_notes: compactBirthPlanList(cardJsonRaw.medical_notes, 3),
    disclaimer:
      asString(cardJsonRaw.disclaimer) ||
      "This card is for communication only. Please follow your clinician and hospital guidance, especially if plans change for safety reasons.",
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
}> = ({ payload, blockId = "rich", onButtonSelect }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const [artifactError, setArtifactError] = useState<Record<number, string>>({});
  const [submittedArtifactMap, setSubmittedArtifactMap] = useState<Record<number, boolean>>({});
  const [downloadingCardIndex, setDownloadingCardIndex] = useState<number | null>(null);
  const [ibclcCompletion, setIbclcCompletion] = useState<IbclcConsultCompletedPayload | null>(() =>
    readStoredIbclcConsultCompletion(),
  );
  const cardArtifactRefs = useRef<Record<number, HTMLElement | null>>({});

  useEffect(() => {
    const syncCompletion = (payload?: IbclcConsultCompletedPayload | null) => {
      setIbclcCompletion(payload ?? readStoredIbclcConsultCompletion());
    };
    const onStorage = (event: StorageEvent) => {
      if (event.key !== "momcozy_ibclc_consult_completed") return;
      syncCompletion(readStoredIbclcConsultCompletion());
    };
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      const payload = event.data as IbclcConsultCompletedPayload | undefined;
      if (payload?.type === "momcozy.ibclc_consult_completed") syncCompletion(payload);
    };
    const onCustom = (event: Event) => {
      const payload = (event as CustomEvent<IbclcConsultCompletedPayload>).detail;
      if (payload?.type === "momcozy.ibclc_consult_completed") syncCompletion(payload);
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
      | { kind: "ibclc_consult"; card: Record<string, unknown> }
      | { kind: "support_ticket_draft"; ticket: Record<string, unknown>; submitLabel?: string }
    > = [];
    for (const action of payload.action) {
      const obj = asObject(action);
      if (!obj) continue;
      if (asString(obj.kind) !== "ag_ui_artifact") continue;
      const artifactType = asString(obj.artifact_type);
      if (artifactType === "form" && asObject(obj.form)) {
        result.push({ kind: "form", form: asObject(obj.form)! });
      } else if (artifactType === "card" && asObject(obj.card)) {
        result.push({ kind: "card", card: asObject(obj.card)! });
      } else if (artifactType === "ibclc_consult" && asObject(obj.card)) {
        result.push({ kind: "ibclc_consult", card: asObject(obj.card)! });
      } else if (artifactType === "support_ticket_draft" && asObject(obj.ticket)) {
        result.push({
          kind: "support_ticket_draft",
          ticket: asObject(obj.ticket)!,
          submitLabel: asString(obj.submit_label),
        });
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

  const renderFormField = (field: FormFieldSpec, variant: "default" | "support_ticket" = "default") => {
    const isSupportTicket = variant === "support_ticket";
    const requiredMark = field.required ? (
      <span className={cn("mr-1", isSupportTicket ? "text-foreground" : "text-destructive")}>*</span>
    ) : null;
    const fieldTextClass = isSupportTicket ? "text-neutral-950 dark:text-neutral-50" : "text-foreground";
    const inputClassName = cn(
      "rounded-lg border px-2 py-1.5 text-[12px] outline-none transition-colors",
      isSupportTicket
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
            isSupportTicket ? "border-neutral-300 bg-white dark:border-neutral-700 dark:bg-background" : "border-border/60",
          )}
        >
          <legend className={cn("text-[12px] font-medium px-1", fieldTextClass)}>
            {requiredMark}
            {field.label}
          </legend>
          <div className="grid gap-1.5">
            {(field.options ?? []).map((option) => (
              <label key={option} className={cn("inline-flex items-center gap-2 text-[12px]", fieldTextClass)}>
                <input type="checkbox" name={field.id} value={option} defaultChecked={defaults.includes(option)} />
                <span>{option}</span>
              </label>
            ))}
          </div>
        </fieldset>
      );
    }
    return (
      <label key={field.id} className={cn("grid gap-1 text-[12px]", fieldTextClass)}>
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
        {field.help_text ? <small className="text-[11px] text-muted-foreground">{field.help_text}</small> : null}
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
            const consultId = stableIbclcConsultId(`${blockId}:${index}:${JSON.stringify(artifact.card)}`);
            const returnTo = `${location.pathname}${location.search}${location.hash}`;
            const chatUrl = buildIbclcChatUrl(url, consultId, threadId, returnTo);
            const consultCompleted = isIbclcCompletionForCard(ibclcCompletion, threadId, consultId);
            const openConsult = () => {
              if (consultCompleted) return;
              if (chatUrl.startsWith("/")) {
                navigate(chatUrl);
                return;
              }
              window.location.assign(chatUrl);
            };
            return (
              <article
                key={`artifact-${index}`}
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
              const subtitle = cardSubtitle([bp.overview.due_date_or_week, bp.overview.birth_path, bp.overview.support_people]);
              const groups: Array<[string, string[]]> = [
                ["Communication", bp.communication],
                ["Pain Relief", bp.pain_relief],
                ["Baby After Birth", bp.baby_after_birth],
                ["If Plans Change", bp.if_plans_change],
              ].filter(([, vals]) => vals.length > 0) as Array<[string, string[]]>;
              return (
                <article
                  key={`artifact-${index}`}
                  ref={(el) => {
                    cardArtifactRefs.current[index] = el;
                  }}
                  className="relative rounded-xl border border-border bg-card p-3 space-y-2"
                >
                  {downloadButton}
                  <header className="flex items-start justify-between gap-2">
                    <div>
                      <h3 className="text-sm font-semibold text-foreground">{bp.title}</h3>
                      {subtitle ? <p className="text-[11px] text-muted-foreground mt-0.5">{subtitle}</p> : null}
                    </div>
                    <div className="flex items-center gap-1.5">
                      <img src={MOMCOZY_LOGO_SRC} alt="Momcozy" className="h-5 w-auto opacity-85" />
                    </div>
                  </header>
                  {bp.top_priorities.length > 0 ? (
                    <section className="rounded-lg border border-border/70 bg-background/60 p-2">
                      <h4 className="text-[12px] font-semibold text-foreground mb-1">What matters most</h4>
                      <ul className="list-disc list-inside text-[12px] text-foreground space-y-0.5">
                        {bp.top_priorities.map((item, i) => (
                          <li key={i}>{item}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {groups.length > 0 ? (
                    <section className="grid gap-1.5">
                      <h4 className="text-[12px] font-semibold text-foreground">Care team preferences</h4>
                      <div className="grid gap-1.5">
                        {groups.map(([title, vals]) => (
                          <div key={title} className="rounded-lg border border-border/60 p-2">
                            <p className="text-[11px] font-semibold text-foreground mb-1">{title}</p>
                            <ul className="list-disc list-inside text-[12px] text-foreground space-y-0.5">
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
                    <section>
                      <h4 className="text-[12px] font-semibold text-foreground mb-1">Medical notes</h4>
                      <ul className="list-disc list-inside text-[12px] text-foreground space-y-0.5">
                        {bp.medical_notes.map((value, i) => (
                          <li key={i}>{value}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {bp.questions_for_hospital.length > 0 ? (
                    <section>
                      <h4 className="text-[12px] font-semibold text-foreground mb-1">Questions before admission</h4>
                      <ul className="list-disc list-inside text-[12px] text-foreground space-y-0.5">
                        {limitList(bp.questions_for_hospital, 3).map((value, i) => (
                          <li key={i}>{formatPlainValue(value)}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {bp.disclaimer ? <p className="text-[11px] text-muted-foreground">{bp.disclaimer}</p> : null}
                </article>
              );
            }
            if (cardType === "hospital_bag_card" && schemaVersion === "1.0") {
              const owner = asObject(cardJson.owner) ?? {};
              const hospital = asObject(cardJson.hospital_context) ?? {};
              const subtitle = cardSubtitle([owner.due_date_or_week, owner.birth_path, owner.packing_style, hospital.expected_stay]);
              const packingGroups = compactPackingGroups(cardJson.packing_groups);
              const confirmItems = limitList(hospital.items_to_confirm_with_hospital, 3);
              const timelineItems = limitList(cardJson.timeline, 2);
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
                  {packingGroups.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>Packing List</h3>
                      {packingGroups.map((group, gIdx) => (
                        <div key={gIdx} className="packing-group">
                          <h4>
                            {asString(group.title) || formatLabel(asString(group.group_id) || "Group")}
                          </h4>
                          <div>
                            {group.items.map((item, i) => (
                              <div key={i} className="packing-item">
                                <span>{renderHospitalCardValue(asString(item.label) || formatPlainValue(item))}</span>
                                {item.priority ? (
                                  <span className={priorityClassName(item.priority)}>
                                    {priorityLabel(item.priority)}
                                  </span>
                                ) : null}
                                {asString(item.note) ? <small>{asString(item.note)}</small> : null}
                              </div>
                            ))}
                          </div>
                        </div>
                      ))}
                    </section>
                  ) : null}
                  {confirmItems.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>Confirm With Hospital</h3>
                      <ul className="agent-card-list">
                        {confirmItems.map((value, i) => (
                          <li key={i}>{renderHospitalCardValue(value)}</li>
                        ))}
                      </ul>
                    </section>
                  ) : null}
                  {timelineItems.length > 0 ? (
                    <section className="agent-card-section">
                      <h3>Timeline</h3>
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
          const title = asString(formSpec.title) || "Confirm details";
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
            .filter((f) => f.id);

          return (
            <form
              key={`artifact-${index}`}
              className={cn(
                "rounded-xl border p-3 space-y-2.5",
                isSupportTicket
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
                onButtonSelect(buildFormConfirmationMessage(formSpec, values), { displayText: `已提交：${title}` });
              }}
            >
              <fieldset disabled={isSubmitted} className="grid gap-2.5">
                <h3 className={cn("text-sm font-semibold", isSupportTicket ? "text-neutral-950 dark:text-neutral-50" : "text-foreground")}>{title}</h3>
                {asString(formSpec.description) ? <p className="text-[12px] text-muted-foreground">{asString(formSpec.description)}</p> : null}
                {fields.map((field) => renderFormField(field, isSupportTicket ? "support_ticket" : "default"))}
                {errorText ? <p className="text-[12px] text-destructive">{errorText}</p> : null}
                <button
                  type="submit"
                  className={cn(
                    "rounded-lg px-3 py-2 text-[12px] font-medium border",
                    isSupportTicket
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
