import { Router } from "express";
import {
  listPendingEvaluationsController,
  submitMannerRatingController
} from "../controllers/rating.controller";
import { authMiddleware } from "../middleware/auth.middleware";

export const ratingRoutes = Router();

ratingRoutes.get("/pending", authMiddleware, listPendingEvaluationsController);
ratingRoutes.post("/reviews", authMiddleware, submitMannerRatingController);

