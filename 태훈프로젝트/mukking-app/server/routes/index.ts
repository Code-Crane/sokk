import { Router } from "express";
import { adminRoutes } from "./admin.routes";
import { authRoutes } from "./auth.routes";
import { chatRoutes } from "./chat.routes";
import { healthRoutes } from "./health.routes";
import { matchingRoutes } from "./matching.routes";
import { ratingRoutes } from "./rating.routes";

export const routes = Router();

routes.use("/health", healthRoutes);
routes.use("/admin", adminRoutes);
routes.use("/auth", authRoutes);
routes.use("/matching", matchingRoutes);
routes.use("/chat", chatRoutes);
routes.use("/rating", ratingRoutes);
