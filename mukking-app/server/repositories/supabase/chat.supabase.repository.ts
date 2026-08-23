import type { ChatMessage, ChatRoom, ChatRoomStatus } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  ChatMessageFilter,
  ChatMessageType,
  ChatRepository,
  CreateChatMessageInput,
  CreateChatRoomInput,
  UpsertChatRoomMemberInput
} from "../interfaces/chat.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type ChatRoomRow = {
  id: string;
  matching_post_id: string;
  title: string;
  status: ChatRoomStatus;
  created_at: string;
  updated_at: string;
};

type ParticipantRow = {
  room_id: string;
  user_id: string;
  role: "owner" | "member";
  joined_at: string;
};

type ChatMessageRow = {
  id: string;
  room_id: string;
  sender_id?: string | null;
  message_type: ChatMessageType;
  text: string;
  created_at: string;
};

function toMessage(row: ChatMessageRow): ChatMessage {
  return {
    id: row.id,
    roomId: row.room_id,
    senderId: row.message_type === "system" ? "system" : row.sender_id ?? "system",
    text: row.text,
    createdAt: row.created_at
  };
}

async function hydrateRooms(rows: ChatRoomRow[]): Promise<ChatRoom[]> {
  if (rows.length === 0) return [];

  const { data, error } = await getSupabaseServiceRoleClient()
    .from("chat_room_participants")
    .select("*")
    .in("room_id", rows.map((row) => row.id))
    .order("joined_at", { ascending: true })
    .order("user_id", { ascending: true })
    .returns<ParticipantRow[]>();

  if (error) throwSupabaseError(error);
  const participantIdsByRoom = new Map<string, string[]>();

  for (const participant of data ?? []) {
    const participantIds = participantIdsByRoom.get(participant.room_id) ?? [];
    participantIds.push(participant.user_id);
    participantIdsByRoom.set(participant.room_id, participantIds);
  }

  return rows.map((row) => ({
    id: row.id,
    postId: row.matching_post_id,
    title: row.title,
    participantIds: participantIdsByRoom.get(row.id) ?? [],
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  }));
}

async function hydrateRoom(row: ChatRoomRow | null): Promise<ChatRoom | null> {
  return row ? (await hydrateRooms([row]))[0] ?? null : null;
}

export const supabaseChatRepository: ChatRepository = {
  async findActiveRoomByPostId(postId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_rooms")
      .select("*")
      .eq("matching_post_id", postId)
      .eq("status", "active")
      .maybeSingle<ChatRoomRow>();
    if (error) throwSupabaseError(error);
    return hydrateRoom(data);
  },

  async findRoomById(roomId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_rooms")
      .select("*")
      .eq("id", roomId)
      .maybeSingle<ChatRoomRow>();
    if (error) throwSupabaseError(error);
    return hydrateRoom(data);
  },

  async createRoom(input: CreateChatRoomInput) {
    const { data, error } = await getSupabaseServiceRoleClient().rpc(
      "create_or_reuse_chat_room",
      {
        p_room_id: createEntityId("room"),
        p_matching_post_id: input.postId,
        p_title: input.title,
        p_participant_ids: input.participantIds,
        p_status: input.status ?? "active"
      }
    );
    if (error) throwSupabaseError(error);
    return ensureRow(await hydrateRoom(data as ChatRoomRow), "Chat room was not created.");
  },

  async updateRoomStatus(roomId, status) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_rooms")
      .update({ status, updated_at: nowIso() })
      .eq("id", roomId)
      .select("*")
      .single<ChatRoomRow>();
    if (error) throwSupabaseError(error);
    return ensureRow(await hydrateRoom(data), "Chat room not found.");
  },

  async touchRoom(roomId, updatedAt) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_rooms")
      .update({ updated_at: updatedAt })
      .eq("id", roomId)
      .select("*")
      .single<ChatRoomRow>();
    if (error) throwSupabaseError(error);
    return ensureRow(await hydrateRoom(data), "Chat room not found.");
  },

  async listRoomsForUser(userId) {
    const { data: memberships, error: membershipError } =
      await getSupabaseServiceRoleClient()
        .from("chat_room_participants")
        .select("room_id")
        .eq("user_id", userId)
        .returns<Array<Pick<ParticipantRow, "room_id">>>();
    if (membershipError) throwSupabaseError(membershipError);
    const roomIds = (memberships ?? []).map((membership) => membership.room_id);
    if (roomIds.length === 0) return [];

    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_rooms")
      .select("*")
      .in("id", roomIds)
      .order("updated_at", { ascending: false })
      .order("id", { ascending: false })
      .returns<ChatRoomRow[]>();
    if (error) throwSupabaseError(error);
    return hydrateRooms(data ?? []);
  },

  async listParticipantIds(roomId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_room_participants")
      .select("user_id")
      .eq("room_id", roomId)
      .order("joined_at", { ascending: true })
      .order("user_id", { ascending: true })
      .returns<Array<Pick<ParticipantRow, "user_id">>>();
    if (error) throwSupabaseError(error);
    return (data ?? []).map((participant) => participant.user_id);
  },

  async isRoomParticipant(roomId, userId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_room_participants")
      .select("room_id")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throwSupabaseError(error);
    return Boolean(data);
  },

  async upsertRoomMember(input: UpsertChatRoomMemberInput) {
    const { error } = await getSupabaseServiceRoleClient()
      .from("chat_room_participants")
      .upsert(
        {
          room_id: input.roomId,
          user_id: input.userId,
          role: input.role ?? "member",
          joined_at: input.joinedAt ?? nowIso()
        },
        { onConflict: "room_id,user_id", ignoreDuplicates: true }
      );
    if (error) throwSupabaseError(error);
  },

  async listMessages(roomId, filter: ChatMessageFilter = {}) {
    let query = getSupabaseServiceRoleClient()
      .from("chat_messages")
      .select("*")
      .eq("room_id", roomId)
      .order("created_at", { ascending: true })
      .order("id", { ascending: true });
    if (filter.before) query = query.lt("created_at", filter.before);
    if (filter.after) query = query.gt("created_at", filter.after);
    if (typeof filter.offset === "number" || typeof filter.limit === "number") {
      const offset = filter.offset ?? 0;
      const limit = filter.limit ?? 100;
      query = query.range(offset, offset + limit - 1);
    }

    const { data, error } = await query.returns<ChatMessageRow[]>();
    if (error) throwSupabaseError(error);
    return (data ?? []).map(toMessage);
  },

  async createMessage(input: CreateChatMessageInput) {
    const messageType = input.messageType ?? (input.senderId === "system" ? "system" : "user");
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("chat_messages")
      .insert({
        id: createEntityId("msg"),
        room_id: input.roomId,
        sender_id: input.senderId === "system" ? null : input.senderId,
        message_type: messageType,
        text: input.text,
        created_at: nowIso()
      })
      .select("*")
      .single<ChatMessageRow>();
    if (error) throwSupabaseError(error);
    return toMessage(ensureRow(data, "Chat message was not created."));
  }
};
