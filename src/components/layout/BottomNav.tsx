import React from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { Heart, Calendar, Bluetooth, Users } from "lucide-react";
import { cn } from "@/lib/utils";

/* Custom nursing/breastfeeding icon matching Lucide stroke style */
const NursingIcon: React.FC<{ className?: string; strokeWidth?: number }> = ({ className, strokeWidth = 2 }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    {/* Mother head */}
    <circle cx="10" cy="5" r="2.5" />
    {/* Mother body holding baby */}
    <path d="M6 10.5c0-1.5 1.5-3 4-3s4 1.5 4 3v1.5c0 .5-.2 1-.5 1.3" />
    {/* Arms cradling */}
    <path d="M6 12c-1.5.5-2 2-2 3s.5 2 1.5 2.5" />
    <path d="M14 12c1 .5 1.8 1.5 1.8 2.5" />
    {/* Baby */}
    <circle cx="10.5" cy="15" r="1.5" />
    <path d="M8.5 16c-.3.8-.5 1.8 0 2.5.5.8 1.5 1 2.5.8s1.8-.8 2-1.5" />
  </svg>
);

const tabs = [
  { path: "/status", icon: NursingIcon as React.ComponentType<{ className?: string; strokeWidth?: number }>, label: "状态" },
  { path: "/schedule", icon: Calendar, label: "计划" },
  { path: "/", icon: Heart, label: "Comate", isCenter: true },
  { path: "/community", icon: Users, label: "社区" },
  { path: "/device", icon: Bluetooth, label: "设备" },
];

export type BottomNavVariant = "fixed" | "embedded";

export type BottomNavProps = {
  /** embedded：参与父级 flex 列，不 fixed；状态页与顶栏、信息区同列排布时用 */
  variant?: BottomNavVariant;
};

const BottomNav: React.FC<BottomNavProps> = ({ variant = "fixed" }) => {
  const location = useLocation();
  const navigate = useNavigate();
  const embedded = variant === "embedded";

  // Hide nav on independent full-screen flows
  if (location.pathname === "/pump" || location.pathname === "/calibration" || location.pathname === "/media-viewer") return null;

  return (
    <nav
      className={cn(
        "z-40 glass-panel border-t border-border/60 pb-safe",
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
                  onClick={() => navigate(tab.path)}
                  className="relative -top-3 flex h-[68px] w-[68px] flex-col items-center justify-center rounded-full border-[5px] border-background bg-gradient-to-br from-primary to-primary/80 text-primary-foreground shadow-[0_10px_22px_-7px_rgba(235,76,122,0.42)] transition-transform active:scale-95"
                >
                  <tab.icon className={cn("h-7 w-7 shrink-0", active && "fill-primary-foreground/20")} strokeWidth={active ? 2.5 : 2} />
                  <span className="mt-0.5 max-w-[56px] whitespace-nowrap text-center text-[8.5px] font-bold leading-none">{tab.label}</span>
                </button>
              </div>
            );
          }

          return (
            <div key={tab.path} className="flex-1 flex justify-center h-full items-center">
              <button
                onClick={() => navigate(tab.path)}
                className={cn(
                  "relative flex flex-col items-center gap-1 py-1.5 px-3 rounded-xl transition-all duration-200",
                  active
                    ? "text-primary"
                    : "text-muted-foreground hover:text-primary/70"
                )}
              >
                {/* Active background glow */}
                {active && (
                  <div className="absolute inset-0 rounded-xl bg-primary/10" />
                )}
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
