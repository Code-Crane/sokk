import type {
  ChatMessage,
  ChatRoom,
  JoinRequest,
  MatchingPost,
  MannerRating,
  PendingEvaluation,
  UserNotification,
  UserAccount,
  UserReport,
  VerificationClaim
} from "../../shared/types";

export const db = {
  users: new Map<string, UserAccount>(),
  verificationClaims: new Map<string, VerificationClaim>(),
  posts: new Map<string, MatchingPost>(),
  joinRequests: new Map<string, JoinRequest>(),
  chatRooms: new Map<string, ChatRoom>(),
  chatMessages: new Map<string, ChatMessage[]>(),
  pendingEvaluations: new Map<string, PendingEvaluation>(),
  mannerRatings: new Map<string, MannerRating>(),
  notifications: new Map<string, UserNotification>(),
  reports: new Map<string, UserReport>(),
  restaurants: new Map<string, import("../../shared/types").Restaurant>(),
  restaurantFavorites: new Map<
    string,
    import("../../shared/types").RestaurantFavorite
  >()
};
