import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  listChatRooms,
  listMessages,
  sendMessage
} from "../services/chat/chat.service";

export async function listChatRoomsController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await listChatRooms(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}

export async function listMessagesController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await listMessages(authenticatedRequest.userId, request.params.roomId)
    );
  } catch (error) {
    next(error);
  }
}

export async function sendMessageController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(
        await sendMessage(authenticatedRequest.userId, request.params.roomId, request.body)
      );
  } catch (error) {
    next(error);
  }
}
