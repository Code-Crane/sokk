import type {
  AuthSession,
  LoginInput,
  PublicUserProfile,
  SignupInput
} from "../../../shared/types";
import type { MfaAssuranceLevel, VerifiedAuthClaims } from "./repository.types";

export interface AuthUserRecord {
  id: string;
  email: string;
  phoneNumber?: string;
  createdAt: string;
}

export interface AuthRepository {
  signup(input: SignupInput): Promise<AuthSession>;
  login(input: LoginInput): Promise<AuthSession>;
  createSession(user: PublicUserProfile): Promise<AuthSession>;
  verifyAccessToken(token: string): Promise<VerifiedAuthClaims>;
  getAuthUser(userId: string): Promise<AuthUserRecord | null>;
  getMfaAssuranceLevel(token: string): Promise<MfaAssuranceLevel>;
}
