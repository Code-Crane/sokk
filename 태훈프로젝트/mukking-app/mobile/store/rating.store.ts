import { create } from "zustand";
import type { PendingEvaluation, SubmitMannerRatingInput } from "../../shared/types";
import {
  listPendingEvaluations,
  submitMannerRating
} from "../features/rating/rating.service";

interface RatingState {
  pendingEvaluations: PendingEvaluation[];
  isLoading: boolean;
  error: string | null;
  loadPendingEvaluations: () => Promise<void>;
  submitRating: (input: SubmitMannerRatingInput) => Promise<void>;
}

export const useRatingStore = create<RatingState>((set, get) => ({
  pendingEvaluations: [],
  isLoading: false,
  error: null,
  loadPendingEvaluations: async () => {
    set({ isLoading: true, error: null });

    try {
      const pendingEvaluations = await listPendingEvaluations();
      set({ pendingEvaluations, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to load evaluations.",
        isLoading: false
      });
    }
  },
  submitRating: async (input) => {
    set({ isLoading: true, error: null });

    try {
      await submitMannerRating(input);
      await get().loadPendingEvaluations();
      set({ isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to submit rating.",
        isLoading: false
      });
    }
  }
}));

