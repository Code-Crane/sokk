import { Router } from "express";
import {
  adminSecurityStatusController,
  adminSensitiveSecurityStatusController
} from "../controllers/admin.controller";
import { adminOnlyMiddleware, requireAdminMfaMiddleware } from "../middleware/adminOnly.middleware";
import { authMiddleware } from "../middleware/auth.middleware";
import {
  adminAuthRateLimit,
  adminSensitiveRateLimit
} from "../middleware/rateLimit.middleware";

export const adminRoutes = Router();

adminRoutes.get(
  "/security-status",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  adminSecurityStatusController
);

adminRoutes.get(
  "/sensitive-security-status",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  requireAdminMfaMiddleware,
  adminSensitiveRateLimit,
  adminSensitiveSecurityStatusController
);
