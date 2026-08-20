import type {
  ChatMessage,
  ChatRoom,
  ChatRoomStatus,
  SendMessageInput
} from "../../../shared/types";
import type { RepositoryListOptions } from "./repository.types";

export type ChatMessageType = "user" | "system" | "admin_notice";
export type ChatRoomMemberRole = "owner" | "member";

export interface CreateChatRoomInput {
  postId: string;
  title: string;
  participantIds: string[];
  status?: ChatRoomStatus;
}

export interface UpsertChatRoomMemberInput {
  roomId: string;
  userId: string;
  role?: ChatRoomMemberRole;
  joinedAt?: string;
}

export interface CreateChatMessageInput extends SendMessageInput {
  roomId: string;
  senderId: string | "system";
  messageType?: ChatMessageType;
}

export interface ChatMessageFilter extends RepositoryListOptions {
  before?: string;
  after?: string;
}

export interface ChatRepository {
  findActiveRoomByPostId(postId: string): Promise<ChatRoom | null>;
  findRoomById(roomId: string): Promise<ChatRoom | null>;
  createRoom(input: CreateChatRoomInput): Promise<ChatRoom>;
  updateRoomStatus(roomId: string, status: ChatRoomStatus): Promise<ChatRoom>;
  touchRoom(roomId: string, updatedAt: string): Promise<ChatRoom>;
  listRoomsForUser(userId: string): Promise<ChatRoom[]>;
  listParticipantIds(roomId: string): Promise<string[]>;
  isRoomParticipant(roomId: string, userId: string): Promise<boolean>;
  upsertRoomMember(input: UpsertChatRoomMemberInput): Promise<void>;
  listMessages(
    roomId: string,
    filter?: ChatMessageFilter
  ): Promise<ChatMessage[]>;
  createMessage(input: CreateChatMessageInput): Promise<ChatMessage>;
}
