import React, { memo } from "react";
import { AlertTriangle, HeartPulse, MessageCircle, Sparkles, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";
import momcozyLogo from "@/assets/momcozy_logo.png";

export type MaiEmotion = "happy" | "encourage" | "alert" | "calm" | "thinking";

interface MaiAvatarProps {
  emotion?: MaiEmotion;
  size?: "xs" | "sm" | "md" | "lg" | "xl";
  animate?: boolean;
  className?: string;
}

const sizeMap = {
  xs: "w-[18px] h-[18px]",
  sm: "w-10 h-10",
  md: "w-16 h-16",
  lg: "w-24 h-24",
  xl: "w-40 h-40",
};

const iconSizeMap = {
  xs: "w-2 h-2",
  sm: "w-3 h-3",
  md: "w-4 h-4",
  lg: "w-5 h-5",
  xl: "w-7 h-7",
};

const emotionIcons: Record<MaiEmotion, LucideIcon> = {
  calm: MessageCircle,
  happy: Sparkles,
  encourage: HeartPulse,
  thinking: MessageCircle,
  alert: AlertTriangle,
};

const emotionTheme: Record<MaiEmotion, { halo: string; ring: string; badge: string; icon: string }> = {
  calm: {
    halo: "bg-[#dceeea]",
    ring: "border-[#b8d8d2] bg-[#f8fcfb]",
    badge: "bg-[#e7f4f1]",
    icon: "text-[#32776d]",
  },
  happy: {
    halo: "bg-[#f4d8e0]",
    ring: "border-[#ecc6d2] bg-[#fff8fa]",
    badge: "bg-[#fff0f4]",
    icon: "text-[#a64d6b]",
  },
  encourage: {
    halo: "bg-[#f1dfc6]",
    ring: "border-[#e6ccb0] bg-[#fffaf3]",
    badge: "bg-[#fff2df]",
    icon: "text-[#9a6330]",
  },
  thinking: {
    halo: "bg-[#d8e4ef]",
    ring: "border-[#bdd0df] bg-[#f7fbff]",
    badge: "bg-[#edf6ff]",
    icon: "text-[#3c6f95]",
  },
  alert: {
    halo: "bg-[#f3c6cc]",
    ring: "border-[#e7a8b1] bg-[#fff7f8]",
    badge: "bg-[#ffe8eb]",
    icon: "text-[#a23244]",
  },
};

const emotionAnimation: Record<MaiEmotion, string> = {
  calm: "mai-anim-breathe",
  happy: "mai-anim-bounce",
  encourage: "mai-anim-nod",
  thinking: "mai-anim-sway",
  alert: "mai-anim-tremble",
};

const MaiAvatar: React.FC<MaiAvatarProps> = ({
  emotion = "calm",
  size = "md",
  animate = true,
  className,
}) => {
  const theme = emotionTheme[emotion];
  const Icon = emotionIcons[emotion];

  return (
    <div
      className={cn(
        "relative rounded-full flex items-center justify-center flex-shrink-0",
        sizeMap[size],
        className
      )}
    >
      <div className={cn(
        "absolute -inset-[2px] rounded-full opacity-40 transition-all duration-700",
        theme.halo,
        emotion === "alert" ? "animate-pulse" : ""
      )} />

      <div className={cn(
        "relative flex h-full w-full items-center justify-center overflow-hidden rounded-full border shadow-sm",
        theme.ring,
        animate && emotionAnimation[emotion]
      )}
      style={{ willChange: animate ? "transform" : undefined }}>
        <img
          src={momcozyLogo}
          alt="M.ai"
          className="h-[48%] w-[72%] object-contain"
          loading="eager"
          decoding="sync"
          draggable={false}
        />
      </div>

      <span
        className={cn(
          "absolute -bottom-[1px] -right-[1px] inline-flex items-center justify-center rounded-full border border-white/80 shadow-sm",
          size === "xs" ? "h-2.5 w-2.5" : size === "sm" ? "h-4 w-4" : size === "md" ? "h-5 w-5" : size === "lg" ? "h-7 w-7" : "h-10 w-10",
          theme.badge,
        )}
        aria-hidden="true"
      >
        <Icon className={cn(iconSizeMap[size], theme.icon)} strokeWidth={2.25} />
      </span>

      <div className="absolute inset-0 rounded-full pointer-events-none bg-white/[0.03]" />
    </div>
  );
};

export default memo(MaiAvatar);
