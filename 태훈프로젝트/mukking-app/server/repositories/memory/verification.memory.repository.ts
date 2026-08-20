import type { VerificationClaim } from "../../../shared/types";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  CreateVerificationFailureLogInput,
  VerificationFailureLog,
  VerificationFailureLogFilter,
  VerificationRepository
} from "../interfaces/verification.repository";

const verificationFailureLogs = new Map<string, VerificationFailureLog>();

export const memoryVerificationRepository: VerificationRepository = {
  async findClaimByUserId(userId) {
    return db.verificationClaims.get(userId) ?? null;
  },

  async upsertClaim(input) {
    const claim: VerificationClaim = {
      userId: input.userId,
      provider: input.provider,
      status: input.status,
      requestedAt: input.requestedAt,
      verifiedAt: input.verifiedAt
    };

    db.verificationClaims.set(input.userId, claim);
    return claim;
  },

  async listFailureLogsForAdmin(filter: VerificationFailureLogFilter = {}) {
    const logs = Array.from(verificationFailureLogs.values())
      .filter((log) => (filter.userId ? log.userId === filter.userId : true))
      .filter((log) => (filter.provider ? log.provider === filter.provider : true))
      .filter((log) =>
        filter.reasonCode ? log.reasonCode === filter.reasonCode : true
      )
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? logs.length;

    return logs.slice(offset, offset + limit);
  },

  async createFailureLog(input: CreateVerificationFailureLogInput) {
    const log: VerificationFailureLog = {
      id: createEntityId("vfail"),
      userId: input.userId,
      provider: input.provider,
      reasonCode: input.reasonCode,
      message: input.message,
      createdAt: new Date().toISOString()
    };

    verificationFailureLogs.set(log.id, log);
    return log;
  }
};
