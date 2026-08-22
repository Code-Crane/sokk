import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  CreateSanctionInput,
  SanctionFilter,
  SanctionRepository,
  UserSanction
} from "../interfaces/sanction.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type SanctionRow = {
  id: string;
  user_id: string;
  created_by?: string | null;
  report_id?: string | null;
  type: UserSanction["type"];
  status: UserSanction["status"];
  reason: string;
  started_at: string;
  expires_at?: string | null;
  revoked_at?: string | null;
  revoked_by_admin_id?: string | null;
  created_at: string;
  updated_at: string;
};

function toSanction(row: SanctionRow): UserSanction {
  return {
    id: row.id,
    userId: row.user_id,
    createdBy: row.created_by ?? undefined,
    reportId: row.report_id ?? undefined,
    type: row.type,
    status: row.status,
    reason: row.reason,
    startedAt: row.started_at,
    expiresAt: row.expires_at ?? undefined,
    revokedAt: row.revoked_at ?? undefined,
    revokedByAdminId: row.revoked_by_admin_id ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function isActive(sanction: UserSanction): boolean {
  return (
    sanction.status === "active" &&
    !sanction.revokedAt &&
    (!sanction.expiresAt || sanction.expiresAt > nowIso())
  );
}

export const supabaseSanctionRepository: SanctionRepository = {
  async createSanction(adminId, input: CreateSanctionInput) {
    const timestamp = nowIso();
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("sanctions")
      .insert({
        id: createEntityId("sanction"),
        user_id: input.userId,
        created_by: adminId,
        report_id: input.reportId,
        type: input.type,
        status: "active",
        reason: input.reason,
        started_at: input.startedAt ?? timestamp,
        expires_at: input.expiresAt,
        created_at: timestamp,
        updated_at: timestamp
      })
      .select("*")
      .single<SanctionRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toSanction(ensureRow(data, "Sanction was not created."));
  },

  async revokeSanction(adminId, sanctionId) {
    const timestamp = nowIso();
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("sanctions")
      .update({
        status: "revoked",
        revoked_at: timestamp,
        revoked_by_admin_id: adminId,
        updated_at: timestamp
      })
      .eq("id", sanctionId)
      .select("*")
      .single<SanctionRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toSanction(ensureRow(data, "Sanction not found."));
  },

  async listSanctions(filter: SanctionFilter = {}) {
    let query = getSupabaseServiceRoleClient()
      .from("sanctions")
      .select("*")
      .order("created_at", { ascending: false });

    if (filter.userId) query = query.eq("user_id", filter.userId);
    if (filter.reportId) query = query.eq("report_id", filter.reportId);
    if (filter.type) query = query.eq("type", filter.type);
    if (filter.status) query = query.eq("status", filter.status);
    if (filter.from) query = query.gte("created_at", filter.from);
    if (filter.to) query = query.lte("created_at", filter.to);

    if (typeof filter.offset === "number" || typeof filter.limit === "number") {
      const offset = filter.offset ?? 0;
      const limit = filter.limit ?? 50;
      query = query.range(offset, offset + limit - 1);
    }

    const { data, error } = await query.returns<SanctionRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toSanction);
  },

  async listActiveSanctionsForUser(userId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("sanctions")
      .select("*")
      .eq("user_id", userId)
      .eq("status", "active")
      .returns<SanctionRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toSanction).filter(isActive);
  },

  async hasActiveRestriction(userId, action) {
    const activeSanctions = await this.listActiveSanctionsForUser(userId);

    return activeSanctions.some((sanction) => {
      if (action === "login") {
        return sanction.type === "permanent_ban";
      }

      if (action === "matching") {
        return (
          sanction.type === "matching_suspension" ||
          sanction.type === "temporary_suspension" ||
          sanction.type === "permanent_ban"
        );
      }

      return (
        sanction.type === "chat_suspension" ||
        sanction.type === "temporary_suspension" ||
        sanction.type === "permanent_ban"
      );
    });
  }
};
