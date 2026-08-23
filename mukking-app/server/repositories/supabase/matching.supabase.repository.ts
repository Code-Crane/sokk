import type {
  CreateMatchingPostInput,
  GeoPoint,
  JoinRequest,
  JoinRequestStatus,
  MatchingPost,
  MatchingPostStatus
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  JoinRequestAcceptanceResult,
  MatchingPostFilter,
  MatchingRepository,
  UpdateMatchingPostInput
} from "../interfaces/matching.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type MatchingPostRow = {
  id: string;
  author_id: string;
  restaurant_id?: string | null;
  restaurant_name: string;
  address: string;
  location?: GeoPoint | null;
  scheduled_at: string;
  max_participants: number;
  intro: string;
  status: MatchingPostStatus;
  participant_ids: string[] | null;
  completed_at?: string | null;
  created_at: string;
  updated_at: string;
};

type JoinRequestRow = {
  id: string;
  post_id: string;
  requester_id: string;
  status: JoinRequestStatus;
  created_at: string;
  updated_at: string;
};

type AcceptedJoinRequestRow = {
  request: JoinRequestRow;
  post: MatchingPostRow;
};

function toPost(row: MatchingPostRow): MatchingPost {
  return {
    id: row.id,
    authorId: row.author_id,
    restaurantId: row.restaurant_id ?? undefined,
    restaurantName: row.restaurant_name,
    address: row.address,
    location: row.location ?? undefined,
    scheduledAt: row.scheduled_at,
    maxParticipants: row.max_participants,
    intro: row.intro,
    status: row.status,
    participantIds: row.participant_ids ?? [],
    completedAt: row.completed_at ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function toJoinRequest(row: JoinRequestRow): JoinRequest {
  return {
    id: row.id,
    postId: row.post_id,
    requesterId: row.requester_id,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function applyFilter(post: MatchingPost, filter: MatchingPostFilter): boolean {
  if (filter.includeWithoutLocation === false && !post.location) return false;
  return true;
}

export const supabaseMatchingRepository: MatchingRepository = {
  async listPosts(filter: MatchingPostFilter = {}) {
    let query = getSupabaseServiceRoleClient()
      .from("matching_posts")
      .select("*")
      .order("created_at", { ascending: false });

    if (filter.authorId) query = query.eq("author_id", filter.authorId);
    if (filter.status) query = query.eq("status", filter.status);

    const { data, error } = await query.returns<MatchingPostRow[]>();
    if (error) throwSupabaseError(error);

    const posts = (data ?? []).map(toPost).filter((post) => applyFilter(post, filter));
    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? posts.length;
    return posts.slice(offset, offset + limit);
  },

  async findPostById(postId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("matching_posts")
      .select("*")
      .eq("id", postId)
      .maybeSingle<MatchingPostRow>();
    if (error) throwSupabaseError(error);
    return data ? toPost(data) : null;
  },

  async createPost(authorId, input: CreateMatchingPostInput) {
    const timestamp = nowIso();
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("matching_posts")
      .insert({
        id: createEntityId("post"),
        author_id: authorId,
        restaurant_id: input.restaurantId,
        restaurant_name: input.restaurantName,
        address: input.address,
        location: input.location,
        scheduled_at: input.scheduledAt,
        max_participants: input.maxParticipants,
        intro: input.intro,
        status: "open",
        participant_ids: [],
        created_at: timestamp,
        updated_at: timestamp
      })
      .select("*")
      .single<MatchingPostRow>();
    if (error) throwSupabaseError(error);
    return toPost(ensureRow(data, "Matching post was not created."));
  },

  async updatePost(postId, input: UpdateMatchingPostInput) {
    const update: Record<string, unknown> = { updated_at: nowIso() };
    if (input.restaurantId !== undefined) update.restaurant_id = input.restaurantId;
    if (input.restaurantName !== undefined) update.restaurant_name = input.restaurantName;
    if (input.address !== undefined) update.address = input.address;
    if (input.location !== undefined) update.location = input.location;
    if (input.scheduledAt !== undefined) update.scheduled_at = input.scheduledAt;
    if (input.maxParticipants !== undefined) update.max_participants = input.maxParticipants;
    if (input.intro !== undefined) update.intro = input.intro;
    if (input.status !== undefined) update.status = input.status;
    if (input.participantIds !== undefined) update.participant_ids = input.participantIds;
    if (input.completedAt !== undefined) update.completed_at = input.completedAt;

    const { data, error } = await getSupabaseServiceRoleClient()
      .from("matching_posts")
      .update(update)
      .eq("id", postId)
      .select("*")
      .single<MatchingPostRow>();
    if (error) throwSupabaseError(error);
    return toPost(ensureRow(data, "Matching post not found."));
  },

  async cancelPost(postId) {
    return this.updatePost(postId, { status: "cancelled" });
  },

  async completePost(postId, completedAt) {
    return this.updatePost(postId, { status: "completed", completedAt });
  },

  async listParticipantIds(postId) {
    return (await this.findPostById(postId))?.participantIds ?? [];
  },

  async addParticipant(postId, userId) {
    const post = await this.findPostById(postId);
    if (!post) throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
    if (post.participantIds.includes(userId)) return post;
    if (post.participantIds.length >= post.maxParticipants) {
      throw Object.assign(new Error("This matching post is full."), { statusCode: 409 });
    }
    const participantIds = [...post.participantIds, userId];
    return this.updatePost(postId, {
      participantIds,
      status: participantIds.length >= post.maxParticipants ? "closed" : post.status
    });
  },

  async findJoinRequestById(requestId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("join_requests")
      .select("*")
      .eq("id", requestId)
      .maybeSingle<JoinRequestRow>();
    if (error) throwSupabaseError(error);
    return data ? toJoinRequest(data) : null;
  },

  async findPendingJoinRequest(postId, requesterId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("join_requests")
      .select("*")
      .eq("post_id", postId)
      .eq("requester_id", requesterId)
      .eq("status", "pending")
      .maybeSingle<JoinRequestRow>();
    if (error) throwSupabaseError(error);
    return data ? toJoinRequest(data) : null;
  },

  async listJoinRequestsForPost(postId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("join_requests")
      .select("*")
      .eq("post_id", postId)
      .order("created_at", { ascending: false })
      .returns<JoinRequestRow[]>();
    if (error) throwSupabaseError(error);
    return (data ?? []).map(toJoinRequest);
  },

  async createJoinRequest(postId, requesterId) {
    const timestamp = nowIso();
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("join_requests")
      .insert({
        id: createEntityId("join"),
        post_id: postId,
        requester_id: requesterId,
        status: "pending",
        created_at: timestamp,
        updated_at: timestamp
      })
      .select("*")
      .single<JoinRequestRow>();
    if (error) throwSupabaseError(error);
    return toJoinRequest(ensureRow(data, "Join request was not created."));
  },

  async updateJoinRequestStatus(requestId, status: JoinRequestStatus) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("join_requests")
      .update({ status, updated_at: nowIso() })
      .eq("id", requestId)
      .select("*")
      .single<JoinRequestRow>();
    if (error) throwSupabaseError(error);
    return toJoinRequest(ensureRow(data, "Join request not found."));
  },

  async acceptJoinRequest(requestId): Promise<JoinRequestAcceptanceResult> {
    const { data, error } = await getSupabaseServiceRoleClient()
      .rpc("accept_join_request", { p_request_id: requestId })
      .returns<AcceptedJoinRequestRow[]>();
    if (error) throwSupabaseError(error);
    const rows = data as unknown as AcceptedJoinRequestRow[] | null;
    const result = ensureRow(rows?.[0] ?? null, "Join request not found.");
    return { request: toJoinRequest(result.request), post: toPost(result.post) };
  }
};
