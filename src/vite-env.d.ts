/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 主界面快捷 pills：`prenatal` 待产宝妈；`postpartum` 已分娩宝妈 */
  readonly VITE_MOM_STAGE?: "prenatal" | "postpartum" | string;
  readonly VITE_CHAT_IMAGE_BASE_URL?: string;
  readonly VITE_CHAT_IMAGE_PROXY_TARGET?: string;
  readonly VITE_DEVICE_REMINDER_WS_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
