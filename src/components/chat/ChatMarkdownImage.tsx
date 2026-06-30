/* eslint-disable react-refresh/only-export-components */
import type { FC } from "react";
import { useNavigate } from "react-router-dom";
import {
  CHAT_IMAGE_PROXY_PREFIX,
  capacitorHttpInterceptorImageSrc,
  resolveChatImageDisplaySrc,
  webHttpsRewriteToImageProxy,
} from "@/lib/chatImageDisplaySrc";
import { navigateToMediaViewer } from "@/lib/openMediaViewer";
import { cn } from "@/lib/utils";

export { CHAT_IMAGE_PROXY_PREFIX, capacitorHttpInterceptorImageSrc, webHttpsRewriteToImageProxy };

export interface ChatMarkdownImgProps {
  /** resolveChatMarkdownImageSrc 之后可直接用于请求的 URL */
  resolvedSrc: string | undefined;
  alt?: string | null;
  className?: string;
  imgClassName?: string;
}

/**
 * 对话 Markdown 内联图片：按环境选择 Capacitor 拦截 URL、Vite 代理或直链。
 * @param props.resolvedSrc 解析后的 src
 * @param props.alt 替代文本
 * @param props.className 可选按钮样式
 * @param props.imgClassName 可选图片样式
 */
export const ChatMarkdownImg: FC<ChatMarkdownImgProps> = ({ resolvedSrc, alt, className, imgClassName }) => {
  const navigate = useNavigate();
  const a = resolvedSrc?.trim();
  if (!a) return null;

  const display = resolveChatImageDisplaySrc(a) ?? a;
  const label = alt?.trim() || "查看图片";

  return (
    <button
      type="button"
      className={cn("block max-w-full cursor-zoom-in rounded-md p-0 text-left", className)}
      aria-label={label}
      onClick={() => navigateToMediaViewer(navigate, { url: a, kind: "image", title: alt?.trim() || undefined })}
    >
      <img
        src={display}
        alt={alt ?? ""}
        className={cn("max-w-full rounded-md h-auto", imgClassName)}
        loading="eager"
        decoding="async"
      />
    </button>
  );
};
