export type NotificationType = "favorite_restaurant_party_created"
  | "join_request_received" | "join_request_accepted" | "join_request_rejected"
  | "chat_message_created";

export interface UserNotification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  restaurantId?: string;
  matchingPostId?: string;
  actorUserId?: string;
  chatRoomId?: string;
  eventKey?: string;
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
  chatRoomId?: string;
  eventKey?: string;
}

export interface NotificationListQuery {
  limit?: number;
  offset?: number;
}

export interface UnreadNotificationCountResponse {
  unreadCount: number;
}
