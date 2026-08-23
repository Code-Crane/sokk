import type { UserNotification } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type { NotificationRepository } from "../interfaces/notification.repository";

function isSameEvent(
  notification: UserNotification,
  input: {
    userId: string;
    type: string;
    matchingPostId?: string;
  }
): boolean {
  return Boolean(
    input.matchingPostId &&
      notification.userId === input.userId &&
      notification.type === input.type &&
      notification.matchingPostId === input.matchingPostId
  );
}

export const memoryNotificationRepository: NotificationRepository = {
  async createMany(inputs) {
    const created: UserNotification[] = [];

    for (const input of inputs) {
      const existing = Array.from(db.notifications.values()).find((notification) =>
        isSameEvent(notification, input)
      );
      if (existing) continue;

      const notification: UserNotification = {
        id: createEntityId("notification"),
        ...input,
        createdAt: nowIso()
      };
      db.notifications.set(notification.id, notification);
      created.push(notification);
    }

    return created;
  },

  async findById(notificationId) {
    return db.notifications.get(notificationId) ?? null;
  },

  async listByUser(userId, options = {}) {
    const rows = Array.from(db.notifications.values())
      .filter((notification) => notification.userId === userId)
      .sort(
        (left, right) =>
          right.createdAt.localeCompare(left.createdAt) || right.id.localeCompare(left.id)
      );
    const offset = options.offset ?? 0;
    return rows.slice(offset, offset + (options.limit ?? rows.length));
  },

  async countUnread(userId) {
    return Array.from(db.notifications.values()).filter(
      (notification) => notification.userId === userId && !notification.readAt
    ).length;
  },

  async markRead(notificationId, readAt) {
    const notification = db.notifications.get(notificationId);
    if (!notification) {
      throw Object.assign(new Error("Notification not found."), { statusCode: 404 });
    }

    if (notification.readAt) return notification;
    const updated = { ...notification, readAt };
    db.notifications.set(notificationId, updated);
    return updated;
  }
};
