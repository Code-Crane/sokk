import type { NextFunction, Request, Response } from "express";
import type { RegisterPushDeviceInput } from "../../shared/types";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  disablePushDevice,
  registerPushDevice
} from "../services/push/push-device.service";

export async function registerPushDeviceController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.status(201).json(
      await registerPushDevice(
        authenticatedRequest.userId,
        request.body as RegisterPushDeviceInput
      )
    );
  } catch (error) {
    next(error);
  }
}

export async function disablePushDeviceController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await disablePushDevice(
        authenticatedRequest.userId,
        request.params.deviceId
      )
    );
  } catch (error) {
    next(error);
  }
}
