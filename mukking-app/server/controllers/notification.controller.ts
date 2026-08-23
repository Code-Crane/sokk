import type { NextFunction, Request, Response } from "express";
import type { NotificationListQuery } from "../../shared/types";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  getUnreadNotificationCount,
  listNotifications,
  markNotificationRead
} from "../services/notification/notification.service";

export async function listNotificationsController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await listNotifications(
        authenticatedRequest.userId,
        request.query as unknown as NotificationListQuery
      )
    );
  } catch (error) {
    next(error);
  }
}

export async function unreadNotificationCountController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await getUnreadNotificationCount(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}

export async function markNotificationReadController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await markNotificationRead(
        authenticatedRequest.userId,
        request.params.notificationId
      )
    );
  } catch (error) {
    next(error);
  }
}
