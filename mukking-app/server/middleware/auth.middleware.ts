import type { NextFunction, Request, Response } from "express";
import { authenticateToken } from "../services/auth/auth.service";
import type { AuthenticatedRequest } from "../models/http.types";

function readToken(request: Request): string | undefined {
  const authorization = request.header("authorization");

  if (authorization?.startsWith("Bearer ")) {
    return authorization.slice("Bearer ".length);
  }

  return undefined;
}

export async function authMiddleware(
  request: Request,
  _response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const token = readToken(request);

    if (!token) {
      throw Object.assign(new Error("Authentication token is required."), {
        statusCode: 401
      });
    }

    const session = await authenticateToken(token);
    const authenticatedRequest = request as AuthenticatedRequest;

    authenticatedRequest.userId = session.user.id;
    authenticatedRequest.user = session.user;
    authenticatedRequest.authClaims = session.claims;

    next();
  } catch (error) {
    next(error);
  }
}
