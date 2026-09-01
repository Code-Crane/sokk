import type { MannerGrade } from "../../../shared/types";
import {
  calculateNextMannerScore,
  getMannerGrade as getSharedMannerGrade,
  MIN_MATCHING_MANNER_SCORE
} from "../../../shared/utils/rating";

// Display-only helpers. The server is the final authority for score mutations.
export const mannerGradeLabels: Record<MannerGrade, string> = {
  sprout: "새싹먹킹",
  regular: "단골먹킹",
  foodie: "맛잘알먹킹",
  mukking: "먹킹"
};

export function calculateMannerGrade(score: number): MannerGrade {
  return getSharedMannerGrade(score);
}

export function getMannerGradeLabel(score: number): string {
  return mannerGradeLabels[calculateMannerGrade(score)];
}

export function canDisplayUserAsMatchable(
  verificationStatus: string,
  pendingEvaluationCount: number,
  mannerScore: number
): boolean {
  return (
    verificationStatus === "verified" &&
    pendingEvaluationCount === 0 &&
    mannerScore >= MIN_MATCHING_MANNER_SCORE
  );
}

export { calculateNextMannerScore };
