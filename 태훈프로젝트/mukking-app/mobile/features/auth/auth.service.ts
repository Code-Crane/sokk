import type { AuthSession, LoginInput, PublicUserProfile, SignupInput } from "../../../shared/types";
import { apiRequest } from "../../services/api.client";

export function signup(input: SignupInput): Promise<AuthSession> {
  return apiRequest<AuthSession>("/api/auth/signup", {
    method: "POST",
    body: JSON.stringify(input)
  });
}

export function login(input: LoginInput): Promise<AuthSession> {
  return apiRequest<AuthSession>("/api/auth/login", {
    method: "POST",
    body: JSON.stringify(input)
  });
}

export function getMe(): Promise<PublicUserProfile> {
  return apiRequest<PublicUserProfile>("/api/auth/me");
}

