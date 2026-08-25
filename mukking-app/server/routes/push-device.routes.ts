import { Router } from "express";
import {
  disablePushDeviceController,
  registerPushDeviceController
} from "../controllers/push-device.controller";
import { authMiddleware } from "../middleware/auth.middleware";
import { pushDeviceRateLimit } from "../middleware/rateLimit.middleware";

export const pushDeviceRoutes = Router();

pushDeviceRoutes.use(authMiddleware);
pushDeviceRoutes.post("/", pushDeviceRateLimit, registerPushDeviceController);
pushDeviceRoutes.delete(
  "/:deviceId",
  pushDeviceRateLimit,
  disablePushDeviceController
);
