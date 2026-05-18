import { capacitorHttpInterceptorResourceSrc, needsNativeHttpInterceptor } from "@/lib/capacitorHttpInterceptorUrl";

/** 与 Vite 中 `proxy` 键一致：浏览器用同源路径替换 http 图 */
export const CHAT_IMAGE_PROXY_PREFIX = "/__chat_image_proxy";

/** @deprecated 使用 `capacitorHttpInterceptorResourceSrc`，保留别名以兼容旧引用 */
export const capacitorHttpInterceptorImageSrc = capacitorHttpInterceptorResourceSrc;

/**
 * Web 且页面为 HTTPS、图片为 HTTP 时，转为 Vite 代理前缀 + 路径，使 `<img>` 与页面同源。
 * @param absoluteUrl 已解析的绝对 URL
 * @returns 代理路径；无需改写时返回 null（沿用原 URL）
 */
export function webHttpsRewriteToImageProxy(absoluteUrl: string): string | null {
  if (typeof window === "undefined") return null;
  if (window.location.protocol !== "https:") return null;
  if (!/^http:\/\//i.test(absoluteUrl)) return null;
  try {
    const u = new URL(absoluteUrl);
    return `${CHAT_IMAGE_PROXY_PREFIX}${u.pathname}${u.search}${u.hash}`;
  } catch {
    return null;
  }
}

/**
 * 将聊天图片 URL 转为当前运行环境可直接给 `<img>` 使用的地址。
 * @param resolvedSrc 已经经 `resolveChatAssetUrl` 解析后的图片 URL
 * @returns 当前平台下的展示地址；入参为空时返回 undefined
 */
export function resolveChatImageDisplaySrc(resolvedSrc: string | undefined): string | undefined {
  const a = resolvedSrc?.trim();
  if (!a) return undefined;
  if (/^(data:|blob:)/i.test(a)) return a;
  if (needsNativeHttpInterceptor(a)) return capacitorHttpInterceptorImageSrc(a);
  return webHttpsRewriteToImageProxy(a) ?? a;
}
