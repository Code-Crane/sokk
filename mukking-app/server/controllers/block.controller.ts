import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  createBlock,
  listMyBlocks,
  revokeBlock
} from "../services/block/block.service";

export async function createBlockController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(await createBlock(authenticatedRequest.userId, request.body));
  } catch (error) {
    next(error);
  }
}

export async function listMyBlocksController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await listMyBlocks(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}

export async function revokeBlockController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await revokeBlock(authenticatedRequest.userId, request.params.userId)
    );
  } catch (error) {
    next(error);
  }
}
