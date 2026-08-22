import type {
  MannerGrade,
  PublicUserProfile,
  UserAccount,
  VerificationStatus
} from "../../../shared/types";
import {
  DEFAULT_MANNER_SCORE,
  getMannerGrade
} from "../../../shared/utils/rating";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  AdminUserListFilter,
  AdminUserSummary,
  CreateUserRecordInput,
  UpdateUserProfileInput,
  UserRepository
} from "../interfaces/user.repository";
import type { AccountStatus } from "../interfaces/repository.types";

const accountStatuses = new Map<string, AccountStatus>();

function matchesQuery(user: UserAccount, query?: string): boolean {
  if (!query) {
    return true;
  }

  const normalizedQuery = query.toLowerCase();
  return (
    user.email.toLowerCase().includes(normalizedQuery) ||
    user.nickname.toLowerCase().includes(normalizedQuery)
  );
}

function getAccountStatus(userId: string): AccountStatus {
  return accountStatuses.get(userId) ?? "active";
}

export const memoryUserRepository: UserRepository = {
  async findById(userId) {
    return db.users.get(userId) ?? null;
  },

  async findByEmail(email) {
    return (
      Array.from(db.users.values()).find(
        (user) => user.email.toLowerCase() === email.toLowerCase()
      ) ?? null
    );
  },

  async create(input: CreateUserRecordInput) {
    const mannerScore = input.mannerScore ?? DEFAULT_MANNER_SCORE;
    const user: UserAccount = {
      id: input.id ?? createEntityId("user"),
      email: input.email,
      nickname: input.nickname,
      phoneNumber: input.phoneNumber,
      verificationStatus: input.verificationStatus ?? "unverified",
      mannerScore,
      mannerGrade: input.mannerGrade ?? getMannerGrade(mannerScore),
      createdAt: input.createdAt ?? new Date().toISOString()
    };

    db.users.set(user.id, user);
    accountStatuses.set(user.id, "active");

    return user;
  },

  async update(userId, input: UpdateUserProfileInput) {
    const user = db.users.get(userId);

    if (!user) {
      throw Object.assign(new Error("User not found."), { statusCode: 404 });
    }

    const updated: UserAccount = {
      ...user,
      nickname: input.nickname ?? user.nickname,
      phoneNumber: input.phoneNumber ?? user.phoneNumber,
      verificationStatus: input.verificationStatus ?? user.verificationStatus,
      mannerScore: input.mannerScore ?? user.mannerScore,
      mannerGrade: input.mannerGrade ?? user.mannerGrade
    };

    db.users.set(userId, updated);

    if (input.accountStatus) {
      accountStatuses.set(userId, input.accountStatus);
    }

    return updated;
  },

  async setVerificationStatus(userId, status: VerificationStatus) {
    return this.update(userId, { verificationStatus: status });
  },

  async updateMannerProfile(
    userId: string,
    mannerScore: number,
    mannerGrade: MannerGrade
  ) {
    return this.update(userId, { mannerScore, mannerGrade });
  },

  async setAccountStatus(userId: string, status: AccountStatus) {
    return this.update(userId, { accountStatus: status });
  },

  toPublicProfile(user: UserAccount, pendingEvaluationCount: number): PublicUserProfile {
    return {
      id: user.id,
      nickname: user.nickname,
      email: user.email,
      verificationStatus: user.verificationStatus,
      mannerScore: user.mannerScore,
      mannerGrade: user.mannerGrade,
      pendingEvaluationCount,
      createdAt: user.createdAt
    };
  },

  async listForAdmin(filter: AdminUserListFilter = {}) {
    const users = Array.from(db.users.values())
      .filter((user) => matchesQuery(user, filter.query))
      .filter((user) =>
        filter.verificationStatus
          ? user.verificationStatus === filter.verificationStatus
          : true
      )
      .filter((user) =>
        filter.accountStatus ? getAccountStatus(user.id) === filter.accountStatus : true
      );

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? users.length;

    return users.slice(offset, offset + limit).map<AdminUserSummary>((user) => ({
      ...this.toPublicProfile(user, 0),
      accountStatus: getAccountStatus(user.id),
      activeSanctionCount: 0,
      reportCount: Array.from(db.reports.values()).filter(
        (report) => report.reportedUserId === user.id
      ).length
    }));
  }
};
