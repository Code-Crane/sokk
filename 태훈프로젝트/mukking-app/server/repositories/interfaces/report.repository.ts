import type {
  ReportReason,
  ReportStatus,
  UserReport
} from "../../../shared/types";
import type { RepositoryDateRange, RepositoryListOptions } from "./repository.types";

export type ReportEventType =
  | "created"
  | "status_changed"
  | "admin_note"
  | "sanction_created"
  | "dismissed"
  | "resolved";

export interface CreateReportInput {
  targetUserId: string;
  reason: ReportReason;
  description: string;
  postId?: string;
  chatRoomId?: string;
  chatMessageId?: string;
}

export interface ReportFilter extends RepositoryDateRange, RepositoryListOptions {
  reporterId?: string;
  targetUserId?: string;
  status?: ReportStatus;
  reason?: ReportReason;
}

export interface ReportEvent {
  id: string;
  reportId: string;
  actorId?: string;
  actorRole: "user" | "admin" | "system";
  eventType: ReportEventType;
  previousStatus?: ReportStatus;
  nextStatus?: ReportStatus;
  note?: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface CreateReportEventInput {
  reportId: string;
  actorId?: string;
  actorRole: ReportEvent["actorRole"];
  eventType: ReportEventType;
  previousStatus?: ReportStatus;
  nextStatus?: ReportStatus;
  note?: string;
  metadata?: Record<string, unknown>;
}

export interface ReportRepository {
  createReport(reporterId: string, input: CreateReportInput): Promise<UserReport>;
  findReportById(reportId: string): Promise<UserReport | null>;
  listReports(filter?: ReportFilter): Promise<UserReport[]>;
  updateReportStatus(
    reportId: string,
    status: ReportStatus,
    adminId?: string
  ): Promise<UserReport>;
  createReportEvent(input: CreateReportEventInput): Promise<ReportEvent>;
  listReportEvents(reportId: string): Promise<ReportEvent[]>;
}
