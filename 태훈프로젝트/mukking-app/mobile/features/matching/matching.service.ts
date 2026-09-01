import type {
  ChatRoom,
  CreateMatchingPostInput,
  JoinRequest,
  MatchingPost,
  RespondJoinRequestInput
} from "../../../shared/types";
import { apiRequest } from "../../services/api.client";

export interface RespondJoinRequestResponse {
  request: JoinRequest;
  chatRoom?: ChatRoom;
}

export function listMatchingPosts(): Promise<MatchingPost[]> {
  return apiRequest<MatchingPost[]>("/api/matching/posts");
}

export function createMatchingPost(input: CreateMatchingPostInput): Promise<MatchingPost> {
  return apiRequest<MatchingPost>("/api/matching/posts", {
    method: "POST",
    body: JSON.stringify(input)
  });
}

export function completeMatchingPost(postId: string): Promise<MatchingPost> {
  return apiRequest<MatchingPost>(`/api/matching/posts/${postId}/complete`, {
    method: "POST"
  });
}

export function requestJoin(postId: string): Promise<JoinRequest> {
  return apiRequest<JoinRequest>(`/api/matching/posts/${postId}/requests`, {
    method: "POST"
  });
}

export function listJoinRequestsForPost(postId: string): Promise<JoinRequest[]> {
  return apiRequest<JoinRequest[]>(`/api/matching/posts/${postId}/requests`);
}

export function respondToJoinRequest(
  requestId: string,
  input: RespondJoinRequestInput
): Promise<RespondJoinRequestResponse> {
  return apiRequest<RespondJoinRequestResponse>(
    `/api/matching/requests/${requestId}/respond`,
    {
      method: "POST",
      body: JSON.stringify(input)
    }
  );
}
