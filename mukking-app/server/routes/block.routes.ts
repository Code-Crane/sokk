import { Router } from "express";
import {
  createBlockController,
  listMyBlocksController,
  revokeBlockController
} from "../controllers/block.controller";
import { authMiddleware } from "../middleware/auth.middleware";
import { blockCreateRateLimit } from "../middleware/rateLimit.middleware";

export const blockRoutes = Router();

blockRoutes.get("/", authMiddleware, listMyBlocksController);
blockRoutes.post("/", authMiddleware, blockCreateRateLimit, createBlockController);
blockRoutes.delete("/:userId", authMiddleware, revokeBlockController);
