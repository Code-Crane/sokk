import type { RepositoryDateRange, RepositoryListOptions } from "./repository.types";

export type SanctionType =
  | "warning"
  | "matching_suspension"
  | "chat_suspension"
  | "temporary_suspension"
  | "permanent_ban";

export type SanctionStatus = "active" | "expired" | "revoked";

export interface UserSanction {
  id: string;
  userId: string;
  createdBy?: string;
  reportId?: string;
  type: SanctionType;
  status: SanctionStatus;
  reason: string;
  startedAt: string;
  expiresAt?: string;
  revokedAt?: string;
  revokedByAdminId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateSanctionInput {
  userId: string;
  reportId?: string;
  type: SanctionType;
  reason: string;
  startedAt?: string;
  expiresAt?: string;
}

export interface SanctionFilter
  extends RepositoryDateRange,
    RepositoryListOptions {
  userId?: string;
  reportId?: string;
  type?: SanctionType;
  status?: SanctionStatus;
}

export interface SanctionRepository {
  createSanction(
    adminId: string,
    input: CreateSanctionInput
  ): Promise<UserSanction>;
  revokeSanction(
    adminId: string,
    sanctionId: string,
    reason?: string
  ): Promise<UserSanction>;
  listSanctions(filter?: SanctionFilter): Promise<UserSanction[]>;
  listActiveSanctionsForUser(userId: string): Promise<UserSanction[]>;
  hasActiveRestriction(
    userId: string,
    action: "matching" | "chat" | "login"
  ): Promise<boolean>;
}
