import type { RepositoryActorContext, RepositoryDateRange, RepositoryListOptions } from "./repository.types";

export interface AdminAuditLog {
  id: string;
  actorAdminId?: string;
  actorEmail: string;
  action: string;
  targetType?: "user" | "report" | "sanction" | "post" | "chat_room";
  targetId?: string;
  aal?: "aal1" | "aal2";
  reason?: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface CreateAdminAuditLogInput extends RepositoryActorContext {
  action: string;
  targetType?: AdminAuditLog["targetType"];
  targetId?: string;
  aal?: "aal1" | "aal2";
  reason?: string;
  metadata?: Record<string, unknown>;
}

export interface AdminAuditLogFilter
  extends RepositoryDateRange,
    RepositoryListOptions {
  actorAdminId?: string;
  action?: string;
  targetType?: AdminAuditLog["targetType"];
  targetId?: string;
}

export interface AdminDashboardStats {
  totalUserCount: number;
  verifiedUserCount: number;
  openPostCount: number;
  pendingReportCount: number;
  activeSanctionCount: number;
  createdAt: string;
}

export interface AdminRepository {
  isWhitelistedAdmin(userId: string, email?: string): Promise<boolean>;
  createAuditLog(input: CreateAdminAuditLogInput): Promise<AdminAuditLog>;
  listAuditLogs(filter?: AdminAuditLogFilter): Promise<AdminAuditLog[]>;
  getDashboardStats(): Promise<AdminDashboardStats>;
}
