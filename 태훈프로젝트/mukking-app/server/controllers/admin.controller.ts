import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";

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
