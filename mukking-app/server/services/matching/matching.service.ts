import type {
  ChatRoom,
  CreateMatchingPostInput,
  JoinRequest,
  MatchingPost,
  RespondJoinRequestInput
} from "../../../shared/types";
import { isFutureIso, nowIso } from "../../../shared/utils/date";
import { repositories } from "../../repositories";
import { awardPetXpBestEffort } from "../pet/pet.service";
import { assertCanUseMatching, assertVerifiedUser } from "../auth/auth.service";
import { assertNoActiveBlockBetween } from "../block/block.service";
import { ensureChatForAcceptedPost } from "../chat/chat.service";
import { createFavoriteRestaurantPartyNotifications, notifyJoinEvent } from "../notification/notification.service";
import { createPendingEvaluationsForMatch } from "../rating/rating.service";

export interface RespondJoinRequestResult {
  request: JoinRequest;
  chatRoom?: ChatRoom;
}

export async function listMatchingPosts(): Promise<MatchingPost[]> {
  return repositories.matching.listPosts();
}

export async function createMatchingPost(
  authorId: string,
  input: CreateMatchingPostInput
): Promise<MatchingPost> {
  await assertCanUseMatching(authorId);

  if (input.restaurantId) {
    const restaurant = await repositories.restaurants.findById(input.restaurantId);

    if (!restaurant) {
      throw Object.assign(new Error("Restaurant not found."), { statusCode: 404 });
    }
  }

  if (!input.restaurantName || !input.address || !input.scheduledAt || !input.intro) {
    throw Object.assign(new Error("restaurantName, address, scheduledAt, and intro are required."), {
      statusCode: 400
    });
  }

  if (!isFutureIso(input.scheduledAt)) {
    throw Object.assign(new Error("scheduledAt must be in the future."), {
      statusCode: 400
    });
  }

  if (input.maxParticipants < 1 || input.maxParticipants > 8) {
    throw Object.assign(new Error("maxParticipants must be between 1 and 8."), {
      statusCode: 400
    });
  }

  const post = await repositories.matching.createPost(authorId, input);

  if (post.restaurantId) {
    try {
      await createFavoriteRestaurantPartyNotifications(post);
    } catch {
      console.error("[notification] Favorite restaurant party notification creation failed.", {
        matchingPostId: post.id
      });
    }
  }

  return post;
}

export async function createJoinRequest(
  userId: string,
  postId: string
): Promise<JoinRequest> {
  await assertCanUseMatching(userId);

  const post = await repositories.matching.findPostById(postId);

  if (!post) {
    throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
  }

  if (post.status !== "open") {
    throw Object.assign(new Error("This matching post is not open."), { statusCode: 409 });
  }

  if (post.authorId === userId) {
    throw Object.assign(new Error("You cannot request to join your own post."), {
      statusCode: 400
    });
  }

  await assertNoActiveBlockBetween(userId, post.authorId, "matching");

  if (post.participantIds.includes(userId)) {
    throw Object.assign(new Error("You are already accepted for this post."), {
      statusCode: 409
    });
  }

  const duplicate = await repositories.matching.findPendingJoinRequest(postId, userId);

  if (duplicate) {
    throw Object.assign(new Error("A pending join request already exists."), {
      statusCode: 409
    });
  }

  const request = await repositories.matching.createJoinRequest(postId, userId);
  await notifyJoinEvent(post, request, "join_request_received");
  return request;
}

export async function listJoinRequestsForPost(
  authorId: string,
  postId: string
): Promise<JoinRequest[]> {
  await assertVerifiedUser(authorId);

  const post = await repositories.matching.findPostById(postId);

  if (!post) {
    throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
  }

  if (post.authorId !== authorId) {
    throw Object.assign(new Error("Only the post author can view join requests."), {
      statusCode: 403
    });
  }

  return repositories.matching.listJoinRequestsForPost(postId);
}

export async function getMyJoinRequest(
  requesterId: string,
  postId: string
): Promise<JoinRequest | null> {
  return repositories.matching.findLatestJoinRequestForRequester(
    postId,
    requesterId
  );
}

export async function respondToJoinRequest(
  authorId: string,
  requestId: string,
  input: RespondJoinRequestInput
): Promise<RespondJoinRequestResult> {
  await assertVerifiedUser(authorId);

  const request = await repositories.matching.findJoinRequestById(requestId);

  if (!request) {
    throw Object.assign(new Error("Join request not found."), { statusCode: 404 });
  }

  const post = await repositories.matching.findPostById(request.postId);

  if (!post) {
    throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
  }

  if (post.authorId !== authorId) {
    throw Object.assign(new Error("Only the post author can respond to join requests."), {
      statusCode: 403
    });
  }

  if (input.decision === "accepted") {
    if (request.status === "accepted") {
      return {
        request,
        chatRoom: await ensureChatForAcceptedPost(post)
      };
    }

    if (request.status !== "pending") {
      throw Object.assign(new Error("This join request has already been handled."), {
        statusCode: 409
      });
    }

    await assertNoActiveBlockBetween(authorId, request.requesterId, "matching");
    await assertNoActiveBlockBetween(authorId, request.requesterId, "chat");
  } else if (request.status !== "pending") {
    throw Object.assign(new Error("This join request has already been handled."), {
      statusCode: 409
    });
  }

  let chatRoom: ChatRoom | undefined;
  let updatedRequest: JoinRequest;

  if (input.decision === "accepted") {
    let result: { request: JoinRequest; post: MatchingPost };

    try {
      result = await repositories.matching.acceptJoinRequest(request.id);
    } catch (error) {
      const latestRequest = await repositories.matching.findJoinRequestById(request.id);

      if (latestRequest?.status !== "accepted") throw error;

      const latestPost = await repositories.matching.findPostById(latestRequest.postId);
      if (!latestPost) throw error;

      return {
        request: latestRequest,
        chatRoom: await ensureChatForAcceptedPost(latestPost)
      };
    }

    updatedRequest = result.request;
    await notifyJoinEvent(result.post, updatedRequest, "join_request_accepted");
    chatRoom = await ensureChatForAcceptedPost(result.post);
  } else {
    updatedRequest = await repositories.matching.updateJoinRequestStatus(
      request.id,
      input.decision
    );
    if (updatedRequest.status === "rejected") {
      await notifyJoinEvent(post, updatedRequest, "join_request_rejected");
    }
  }

  return {
    request: updatedRequest,
    chatRoom
  };
}

export async function completeMatchingPost(
  userId: string,
  postId: string
): Promise<MatchingPost> {
  await assertVerifiedUser(userId);

  const post = await repositories.matching.findPostById(postId);

  if (!post) {
    throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
  }

  const participantIds = [post.authorId, ...post.participantIds];

  if (!participantIds.includes(userId)) {
    throw Object.assign(new Error("Only participants can complete this meeting."), {
      statusCode: 403
    });
  }

  if (post.status !== "closed") {
    throw Object.assign(new Error("Only closed matched posts can be completed."), {
      statusCode: 409
    });
  }

  const timestamp = nowIso();
  const completedPost = await repositories.matching.completePost(post.id, timestamp);
  await createPendingEvaluationsForMatch(post.id, participantIds);
  for (const participantId of new Set(participantIds)) {
    await awardPetXpBestEffort(participantId,
      participantId === post.authorId ? "hosted_matching_completed" : "matching_completed", post.id);
  }

  return completedPost;
}
