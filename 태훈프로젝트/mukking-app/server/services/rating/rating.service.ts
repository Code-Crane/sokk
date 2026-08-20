import type {
  MannerRating,
  MannerRatingResult,
  PendingEvaluation,
  SubmitMannerRatingInput
} from "../../../shared/types";
import {
  calculateMannerScoreDelta,
  calculateNextMannerScore,
  DEFAULT_MANNER_SCORE,
  getMannerGrade,
  MIN_MATCHING_MANNER_SCORE
} from "../../../shared/utils/rating";
import { repositories } from "../../repositories";

export { DEFAULT_MANNER_SCORE, getMannerGrade, MIN_MATCHING_MANNER_SCORE };

export async function listPendingEvaluations(
  userId: string
): Promise<PendingEvaluation[]> {
  return repositories.rating.listPendingEvaluations(userId);
}

export async function getPendingEvaluationCount(userId: string): Promise<number> {
  return repositories.rating.countPendingEvaluations(userId);
}

export async function assertNoPendingEvaluations(userId: string): Promise<void> {
  const pendingCount = await getPendingEvaluationCount(userId);

  if (pendingCount > 0) {
    throw Object.assign(
      new Error("Pending meeting evaluations must be submitted before matching again."),
      { statusCode: 403 }
    );
  }
}

export async function assertMannerScoreCanMatch(userId: string): Promise<void> {
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  if (user.mannerScore < MIN_MATCHING_MANNER_SCORE) {
    throw Object.assign(new Error("Manner score is too low to start new matching."), {
      statusCode: 403
    });
  }
}

export async function createPendingEvaluationsForMatch(
  matchId: string,
  participantIds: string[]
): Promise<PendingEvaluation[]> {
  return repositories.rating.createPendingEvaluationsForMatch(matchId, participantIds);
}

export async function submitMannerRating(
  reviewerId: string,
  input: SubmitMannerRatingInput
): Promise<MannerRatingResult> {
  const reviewer = await repositories.users.findById(reviewerId);

  if (!reviewer) {
    throw Object.assign(new Error("Reviewer not found."), { statusCode: 404 });
  }

  if (reviewer.verificationStatus !== "verified") {
    throw Object.assign(new Error("Verification is required to submit ratings."), {
      statusCode: 403
    });
  }

  const pendingEvaluation = await repositories.rating.findPendingEvaluation(
    input.matchId,
    reviewerId,
    input.revieweeId
  );

  if (!pendingEvaluation) {
    throw Object.assign(new Error("No pending evaluation exists for this match."), {
      statusCode: 404
    });
  }

  if (input.score < 1 || input.score > 5 || !Number.isInteger(input.score)) {
    throw Object.assign(new Error("score must be an integer between 1 and 5."), {
      statusCode: 400
    });
  }

  const reviewee = await repositories.users.findById(input.revieweeId);

  if (!reviewee) {
    throw Object.assign(new Error("Reviewee not found."), { statusCode: 404 });
  }

  const previousScore = reviewee.mannerScore;
  const nextScore = calculateNextMannerScore(previousScore, input);
  const nextGrade = getMannerGrade(nextScore);

  await repositories.rating.createMannerRating({
    ...input,
    reviewerId,
    previousScore,
    nextScore,
    delta: calculateMannerScoreDelta(input)
  });

  await repositories.users.updateMannerProfile(reviewee.id, nextScore, nextGrade);
  await repositories.rating.deletePendingEvaluation(pendingEvaluation.id);

  return {
    previousScore,
    nextScore,
    nextGrade,
    remainingPendingEvaluationCount: await getPendingEvaluationCount(reviewerId)
  };
}
