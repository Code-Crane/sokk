import type {
  CreateUserReportInput,
  ReportReason,
  ReportStatus,
  UpdateReportStatusInput,
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
  reportedUserId: string;
  targetType: CreateUserReportInput["targetType"];
  targetId: string;
  chatRoomId?: string;
  messageId?: string;
  reason: ReportReason;
  description?: string;
}

export interface ReportFilter extends RepositoryDateRange, RepositoryListOptions {
  reporterId?: string;
  reportedUserId?: string;
  targetType?: CreateReportInput["targetType"];
  targetId?: string;
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
  updateReportStatus(reportId: string, input: UpdateReportStatusInput & {
    resolvedBy?: string;
  }): Promise<UserReport>;
  createReportEvent(input: CreateReportEventInput): Promise<ReportEvent>;
  listReportEvents(reportId: string): Promise<ReportEvent[]>;
}
