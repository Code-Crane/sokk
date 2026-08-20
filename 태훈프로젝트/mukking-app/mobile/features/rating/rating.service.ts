import type {
  MannerRatingResult,
  PendingEvaluation,
  SubmitMannerRatingInput
} from "../../../shared/types";
import { apiRequest } from "../../services/api.client";

export function listPendingEvaluations(): Promise<PendingEvaluation[]> {
  return apiRequest<PendingEvaluation[]>("/api/rating/pending");
}

export function submitMannerRating(
  input: SubmitMannerRatingInput
): Promise<MannerRatingResult> {
  return apiRequest<MannerRatingResult>("/api/rating/reviews", {
    method: "POST",
    body: JSON.stringify(input)
  });
}

