import type {
  CreateNotificationInput,
  UserNotification
} from "../../../shared/types";
import type { RepositoryListOptions } from "./repository.types";

export interface NotificationRepository {
  createMany(inputs: CreateNotificationInput[]): Promise<UserNotification[]>;
  findById(notificationId: string): Promise<UserNotification | null>;
  listByUser(
    userId: string,
    options?: RepositoryListOptions
  ): Promise<UserNotification[]>;
  countUnread(userId: string): Promise<number>;
  markRead(notificationId: string, readAt: string): Promise<UserNotification>;
}
