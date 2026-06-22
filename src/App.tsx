import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useEffect } from "react";
import {
  BrowserRouter,
  Routes,
  Route,
  useLocation,
  useNavigate,
} from "react-router-dom";
import AppLayout from "@/components/layout/AppLayout";
import { consumePumpNotificationPending } from "@/lib/pumpSessionNotification";
import { notifyPumpSessionOverlayRouteChanged } from "@/lib/pumpSessionOverlay";
import { tryRunPumpAutoEndOffPumpTeardownOnce } from "@/lib/pumpAutoEndSession";
import AgentHub from "@/pages/AgentHub";
import ComfortCalibration from "@/pages/ComfortCalibration";
import PumpSession from "@/pages/PumpSession";
import Records from "@/pages/Records";
import Schedule from "@/pages/Schedule";
import DeviceManagement from "@/pages/DeviceManagement";
import DeviceManageActions from "@/pages/DeviceManageActions";
import UserParameterConfig from "@/pages/UserParameterConfig";
import StatusPage from "@/pages/Status";
import Community from "@/pages/Community";
import NotFound from "@/pages/NotFound";
import W1Promo from "@/pages/W1Promo";
import MediaViewer from "@/pages/MediaViewer";
import IbclcChat from "@/pages/IbclcChat";
import HospitalBagCart from "@/pages/HospitalBagCart";
import BackgroundNotifyOnboardingGate from "@/components/system/BackgroundNotifyOnboardingGate";
import { markStatusGrowthHighlightPending } from "@/lib/statusGrowthHighlight";
import {
  appendAgentHubAnalysisMessage,
  appendAgentHubNotificationMessage,
} from "@/lib/agentHubChatMessages";
import { recordMilkAnalysisContextEvent } from "@/lib/analysisContextEvents";
import { startDeviceReminderWebSocket } from "@/lib/deviceReminderWebSocket";
import { HEALTH_ISSUE_NOTIFICATION_MESSAGE } from "@/lib/deviceReminderActions";
import { queueMilkAnalysisReminderFollowup } from "@/lib/milkAnalysisReminderFollowup";
import { personalizeNotificationText } from "@/lib/agentNotificationMessages";
import type { AgentAnalysisCard } from "@/lib/agentApiTypes";
import {
  AGENT_NOTIFICATION_VOICE_EVENT,
  dispatchAgentNotificationVoiceIdle,
  setAgentNotificationVoicePlaying,
} from "@/lib/agentNotificationVoice";
import type { ChatMessage } from "@/types/chat";
import {
  buildSpeakableTextForVoice,
  CHAT_BUBBLE_VOICE_MAX_CHARS,
} from "@/lib/chatBubbleTtsPlayback";
import {
  playFocusPlainTextVoice,
  stopFocusVoicePlayback,
} from "@/lib/focusVoiceTtsPlayback";
import { beginAgentVoicePlayback } from "@/lib/agentVoicePlaybackCoordinator";
import { warn } from "@/lib/logger";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

const queryClient = new QueryClient();
const NOTIFICATION_VOICE_TIMEOUT_MS = 12000;

/** Android：点击前台服务通知下拉区域后原生写入待跳转路径，在此消费并进入路由。 */
function PumpNotificationNavigateSync() {
  const navigate = useNavigate();

  useEffect(() => {
    let alive = true;

    const tryConsume = (): void => {
      void consumePumpNotificationPending().then(
        async ({ path, autoEndTeardown, notifyJson }) => {
          if (!alive) return;
          if (notifyJson) {
            try {
              const o = JSON.parse(notifyJson) as {
                event?: string;
                body?: string;
                chatMessageId?: string;
                analysis_card?: AgentAnalysisCard;
                analysis_context?: AgentAnalysisCard;
              };
              const analysisKind =
                o?.event === "summary"
                  ? "daily_summary"
                  : o?.event === "mom_baby"
                    ? "mom_baby"
                    : o?.event === "milk_analysis"
                      ? "milk_analysis"
                      : null;
              if (analysisKind && typeof o.body === "string" && o.body.trim()) {
                const body =
                  analysisKind === "milk_analysis"
                    ? await personalizeNotificationText(o.body)
                    : o.body;
                if (!alive) return;
                appendAgentHubAnalysisMessage(body, {
                  kind: analysisKind,
                  id: o.chatMessageId,
                  analysisCard: o.analysis_card,
                  notification: analysisKind === "milk_analysis",
                });
                if (analysisKind === "milk_analysis") {
                  const analysisContext = o.analysis_context ?? o.analysis_card;
                  void recordMilkAnalysisContextEvent({
                    message: body,
                    analysisCard: analysisContext,
                    chatMessageId: o.chatMessageId,
                  });
                  queueMilkAnalysisReminderFollowup({
                    chatMessageId: o.chatMessageId,
                    message: body,
                    analysisContext,
                  });
                }
              } else if (o?.event === "grown") {
                markStatusGrowthHighlightPending();
              } else if (o?.event === "health_issue") {
                const body = await personalizeNotificationText(
                  o.body || HEALTH_ISSUE_NOTIFICATION_MESSAGE,
                );
                if (!alive) return;
                appendAgentHubNotificationMessage(body, {
                  kind: "health_issue",
                  id: o.chatMessageId,
                });
              }
            } catch {
              /* ignore */
            }
          }
          if (!path) return;
          navigate(path);
          if (autoEndTeardown && path === "/") {
            void tryRunPumpAutoEndOffPumpTeardownOnce();
          }
        },
      );
    };

    tryConsume();
    const retry = window.setTimeout(tryConsume, 160);
    const retry2 = window.setTimeout(tryConsume, 600);
    const onVisibilityChange = (): void => {
      if (document.visibilityState === "visible") tryConsume();
    };
    document.addEventListener("visibilitychange", onVisibilityChange);
    window.addEventListener("focus", tryConsume);
    window.addEventListener("mmc-pump-native-nav", tryConsume);

    return () => {
      alive = false;
      window.clearTimeout(retry);
      window.clearTimeout(retry2);
      document.removeEventListener("visibilitychange", onVisibilityChange);
      window.removeEventListener("focus", tryConsume);
      window.removeEventListener("mmc-pump-native-nav", tryConsume);
    };
  }, [navigate]);

  return null;
}

