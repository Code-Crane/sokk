import type {
  MatchingPost,
  JoinRequest,
  ChatRoom,
  ChatMessage,
  CreateNotificationInput,
  NotificationListQuery,
  UnreadNotificationCountResponse,
  UserNotification
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { repositories } from "../../repositories";
import { dispatchNotificationsBestEffort } from "../push/push-dispatch.service";

function invalid(message: string): never {
  throw Object.assign(new Error(message), { statusCode: 400 });
}

async function persistBestEffort(inputs: CreateNotificationInput[]): Promise<void> {
  try {
    const rows = await repositories.notifications.createMany(inputs);
    await dispatchNotificationsBestEffort(rows);
  } catch {
    console.error("[notification] Core event notification failed after business persistence.");
  }
}

export async function notifyJoinEvent(post: MatchingPost, request: JoinRequest,
  type: "join_request_received" | "join_request_accepted" | "join_request_rejected"
): Promise<void> {
  const received = type === "join_request_received";
  const userId = received ? post.authorId : request.requesterId;
  const actorUserId = received ? request.requesterId : post.authorId;
  if (userId === actorUserId) return;
  const copy = {
    join_request_received: ["새로운 참여 신청이 왔어요", "모임 참여 신청을 확인해보세요."],
    join_request_accepted: ["참여 신청이 승인됐어요", "모임이 확정됐어요. 채팅에서 약속을 확인해보세요."],
    join_request_rejected: ["참여 신청 결과가 도착했어요", "이번 모임 참여 신청이 승인되지 않았어요."]
  }[type];
  await persistBestEffort([{userId, actorUserId, type, title: copy[0], body: copy[1],
    matchingPostId: post.id, restaurantId: post.restaurantId, eventKey: request.id}]);
}

export async function notifyChatMessage(room: ChatRoom, message: ChatMessage): Promise<void> {
  await persistBestEffort([...new Set(room.participantIds)]
    .filter(userId => userId !== message.senderId)
    .map(userId => ({userId, actorUserId: message.senderId, type: "chat_message_created",
      title: "새 메시지가 도착했어요", body: "채팅방에서 새 메시지를 확인해보세요.",
      matchingPostId: room.postId, chatRoomId: room.id, eventKey: message.id})));
}

function parseOptionalInteger(
  value: unknown,
  name: string,
  minimum: number,
  maximum?: number
): number | undefined {
  if (value === undefined) return undefined;
  const parsed = typeof value === "number" ? value : Number(value);
  if (
    !Number.isInteger(parsed) ||
    parsed < minimum ||
    (maximum !== undefined && parsed > maximum)
  ) {
    return invalid(
      maximum === undefined
        ? `${name} must be an integer greater than or equal to ${minimum}.`
        : `${name} must be an integer between ${minimum} and ${maximum}.`
    );
  }
  return parsed;
}

export async function createFavoriteRestaurantPartyNotifications(
  post: MatchingPost
): Promise<UserNotification[]> {
  if (!post.restaurantId) return [];

  const favoriteUserIds = await repositories.restaurantFavorites.listUserIdsByRestaurant(
    post.restaurantId
  );
  const recipientIds = [...new Set(favoriteUserIds)].filter(
    (userId) => userId !== post.authorId
  );

  const notifications = await repositories.notifications.createMany(
    recipientIds.map((userId) => ({
      userId,
      type: "favorite_restaurant_party_created" as const,
      title: "찜한 식당에 새 파티가 열렸어요",
      body: "가고 싶어한 식당의 새 식사 동행 모집을 확인해 보세요.",
      restaurantId: post.restaurantId,
      matchingPostId: post.id,
      actorUserId: post.authorId
    }))
  );

  await dispatchNotificationsBestEffort(notifications);
  return notifications;
}

export async function listNotifications(
  userId: string,
  query: NotificationListQuery
): Promise<UserNotification[]> {
  return repositories.notifications.listByUser(userId, {
    limit: parseOptionalInteger(query.limit, "limit", 1, 100) ?? 50,
    offset: parseOptionalInteger(query.offset, "offset", 0) ?? 0
  });
}

export async function getUnreadNotificationCount(
  userId: string
): Promise<UnreadNotificationCountResponse> {
  return { unreadCount: await repositories.notifications.countUnread(userId) };
}

export async function markNotificationRead(
  userId: string,
  notificationId: string
): Promise<UserNotification> {
  const notification = await repositories.notifications.findById(notificationId);
  if (!notification) {
    throw Object.assign(new Error("Notification not found."), { statusCode: 404 });
  }
  if (notification.userId !== userId) {
    throw Object.assign(new Error("You cannot read another user's notification."), {
      statusCode: 403
    });
  }
  if (notification.readAt) return notification;
  return repositories.notifications.markRead(notification.id, nowIso());
}
