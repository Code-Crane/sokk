import type { MannerGrade } from "./rating.types";
import type { VerificationStatus } from "./verification.types";

export interface PublicUserProfile {
  id: string;
  nickname: string;
  email: string;
  verificationStatus: VerificationStatus;
  mannerScore: number;
  mannerGrade: MannerGrade;
  pendingEvaluationCount: number;
  createdAt: string;
}

export interface UserAccount extends Omit<PublicUserProfile, "pendingEvaluationCount"> {
  phoneNumber: string;
}

export interface SignupInput {
  email: string;
  nickname: string;
  phoneNumber: string;
}

export interface LoginInput {
  email: string;
}

export interface AuthSession {
  token: string;
  user: PublicUserProfile;
}
