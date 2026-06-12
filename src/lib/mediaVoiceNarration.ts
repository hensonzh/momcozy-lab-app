export type MediaVoicePolicy = "silent" | "announce" | "describe_on_request" | "read_text";

export type MediaVoicePriority = "decorative" | "supporting" | "primary" | "instructional";

export interface MediaVoiceNarrationItem {
  mediaId?: string;
  kind?: "image" | "video" | "pdf" | "card" | string;
  visualLabel?: string;
  accessibilityLabel?: string;
  spokenLabel?: string;
  spokenDetail?: string;
  voicePolicy: MediaVoicePolicy;
  priority?: MediaVoicePriority | string;
}

const FALLBACK_MEDIA_URL_BASE = "http://momcozy.local";
const DEVICE_GUIDANCE_IMAGE_SPOKEN_LABEL = "我放了一张当前步骤的对照图，你可以边看图边完成这一步。";
const DEVICE_GUIDANCE_IMAGE_PATH_PATTERN =
  /^\/skill-assets\/device-guidance\/[^/]+\/images\/[^?#]+\.(?:png|jpe?g|webp|gif|svg)(?:[?#].*)?$/i;

const MEDIA_VOICE_POLICIES = new Set<MediaVoicePolicy>([
  "silent",
  "announce",
  "describe_on_request",
  "read_text",
]);

function readStringField(record: Record<string, unknown>, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

function normalizeMediaVoicePolicy(value: unknown): MediaVoicePolicy {
  if (typeof value === "string" && MEDIA_VOICE_POLICIES.has(value as MediaVoicePolicy)) {
    return value as MediaVoicePolicy;
  }
  return "silent";
}

export function normalizeMediaVoiceNarrationItems(value: unknown): MediaVoiceNarrationItem[] {
  if (!Array.isArray(value)) return [];
  const items: MediaVoiceNarrationItem[] = [];
  const seen = new Set<string>();

  for (const raw of value) {
    if (!raw || typeof raw !== "object") continue;
    const record = raw as Record<string, unknown>;
    const voicePolicy = normalizeMediaVoicePolicy(record.voicePolicy ?? record.voice_policy);
    const spokenLabel = readStringField(record, "spokenLabel", "spoken_label");
    const spokenDetail = readStringField(record, "spokenDetail", "spoken_detail");
    const mediaId = readStringField(record, "mediaId", "media_id", "id", "url");
    const key = `${voicePolicy}:${mediaId ?? ""}:${spokenLabel ?? ""}:${spokenDetail ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);

    items.push({
      mediaId,
      kind: readStringField(record, "kind", "type"),
      visualLabel: readStringField(record, "visualLabel", "visual_label", "title", "alt"),
      accessibilityLabel: readStringField(record, "accessibilityLabel", "accessibility_label"),
      spokenLabel,
      spokenDetail,
      voicePolicy,
      priority: readStringField(record, "priority"),
    });
  }

  return items;
}

function pushUnique(values: string[], value: string | undefined): void {
  const text = value?.trim();
  if (!text || values.includes(text)) return;
  values.push(text);
}

export function mediaVoiceLookupKeys(mediaId: string | undefined): string[] {
  const raw = mediaId?.trim();
  if (!raw) return [];
  const keys: string[] = [];
  pushUnique(keys, raw);

  try {
    const base =
      typeof window !== "undefined" && window.location?.href
        ? window.location.href
        : FALLBACK_MEDIA_URL_BASE;
    const url = new URL(raw, base);
    const pathWithSearch = `${url.pathname}${url.search}`;
    pushUnique(keys, pathWithSearch);
    pushUnique(keys, url.pathname);
    if (url.hash) pushUnique(keys, `${pathWithSearch}${url.hash}`);
    try {
      pushUnique(keys, decodeURI(pathWithSearch));
      pushUnique(keys, decodeURI(url.pathname));
    } catch {
      /* keep encoded keys only */
    }
  } catch {
    const pathWithoutHash = raw.split("#")[0] ?? raw;
    const pathWithoutQuery = pathWithoutHash.split("?")[0] ?? pathWithoutHash;
    pushUnique(keys, pathWithoutHash);
    pushUnique(keys, pathWithoutQuery);
  }

  return keys;
}

export function fallbackMediaVoiceNarration(mediaId: string | undefined): string | undefined {
  for (const key of mediaVoiceLookupKeys(mediaId)) {
    if (DEVICE_GUIDANCE_IMAGE_PATH_PATTERN.test(key)) {
      return DEVICE_GUIDANCE_IMAGE_SPOKEN_LABEL;
    }
  }
  return undefined;
}

export function buildSpeakableTextForMediaVoice(items: MediaVoiceNarrationItem[] | undefined): string {
  if (!items?.length) return "";
  const spoken: string[] = [];
  const seen = new Set<string>();

  for (const item of items) {
    if (item.voicePolicy !== "announce" && item.voicePolicy !== "read_text") continue;
    const text = (item.spokenLabel || item.spokenDetail || "").trim();
    if (!text || seen.has(text)) continue;
    seen.add(text);
    spoken.push(text);
  }

  return spoken.join(" ");
}
