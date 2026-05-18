import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useEffect } from "react";
import { BrowserRouter, Routes, Route, useNavigate } from "react-router-dom";
import AppLayout from "@/components/layout/AppLayout";
import PumpSessionIsland from "@/components/pumpSession/PumpSessionIsland";
import { consumePumpNotificationPending } from "@/lib/pumpSessionNotification";
import { tryRunPumpAutoEndOffPumpTeardownOnce } from "@/lib/pumpAutoEndSession";
import ReconnectPairedDevices from "@/components/device/ReconnectPairedDevices";
import AgentHub from "@/pages/AgentHub";
import ComfortCalibration from "@/pages/ComfortCalibration";
import PumpSession from "@/pages/PumpSession";
import Records from "@/pages/Records";
import Schedule from "@/pages/Schedule";
import DeviceManagement from "@/pages/DeviceManagement";
import DeviceManageActions from "@/pages/DeviceManageActions";
import StatusPage from "@/pages/Status";
import Community from "@/pages/Community";
import NotFound from "@/pages/NotFound";
import W1Promo from "@/pages/W1Promo";
import MediaViewer from "@/pages/MediaViewer";
import IbclcChat from "@/pages/IbclcChat";
import BackgroundNotifyOnboardingGate from "@/components/system/BackgroundNotifyOnboardingGate";
import { markStatusGrowthHighlightPending } from "@/lib/statusGrowthHighlight";
import { appendAgentHubAnalysisMessage } from "@/lib/agentHubChatMessages";

const queryClient = new QueryClient();

/** Android：点击前台服务通知下拉区域后原生写入待跳转路径，在此消费并进入路由。 */
function PumpNotificationNavigateSync() {
  const navigate = useNavigate();

  useEffect(() => {
    let alive = true;

    const tryConsume = (): void => {
      void consumePumpNotificationPending().then(({ path, autoEndTeardown, notifyJson }) => {
        if (!alive) return;
        if (notifyJson) {
          try {
            const o = JSON.parse(notifyJson) as { event?: string; body?: string; chatMessageId?: string };
            if (
              (o?.event === "summary" || o?.event === "mom_baby") &&
              typeof o.body === "string" &&
              o.body.trim()
            ) {
              appendAgentHubAnalysisMessage(o.body, {
                kind: o.event === "summary" ? "daily_summary" : "mom_baby",
                id: o.chatMessageId,
              });
            } else if (o?.event === "grown") {
              markStatusGrowthHighlightPending();
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
      });
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

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <PumpNotificationNavigateSync />
        <BackgroundNotifyOnboardingGate />
        <PumpSessionIsland />
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
            <Route path="/w1" element={<W1Promo />} />
            <Route path="/media-viewer" element={<MediaViewer />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AppLayout>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
