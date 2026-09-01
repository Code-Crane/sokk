import { create } from "zustand";
import type { ChatMessage, ChatRoom } from "../../shared/types";
import {
  listChatRooms,
  listMessages,
  sendMessage as sendMessageRequest
} from "../features/chat/chat.service";

interface ChatState {
  rooms: ChatRoom[];
  activeRoomId: string | null;
  messagesByRoomId: Record<string, ChatMessage[]>;
  isLoading: boolean;
  error: string | null;
  loadRooms: () => Promise<void>;
  openRoom: (roomId: string) => Promise<void>;
  sendMessage: (roomId: string, text: string) => Promise<void>;
}

export const useChatStore = create<ChatState>((set, get) => ({
  rooms: [],
  activeRoomId: null,
  messagesByRoomId: {},
  isLoading: false,
  error: null,
  loadRooms: async () => {
    set({ isLoading: true, error: null });

    try {
      const rooms = await listChatRooms();
      set((state) => ({
        rooms,
        activeRoomId: state.activeRoomId ?? rooms[0]?.id ?? null,
        isLoading: false
      }));
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to load chat rooms.",
        isLoading: false
      });
    }
  },
  openRoom: async (roomId) => {
    set({ activeRoomId: roomId, isLoading: true, error: null });

    try {
      const messages = await listMessages(roomId);
      set((state) => ({
        messagesByRoomId: {
          ...state.messagesByRoomId,
          [roomId]: messages
        },
        isLoading: false
      }));
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to open chat room.",
        isLoading: false
      });
    }
  },
  sendMessage: async (roomId, text) => {
    set({ error: null });

    try {
      const message = await sendMessageRequest(roomId, { text });
      const currentMessages = get().messagesByRoomId[roomId] ?? [];

      set((state) => ({
        messagesByRoomId: {
          ...state.messagesByRoomId,
          [roomId]: [...currentMessages, message]
        }
      }));

      await get().loadRooms();
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to send message."
      });
    }
  }
}));

