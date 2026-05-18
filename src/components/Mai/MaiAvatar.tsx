import React, { memo } from "react";
import { cn } from "@/lib/utils";

import maiCalm from "@/assets/mai-calm-avatar.png";
import maiHappy from "@/assets/mai-happy-avatar.png";
import maiEncourage from "@/assets/mai-encourage-avatar.png";
import maiThinking from "@/assets/mai-thinking-avatar.png";
import maiAlert from "@/assets/mai-worry-avatar.png";

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

const emotionImages: Record<MaiEmotion, string> = {
  calm: maiCalm,
  happy: maiHappy,
  encourage: maiEncourage,
  thinking: maiThinking,
  alert: maiAlert,
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
        emotion === "alert" ? "bg-mai-warm animate-pulse" :
        emotion === "happy" ? "bg-mai-blush" :
        emotion === "encourage" ? "bg-mai-warm" :
        "bg-mai-blush/50"
      )} />

      <div className={cn(
        "relative w-full h-full rounded-full overflow-hidden mai-shadow",
        animate && emotionAnimation[emotion]
      )}
      style={{ willChange: animate ? "transform" : undefined }}>
        <img
          src={emotionImages[emotion]}
          alt={`M.ai - ${emotion}`}
          className="w-[140%] h-[140%] object-cover object-[center_30%] absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
          loading="eager"
          decoding="sync"
          draggable={false}
        />
      </div>

      <div className="absolute inset-0 rounded-full pointer-events-none bg-mai-blush/[0.03]" />
    </div>
  );
};

export default memo(MaiAvatar);
