import { capacitorHttpInterceptorResourceSrc, needsNativeHttpInterceptor } from "@/lib/capacitorHttpInterceptorUrl";

/** 与 Vite `proxy` 中 `__media_http_proxy` 一致：HTTPS 页拉 HTTP 媒体时走同源代理 */
export const MEDIA_HTTP_PROXY_PREFIX = "/__media_http_proxy";

/**
 * 解析远程媒体 URL，供 `<video>` 的 src 使用（原生 HTTP 走拦截，Web HTTPS+HTTP 走 Vite 代理）。
 * @param absoluteUrl 绝对 URL（需已含协议）
 * @returns 可直接赋给媒体元素的 src
 */
export function resolveVideoElementSrc(absoluteUrl: string): string {
  const u = absoluteUrl.trim();
  if (!u) return u;
  if (needsNativeHttpInterceptor(u)) {
    return capacitorHttpInterceptorResourceSrc(u);
  }
  const proxied = webHttpsRewriteToMediaProxy(u);
  if (proxied) {
    if (typeof window !== "undefined") {
      return `${window.location.origin}${proxied}`;
    }
    return proxied;
  }
  return u;
}

/**
 * Web 且页面为 HTTPS、资源为 HTTP 时，转为 Vite 代理前缀 + 路径。
 * @param absoluteUrl 绝对 URL
 * @returns 代理路径；无需改写时返回 null
 */
export function webHttpsRewriteToMediaProxy(absoluteUrl: string): string | null {
  if (typeof window === "undefined") return null;
  if (window.location.protocol !== "https:") return null;
  if (!/^http:\/\//i.test(absoluteUrl)) return null;
  try {
    const u = new URL(absoluteUrl);
    return `${MEDIA_HTTP_PROXY_PREFIX}${u.pathname}${u.search}${u.hash}`;
  } catch {
    return null;
  }
}

/**
 * Web 端对「绝对 HTTP URL」发起 fetch 时使用的同源 URL（HTTPS 开发/部署页避免 mixed content）。
 * @param absoluteUrl 远程绝对 URL
 * @returns 实际 fetch 使用的 URL
 */
export function resolveFetchUrlForAbsoluteHttp(absoluteUrl: string): string {
  const proxied = webHttpsRewriteToMediaProxy(absoluteUrl);
  if (proxied && typeof window !== "undefined") {
    return `${window.location.origin}${proxied}`;
  }
  return absoluteUrl;
}
