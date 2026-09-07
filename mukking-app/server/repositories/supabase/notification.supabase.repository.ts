import type {
  CreateNotificationInput,
  NotificationType,
  UserNotification
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type { NotificationRepository } from "../interfaces/notification.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type NotificationRow = {
  id: string;
  user_id: string;
  type: NotificationType;
  title: string;
  body: string;
  restaurant_id: string | null;
  matching_post_id: string | null;
  actor_user_id: string | null;
  chat_room_id: string | null;
  event_key: string | null;
  read_at: string | null;
  created_at: string;
};

function toNotification(row: NotificationRow): UserNotification {
  return {
    id: row.id,
    userId: row.user_id,
    type: row.type,
    title: row.title,
    body: row.body,
    restaurantId: row.restaurant_id ?? undefined,
    matchingPostId: row.matching_post_id ?? undefined,
    actorUserId: row.actor_user_id ?? undefined,
    chatRoomId: row.chat_room_id ?? undefined,
    eventKey: row.event_key ?? undefined,
    readAt: row.read_at ?? undefined,
    createdAt: row.created_at
  };
}

function toInsert(input: CreateNotificationInput): Record<string, unknown> {
  return {
    id: createEntityId("notification"),
    user_id: input.userId,
    type: input.type,
    title: input.title,
    body: input.body,
    restaurant_id: input.restaurantId ?? null,
    matching_post_id: input.matchingPostId ?? null,
    actor_user_id: input.actorUserId ?? null,
    chat_room_id: input.chatRoomId ?? null,
    event_key: input.eventKey ?? input.matchingPostId,
    created_at: nowIso()
  };
}

export const supabaseNotificationRepository: NotificationRepository = {
  async createMany(inputs) {
    if (inputs.length === 0) return [];
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("notifications")
      .upsert(inputs.map(toInsert), {
        onConflict: "user_id,type,event_key",
        ignoreDuplicates: true
      })
      .select("*")
      .returns<NotificationRow[]>();

    if (error) throwSupabaseError(error);
    return (data ?? []).map(toNotification);
  },

  async findById(notificationId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("notifications")
      .select("*")
      .eq("id", notificationId)
      .maybeSingle<NotificationRow>();

    if (error) throwSupabaseError(error);
    return data ? toNotification(data) : null;
  },

  async listByUser(userId, options = {}) {
    const offset = options.offset ?? 0;
    const limit = options.limit ?? 50;
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("notifications")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .range(offset, offset + limit - 1)
      .returns<NotificationRow[]>();

    if (error) throwSupabaseError(error);
    return (data ?? []).map(toNotification);
  },

  async countUnread(userId) {
    const { count, error } = await getSupabaseServiceRoleClient()
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .is("read_at", null);

    if (error) throwSupabaseError(error);
    return count ?? 0;
  },

  async markRead(notificationId, readAt) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("notifications")
      .update({ read_at: readAt })
      .eq("id", notificationId)
      .select("*")
      .single<NotificationRow>();

    if (error) throwSupabaseError(error);
    return toNotification(ensureRow(data, "Notification not found."));
  }
};
