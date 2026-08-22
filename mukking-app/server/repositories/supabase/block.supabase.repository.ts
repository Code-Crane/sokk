import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  BlockFilter,
  BlockRepository,
  CreateBlockInput,
  UserBlock
} from "../interfaces/block.repository";
import { throwSupabaseError } from "./helpers";

type BlockRow = {
  id: string;
  blocker_id: string;
  blocked_id: string;
  scope: UserBlock["scope"];
  reason?: string | null;
  created_at: string;
  expires_at?: string | null;
  revoked_at?: string | null;
};

function toBlock(row: BlockRow): UserBlock {
  return {
    id: row.id,
    blockerId: row.blocker_id,
    blockedId: row.blocked_id,
    scope: row.scope,
    reason: row.reason ?? undefined,
    createdAt: row.created_at,
    expiresAt: row.expires_at ?? undefined,
    revokedAt: row.revoked_at ?? undefined
  };
}

function isActive(block: UserBlock): boolean {
  return !block.revokedAt && (!block.expiresAt || block.expiresAt > nowIso());
}

export const supabaseBlockRepository: BlockRepository = {
  async createBlock(blockerId, input: CreateBlockInput) {
    const blockedId = input.blockedId ?? input.blockedUserId;

    if (!blockedId) {
      throw Object.assign(new Error("blockedId is required."), { statusCode: 400 });
    }

    const { data, error } = await getSupabaseServiceRoleClient()
      .from("blocks")
      .insert({
        id: createEntityId("block"),
        blocker_id: blockerId,
        blocked_id: blockedId,
        scope: input.scope ?? "all",
        reason: input.reason,
        expires_at: input.expiresAt,
        created_at: nowIso()
      })
      .select("*")
      .single<BlockRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toBlock(data as BlockRow);
  },

  async revokeBlock(blockerId, blockedUserId) {
    const { error } = await getSupabaseServiceRoleClient()
      .from("blocks")
      .update({ revoked_at: nowIso() })
      .eq("blocker_id", blockerId)
      .eq("blocked_id", blockedUserId)
      .is("revoked_at", null);

    if (error) {
      throwSupabaseError(error);
    }
  },

  async listBlocks(filter: BlockFilter = {}) {
    let query = getSupabaseServiceRoleClient().from("blocks").select("*");

    if (filter.blockerId) query = query.eq("blocker_id", filter.blockerId);
    if (filter.blockedId) query = query.eq("blocked_id", filter.blockedId);
    if (filter.scope) query = query.eq("scope", filter.scope);
    if (!filter.includeRevoked) query = query.is("revoked_at", null);

    query = query.order("created_at", { ascending: false });

    if (typeof filter.offset === "number" || typeof filter.limit === "number") {
      const offset = filter.offset ?? 0;
      const limit = filter.limit ?? 50;
      query = query.range(offset, offset + limit - 1);
    }

    const { data, error } = await query.returns<BlockRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toBlock);
  },

  async hasActiveBlockBetween(userAId, userBId, scope = "all") {
    let query = getSupabaseServiceRoleClient()
      .from("blocks")
      .select("*")
      .or(
        `and(blocker_id.eq.${userAId},blocked_id.eq.${userBId}),and(blocker_id.eq.${userBId},blocked_id.eq.${userAId})`
      )
      .is("revoked_at", null);

    if (scope !== "all") {
      query = query.in("scope", ["all", scope]);
    } else {
      query = query.eq("scope", "all");
    }

    const { data, error } = await query.returns<BlockRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toBlock).some(isActive);
  }
};
