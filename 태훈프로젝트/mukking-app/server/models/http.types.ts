import type { Request } from "express";
import type { PublicUserProfile } from "../../shared/types";
import type { VerifiedAuthClaims } from "../repositories/interfaces/repository.types";

export interface AuthenticatedRequest extends Request {
  userId: string;
  user: PublicUserProfile;
  authClaims: VerifiedAuthClaims;
}
