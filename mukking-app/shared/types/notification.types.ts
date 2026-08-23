export type NotificationType = "favorite_restaurant_party_created";

export interface UserNotification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  restaurantId?: string;
  matchingPostId?: string;
  actorUserId?: string;
  readAt?: string;
  createdAt: string;
}

export interface CreateNotificationInput {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  restaurantId?: string;
  matchingPostId?: string;
  actorUserId?: string;
}

export interface NotificationListQuery {
  limit?: number;
  offset?: number;
}

export interface UnreadNotificationCountResponse {
  unreadCount: number;
}
