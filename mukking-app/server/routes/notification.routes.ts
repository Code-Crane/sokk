import { Router } from "express";
import {
  listNotificationsController,
  markNotificationReadController,
  unreadNotificationCountController
} from "../controllers/notification.controller";
import { authMiddleware } from "../middleware/auth.middleware";

export const notificationRoutes = Router();

notificationRoutes.use(authMiddleware);
notificationRoutes.get("/", listNotificationsController);
notificationRoutes.get("/unread-count", unreadNotificationCountController);
notificationRoutes.patch("/:notificationId/read", markNotificationReadController);
