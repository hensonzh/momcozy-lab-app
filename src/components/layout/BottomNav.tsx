import React, { useEffect } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { Calendar, Bluetooth, Users } from "lucide-react";
import momcozyAgentAvatar from "@/assets/momcozy-agent.png";
import momcozyAgentAwakenAvatar from "@/assets/momcozy-agent-awaken.gif";
import { cn } from "@/lib/utils";
import {
  transferBirthJourneyPlanNotificationToStatusCard,
  useBirthJourneyPlanNavNotification,
} from "@/lib/birthJourneyPlanNotification";
import {
  transferPregnancyDiaryNotificationToStatusCard,
  usePregnancyDiaryNavNotification,
} from "@/lib/pregnancyDiaryEvents";
import {
  milkPlanNotificationConfig,
  transferPlanNotificationToPage,
  usePlanNavNotification,
} from "@/lib/planNotification";

/* Custom mom-and-baby icon matching Lucide stroke style */
const MomBabyIcon: React.FC<{ className?: string; strokeWidth?: number }> = ({ className, strokeWidth = 2 }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    <circle cx="8.2" cy="7.1" r="2.8" />
    <path d="M3.8 19.2v-1.4c0-3.1 1.9-5.4 4.4-5.4s4.4 2.3 4.4 5.4v1.4" />
    <path d="M5.7 18.8c.7.4 1.5.6 2.5.6s1.8-.2 2.5-.6" />
    <circle cx="16.4" cy="9.7" r="2.1" />
    <path d="M12.9 19.2v-.9c0-2.4 1.4-4.1 3.5-4.1s3.5 1.7 3.5 4.1v.9" />
    <path d="M14.5 18.7c.5.3 1.1.4 1.9.4s1.4-.1 1.9-.4" />
  </svg>
);

const tabs = [
  { path: "/status", icon: MomBabyIcon as React.ComponentType<{ className?: string; strokeWidth?: number }>, label: "宝宝和我" },
  { path: "/schedule", icon: Calendar, label: "计划" },
  { path: "/", icon: null, label: "智能体", isCenter: true },
  { path: "/community", icon: Users, label: "社区" },
  { path: "/device", icon: Bluetooth, label: "设备" },
];

let agentAwakenPreloadImage: HTMLImageElement | null = null;
let agentAwakenAvatarBlob: Blob | null = null;
let agentAwakenAvatarBlobPromise: Promise<Blob | null> | null = null;
let agentWakeOverlayTimer: number | null = null;
let agentWakePlaybackObjectUrl: string | null = null;
let agentWakePlaybackNonce = 0;

const AGENT_WAKE_ANIMATION_MS = 1640;

function prefersReducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

function preloadAgentAwakenAvatar(): void {
  if (typeof window === "undefined") return;

  if (!agentAwakenPreloadImage) {
    agentAwakenPreloadImage = new Image();
    agentAwakenPreloadImage.decoding = "async";
    agentAwakenPreloadImage.src = momcozyAgentAwakenAvatar;
    void agentAwakenPreloadImage.decode?.().catch(() => undefined);
  }
  preloadAgentAwakenAvatarBlob();
}

function preloadAgentAwakenAvatarBlob(): void {
  if (
    typeof window === "undefined" ||
    typeof window.fetch !== "function" ||
    agentAwakenAvatarBlob ||
    agentAwakenAvatarBlobPromise
  ) {
    return;
  }

  agentAwakenAvatarBlobPromise = window
    .fetch(momcozyAgentAwakenAvatar)
    .then((response) => (response.ok ? response.blob() : null))
    .then((blob) => {
      agentAwakenAvatarBlob = blob;
      return blob;
    })
    .catch(() => null);
}

function revokeAgentWakePlaybackObjectUrl(): void {
  if (
    agentWakePlaybackObjectUrl &&
    typeof URL !== "undefined" &&
    typeof URL.revokeObjectURL === "function"
  ) {
    URL.revokeObjectURL(agentWakePlaybackObjectUrl);
  }
  agentWakePlaybackObjectUrl = null;
}

function createAgentWakePlaybackUrl(): string {
  agentWakePlaybackNonce += 1;

  if (
    agentAwakenAvatarBlob &&
    typeof URL !== "undefined" &&
    typeof URL.createObjectURL === "function"
  ) {
    revokeAgentWakePlaybackObjectUrl();
    agentWakePlaybackObjectUrl = URL.createObjectURL(agentAwakenAvatarBlob);
    return agentWakePlaybackObjectUrl;
  }

  const separator = momcozyAgentAwakenAvatar.includes("?") ? "&" : "?";
  return `${momcozyAgentAwakenAvatar}${separator}wake=${agentWakePlaybackNonce}`;
}

function playAgentWakeOverlay(sourceButton: HTMLButtonElement): void {
  if (typeof document === "undefined" || prefersReducedMotion()) return;

  preloadAgentAwakenAvatar();

  const rect = sourceButton.getBoundingClientRect();
  document.querySelector("[data-agent-wake-overlay]")?.remove();
  if (agentWakeOverlayTimer != null) {
    window.clearTimeout(agentWakeOverlayTimer);
  }

  const overlay = document.createElement("div");
  overlay.setAttribute("data-agent-wake-overlay", "true");
  overlay.className = "agent-nav-avatar-wake-overlay";
  overlay.style.left = `${rect.left}px`;
  overlay.style.top = `${rect.top}px`;
  overlay.style.width = `${rect.width}px`;
  overlay.style.height = `${rect.height}px`;

  const image = document.createElement("img");
  image.src = createAgentWakePlaybackUrl();
  image.alt = "";
  image.setAttribute("aria-hidden", "true");
  image.className = "agent-nav-avatar-wake-overlay-media";
  overlay.appendChild(image);

  document.body.appendChild(overlay);
  agentWakeOverlayTimer = window.setTimeout(() => {
    overlay.remove();
    revokeAgentWakePlaybackObjectUrl();
    agentWakeOverlayTimer = null;
  }, AGENT_WAKE_ANIMATION_MS);
}

