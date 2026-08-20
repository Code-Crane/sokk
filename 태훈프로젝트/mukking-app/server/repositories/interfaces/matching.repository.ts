import type {
  CreateMatchingPostInput,
  JoinRequest,
  JoinRequestStatus,
  MatchingPost,
  MatchingPostStatus
} from "../../../shared/types";
import type { RepositoryListOptions } from "./repository.types";

export interface MatchingPostFilter extends RepositoryListOptions {
  authorId?: string;
  status?: MatchingPostStatus;
  includeWithoutLocation?: boolean;
}

export interface UpdateMatchingPostInput {
  restaurantName?: string;
  address?: string;
  location?: CreateMatchingPostInput["location"] | null;
  scheduledAt?: string;
  maxParticipants?: number;
  intro?: string;
  status?: MatchingPostStatus;
  participantIds?: string[];
  completedAt?: string;
}

export interface JoinRequestAcceptanceResult {
  request: JoinRequest;
  post: MatchingPost;
}

export interface MatchingRepository {
  listPosts(filter?: MatchingPostFilter): Promise<MatchingPost[]>;
  findPostById(postId: string): Promise<MatchingPost | null>;
  createPost(
    authorId: string,
    input: CreateMatchingPostInput
  ): Promise<MatchingPost>;
  updatePost(postId: string, input: UpdateMatchingPostInput): Promise<MatchingPost>;
  cancelPost(postId: string, actorId: string): Promise<MatchingPost>;
  completePost(postId: string, completedAt: string): Promise<MatchingPost>;
  listParticipantIds(postId: string): Promise<string[]>;
  addParticipant(postId: string, userId: string): Promise<MatchingPost>;
  findJoinRequestById(requestId: string): Promise<JoinRequest | null>;
  findPendingJoinRequest(
    postId: string,
    requesterId: string
  ): Promise<JoinRequest | null>;
  listJoinRequestsForPost(postId: string): Promise<JoinRequest[]>;
  createJoinRequest(postId: string, requesterId: string): Promise<JoinRequest>;
  updateJoinRequestStatus(
    requestId: string,
    status: JoinRequestStatus
  ): Promise<JoinRequest>;
  acceptJoinRequest(requestId: string): Promise<JoinRequestAcceptanceResult>;
}
