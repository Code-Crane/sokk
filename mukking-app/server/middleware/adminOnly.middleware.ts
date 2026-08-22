import type { NextFunction, Request, Response } from "express";
import { environment } from "../config/environment";
import type { AuthenticatedRequest } from "../models/http.types";

function isEmailWhitelisted(email?: string): boolean {
  return Boolean(email && environment.adminEmailWhitelist.includes(email));
}

function isUidWhitelisted(userId?: string): boolean {
  if (environment.adminUidWhitelist.length === 0) {
    return true;
  }

  return Boolean(userId && environment.adminUidWhitelist.includes(userId));
}

export function adminOnlyMiddleware(
  request: Request,
  _response: Response,
  next: NextFunction
): void {
  const authenticatedRequest = request as AuthenticatedRequest;
  const email = authenticatedRequest.user?.email;
  const userId = authenticatedRequest.userId;

  if (!isEmailWhitelisted(email) || !isUidWhitelisted(userId)) {
    next(Object.assign(new Error("Admin whitelist check failed."), { statusCode: 403 }));
    return;
  }

  next();
}

export function requireAdminMfaMiddleware(
  request: Request,
  _response: Response,
  next: NextFunction
): void {
  const authenticatedRequest = request as AuthenticatedRequest;

  if (!environment.requireAdminMfa) {
    next();
    return;
  }

  if (authenticatedRequest.authClaims?.aal !== "aal2") {
    next(
      Object.assign(new Error("Admin MFA aal2 is required for this action."), {
        statusCode: 403
      })
    );
    return;
  }

  next();
}
