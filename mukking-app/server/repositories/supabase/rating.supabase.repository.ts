import type { MannerGrade, MannerRating, PendingEvaluation } from "../../../shared/types";
import { getMannerGrade } from "../../../shared/utils/rating";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  CreateMannerRatingInput,
  MannerRatingFilter,
  RatingRepository
} from "../interfaces/rating.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type PendingRow = { id: string; matching_post_id: string; reviewer_id: string; reviewee_id: string; created_at: string };
type RatingRow = { id: string; matching_post_id: string; reviewer_id: string; reviewee_id: string; score: number; tags: string[] | null; source: string; previous_score: number; next_score: number; delta: number; created_at: string };
type ProfileRow = { user_id: string; manner_score: number; manner_grade: MannerGrade };
type SubmitRow = { rating: RatingRow; previous_score: number; next_score: number; next_grade: MannerGrade };

const toPending = (row: PendingRow): PendingEvaluation => ({ id: row.id, matchId: row.matching_post_id, reviewerId: row.reviewer_id, revieweeId: row.reviewee_id, createdAt: row.created_at });
const toRating = (row: RatingRow): MannerRating => ({ id: row.id, matchId: row.matching_post_id, reviewerId: row.reviewer_id, revieweeId: row.reviewee_id, score: row.score as MannerRating["score"], tags: row.tags ?? [], createdAt: row.created_at });

async function insertRating(input: CreateMannerRatingInput): Promise<RatingRow> {
  const { data, error } = await getSupabaseServiceRoleClient().from("manner_ratings").insert({
    id: createEntityId("rating"), matching_post_id: input.matchId, reviewer_id: input.reviewerId,
    reviewee_id: input.revieweeId, score: input.score, tags: input.tags,
    source: input.source ?? "meeting_review", previous_score: input.previousScore,
    next_score: input.nextScore, delta: input.delta, created_at: nowIso()
  }).select("*").single<RatingRow>();
  if (error) throwSupabaseError(error);
  return ensureRow(data, "Manner rating was not created.");
}

export const supabaseRatingRepository: RatingRepository = {
  async listPendingEvaluations(userId) {
    const { data, error } = await getSupabaseServiceRoleClient().from("pending_evaluations").select("*").eq("reviewer_id", userId).order("created_at", { ascending: false }).order("id", { ascending: false }).returns<PendingRow[]>();
    if (error) throwSupabaseError(error);
    return (data ?? []).map(toPending);
  },
  async countPendingEvaluations(userId) {
    const { count, error } = await getSupabaseServiceRoleClient().from("pending_evaluations").select("id", { count: "exact", head: true }).eq("reviewer_id", userId);
    if (error) throwSupabaseError(error);
    return count ?? 0;
  },
  async findPendingEvaluation(matchId, reviewerId, revieweeId) {
    const { data, error } = await getSupabaseServiceRoleClient().from("pending_evaluations").select("*").eq("matching_post_id", matchId).eq("reviewer_id", reviewerId).eq("reviewee_id", revieweeId).maybeSingle<PendingRow>();
    if (error) throwSupabaseError(error);
    return data ? toPending(data) : null;
  },
  async createPendingEvaluation(input) {
    const existing = await this.findPendingEvaluation(input.matchId, input.reviewerId, input.revieweeId);
    if (existing) return existing;
    const { data, error } = await getSupabaseServiceRoleClient().from("pending_evaluations").insert({ id: createEntityId("eval"), matching_post_id: input.matchId, reviewer_id: input.reviewerId, reviewee_id: input.revieweeId, created_at: input.createdAt ?? nowIso() }).select("*").single<PendingRow>();
    if (error) throwSupabaseError(error);
    return toPending(ensureRow(data, "Pending evaluation was not created."));
  },
  async createPendingEvaluationsForMatch(matchId, participantIds) {
    const created: PendingEvaluation[] = [];
    const timestamp = nowIso();
    for (const reviewerId of participantIds) for (const revieweeId of participantIds) {
      if (reviewerId !== revieweeId) created.push(await this.createPendingEvaluation({ matchId, reviewerId, revieweeId, createdAt: timestamp }));
    }
    return created;
  },
  async deletePendingEvaluation(evaluationId) {
    const { error } = await getSupabaseServiceRoleClient().from("pending_evaluations").delete().eq("id", evaluationId);
    if (error) throwSupabaseError(error);
  },
  async createMannerRating(input) {
    const row = await insertRating(input);
    const { error } = await getSupabaseServiceRoleClient().from("user_manner_profiles").upsert({ user_id: input.revieweeId, manner_score: input.nextScore, manner_grade: getMannerGrade(input.nextScore), updated_at: nowIso() });
    if (error) throwSupabaseError(error);
    return toRating(row);
  },
  async submitMannerRating(input, pendingEvaluationId) {
    const { data, error } = await getSupabaseServiceRoleClient().rpc("submit_manner_rating", {
      p_rating_id: createEntityId("rating"), p_pending_evaluation_id: pendingEvaluationId,
      p_matching_post_id: input.matchId, p_reviewer_id: input.reviewerId,
      p_reviewee_id: input.revieweeId, p_score: input.score, p_tags: input.tags,
      p_delta: input.delta, p_source: input.source ?? "meeting_review"
    });
    if (error) throwSupabaseError(error);
    const row = data as SubmitRow;
    return { rating: toRating(row.rating), previousScore: Number(row.previous_score), nextScore: Number(row.next_score), nextGrade: row.next_grade };
  },
  async getMannerProfile(userId) {
    const { data, error } = await getSupabaseServiceRoleClient().from("user_manner_profiles").select("*").eq("user_id", userId).maybeSingle<ProfileRow>();
    if (error) throwSupabaseError(error);
    return data ? { mannerScore: Number(data.manner_score), mannerGrade: data.manner_grade } : null;
  },
  async listMannerRatings(filter: MannerRatingFilter = {}) {
    let query = getSupabaseServiceRoleClient().from("manner_ratings").select("*").order("created_at", { ascending: false }).order("id", { ascending: false });
    if (filter.reviewerId) query = query.eq("reviewer_id", filter.reviewerId);
    if (filter.revieweeId) query = query.eq("reviewee_id", filter.revieweeId);
    if (filter.matchId) query = query.eq("matching_post_id", filter.matchId);
    if (filter.source) query = query.eq("source", filter.source);
    if (filter.from) query = query.gte("created_at", filter.from);
    if (filter.to) query = query.lte("created_at", filter.to);
    if (filter.offset !== undefined || filter.limit !== undefined) { const offset = filter.offset ?? 0; query = query.range(offset, offset + (filter.limit ?? 50) - 1); }
    const { data, error } = await query.returns<RatingRow[]>();
    if (error) throwSupabaseError(error);
    return (data ?? []).map(toRating);
  },
  async createAdminMannerAdjustment() {
    throw Object.assign(new Error("Admin manner adjustment is scheduled for Phase 3."), { statusCode: 501 });
  }
};
