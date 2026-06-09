interface AgentHubMainChatRuntimeActive {
  replyId: string;
  cancel: () => void;
}

export interface AgentHubMainChatRuntimeSnapshot {
  replyId: string | null;
  running: boolean;
}

type AgentHubMainChatRuntimeListener = () => void;

let active: AgentHubMainChatRuntimeActive | null = null;
let snapshot: AgentHubMainChatRuntimeSnapshot = {
  replyId: null,
  running: false,
};

const listeners = new Set<AgentHubMainChatRuntimeListener>();

function notify() {
  listeners.forEach((listener) => listener());
}

function publish(next: AgentHubMainChatRuntimeSnapshot) {
  if (snapshot.replyId === next.replyId && snapshot.running === next.running) return;
  snapshot = next;
  notify();
}

export const agentHubMainChatRuntime = {
  getSnapshot: () => snapshot,
  subscribe: (listener: AgentHubMainChatRuntimeListener) => {
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  },
  start: (replyId: string, cancel: () => void) => {
    active?.cancel();
    active = { replyId, cancel };
    publish({ replyId, running: true });
  },
  finish: (replyId: string) => {
    if (active?.replyId !== replyId) return;
    active = null;
    publish({ replyId: null, running: false });
  },
  cancel: () => {
    const current = active;
    if (!current) return false;
    current.cancel();
    active = null;
    publish({ replyId: null, running: false });
    return true;
  },
};
