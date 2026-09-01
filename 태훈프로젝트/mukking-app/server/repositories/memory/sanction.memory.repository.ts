import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import type {
  CreateSanctionInput,
  SanctionFilter,
  SanctionRepository,
  UserSanction
} from "../interfaces/sanction.repository";

const sanctions = new Map<string, UserSanction>();

function isActive(sanction: UserSanction): boolean {
  return (
    sanction.status === "active" &&
    (!sanction.endsAt || sanction.endsAt > nowIso()) &&
    !sanction.revokedAt
  );
}

export const memorySanctionRepository: SanctionRepository = {
  async createSanction(adminId, input: CreateSanctionInput) {
    const timestamp = nowIso();
    const sanction: UserSanction = {
      id: createEntityId("sanction"),
      userId: input.userId,
      issuedByAdminId: adminId,
      reportId: input.reportId,
      type: input.type,
      status: "active",
      reason: input.reason,
      startsAt: input.startsAt ?? timestamp,
      endsAt: input.endsAt,
      createdAt: timestamp,
      updatedAt: timestamp
    };

    sanctions.set(sanction.id, sanction);
    return sanction;
  },

  async revokeSanction(adminId, sanctionId) {
    const sanction = sanctions.get(sanctionId);

    if (!sanction) {
      throw Object.assign(new Error("Sanction not found."), { statusCode: 404 });
    }

    const timestamp = nowIso();
    const updated: UserSanction = {
      ...sanction,
      status: "revoked",
      revokedAt: timestamp,
      revokedByAdminId: adminId,
      updatedAt: timestamp
    };

    sanctions.set(sanctionId, updated);
    return updated;
  },

  async listSanctions(filter: SanctionFilter = {}) {
    const filtered = Array.from(sanctions.values())
      .filter((sanction) => (filter.userId ? sanction.userId === filter.userId : true))
      .filter((sanction) =>
        filter.reportId ? sanction.reportId === filter.reportId : true
      )
      .filter((sanction) => (filter.type ? sanction.type === filter.type : true))
      .filter((sanction) =>
        filter.status ? sanction.status === filter.status : true
      )
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? filtered.length;

    return filtered.slice(offset, offset + limit);
  },

  async listActiveSanctionsForUser(userId) {
    return Array.from(sanctions.values()).filter(
      (sanction) => sanction.userId === userId && isActive(sanction)
    );
  },

  async hasActiveRestriction(userId, action) {
    const activeSanctions = await this.listActiveSanctionsForUser(userId);

    return activeSanctions.some((sanction) => {
      if (action === "login") {
        return (
          sanction.type === "temporary_suspension" ||
          sanction.type === "permanent_ban"
        );
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
