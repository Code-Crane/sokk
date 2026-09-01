import type { ChatMessage, ChatRoom, SendMessageInput } from "../../../shared/types";
import { apiRequest } from "../../services/api.client";

export function listChatRooms(): Promise<ChatRoom[]> {
  return apiRequest<ChatRoom[]>("/api/chat/rooms");
}

export function listMessages(roomId: string): Promise<ChatMessage[]> {
  return apiRequest<ChatMessage[]>(`/api/chat/rooms/${roomId}/messages`);
}

export function sendMessage(
  roomId: string,
  input: SendMessageInput
): Promise<ChatMessage> {
  return apiRequest<ChatMessage>(`/api/chat/rooms/${roomId}/messages`, {
    method: "POST",
    body: JSON.stringify(input)
  });
}

