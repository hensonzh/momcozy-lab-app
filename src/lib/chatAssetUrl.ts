const DEFAULT_CHAT_IMAGE_BASE_URL = "http://192.168.24.182:8900";

type ResolveChatAssetUrlOptions = {
  allowBaseFallback?: boolean;
  preservePageRelative?: boolean;
};

function envValue(key: keyof ImportMetaEnv): string {
  return (typeof import.meta !== "undefined" && import.meta.env?.[key]?.trim()) || "";
}

function chatAssetBaseUrl(allowBaseFallback: boolean): string {
  const proxyTarget = envValue("VITE_CHAT_IMAGE_PROXY_TARGET");
  if (proxyTarget) return proxyTarget;
  if (!allowBaseFallback) return "";
  return envValue("VITE_CHAT_IMAGE_BASE_URL") || DEFAULT_CHAT_IMAGE_BASE_URL;
}

function isAbsoluteOrInlineUrl(value: string): boolean {
  return /^[a-z][a-z\d+.-]*:/i.test(value) || value.startsWith("//");
}

export function resolveChatAssetUrl(value: string, options: ResolveChatAssetUrlOptions = {}): string {
  const raw = value.trim();
  if (!raw) return raw;
  if (isAbsoluteOrInlineUrl(raw)) return raw;
  if (options.preservePageRelative) return raw;

  const base = chatAssetBaseUrl(options.allowBaseFallback ?? true).replace(/\/+$/, "");
  if (!base) return raw;

  try {
    const path = raw.startsWith("/") ? raw : `/${raw}`;
    return new URL(path, `${base}/`).href;
  } catch {
    return `${base}/${raw.replace(/^\/+/, "")}`;
  }
}
