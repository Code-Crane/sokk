import { Router } from "express";
import {
  createJoinRequestController,
  completeMatchingPostController,
  createMatchingPostController,
  getMyJoinRequestController,
  listJoinRequestsForPostController,
  listMatchingPostsController,
  respondToJoinRequestController
} from "../controllers/matching.controller";
import { authMiddleware } from "../middleware/auth.middleware";
import { matchingRequestRateLimit } from "../middleware/rateLimit.middleware";

export const matchingRoutes = Router();

matchingRoutes.get("/posts", listMatchingPostsController);
matchingRoutes.post("/posts", authMiddleware, createMatchingPostController);
matchingRoutes.post(
  "/posts/:postId/requests",
  authMiddleware,
  matchingRequestRateLimit,
  createJoinRequestController
);
matchingRoutes.post("/posts/:postId/complete", authMiddleware, completeMatchingPostController);
matchingRoutes.get(
  "/posts/:postId/request/me",
  authMiddleware,
  getMyJoinRequestController
);
matchingRoutes.get(
  "/posts/:postId/requests",
  authMiddleware,
  listJoinRequestsForPostController
);
matchingRoutes.post(
  "/requests/:requestId/respond",
  authMiddleware,
  respondToJoinRequestController
);
