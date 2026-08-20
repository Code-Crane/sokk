export interface RepositoryListOptions {
  limit?: number;
  offset?: number;
}

export interface RepositoryDateRange {
  from?: string;
  to?: string;
}

export interface RepositoryActorContext {
  actorId: string;
  actorEmail?: string;
  ipHash?: string;
  userAgentHash?: string;
}

export type AccountStatus = "active" | "suspended" | "banned" | "deleted";

export type MfaAssuranceLevel = "aal1" | "aal2";

export interface VerifiedAuthClaims {
  userId: string;
  email?: string;
  aal?: MfaAssuranceLevel;
  authProvider?: "signed_mock" | "supabase";
  expiresAt?: string;
  rawClaims?: Record<string, unknown>;
}

export interface RepositoryMutationMetadata {
  reason?: string;
  actorId?: string;
  createdAt?: string;
  metadata?: Record<string, unknown>;
}
