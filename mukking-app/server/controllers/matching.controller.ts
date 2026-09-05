import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  createJoinRequest,
  completeMatchingPost,
  createMatchingPost,
  getMyJoinRequest,
  listJoinRequestsForPost,
  listMatchingPosts,
  respondToJoinRequest
} from "../services/matching/matching.service";

export async function listMatchingPostsController(
  _request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.json(await listMatchingPosts());
  } catch (error) {
    next(error);
  }
}

export async function createMatchingPostController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(await createMatchingPost(authenticatedRequest.userId, request.body));
  } catch (error) {
    next(error);
  }
}

export async function createJoinRequestController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(await createJoinRequest(authenticatedRequest.userId, request.params.postId));
  } catch (error) {
    next(error);
  }
}

export async function getMyJoinRequestController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await getMyJoinRequest(authenticatedRequest.userId, request.params.postId)
    );
  } catch (error) {
    next(error);
  }
}

export async function listJoinRequestsForPostController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await listJoinRequestsForPost(authenticatedRequest.userId, request.params.postId)
    );
  } catch (error) {
    next(error);
  }
}

export async function respondToJoinRequestController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await respondToJoinRequest(
        authenticatedRequest.userId,
        request.params.requestId,
        request.body
      )
    );
  } catch (error) {
    next(error);
  }
}

export async function completeMatchingPostController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await completeMatchingPost(authenticatedRequest.userId, request.params.postId)
    );
  } catch (error) {
    next(error);
  }
}
