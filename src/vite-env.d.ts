/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_DEMO_MANUAL_PDF_URL?: string;
  readonly VITE_DEMO_UNBOX_VIDEO_URL?: string;
  readonly VITE_CHAT_IMAGE_BASE_URL?: string;
  readonly VITE_CHAT_IMAGE_PROXY_TARGET?: string;
  /** 专注模式 STT：`chunk` 分片上传；`iflytek` 讯飞实时转写 */
  readonly VITE_FOCUS_STT_PROVIDER?: string;
  readonly VITE_IFLYTEK_RTASR_APPID?: string;
  readonly VITE_IFLYTEK_RTASR_API_KEY?: string;
  readonly VITE_IFLYTEK_RTASR_LANG?: string;
  readonly VITE_IFLYTEK_RTASR_PD?: string;
  readonly VITE_IFLYTEK_RTASR_ENG_LANG_TYPE?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
