import { cn } from "@/lib/utils";
import type { AgentResponseLightRailMode } from "@/lib/agentResponseLightRail";
import type React from "react";

type AgentResponseLightRailProps = {
  mode: AgentResponseLightRailMode;
};

const AgentResponseLightRail: React.FC<AgentResponseLightRailProps> = ({
  mode,
}) => {
  if (mode === "idle") return null;

  return (
    <div
      aria-hidden="true"
      className={cn(
        "agent-response-light-rail",
        mode === "loop" ? "is-loop" : "is-replying",
      )}
    >
      <span className="agent-response-page-glow" />
    </div>
  );
};

export default AgentResponseLightRail;
