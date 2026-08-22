import type {
  MannerRating,
  PendingEvaluation,
  SubmitMannerRatingInput
} from "../../../shared/types";
import type { RepositoryDateRange, RepositoryListOptions } from "./repository.types";

export type MannerRatingSource =
  | "meeting_review"
  | "admin_adjustment"
  | "system_penalty";

export interface CreatePendingEvaluationInput {
  matchId: string;
  reviewerId: string;
  revieweeId: string;
  createdAt?: string;
}

export interface CreateMannerRatingInput extends SubmitMannerRatingInput {
  reviewerId: string;
  source?: MannerRatingSource;
  previousScore: number;
  nextScore: number;
  delta: number;
}

export interface AdminMannerAdjustmentInput {
  adminActorId: string;
  revieweeId: string;
  previousScore: number;
  nextScore: number;
  delta: number;
  reason: string;
  tags?: string[];
}

export interface MannerRatingFilter
  extends RepositoryDateRange,
    RepositoryListOptions {
  reviewerId?: string;
  revieweeId?: string;
  matchId?: string;
  source?: MannerRatingSource;
}

export interface RatingRepository {
  listPendingEvaluations(userId: string): Promise<PendingEvaluation[]>;
  countPendingEvaluations(userId: string): Promise<number>;
  findPendingEvaluation(
    matchId: string,
    reviewerId: string,
    revieweeId: string
  ): Promise<PendingEvaluation | null>;
  createPendingEvaluation(
    input: CreatePendingEvaluationInput
  ): Promise<PendingEvaluation>;
  createPendingEvaluationsForMatch(
    matchId: string,
    participantIds: string[]
  ): Promise<PendingEvaluation[]>;
  deletePendingEvaluation(evaluationId: string): Promise<void>;
  createMannerRating(input: CreateMannerRatingInput): Promise<MannerRating>;
  listMannerRatings(filter?: MannerRatingFilter): Promise<MannerRating[]>;
  createAdminMannerAdjustment(
    input: AdminMannerAdjustmentInput
  ): Promise<MannerRating>;
}
