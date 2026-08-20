import type { MannerRating, PendingEvaluation } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  AdminMannerAdjustmentInput,
  CreateMannerRatingInput,
  CreatePendingEvaluationInput,
  MannerRatingFilter,
  RatingRepository
} from "../interfaces/rating.repository";

function filterRating(rating: MannerRating, filter: MannerRatingFilter): boolean {
  if (filter.reviewerId && rating.reviewerId !== filter.reviewerId) {
    return false;
  }

  if (filter.revieweeId && rating.revieweeId !== filter.revieweeId) {
    return false;
  }

  if (filter.matchId && rating.matchId !== filter.matchId) {
    return false;
  }

  if (filter.from && rating.createdAt < filter.from) {
    return false;
  }

  if (filter.to && rating.createdAt > filter.to) {
    return false;
  }

  return true;
}

export const memoryRatingRepository: RatingRepository = {
  async listPendingEvaluations(userId) {
    return Array.from(db.pendingEvaluations.values())
      .filter((evaluation) => evaluation.reviewerId === userId)
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  },

  async countPendingEvaluations(userId) {
    return (await this.listPendingEvaluations(userId)).length;
  },

  async findPendingEvaluation(matchId, reviewerId, revieweeId) {
    return (
      Array.from(db.pendingEvaluations.values()).find(
        (evaluation) =>
          evaluation.matchId === matchId &&
          evaluation.reviewerId === reviewerId &&
          evaluation.revieweeId === revieweeId
      ) ?? null
    );
  },

  async createPendingEvaluation(input: CreatePendingEvaluationInput) {
    const duplicate = await this.findPendingEvaluation(
      input.matchId,
      input.reviewerId,
      input.revieweeId
    );

    if (duplicate) {
      return duplicate;
    }

    const evaluation: PendingEvaluation = {
      id: createEntityId("eval"),
      matchId: input.matchId,
      reviewerId: input.reviewerId,
      revieweeId: input.revieweeId,
      createdAt: input.createdAt ?? nowIso()
    };

    db.pendingEvaluations.set(evaluation.id, evaluation);
    return evaluation;
  },

  async createPendingEvaluationsForMatch(matchId, participantIds) {
    const timestamp = nowIso();
    const pendingEvaluations: PendingEvaluation[] = [];

    for (const reviewerId of participantIds) {
      for (const revieweeId of participantIds.filter((id) => id !== reviewerId)) {
        const evaluation = await this.createPendingEvaluation({
          matchId,
          reviewerId,
          revieweeId,
          createdAt: timestamp
        });

        if (evaluation.createdAt === timestamp) {
          pendingEvaluations.push(evaluation);
        }
      }
    }

    return pendingEvaluations;
  },

  async deletePendingEvaluation(evaluationId) {
    db.pendingEvaluations.delete(evaluationId);
  },

  async createMannerRating(input: CreateMannerRatingInput) {
    const rating: MannerRating = {
      id: createEntityId("rating"),
      matchId: input.matchId,
      reviewerId: input.reviewerId,
      revieweeId: input.revieweeId,
      score: input.score,
      tags: input.tags,
      createdAt: nowIso()
    };

    db.mannerRatings.set(rating.id, rating);
    return rating;
  },

  async listMannerRatings(filter: MannerRatingFilter = {}) {
    const ratings = Array.from(db.mannerRatings.values())
      .filter((rating) => filterRating(rating, filter))
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? ratings.length;

    return ratings.slice(offset, offset + limit);
  },

  async createAdminMannerAdjustment(_input: AdminMannerAdjustmentInput) {
    throw Object.assign(new Error("Admin manner adjustment is scheduled for Phase 3."), {
      statusCode: 501
    });
  }
};
