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
      targetUserId: input.targetUserId,
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
        filter.targetUserId ? report.targetUserId === filter.targetUserId : true
      )
      .filter((report) => (filter.status ? report.status === filter.status : true))
      .filter((report) => (filter.reason ? report.reason === filter.reason : true))
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? reports.length;

    return reports.slice(offset, offset + limit);
  },

  async updateReportStatus(reportId, status) {
    const report = db.reports.get(reportId);

    if (!report) {
      throw Object.assign(new Error("Report not found."), { statusCode: 404 });
    }

    const updated: UserReport = {
      ...report,
      status,
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
