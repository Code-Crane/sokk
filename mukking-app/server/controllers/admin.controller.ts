import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import { repositories } from "../repositories";
import {
  getReportForAdmin,
  listReportsForAdmin,
  updateReportForAdmin
} from "../services/report/report.service";
import {
  createSanction,
  listSanctions,
  revokeSanction
} from "../services/sanction/sanction.service";

export function adminSecurityStatusController(
  request: Request,
  response: Response,
  next: NextFunction
): void {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;

    response.json({
      ok: true,
      userId: authenticatedRequest.userId,
      email: authenticatedRequest.user.email,
      aal: authenticatedRequest.authClaims.aal ?? "aal1",
      authProvider: authenticatedRequest.authClaims.authProvider,
      mfaVerified: authenticatedRequest.authClaims.aal === "aal2"
    });
  } catch (error) {
    next(error);
  }
}

export function adminSensitiveSecurityStatusController(
  request: Request,
  response: Response,
  next: NextFunction
): void {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;

    response.json({
      ok: true,
      userId: authenticatedRequest.userId,
      email: authenticatedRequest.user.email,
      aal: authenticatedRequest.authClaims.aal ?? "aal1",
      mfaVerified: authenticatedRequest.authClaims.aal === "aal2"
    });
  } catch (error) {
    next(error);
  }
}

export async function listAdminReportsController(
  _request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.json(await listReportsForAdmin());
  } catch (error) {
    next(error);
  }
}

export async function getAdminReportController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.json(await getReportForAdmin(request.params.reportId));
  } catch (error) {
    next(error);
  }
}

export async function updateAdminReportController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    const report = await updateReportForAdmin(authenticatedRequest.userId, {
      reportId: request.params.reportId,
      ...request.body
    });

    await repositories.admin.createAuditLog({
      actorId: authenticatedRequest.userId,
      actorEmail: authenticatedRequest.user.email,
      action: "report.updated",
      targetType: "report",
      targetId: report.id,
      aal: authenticatedRequest.authClaims.aal,
      reason: request.body?.adminNote,
      metadata: {
        reportedUserId: report.reportedUserId,
        status: report.status,
        actionTaken: report.actionTaken
      }
    });

    response.json(report);
  } catch (error) {
    next(error);
  }
}

export async function listAdminSanctionsController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.json(await listSanctions({ userId: request.query.userId as string }));
  } catch (error) {
    next(error);
  }
}

export async function createAdminSanctionController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(await createSanction(authenticatedRequest.userId, request.body));
  } catch (error) {
    next(error);
  }
}

export async function revokeAdminSanctionController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await revokeSanction(
        authenticatedRequest.userId,
        request.params.sanctionId,
        request.body?.reason
      )
    );
  } catch (error) {
    next(error);
  }
}

export async function listAdminAuditLogsController(
  _request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.json(await repositories.admin.listAuditLogs());
  } catch (error) {
    next(error);
  }
}
