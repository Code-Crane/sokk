import type {
  ChatMessage,
  ChatRoom,
  MatchingPost,
  SendMessageInput
} from "../../../shared/types";
import { repositories } from "../../repositories";
import { assertCanUseChat, assertVerifiedUser } from "../auth/auth.service";
import { assertNoActiveBlockBetween } from "../block/block.service";

const ROOM_OPENED_SYSTEM_MESSAGE = "매칭이 성사되어 채팅방이 열렸습니다.";

function assertRoomParticipant(room: ChatRoom, userId: string): void {
  if (!room.participantIds.includes(userId)) {
    throw Object.assign(new Error("You are not a participant in this chat room."), {
      statusCode: 403
    });
  }
}

export async function ensureChatForAcceptedPost(post: MatchingPost): Promise<ChatRoom> {
  const participantIds = Array.from(new Set([post.authorId, ...post.participantIds]));
  const room = await repositories.chat.ensureRoom({
    postId: post.id,
    title: post.restaurantName,
    participantIds,
    status: "active"
  });

  const hasLegacyOpenedMessage = await repositories.chat.hasSystemMessage(
    room.id,
    ROOM_OPENED_SYSTEM_MESSAGE
  );

  if (!hasLegacyOpenedMessage) {
    await repositories.chat.ensureSystemMessage({
      id: `msg_room_opened_${room.id}`,
      roomId: room.id,
      text: ROOM_OPENED_SYSTEM_MESSAGE
    });
  }

  return (
    (await repositories.chat.findRoomById(room.id)) ?? room
  );
}

export async function listChatRooms(userId: string): Promise<ChatRoom[]> {
  await assertVerifiedUser(userId);

  return repositories.chat.listRoomsForUser(userId);
}

export async function listMessages(
  userId: string,
  roomId: string
): Promise<ChatMessage[]> {
  await assertVerifiedUser(userId);

  const room = await repositories.chat.findRoomById(roomId);

  if (!room) {
    throw Object.assign(new Error("Chat room not found."), { statusCode: 404 });
  }

  assertRoomParticipant(room, userId);
  return repositories.chat.listMessages(roomId);
}

export async function sendMessage(
  userId: string,
  roomId: string,
  input: SendMessageInput
): Promise<ChatMessage> {
  await assertCanUseChat(userId);

  const room = await repositories.chat.findRoomById(roomId);

  if (!room) {
    throw Object.assign(new Error("Chat room not found."), { statusCode: 404 });
  }

  assertRoomParticipant(room, userId);

  for (const participantId of room.participantIds) {
    if (participantId !== userId) {
      await assertNoActiveBlockBetween(userId, participantId, "chat");
    }
  }

  const text = input.text.trim();

  if (!text) {
    throw Object.assign(new Error("Message text is required."), { statusCode: 400 });
  }

  const message = await repositories.chat.createMessage({
    roomId,
    senderId: userId,
    text
  });

  await repositories.chat.touchRoom(roomId, message.createdAt);

  return message;
}
