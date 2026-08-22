import { environment } from "../../config/environment";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import { nowIso } from "../../../shared/utils/date";
import type {
  AdminAuditLog,
  AdminAuditLogFilter,
  AdminRepository,
  CreateAdminAuditLogInput
} from "../interfaces/admin.repository";
import { throwSupabaseError } from "./helpers";

type AdminAuditLogRow = {
  id: string;
  actor_admin_id?: string | null;
  actor_email: string;
  action: string;
  target_type?: AdminAuditLog["targetType"] | null;
  target_id?: string | null;
  aal?: "aal1" | "aal2" | null;
  reason?: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
};

function toAuditLog(row: AdminAuditLogRow): AdminAuditLog {
  return {
    id: row.id,
    actorAdminId: row.actor_admin_id ?? undefined,
    actorEmail: row.actor_email,
    action: row.action,
    targetType: row.target_type ?? undefined,
    targetId: row.target_id ?? undefined,
    aal: row.aal ?? undefined,
    reason: row.reason ?? undefined,
    metadata: row.metadata ?? {},
    createdAt: row.created_at
  };
}

export const supabaseAdminRepository: AdminRepository = {
  async isWhitelistedAdmin(userId, email) {
    const emailAllowed = Boolean(email && environment.adminEmailWhitelist.includes(email));
    const uidAllowed =
      environment.adminUidWhitelist.length === 0 ||
      environment.adminUidWhitelist.includes(userId);

    return emailAllowed && uidAllowed;
  },

  async createAuditLog(input: CreateAdminAuditLogInput) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("admin_audit_logs")
      .insert({
        id: createEntityId("audit"),
        actor_admin_id: input.actorId,
        actor_email: input.actorEmail ?? "",
        action: input.action,
        target_type: input.targetType,
        target_id: input.targetId,
        aal: input.aal,
        reason: input.reason,
        metadata: input.metadata ?? {},
        created_at: nowIso()
      })
      .select("*")
      .single<AdminAuditLogRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toAuditLog(data as AdminAuditLogRow);
  },

  async listAuditLogs(filter: AdminAuditLogFilter = {}) {
    let query = getSupabaseServiceRoleClient()
      .from("admin_audit_logs")
      .select("*")
      .order("created_at", { ascending: false });

    if (filter.actorAdminId) query = query.eq("actor_admin_id", filter.actorAdminId);
    if (filter.action) query = query.eq("action", filter.action);
    if (filter.targetType) query = query.eq("target_type", filter.targetType);
    if (filter.targetId) query = query.eq("target_id", filter.targetId);
    if (filter.from) query = query.gte("created_at", filter.from);
    if (filter.to) query = query.lte("created_at", filter.to);

    if (typeof filter.offset === "number" || typeof filter.limit === "number") {
      const offset = filter.offset ?? 0;
      const limit = filter.limit ?? 50;
      query = query.range(offset, offset + limit - 1);
    }

    const { data, error } = await query.returns<AdminAuditLogRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toAuditLog);
  },

  async getDashboardStats() {
    const supabase = getSupabaseServiceRoleClient();
    const [reports, sanctions] = await Promise.all([
      supabase
        .from("reports")
        .select("id", { count: "exact", head: true })
        .eq("status", "pending"),
      supabase
        .from("sanctions")
        .select("id", { count: "exact", head: true })
        .eq("status", "active")
    ]);

    if (reports.error) {
      throwSupabaseError(reports.error);
    }

    if (sanctions.error) {
      throwSupabaseError(sanctions.error);
    }

    return {
      totalUserCount: 0,
      verifiedUserCount: 0,
      openPostCount: 0,
      pendingReportCount: reports.count ?? 0,
      activeSanctionCount: sanctions.count ?? 0,
      createdAt: nowIso()
    };
  }
};
