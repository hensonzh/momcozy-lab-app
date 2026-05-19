// 必须为本文件第一条 import：先于 App 加载，避免模块初始化里的 console 仍是 [object Object]
import "@/lib/consoleNativePatch";
/** 尽早从 localStorage 恢复主对话 conversation_id 到内存，先于界面发 chat-messages */
import "@/lib/agentConversationSession";
/** 全局吸奶会话状态机：在路由挂载前完成 deviceStore 订阅与 sessionStorage 状态恢复 */
import "@/lib/pumpSessionLifecycle";

import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { startPumpAgentUploadService } from "@/lib/pumpAgentUpload";
import { startPumpSessionNotificationBridge } from "@/lib/pumpSessionNotification";
import { startPumpSessionOverlayBridge } from "@/lib/pumpSessionOverlay";
import { startPumpBackgroundBleNotifyWatchdog } from "@/lib/pumpBackgroundBleNotifyWatchdog";
import { startPumpCompletionReminder } from "@/lib/pumpCompletionReminder";
import { startPumpAutoEndOffPumpReminder } from "@/lib/pumpAutoEndSession";

startPumpAgentUploadService();
startPumpSessionNotificationBridge();
startPumpSessionOverlayBridge();
startPumpBackgroundBleNotifyWatchdog();
startPumpCompletionReminder();
startPumpAutoEndOffPumpReminder();

createRoot(document.getElementById("root")!).render(<App />);