function PumpOverlayRouteSync() {
  const location = useLocation();

  useEffect(() => {
    notifyPumpSessionOverlayRouteChanged(location.pathname);
  }, [location.pathname]);

  return null;
}

function DeviceReminderWebSocketSync() {
  useEffect(() => startDeviceReminderWebSocket(), []);

  return null;
}

function AgentNotificationVoiceSync() {
  useEffect(() => {
    const queue: ChatMessage[] = [];
    const playedIds = new Set<string>();
    let disposed = false;
    let running = false;

    const notificationVoiceTimeoutMs = (text: string): number =>
      Math.min(
        30000,
        Math.max(NOTIFICATION_VOICE_TIMEOUT_MS, 4000 + text.length * 220),
      );

    const playNotificationVoice = async (
      message: ChatMessage,
      text: string,
    ): Promise<void> => {
      const ac = new AbortController();
      const handle = beginAgentVoicePlayback({
        id: message.id,
        source: "notification",
        cancel: () => {
          ac.abort();
          void stopFocusVoicePlayback();
        },
      });
      if (!handle) {
        warn("[AgentNotificationVoice] 通知语音被更高优先级播报占用，已跳过", {
          id: message.id,
        });
        return;
      }
      let timeout: number | null = null;
      const voicePromise = playFocusPlainTextVoice({
        userId: DEFAULT_CHAT_USER_ID,
        text,
        signal: ac.signal,
        onSubtitle: () => {},
        syncSubtitle: false,
      });
      voicePromise.catch(() => {
        /* handled by race below; keep late aborts quiet */
      });
      try {
        await Promise.race([
          voicePromise,
          new Promise<never>((_, reject) => {
            timeout = window.setTimeout(() => {
              ac.abort();
              void stopFocusVoicePlayback();
              reject(
                new DOMException(
                  "notification voice timeout",
                  "TimeoutError",
                ),
              );
            }, notificationVoiceTimeoutMs(text));
          }),
        ]);
      } finally {
        if (timeout != null) window.clearTimeout(timeout);
        handle.finish();
      }
    };

    const drain = async (): Promise<void> => {
      if (running) return;
      running = true;
      setAgentNotificationVoicePlaying(true);
      try {
        while (!disposed && queue.length > 0) {
          const message = queue.shift();
          if (!message) continue;
          const speakable = buildSpeakableTextForVoice(message)
            .trim()
            .slice(0, CHAT_BUBBLE_VOICE_MAX_CHARS);
          if (!speakable) continue;
          try {
            await playNotificationVoice(message, speakable);
          } catch (e: unknown) {
            // 通知已写入对话，语音失败不影响后续自动接续。
            warn(
              "[AgentNotificationVoice] 通知语音播报失败",
              e instanceof Error ? e.message : String(e),
            );
          }
        }
      } finally {
        running = false;
        setAgentNotificationVoicePlaying(false);
        dispatchAgentNotificationVoiceIdle();
      }
    };

    const onNotificationVoice = (event: Event): void => {
      const message = (event as CustomEvent<ChatMessage>).detail;
      if (!message?.id || playedIds.has(message.id)) return;
      playedIds.add(message.id);
      queue.push(message);
      void drain();
    };

    window.addEventListener(
      AGENT_NOTIFICATION_VOICE_EVENT,
      onNotificationVoice,
    );
    return () => {
      disposed = true;
      queue.length = 0;
      setAgentNotificationVoicePlaying(false);
      window.removeEventListener(
        AGENT_NOTIFICATION_VOICE_EVENT,
        onNotificationVoice,
      );
    };
  }, []);

  return null;
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <PumpNotificationNavigateSync />
        <PumpOverlayRouteSync />
        <DeviceReminderWebSocketSync />
        <AgentNotificationVoiceSync />
        <BackgroundNotifyOnboardingGate />
        <AppLayout>
          <Routes>
            <Route path="/" element={<AgentHub />} />
            <Route path="/calibration" element={<ComfortCalibration />} />
            <Route path="/pump" element={<PumpSession />} />
            <Route path="/records" element={<Records />} />
            <Route path="/schedule" element={<Schedule />} />
            <Route path="/status" element={<StatusPage />} />
            <Route path="/community" element={<Community />} />
            <Route path="/device" element={<DeviceManagement />} />
            <Route path="/device/manage" element={<DeviceManageActions />} />
            <Route path="/device/user" element={<UserParameterConfig />} />
            <Route path="/w1" element={<W1Promo />} />
            <Route path="/hospital-bag-cart" element={<HospitalBagCart />} />
            <Route path="/ibclc-chat.html" element={<IbclcChat />} />
            <Route path="/media-viewer" element={<MediaViewer />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AppLayout>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
