import type { NavigateFunction } from "react-router-dom";
import { toast } from "sonner";
import { navigateToMediaViewer, resolveViewerKindFromDocLink } from "@/lib/openMediaViewer";

/**
 * 处理 rich_text 中 type 为 open 的按钮：按文件后缀选择 PDF / 视频查看器，不往对话里发送 value。
 * @param absoluteUrl 完整可请求 URL（解析阶段已对 open 类型拼接聊天资源服务前缀）
 * @param buttonLabel 按钮展示文案，用作查看页标题
 * @param navigate React Router 的 navigate
 * @returns 始终为 true（表示已消费点击，不应再走「作为 query 发送」逻辑）
 */
export function tryOpenRichTextOpenButton(
  absoluteUrl: string,
  buttonLabel: string | undefined,
  navigate: NavigateFunction,
): true {
  const url = absoluteUrl?.trim();
  if (!url) {
    toast("文件地址为空");
    return true;
  }
  const kind = resolveViewerKindFromDocLink(url, undefined);
  if (!kind) {
    toast("暂不支持打开该类型文件，请使用 PDF、图片或 MP4 等常见格式");
    return true;
  }
  navigateToMediaViewer(navigate, {
    url,
    kind,
    title: buttonLabel?.trim() || undefined,
  });
  return true;
}
