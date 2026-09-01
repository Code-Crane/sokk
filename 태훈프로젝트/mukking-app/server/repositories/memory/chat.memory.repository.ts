import type { ChatMessage, ChatRoom } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  ChatMessageFilter,
  ChatRepository,
  CreateChatMessageInput,
  CreateChatRoomInput,
  UpsertChatRoomMemberInput
} from "../interfaces/chat.repository";

export const memoryChatRepository: ChatRepository = {
  async findActiveRoomByPostId(postId) {
    return (
      Array.from(db.chatRooms.values()).find(
        (room) => room.postId === postId && room.status === "active"
      ) ?? null
    );
  },

  async findRoomById(roomId) {
    return db.chatRooms.get(roomId) ?? null;
  },

  async createRoom(input: CreateChatRoomInput) {
    const timestamp = nowIso();
    const room: ChatRoom = {
      id: createEntityId("room"),
      postId: input.postId,
      title: input.title,
      participantIds: input.participantIds,
      status: input.status ?? "active",
      createdAt: timestamp,
      updatedAt: timestamp
    };

    db.chatRooms.set(room.id, room);
    db.chatMessages.set(room.id, []);

    return room;
  },

  async updateRoomStatus(roomId, status) {
    const room = db.chatRooms.get(roomId);

    if (!room) {
      throw Object.assign(new Error("Chat room not found."), { statusCode: 404 });
    }

    const updated = {
      ...room,
      status,
      updatedAt: nowIso()
    };

    db.chatRooms.set(roomId, updated);
    return updated;
  },

  async touchRoom(roomId, updatedAt) {
    const room = db.chatRooms.get(roomId);

    if (!room) {
      throw Object.assign(new Error("Chat room not found."), { statusCode: 404 });
    }

    const updated = {
      ...room,
      updatedAt
    };

    db.chatRooms.set(roomId, updated);
    return updated;
  },

  async listRoomsForUser(userId) {
    return Array.from(db.chatRooms.values())
      .filter((room) => room.participantIds.includes(userId))
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
  },

  async listParticipantIds(roomId) {
    const room = db.chatRooms.get(roomId);
    return room?.participantIds ?? [];
  },

  async isRoomParticipant(roomId, userId) {
    const room = db.chatRooms.get(roomId);
    return room?.participantIds.includes(userId) ?? false;
  },

  async upsertRoomMember(input: UpsertChatRoomMemberInput) {
    const room = db.chatRooms.get(input.roomId);

    if (!room) {
      throw Object.assign(new Error("Chat room not found."), { statusCode: 404 });
    }

    if (!room.participantIds.includes(input.userId)) {
      room.participantIds.push(input.userId);
      room.updatedAt = nowIso();
      db.chatRooms.set(room.id, room);
    }
  },

  async listMessages(roomId, filter: ChatMessageFilter = {}) {
    const messages = db.chatMessages.get(roomId) ?? [];
    const filtered = messages
      .filter((message) => (filter.before ? message.createdAt < filter.before : true))
      .filter((message) => (filter.after ? message.createdAt > filter.after : true));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? filtered.length;

    return filtered.slice(offset, offset + limit);
  },

  async createMessage(input: CreateChatMessageInput) {
    const message: ChatMessage = {
      id: createEntityId("msg"),
      roomId: input.roomId,
      senderId: input.senderId,
      text: input.text,
      createdAt: nowIso()
    };

    const messages = db.chatMessages.get(input.roomId) ?? [];
    messages.push(message);
    db.chatMessages.set(input.roomId, messages);

    return message;
  }
};
