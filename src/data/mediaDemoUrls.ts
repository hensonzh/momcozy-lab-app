/**
 * 设备流程 / 抽屉中 doc-links 演示用远程地址，通过环境变量注入，未配置时按钮仍可点击但会提示无链接。
 * @property manualPdf 电子说明书 PDF
 * @property unboxVideo 开箱类教程视频
 */
export const MEDIA_DEMO_URLS = {
  manualPdf: (import.meta.env.VITE_DEMO_MANUAL_PDF_URL || "").trim(),
  unboxVideo: (import.meta.env.VITE_DEMO_UNBOX_VIDEO_URL || "").trim(),
} as const;
