import { Router } from "express";
import { createReportController } from "../controllers/report.controller";
import { authMiddleware } from "../middleware/auth.middleware";
import { reportCreateRateLimit } from "../middleware/rateLimit.middleware";

export const reportRoutes = Router();

reportRoutes.post("/", authMiddleware, reportCreateRateLimit, createReportController);
