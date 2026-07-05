import {
  agentHubVoicePlaybackRuntime,
  type AgentHubVoicePlaybackHandle,
} from "@/lib/agentHubVoicePlaybackRuntime";

export type AgentVoicePlaybackSource =
  | "auto-reply"
  | "greeting"
  | "notification"
  | "manual-bubble";

export interface AgentVoicePlaybackHandle {
  id: string;
  source: AgentVoicePlaybackSource;
  token: number;
  setCancel: (cancel: (() => void) | undefined) => void;
  isCurrent: () => boolean;
  finish: () => void;
  cancel: () => boolean;
}

interface ActiveAgentVoicePlayback {
  id: string;
  source: AgentVoicePlaybackSource;
  token: number;
  priority: number;
  cancel?: () => void;
  visualHandle?: AgentHubVoicePlaybackHandle;
}

export interface BeginAgentVoicePlaybackOptions {
  id: string;
  source: AgentVoicePlaybackSource;
  priority?: number;
  cancel?: () => void;
  visual?: boolean;
}

export type RequestAgentVoicePlaybackResult =
  | { status: "started"; handle: AgentVoicePlaybackHandle }
  | {
      status: "blocked";
      activeId: string;
      activeSource: AgentVoicePlaybackSource;
    }
  | { status: "rejected" };

type CancelAgentVoicePlaybackOptions = {
  preserveSources?: AgentVoicePlaybackSource[];
};

type AgentVoicePlaybackIdleListener = () => void;

const SOURCE_PRIORITY: Record<AgentVoicePlaybackSource, number> = {
  "auto-reply": 50,
  greeting: 70,
  notification: 90,
  "manual-bubble": 100,
};

let activePlayback: ActiveAgentVoicePlayback | null = null;
let nextToken = 0;
const idleListeners = new Set<AgentVoicePlaybackIdleListener>();

function matches(handle: AgentVoicePlaybackHandle): boolean {
  return activePlayback?.token === handle.token;
}

function isPlaybackHandle(
  value: AgentVoicePlaybackHandle | CancelAgentVoicePlaybackOptions,
): value is AgentVoicePlaybackHandle {
  return typeof (value as AgentVoicePlaybackHandle).token === "number";
}

function finishActivePlayback(
  active: ActiveAgentVoicePlayback,
  opts?: { runCancel?: boolean; notifyIdle?: boolean },
): void {
  let clearedActive = false;
  if (activePlayback?.token === active.token) {
    activePlayback = null;
    clearedActive = true;
  }
  if (opts?.runCancel) active.cancel?.();
  if (active.visualHandle) {
    agentHubVoicePlaybackRuntime.finishAutoVoice(active.visualHandle);
  }
  if (clearedActive && opts?.notifyIdle !== false) {
    Array.from(idleListeners).forEach((listener) => listener());
  }
}

export function requestAgentVoicePlayback(
  opts: BeginAgentVoicePlaybackOptions,
): RequestAgentVoicePlaybackResult {
  const id = opts.id.trim();
  if (!id) return { status: "rejected" };
  const priority = opts.priority ?? SOURCE_PRIORITY[opts.source];
  const current = activePlayback;
  if (current) {
    if (priority < current.priority) {
      return {
        status: "blocked",
        activeId: current.id,
        activeSource: current.source,
      };
    }
    finishActivePlayback(current, { runCancel: true, notifyIdle: false });
  }

  nextToken += 1;
  const token = nextToken;
  const active: ActiveAgentVoicePlayback = {
    id,
    source: opts.source,
    token,
    priority,
    cancel: opts.cancel,
  };

  const handle: AgentVoicePlaybackHandle = {
    id,
    source: opts.source,
    token,
    setCancel(cancel) {
      if (activePlayback?.token === token) {
        activePlayback.cancel = cancel;
      }
    },
    isCurrent() {
      return activePlayback?.token === token;
    },
    finish() {
      if (activePlayback?.token !== token) return;
      finishActivePlayback(activePlayback);
    },
    cancel() {
      return cancelAgentVoicePlayback(handle);
    },
  };

  if (opts.visual !== false) {
    active.visualHandle = agentHubVoicePlaybackRuntime.startAutoVoice(id, () => {
      cancelAgentVoicePlayback(handle);
    });
  }

  activePlayback = active;
  return { status: "started", handle };
}

export function beginAgentVoicePlayback(
  opts: BeginAgentVoicePlaybackOptions,
): AgentVoicePlaybackHandle | null {
  const result = requestAgentVoicePlayback(opts);
  return result.status === "started" ? result.handle : null;
}

export function cancelAgentVoicePlayback(
  handleOrOptions?: AgentVoicePlaybackHandle | CancelAgentVoicePlaybackOptions,
): boolean {
  const current = activePlayback;
  if (!current) return false;
  if (handleOrOptions) {
    if (isPlaybackHandle(handleOrOptions)) {
      if (!matches(handleOrOptions)) return false;
    } else if (handleOrOptions.preserveSources?.includes(current.source)) {
      return false;
    }
  }
  finishActivePlayback(current, { runCancel: true });
  return true;
}

export function getActiveAgentVoicePlaybackSource():
  | AgentVoicePlaybackSource
  | null {
  return activePlayback?.source ?? null;
}

export function subscribeAgentVoicePlaybackIdle(
  listener: AgentVoicePlaybackIdleListener,
): () => void {
  idleListeners.add(listener);
  return () => {
    idleListeners.delete(listener);
  };
}
