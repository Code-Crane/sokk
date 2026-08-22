export type MannerGrade =
  | "sprout"
  | "regular"
  | "foodie"
  | "mukking";

export interface MannerRatingInput {
  score: 1 | 2 | 3 | 4 | 5;
  tags: string[];
  reviewerId: string;
  revieweeId: string;
  matchId: string;
}

export interface MannerRatingResult {
  previousScore: number;
  nextScore: number;
  nextGrade: MannerGrade;
  remainingPendingEvaluationCount: number;
}

export interface PendingEvaluation {
  id: string;
  matchId: string;
  reviewerId: string;
  revieweeId: string;
  createdAt: string;
}

export interface SubmitMannerRatingInput {
  matchId: string;
  revieweeId: string;
  score: 1 | 2 | 3 | 4 | 5;
  tags: string[];
}

export interface MannerRating {
  id: string;
  matchId: string;
  reviewerId: string;
  revieweeId: string;
  score: 1 | 2 | 3 | 4 | 5;
  tags: string[];
  createdAt: string;
}
