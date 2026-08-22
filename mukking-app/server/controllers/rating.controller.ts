import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  listPendingEvaluations,
  submitMannerRating
} from "../services/rating/rating.service";

export async function listPendingEvaluationsController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await listPendingEvaluations(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}

export async function submitMannerRatingController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(await submitMannerRating(authenticatedRequest.userId, request.body));
  } catch (error) {
    next(error);
  }
}
