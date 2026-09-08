import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware";
import type { AuthenticatedRequest } from "../models/http.types";
import { getMyPet, selectPet } from "../services/pet/pet.service";
export const petRoutes = Router();
petRoutes.use(authMiddleware);
petRoutes.get("/me", async (req, res, next) => {
  try { res.json(await getMyPet((req as AuthenticatedRequest).userId)); } catch (error) { next(error); }
});
petRoutes.post("/me", async (req, res, next) => {
  try { res.status(201).json(await selectPet((req as AuthenticatedRequest).userId, req.body)); } catch (error) { next(error); }
});
