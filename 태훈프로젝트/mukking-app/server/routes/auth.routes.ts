import { Router } from "express";
import {
  loginController,
  meController,
  completeMockVerificationController,
  mockVerificationController,
  startMockVerificationController,
  verificationStatusController,
  signupController
} from "../controllers/auth.controller";
import { authMiddleware } from "../middleware/auth.middleware";
import {
  authLoginRateLimit,
  authSignupRateLimit,
  verificationRateLimit
} from "../middleware/rateLimit.middleware";

export const authRoutes = Router();

authRoutes.post("/signup", authSignupRateLimit, signupController);
authRoutes.post("/login", authLoginRateLimit, loginController);
authRoutes.get("/me", authMiddleware, meController);
authRoutes.get(
  "/verification/status",
  authMiddleware,
  verificationRateLimit,
  verificationStatusController
);
authRoutes.post(
  "/verification/mock/start",
  authMiddleware,
  verificationRateLimit,
  startMockVerificationController
);
authRoutes.post(
  "/verification/mock/complete",
  authMiddleware,
  verificationRateLimit,
  completeMockVerificationController
);
authRoutes.post(
  "/verification/mock",
  authMiddleware,
  verificationRateLimit,
  mockVerificationController
);
