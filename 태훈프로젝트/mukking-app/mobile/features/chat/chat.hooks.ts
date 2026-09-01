import { useEffect, useMemo } from "react";
import { useAuthStore } from "../../store/auth.store";
import { useChatStore } from "../../store/chat.store";

export function useChatRooms() {
  const user = useAuthStore((state) => state.user);
  const rooms = useChatStore((state) => state.rooms);
  const activeRoomId = useChatStore((state) => state.activeRoomId);
  const messagesByRoomId = useChatStore((state) => state.messagesByRoomId);
  const isLoading = useChatStore((state) => state.isLoading);
  const error = useChatStore((state) => state.error);
  const loadRooms = useChatStore((state) => state.loadRooms);
  const openRoom = useChatStore((state) => state.openRoom);
  const sendMessage = useChatStore((state) => state.sendMessage);

  useEffect(() => {
    if (user?.verificationStatus === "verified") {
      void loadRooms();
    }
  }, [loadRooms, user?.verificationStatus]);

  useEffect(() => {
    if (activeRoomId && !messagesByRoomId[activeRoomId]) {
      void openRoom(activeRoomId);
    }
  }, [activeRoomId, messagesByRoomId, openRoom]);

  const activeMessages = useMemo(
    () => (activeRoomId ? messagesByRoomId[activeRoomId] ?? [] : []),
    [activeRoomId, messagesByRoomId]
  );

  return {
    rooms,
    activeRoomId,
    activeMessages,
    isLoading,
    error,
    openRoom,
    sendMessage
  };
}
