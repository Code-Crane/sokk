export type MatchingPostStatus = "open" | "closed" | "cancelled" | "completed";
export type JoinRequestStatus = "pending" | "accepted" | "rejected" | "cancelled";

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface MatchingPost {
  id: string;
  authorId: string;
  restaurantName: string;
  address: string;
  location?: GeoPoint;
  scheduledAt: string;
  maxParticipants: number;
  intro: string;
  status: MatchingPostStatus;
  participantIds: string[];
  completedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateMatchingPostInput {
  restaurantName: string;
  address: string;
  location?: GeoPoint;
  scheduledAt: string;
  maxParticipants: number;
  intro: string;
}

export interface JoinRequest {
  id: string;
  postId: string;
  requesterId: string;
  status: JoinRequestStatus;
  createdAt: string;
  updatedAt: string;
}

export interface RespondJoinRequestInput {
  decision: "accepted" | "rejected";
}
