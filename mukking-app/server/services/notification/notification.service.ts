import type {
  MatchingPost,
  NotificationListQuery,
  UnreadNotificationCountResponse,
  UserNotification
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { repositories } from "../../repositories";

function invalid(message: string): never {
  throw Object.assign(new Error(message), { statusCode: 400 });
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

  return repositories.notifications.createMany(
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
