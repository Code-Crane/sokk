import { Router } from "express";
import {
  createAdminSanctionController,
  getAdminReportController,
  listAdminAuditLogsController,
  listAdminReportsController,
  listAdminSanctionsController,
  adminSecurityStatusController,
  adminSensitiveSecurityStatusController,
  revokeAdminSanctionController,
  updateAdminReportController
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

adminRoutes.get(
  "/reports",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  listAdminReportsController
);

adminRoutes.get(
  "/reports/:reportId",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  getAdminReportController
);

adminRoutes.patch(
  "/reports/:reportId",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  requireAdminMfaMiddleware,
  adminSensitiveRateLimit,
  updateAdminReportController
);

adminRoutes.get(
  "/sanctions",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  listAdminSanctionsController
);

adminRoutes.post(
  "/sanctions",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  requireAdminMfaMiddleware,
  adminSensitiveRateLimit,
  createAdminSanctionController
);

adminRoutes.post(
  "/sanctions/:sanctionId/revoke",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  requireAdminMfaMiddleware,
  adminSensitiveRateLimit,
  revokeAdminSanctionController
);

adminRoutes.get(
  "/audit-logs",
  authMiddleware,
  adminAuthRateLimit,
  adminOnlyMiddleware,
  listAdminAuditLogsController
);
