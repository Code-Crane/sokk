import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import { createReport } from "../services/report/report.service";

export async function createReportController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response
      .status(201)
      .json(await createReport(authenticatedRequest.userId, request.body));
  } catch (error) {
    next(error);
  }
}
