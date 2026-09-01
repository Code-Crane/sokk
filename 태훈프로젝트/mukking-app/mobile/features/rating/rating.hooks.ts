import { useEffect } from "react";
import { useAuthStore } from "../../store/auth.store";
import { useRatingStore } from "../../store/rating.store";

export function usePendingEvaluations() {
  const user = useAuthStore((state) => state.user);
  const refreshMe = useAuthStore((state) => state.refreshMe);
  const pendingEvaluations = useRatingStore((state) => state.pendingEvaluations);
  const isLoading = useRatingStore((state) => state.isLoading);
  const error = useRatingStore((state) => state.error);
  const loadPendingEvaluations = useRatingStore(
    (state) => state.loadPendingEvaluations
  );
  const submitRatingRequest = useRatingStore((state) => state.submitRating);

  useEffect(() => {
    if (user?.verificationStatus === "verified") {
      void loadPendingEvaluations();
    }
  }, [loadPendingEvaluations, user?.verificationStatus]);

  const submitRating: typeof submitRatingRequest = async (input) => {
    await submitRatingRequest(input);
    await refreshMe();
  };

  return {
    pendingEvaluations,
    isLoading,
    error,
    submitRating,
    refresh: loadPendingEvaluations
  };
}
