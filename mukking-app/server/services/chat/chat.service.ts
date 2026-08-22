import type {
  ChatMessage,
  ChatRoom,
  MatchingPost,
  SendMessageInput
} from "../../../shared/types";
import { repositories } from "../../repositories";
import { assertCanUseChat, assertVerifiedUser } from "../auth/auth.service";
import { assertNoActiveBlockBetween } from "../block/block.service";

function assertRoomParticipant(room: ChatRoom, userId: string): void {
  if (!room.participantIds.includes(userId)) {
    throw Object.assign(new Error("You are not a participant in this chat room."), {
      statusCode: 403
    });
  }
}

export function createOrUpdateRoomForPost(
  post: MatchingPost,
  acceptedUserId: string
): Promise<ChatRoom> {
  return createOrUpdateRoomForPostAsync(post, acceptedUserId);
}

async function createOrUpdateRoomForPostAsync(
  post: MatchingPost,
  acceptedUserId: string
): Promise<ChatRoom> {
  await assertNoActiveBlockBetween(post.authorId, acceptedUserId, "chat");

  const existingRoom = await repositories.chat.findActiveRoomByPostId(post.id);

  if (existingRoom) {
    await repositories.chat.upsertRoomMember({
      roomId: existingRoom.id,
      userId: acceptedUserId
    });

    return repositories.chat.touchRoom(existingRoom.id, new Date().toISOString());
  }

  const room = await repositories.chat.createRoom({
    postId: post.id,
    title: post.restaurantName,
    participantIds: [post.authorId, acceptedUserId],
    status: "active"
  });

  await repositories.chat.createMessage({
    roomId: room.id,
    senderId: "system",
    messageType: "system",
    text: "매칭이 성사되어 채팅방이 열렸습니다."
  });

  return room;
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
