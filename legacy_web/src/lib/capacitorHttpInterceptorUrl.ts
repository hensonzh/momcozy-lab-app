import { Capacitor } from "@capacitor/core";

/**
 * 将绝对 HTTP(S) URL 转为 WebView 本地 `/_capacitor_http_interceptor_?u=...`，由 Capacitor 代拉远程资源，避免 HTTPS 页面混合内容。
 * 可用于 `<img>`、`<video>` 等；视频是否支持 Range/流式取决于本地桥接实现，失败时需降级为整包下载后 `convertFileSrc` 或 Blob。
 * @param absoluteUrl 完整绝对 URL
 * @returns 可赋给媒体 src 的地址；无法构造时退回原 URL
 */
export function capacitorHttpInterceptorResourceSrc(absoluteUrl: string): string {
  try {
    const getServerUrl = (Capacitor as unknown as { getServerUrl?: () => string }).getServerUrl;
    const server = typeof getServerUrl === "function" ? getServerUrl() : "";
    if (!server) return absoluteUrl;
    const bridgeUrl = new URL(server);
    bridgeUrl.pathname = "/_capacitor_http_interceptor_";
    bridgeUrl.searchParams.append("u", absoluteUrl);
    return bridgeUrl.toString();
  } catch {
    return absoluteUrl;
  }
}

/**
 * 判断当前是否原生且目标为 HTTP（需走拦截 URL，不能由页面直链）。
 * @param absoluteUrl 已解析的绝对 URL
 * @returns 为 true 时应使用 `capacitorHttpInterceptorResourceSrc`
 */
export function needsNativeHttpInterceptor(absoluteUrl: string): boolean {
  try {
    return Capacitor.isNativePlatform() && /^http:\/\//i.test(absoluteUrl);
  } catch {
    return false;
  }
}
