import { environment } from "../../config/environment";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  AdminAuditLog,
  AdminAuditLogFilter,
  AdminRepository,
  CreateAdminAuditLogInput
} from "../interfaces/admin.repository";

const adminAuditLogs = new Map<string, AdminAuditLog>();

export const memoryAdminRepository: AdminRepository = {
  async isWhitelistedAdmin(_userId, email) {
    return Boolean(email && environment.adminEmailWhitelist.includes(email));
  },

  async createAuditLog(input: CreateAdminAuditLogInput) {
    const log: AdminAuditLog = {
      id: createEntityId("audit"),
      actorAdminId: input.actorId,
      actorEmail: input.actorEmail ?? "",
      action: input.action,
      targetType: input.targetType,
      targetId: input.targetId,
      aal: input.aal,
      reason: input.reason,
      metadata: input.metadata ?? {},
      createdAt: nowIso()
    };

    adminAuditLogs.set(log.id, log);
    return log;
  },

  async listAuditLogs(filter: AdminAuditLogFilter = {}) {
    const logs = Array.from(adminAuditLogs.values())
      .filter((log) =>
        filter.actorAdminId ? log.actorAdminId === filter.actorAdminId : true
      )
      .filter((log) => (filter.action ? log.action === filter.action : true))
      .filter((log) =>
        filter.targetType ? log.targetType === filter.targetType : true
      )
      .filter((log) =>
        filter.targetId ? log.targetId === filter.targetId : true
      )
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? logs.length;

    return logs.slice(offset, offset + limit);
  },

  async getDashboardStats() {
    return {
      totalUserCount: db.users.size,
      verifiedUserCount: Array.from(db.users.values()).filter(
        (user) => user.verificationStatus === "verified"
      ).length,
      openPostCount: Array.from(db.posts.values()).filter(
        (post) => post.status === "open"
      ).length,
      pendingReportCount: Array.from(db.reports.values()).filter(
        (report) => report.status === "pending"
      ).length,
      activeSanctionCount: 0,
      createdAt: nowIso()
    };
  }
};
