export type ReportReason =
  | "inappropriate_chat"
  | "no_show"
  | "safety_risk"
  | "spam"
  | "other";

export type ReportStatus = "pending" | "reviewing" | "resolved" | "dismissed";

export type ReportTargetType =
  | "user"
  | "post"
  | "chat_room"
  | "chat_message"
  | "join_request";

export interface UserReport {
  id: string;
  reporterId: string;
  reportedUserId: string;
  targetType: ReportTargetType;
  targetId: string;
  chatRoomId?: string;
  messageId?: string;
  reason: ReportReason;
  description?: string;
  status: ReportStatus;
  resolvedAt?: string;
  resolvedBy?: string;
  actionTaken?: string;
  adminNote?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateUserReportInput {
  reportedUserId: string;
  targetType: ReportTargetType;
  targetId: string;
  chatRoomId?: string;
  messageId?: string;
  reason: ReportReason;
  description?: string;
}

export interface UpdateReportStatusInput {
  status: ReportStatus;
  actionTaken?: string;
  adminNote?: string;
}
