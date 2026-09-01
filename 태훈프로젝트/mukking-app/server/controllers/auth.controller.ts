import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import { login, signup } from "../services/auth/auth.service";
import {
  completeMockVerification,
  getVerificationStatusSnapshot,
  startMockVerification,
  submitMockVerification
} from "../services/verification/verification.service";

export async function signupController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.status(201).json(await signup(request.body));
  } catch (error) {
    next(error);
  }
}

export async function loginController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.json(await login(request.body));
  } catch (error) {
    next(error);
  }
}

export function meController(
  request: Request,
  response: Response,
  next: NextFunction
): void {
  try {
    response.json((request as AuthenticatedRequest).user);
  } catch (error) {
    next(error);
  }
}

export async function mockVerificationController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await submitMockVerification(authenticatedRequest.userId, request.body)
    );
  } catch (error) {
    next(error);
  }
}

export async function verificationStatusController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await getVerificationStatusSnapshot(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}

export async function startMockVerificationController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await startMockVerification(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}

export async function completeMockVerificationController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await completeMockVerification(authenticatedRequest.userId, request.body)
    );
  } catch (error) {
    next(error);
  }
}
