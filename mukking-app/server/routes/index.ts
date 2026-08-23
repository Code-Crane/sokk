import { Router } from "express";
import { adminRoutes } from "./admin.routes";
import { authRoutes } from "./auth.routes";
import { blockRoutes } from "./block.routes";
import { chatRoutes } from "./chat.routes";
import { healthRoutes } from "./health.routes";
import { matchingRoutes } from "./matching.routes";
import { notificationRoutes } from "./notification.routes";
import { ratingRoutes } from "./rating.routes";
import { reportRoutes } from "./report.routes";
import { restaurantRoutes } from "./restaurant.routes";

export const routes = Router();

routes.use("/health", healthRoutes);
routes.use("/admin", adminRoutes);
routes.use("/auth", authRoutes);
routes.use("/blocks", blockRoutes);
routes.use("/matching", matchingRoutes);
routes.use("/notifications", notificationRoutes);
routes.use("/chat", chatRoutes);
routes.use("/rating", ratingRoutes);
routes.use("/reports", reportRoutes);
routes.use("/restaurants", restaurantRoutes);
