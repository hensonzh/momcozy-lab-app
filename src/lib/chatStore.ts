import type { ChatMessage } from "@/types/chat";
import type { SetStateAction } from "react";

interface ChatState {
  messages: ChatMessage[];
}

type ChatStoreListener = () => void;

const state: ChatState = {
  messages: [],
};

const listeners = new Set<ChatStoreListener>();

function notify() {
  listeners.forEach((listener) => listener());
}

function resolveNextMessages(action: SetStateAction<ChatMessage[]>): ChatMessage[] {
  return typeof action === "function" ? action(state.messages) : action;
}

export const chatStore = {
  get: () => state,
  setMessages: (msgs: ChatMessage[]) => {
    if (state.messages === msgs) return;
    state.messages = msgs;
    notify();
  },
  updateMessages: (action: SetStateAction<ChatMessage[]>) => {
    const next = resolveNextMessages(action);
    if (state.messages === next) return;
    state.messages = next;
    notify();
  },
  subscribe: (listener: ChatStoreListener) => {
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  },
};
