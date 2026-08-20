import type { MannerGrade, SubmitMannerRatingInput } from "../types/rating.types";

export const DEFAULT_MANNER_SCORE = 36.5;
export const MIN_MATCHING_MANNER_SCORE = 30;
export const MIN_MANNER_SCORE = 0;
export const MAX_MANNER_SCORE = 50;

const scoreDeltas: Record<SubmitMannerRatingInput["score"], number> = {
  1: -3,
  2: -1.5,
  3: 0,
  4: 0.8,
  5: 1.5
};

const tagDeltas: Record<string, number> = {
  on_time: 0.4,
  kind: 0.4,
  good_conversation: 0.3,
  clean: 0.2,
  no_show: -5,
  rude: -2,
  unsafe: -8
};

function clampScore(score: number): number {
  return Math.min(MAX_MANNER_SCORE, Math.max(MIN_MANNER_SCORE, score));
}

export function getMannerGrade(score: number): MannerGrade {
  if (score >= 45) {
    return "mukking";
  }

  if (score >= 40) {
    return "foodie";
  }

  if (score >= 35) {
    return "regular";
  }

  return "sprout";
}

export function calculateMannerScoreDelta(input: SubmitMannerRatingInput): number {
  const tagDelta = input.tags.reduce(
    (total, tag) => total + (tagDeltas[tag] ?? 0),
    0
  );

  return scoreDeltas[input.score] + tagDelta;
}

export function calculateNextMannerScore(
  currentScore: number,
  input: SubmitMannerRatingInput
): number {
  return Number((clampScore(currentScore + calculateMannerScoreDelta(input))).toFixed(1));
}

