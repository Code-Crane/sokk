export type ChatRoomStatus = "active" | "closed" | "reported";

export interface ChatRoom {
  id: string;
  postId: string;
  title: string;
  participantIds: string[];
  status: ChatRoomStatus;
  createdAt: string;
  updatedAt: string;
}

export interface ChatMessage {
  id: string;
  roomId: string;
  senderId: string;
  text: string;
  createdAt: string;
}

export interface SendMessageInput {
  text: string;
}

