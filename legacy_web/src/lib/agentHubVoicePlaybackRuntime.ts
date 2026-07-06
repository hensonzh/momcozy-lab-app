export interface AgentHubVoicePlaybackSnapshot {
  autoVoicePlayingId: string | null;
  running: boolean;
}

export interface AgentHubVoicePlaybackHandle {
  replyId: string;
  token: number;
}

interface AgentHubVoicePlaybackActive {
  replyId: string;
  token: number;
  cancel?: () => void;
}

type AgentHubVoicePlaybackListener = () => void;

let active: AgentHubVoicePlaybackActive | null = null;
let nextToken = 0;
let snapshot: AgentHubVoicePlaybackSnapshot = {
  autoVoicePlayingId: null,
  running: false,
};

const listeners = new Set<AgentHubVoicePlaybackListener>();

function notify() {
  listeners.forEach((listener) => listener());
}

function publish(next: AgentHubVoicePlaybackSnapshot) {
  if (
    snapshot.autoVoicePlayingId === next.autoVoicePlayingId &&
    snapshot.running === next.running
  ) {
    return;
  }
  snapshot = next;
  notify();
}

function handleMatches(handle: AgentHubVoicePlaybackHandle): boolean {
  return active?.replyId === handle.replyId && active.token === handle.token;
}

export const agentHubVoicePlaybackRuntime = {
  getSnapshot: () => snapshot,
  subscribe: (listener: AgentHubVoicePlaybackListener) => {
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  },
  startAutoVoice: (
    replyId: string,
    cancel?: () => void,
  ): AgentHubVoicePlaybackHandle => {
    nextToken += 1;
    const handle: AgentHubVoicePlaybackHandle = {
      replyId,
      token: nextToken,
    };
    active = { ...handle, cancel };
    publish({ autoVoicePlayingId: replyId, running: true });
    return handle;
  },
  finishAutoVoice: (handle: AgentHubVoicePlaybackHandle) => {
    if (!handleMatches(handle)) return;
    active = null;
    publish({ autoVoicePlayingId: null, running: false });
  },
  cancelAutoVoice: (handle?: AgentHubVoicePlaybackHandle) => {
    if (handle && !handleMatches(handle)) return false;
    const current = active;
    if (!current) return false;
    active = null;
    publish({ autoVoicePlayingId: null, running: false });
    current.cancel?.();
    return true;
  },
};
