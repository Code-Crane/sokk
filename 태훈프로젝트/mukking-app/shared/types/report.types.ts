export type ReportReason =
  | "inappropriate_chat"
  | "no_show"
  | "safety_risk"
  | "spam"
  | "other";

export type ReportStatus = "pending" | "reviewing" | "resolved" | "dismissed";

export interface UserReport {
  id: string;
  reporterId: string;
  targetUserId: string;
  reason: ReportReason;
  description: string;
  status: ReportStatus;
  createdAt: string;
  updatedAt: string;
}

