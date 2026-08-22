import type { UserReport } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  CreateReportEventInput,
  ReportEvent,
  ReportFilter,
  ReportRepository
} from "../interfaces/report.repository";

const reportEvents = new Map<string, ReportEvent>();

export const memoryReportRepository: ReportRepository = {
  async createReport(reporterId, input) {
    const timestamp = nowIso();
    const report: UserReport = {
      id: createEntityId("report"),
      reporterId,
      reportedUserId: input.reportedUserId,
      targetType: input.targetType,
      targetId: input.targetId,
      chatRoomId: input.chatRoomId,
      messageId: input.messageId,
      reason: input.reason,
      description: input.description,
      status: "pending",
      createdAt: timestamp,
      updatedAt: timestamp
    };

    db.reports.set(report.id, report);
    return report;
  },

  async findReportById(reportId) {
    return db.reports.get(reportId) ?? null;
  },

  async listReports(filter: ReportFilter = {}) {
    const reports = Array.from(db.reports.values())
      .filter((report) =>
        filter.reporterId ? report.reporterId === filter.reporterId : true
      )
      .filter((report) =>
        filter.reportedUserId
          ? report.reportedUserId === filter.reportedUserId
          : true
      )
      .filter((report) =>
        filter.targetType ? report.targetType === filter.targetType : true
      )
      .filter((report) =>
        filter.targetId ? report.targetId === filter.targetId : true
      )
      .filter((report) => (filter.status ? report.status === filter.status : true))
      .filter((report) => (filter.reason ? report.reason === filter.reason : true))
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? reports.length;

    return reports.slice(offset, offset + limit);
  },

  async updateReportStatus(reportId, input) {
    const report = db.reports.get(reportId);

    if (!report) {
      throw Object.assign(new Error("Report not found."), { statusCode: 404 });
    }

    const updated: UserReport = {
      ...report,
      status: input.status,
      resolvedAt:
        input.status === "resolved" || input.status === "dismissed"
          ? nowIso()
          : report.resolvedAt,
      resolvedBy:
        input.status === "resolved" || input.status === "dismissed"
          ? input.resolvedBy
          : report.resolvedBy,
      actionTaken: input.actionTaken ?? report.actionTaken,
      adminNote: input.adminNote ?? report.adminNote,
      updatedAt: nowIso()
    };

    db.reports.set(reportId, updated);
    return updated;
  },

  async createReportEvent(input: CreateReportEventInput) {
    const event: ReportEvent = {
      id: createEntityId("revent"),
      reportId: input.reportId,
      actorId: input.actorId,
      actorRole: input.actorRole,
      eventType: input.eventType,
      previousStatus: input.previousStatus,
      nextStatus: input.nextStatus,
      note: input.note,
      metadata: input.metadata ?? {},
      createdAt: nowIso()
    };

    reportEvents.set(event.id, event);
    return event;
  },

  async listReportEvents(reportId) {
    return Array.from(reportEvents.values())
      .filter((event) => event.reportId === reportId)
      .sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  }
};
