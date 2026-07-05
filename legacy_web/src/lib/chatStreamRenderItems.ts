import type { ChatRichTextPayload } from "@/lib/agentApiTypes";
import type { ChatStreamRenderItem } from "@/types/chat";

export function richTextPayloadHasAgUiArtifact(payload?: ChatRichTextPayload | null): boolean {
  if (!payload || !Array.isArray(payload.action)) return false;
  return payload.action.some((action) => {
    if (!action || typeof action !== "object" || Array.isArray(action)) return false;
    const rec = action as Record<string, unknown>;
    if (rec.kind !== "ag_ui_artifact") return false;
    return Boolean(rec.form || rec.card || rec.ticket);
  });
}

export function streamItemHasAgUiArtifact(item: ChatStreamRenderItem): boolean {
  return item.kind === "rich" && richTextPayloadHasAgUiArtifact(item.payload);
}

export function appendTextRenderItem(
  items: ChatStreamRenderItem[] | undefined,
  text: string,
): ChatStreamRenderItem[] {
  if (!text) return items ?? [];
  const list = [...(items ?? [])];
  const last = list.at(-1);
  if (last?.kind === "text") {
    list[list.length - 1] = { kind: "text", text: last.text + text };
    return list;
  }
  list.push({ kind: "text", text });
  return list;
}

export function appendTextRenderItemBeforeAgUiArtifacts(
  items: ChatStreamRenderItem[] | undefined,
  text: string,
): ChatStreamRenderItem[] {
  if (!text) return items ?? [];
  const list = [...(items ?? [])];
  const firstArtifactIndex = list.findIndex(streamItemHasAgUiArtifact);
  if (firstArtifactIndex < 0) return appendTextRenderItem(list, text);
  const previous = list[firstArtifactIndex - 1];
  if (previous?.kind === "text") {
    list[firstArtifactIndex - 1] = { kind: "text", text: previous.text + text };
    return list;
  }
  list.splice(firstArtifactIndex, 0, { kind: "text", text });
  return list;
}
