// Lightweight pub/sub for cross-module chat card injection
import type { ChatMessage } from "@/types/chat";

type Listener = (msg: ChatMessage) => void;
const listeners = new Set<Listener>();
let pendingMessages: ChatMessage[] = [];

export const chatBus = {
  subscribe(fn: Listener) {
    listeners.add(fn);
    // Deliver any pending messages to the new subscriber
    if (pendingMessages.length > 0) {
      const msgs = [...pendingMessages];
      pendingMessages = [];
      msgs.forEach((m) => fn(m));
    }
    return () => { listeners.delete(fn); };
  },
  push(msg: ChatMessage) {
    if (listeners.size === 0) {
      // No subscribers yet (e.g. navigating to AgentHub), queue the message
      pendingMessages.push(msg);
    } else {
      listeners.forEach((fn) => fn(msg));
    }
  },
};
