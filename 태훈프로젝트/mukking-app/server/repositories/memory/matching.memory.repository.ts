import type {
  JoinRequest,
  JoinRequestStatus,
  MatchingPost,
  MatchingPostStatus
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  JoinRequestAcceptanceResult,
  MatchingPostFilter,
  MatchingRepository,
  UpdateMatchingPostInput
} from "../interfaces/matching.repository";

function applyPostFilter(post: MatchingPost, filter: MatchingPostFilter): boolean {
  if (filter.authorId && post.authorId !== filter.authorId) {
    return false;
  }

  if (filter.status && post.status !== filter.status) {
    return false;
  }

  if (filter.includeWithoutLocation === false && !post.location) {
    return false;
  }

  return true;
}

export const memoryMatchingRepository: MatchingRepository = {
  async listPosts(filter: MatchingPostFilter = {}) {
    const posts = Array.from(db.posts.values())
      .filter((post) => applyPostFilter(post, filter))
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? posts.length;

    return posts.slice(offset, offset + limit);
  },

  async findPostById(postId) {
    return db.posts.get(postId) ?? null;
  },

  async createPost(authorId, input) {
    const timestamp = nowIso();
    const post: MatchingPost = {
      id: createEntityId("post"),
      authorId,
      restaurantName: input.restaurantName,
      address: input.address,
      location: input.location,
      scheduledAt: input.scheduledAt,
      maxParticipants: input.maxParticipants,
      intro: input.intro,
      status: "open",
      participantIds: [],
      createdAt: timestamp,
      updatedAt: timestamp
    };

    db.posts.set(post.id, post);
    return post;
  },

  async updatePost(postId, input: UpdateMatchingPostInput) {
    const post = db.posts.get(postId);

    if (!post) {
      throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
    }

    const updated: MatchingPost = {
      ...post,
      restaurantName: input.restaurantName ?? post.restaurantName,
      address: input.address ?? post.address,
      location:
        input.location === null ? undefined : input.location ?? post.location,
      scheduledAt: input.scheduledAt ?? post.scheduledAt,
      maxParticipants: input.maxParticipants ?? post.maxParticipants,
      intro: input.intro ?? post.intro,
      status: input.status ?? post.status,
      participantIds: input.participantIds ?? post.participantIds,
      completedAt: input.completedAt ?? post.completedAt,
      updatedAt: nowIso()
    };

    db.posts.set(postId, updated);
    return updated;
  },

  async cancelPost(postId) {
    return this.updatePost(postId, { status: "cancelled" });
  },

  async completePost(postId, completedAt) {
    return this.updatePost(postId, {
      status: "completed",
      completedAt
    });
  },

  async listParticipantIds(postId) {
    const post = db.posts.get(postId);
    return post?.participantIds ?? [];
  },

  async addParticipant(postId, userId) {
    const post = db.posts.get(postId);

    if (!post) {
      throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
    }

    const participantIds = post.participantIds.includes(userId)
      ? post.participantIds
      : [...post.participantIds, userId];

    const nextStatus: MatchingPostStatus =
      participantIds.length >= post.maxParticipants ? "closed" : post.status;

    return this.updatePost(postId, {
      participantIds,
      status: nextStatus
    });
  },

  async findJoinRequestById(requestId) {
    return db.joinRequests.get(requestId) ?? null;
  },

  async findPendingJoinRequest(postId, requesterId) {
    return (
      Array.from(db.joinRequests.values()).find(
        (request) =>
          request.postId === postId &&
          request.requesterId === requesterId &&
          request.status === "pending"
      ) ?? null
    );
  },

  async listJoinRequestsForPost(postId) {
    return Array.from(db.joinRequests.values())
      .filter((request) => request.postId === postId)
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  },

  async createJoinRequest(postId, requesterId) {
    const timestamp = nowIso();
    const request: JoinRequest = {
      id: createEntityId("join"),
      postId,
      requesterId,
      status: "pending",
      createdAt: timestamp,
      updatedAt: timestamp
    };

    db.joinRequests.set(request.id, request);
    return request;
  },

  async updateJoinRequestStatus(requestId, status: JoinRequestStatus) {
    const request = db.joinRequests.get(requestId);

    if (!request) {
      throw Object.assign(new Error("Join request not found."), { statusCode: 404 });
    }

    const updated: JoinRequest = {
      ...request,
      status,
      updatedAt: nowIso()
    };

    db.joinRequests.set(requestId, updated);
    return updated;
  },

  async acceptJoinRequest(requestId): Promise<JoinRequestAcceptanceResult> {
    const request = await this.updateJoinRequestStatus(requestId, "accepted");
    const post = await this.addParticipant(request.postId, request.requesterId);

    return {
      request,
      post
    };
  }
};