export type BottomNavVariant = "fixed" | "embedded";

export type BottomNavProps = {
  /** embedded：参与父级 flex 列，不 fixed；状态页与顶栏、信息区同列排布时用 */
  variant?: BottomNavVariant;
};

const BottomNav: React.FC<BottomNavProps> = ({ variant = "fixed" }) => {
  const location = useLocation();
  const navigate = useNavigate();
  const embedded = variant === "embedded";
  const birthJourneyPlanNavNotification = useBirthJourneyPlanNavNotification();
  const pregnancyDiaryNavNotification = usePregnancyDiaryNavNotification();
  const milkPlanNavNotification = usePlanNavNotification(milkPlanNotificationConfig);
  const statusNotificationCount =
    Number(birthJourneyPlanNavNotification) + Number(pregnancyDiaryNavNotification);
  const scheduleNotificationCount = Number(milkPlanNavNotification);

  useEffect(() => {
    preloadAgentAwakenAvatar();
  }, []);

  const handleCenterTabClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    if (location.pathname !== "/") {
      playAgentWakeOverlay(event.currentTarget);
    }
    navigate("/");
  };

  // Hide nav on independent full-screen flows
  if (location.pathname === "/pump" || location.pathname === "/calibration" || location.pathname === "/media-viewer") return null;

  return (
    <nav
      className={cn(
        "z-40 border-t border-border/35 bg-card/88 backdrop-blur-xl pb-safe",
        embedded ? "relative w-full shrink-0" : "fixed bottom-0 left-0 right-0",
      )}
    >
      <div className="max-w-lg mx-auto flex items-center justify-between px-2 h-[4.5rem] relative">
        {tabs.map((tab) => {
          const active =
            tab.path === "/status"
              ? ["/status", "/baby", "/mom"].includes(location.pathname)
              : tab.path === "/device"
                ? location.pathname.startsWith("/device") || location.pathname === "/w1"
                : location.pathname === tab.path;
          
          if (tab.isCenter) {
            return (
              <div key={tab.path} className="flex-1 flex justify-center h-full items-center">
                <button
                  onClick={handleCenterTabClick}
                  aria-current={active ? "page" : undefined}
                  aria-label={tab.label}
                  className={cn(
                    "relative -top-3 flex h-[68px] w-[68px] flex-col items-center justify-center rounded-full border-[5px] border-background transition-all duration-200 active:scale-95 focus:outline-none focus-visible:outline-none",
                    active
                      ? "bg-gradient-to-br from-primary to-primary/85 text-primary-foreground shadow-[0_12px_30px_rgba(117,75,94,0.26)]"
                      : "bg-card text-muted-foreground shadow-[0_8px_22px_rgba(58,39,49,0.10)] ring-1 ring-border/70 hover:text-primary hover:ring-primary/24",
                  )}
                >
                  {active && <span className="absolute inset-1 rounded-full bg-white/10" />}
                  <img
                    src={momcozyAgentAvatar}
                    alt=""
                    aria-hidden="true"
                    className="relative z-10 h-12 w-12 shrink-0 rounded-full object-cover shadow-[0_4px_10px_rgba(58,39,49,0.14)]"
                  />
                </button>
              </div>
            );
          }

          return (
            <div key={tab.path} className="flex-1 flex justify-center h-full items-center">
              <button
                onClick={() => {
                  if (tab.path === "/status") {
                    transferBirthJourneyPlanNotificationToStatusCard();
                    transferPregnancyDiaryNotificationToStatusCard();
                  }
                  if (tab.path === "/schedule") {
                    transferPlanNotificationToPage(milkPlanNotificationConfig);
                  }
                  navigate(tab.path);
                }}
                className={cn(
                  "relative flex flex-col items-center gap-1 py-1.5 px-3 rounded-xl transition-all duration-200",
                  active
                    ? "text-primary"
                    : "text-muted-foreground hover:text-primary/70"
                )}
              >
                {/* Active background glow */}
                {active && (
                  <div className="absolute inset-0 rounded-xl bg-primary/8" />
                )}
                {tab.path === "/status" && statusNotificationCount > 0 ? (
                  <span
                    aria-label="宝宝和我有新通知"
                    className="absolute right-1 top-0 z-20 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#e3405f] px-1 text-[10px] font-extrabold leading-none text-white shadow-[0_5px_12px_rgba(227,64,95,0.35)] ring-2 ring-card"
                  >
                    {statusNotificationCount}
                  </span>
                ) : null}
                {tab.path === "/schedule" && scheduleNotificationCount > 0 ? (
                  <span
                    aria-label="计划有新通知"
                    className="absolute right-1 top-0 z-20 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#e3405f] px-1 text-[10px] font-extrabold leading-none text-white shadow-[0_5px_12px_rgba(227,64,95,0.35)] ring-2 ring-card"
                  >
                    {scheduleNotificationCount}
                  </span>
                ) : null}
                <tab.icon className={cn("w-5 h-5 relative z-10", active && "fill-primary/20")} strokeWidth={active ? 2.5 : 1.8} />
                <span className={cn("text-[10px] font-medium relative z-10", active && "font-bold")}>{tab.label}</span>
              </button>
            </div>
          );
        })}
      </div>
    </nav>
  );
};

export default BottomNav;
