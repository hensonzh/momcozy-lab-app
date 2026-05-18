import type { ChatMessage } from "@/types/chat";

interface ChatState {
  messages: ChatMessage[];
}

const state: ChatState = {
  messages: [],
};

export const chatStore = {
  get: () => state,
  setMessages: (msgs: ChatMessage[]) => { state.messages = msgs; },
};
