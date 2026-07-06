/** AgentHub 版面与页面拆离的常量（避免 AgentHub.tsx 顶部过长） */

/** Hub 药丸 flowType → 传给设备指引的固定 query。 */
import { getRuntimeUserId } from "@/lib/debugUserConfig";

export const DEVICE_INSTRUCT_QUERY_BY_FLOW: Record<string, string> = {
  unbox: "开箱指引",
  "wearing-guide": "上身指引",
  measurement: "法兰或硅胶塞调整",
  maintenance: "设备保养",
  "photo-identify": "帮我识别吸奶器配件图片，我会上传图片",
};

export const DEFAULT_CHAT_USER_ID = getRuntimeUserId(import.meta.env.VITE_DEFAULT_USER_ID as string | undefined);

export const CALIBRATION_HUB_NOTICE_KEY = "calibrationHubNotice";

/** Hub 语音模式 Realtime 播报：每段文本的目标长度，越小首响越快但请求数越多。 */
export const HUB_AUTO_VOICE_STREAM_SEGMENT_MAX_CHARS = 64;
export const HUB_AUTO_VOICE_STREAM_SEGMENT_MIN_CHARS = 12;

export const HUB_BOTTOM_NAV_HEIGHT = "4rem";
export const HUB_BOTTOM_INPUT_GAP = "6px";

export const HUB_CHAT_HISTORY_PAGE = 10;

export const cardBg: Record<string, string> = {
  report: "border-mai-warm/30 bg-mai-warm/5",
  encourage: "border-mai-blush/30 bg-mai-blush/5",
  plan: "border-primary/20 bg-primary/5",
  tutorial: "border-accent/40 bg-accent/10",
  data: "border-muted-foreground/20 bg-muted/50",
  calibration: "border-accent/40 bg-accent/10",
  "device-flow": "border-accent/40 bg-accent/10",
  "maternity-flow": "border-pink-200 bg-pink-50/50 dark:border-pink-800 dark:bg-pink-900/10",
  "work-flow": "border-violet-200 bg-violet-50/50 dark:border-violet-800 dark:bg-violet-900/10",
};
