import type { NavigateFunction } from "react-router-dom";
import { toast } from "sonner";
import type { DocLinkItem, DocLinkKind } from "@/types/docLink";
import { resolveChatAssetUrl } from "@/lib/chatAssetUrl";

/** 媒体查看页路由 state（pdf / video / image） */
export type MediaViewerKind = "pdf" | "video" | "image";

/** 传入 `/media-viewer` 的 location.state */
export interface MediaViewerNavigateState {
  url: string;
  kind: MediaViewerKind;
  title?: string;
}

/**
 * 跳转到应用内全屏媒体查看页。
 * @param navigate React Router 的 navigate
 * @param state 资源 URL、类型与可选标题
 */
export function navigateToMediaViewer(navigate: NavigateFunction, state: MediaViewerNavigateState): void {
  navigate("/media-viewer", { state: { ...state, url: resolveChatAssetUrl(state.url) } });
}

/**
 * 将 doc-link 条目解析为可打开的类型；无法应用内展示时返回 null。
 * @param url 资源 URL（可为空）
 * @param kind 显式类型或其它
 * @returns pdf / video / image / null
 */
export function resolveViewerKindFromDocLink(url: string | undefined, kind?: DocLinkKind): MediaViewerKind | null {
  if (!url?.trim()) return null;
  if (kind === "pdf" || kind === "video") return kind;
  if (kind === "other") return null;
  const path = url.split("?")[0].toLowerCase();
  if (path.endsWith(".pdf")) return "pdf";
  if (/\.(mp4|webm|ogv|m4v)$/.test(path)) return "video";
  if (/\.(png|jpe?g|gif|webp|svg|bmp|ico|avif)$/.test(path)) return "image";
  return null;
}

/**
 * 从 doc-links 条目打开应用内查看器；缺 URL 或不支持的类型时用 toast 提示。
 * @param navigate React Router navigate
 * @param doc 单条资料
 */
export function openDocLinkInMediaViewer(navigate: NavigateFunction, doc: DocLinkItem): void {
  const url = doc.url?.trim();
  if (!url) {
    toast("暂无资料链接");
    return;
  }
  const k = resolveViewerKindFromDocLink(url, doc.kind);
  if (!k) {
    toast("该资料暂不支持应用内打开");
    return;
  }
  navigateToMediaViewer(navigate, { url, kind: k, title: doc.title });
}
