import type {
  CreateUserReportInput,
  UpdateReportStatusInput,
  UserReport
} from "../../../shared/types";
import { repositories } from "../../repositories";
import type { ReportEvent } from "../../repositories/interfaces/report.repository";

const reportReasons = new Set([
  "inappropriate_chat",
  "no_show",
  "safety_risk",
  "spam",
  "other"
]);

const reportStatuses = new Set(["pending", "reviewing", "resolved", "dismissed"]);

async function assertUserExists(userId: string, label: string): Promise<void> {
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error(`${label} user not found.`), { statusCode: 404 });
  }
}

async function validateReportTarget(
  reporterId: string,
  input: CreateUserReportInput
): Promise<void> {
  if (!input.reportedUserId || !input.targetType || !input.targetId || !input.reason) {
    throw Object.assign(
      new Error("reportedUserId, targetType, targetId, and reason are required."),
      { statusCode: 400 }
    );
  }

  if (!reportReasons.has(input.reason)) {
    throw Object.assign(new Error("Invalid report reason."), { statusCode: 400 });
  }

  if (input.reportedUserId === reporterId) {
    throw Object.assign(new Error("You cannot report yourself."), { statusCode: 400 });
  }

  await assertUserExists(input.reportedUserId, "Reported");

  if (input.targetType === "user") {
    if (input.targetId !== input.reportedUserId) {
      throw Object.assign(
        new Error("For user reports, targetId must match reportedUserId."),
        { statusCode: 400 }
      );
    }

    return;
  }

  if (input.targetType === "post") {
    const post = await repositories.matching.findPostById(input.targetId);

    if (!post) {
      throw Object.assign(new Error("Report target post not found."), {
        statusCode: 400
      });
    }

    return;
  }

  if (input.targetType === "join_request") {
    const joinRequest = await repositories.matching.findJoinRequestById(input.targetId);

    if (!joinRequest) {
      throw Object.assign(new Error("Report target join request not found."), {
        statusCode: 400
      });
    }

    return;
  }

  if (input.targetType === "chat_room" || input.targetType === "chat_message") {
    const roomId = input.chatRoomId ?? input.targetId;
    const room = await repositories.chat.findRoomById(roomId);

    if (!room) {
      throw Object.assign(new Error("Report target chat room not found."), {
        statusCode: 400
      });
    }

    if (!room.participantIds.includes(reporterId)) {
      throw Object.assign(
        new Error("Only chat room participants can report chat targets."),
        { statusCode: 403 }
      );
    }

    if (!room.participantIds.includes(input.reportedUserId)) {
      throw Object.assign(
        new Error("reportedUserId must be a participant of the chat room."),
        { statusCode: 400 }
      );
    }

    if (input.targetType === "chat_message") {
      const messageId = input.messageId ?? input.targetId;
      const messages = await repositories.chat.listMessages(room.id);
      const message = messages.find((item) => item.id === messageId);

      if (!message) {
        throw Object.assign(new Error("Report target message not found."), {
          statusCode: 400
        });
      }

      if (message.senderId === "system" || message.senderId !== input.reportedUserId) {
        throw Object.assign(
          new Error("reportedUserId must match the reported message sender."),
          { statusCode: 400 }
        );
      }
    }

    return;
  }

  throw Object.assign(new Error("Invalid report targetType."), { statusCode: 400 });
}

export async function createReport(
  reporterId: string,
  input: CreateUserReportInput
): Promise<UserReport> {
  await assertUserExists(reporterId, "Reporter");
  await validateReportTarget(reporterId, input);

  const report = await repositories.reports.createReport(reporterId, input);
  await repositories.reports.createReportEvent({
    reportId: report.id,
    actorId: reporterId,
    actorRole: "user",
    eventType: "created",
    nextStatus: "pending",
    metadata: {
      targetType: report.targetType,
      targetId: report.targetId
    }
  });

  return report;
}

export async function listReportsForAdmin(): Promise<UserReport[]> {
  return repositories.reports.listReports();
}

export async function getReportForAdmin(reportId: string): Promise<{
  report: UserReport;
  events: ReportEvent[];
}> {
  const report = await repositories.reports.findReportById(reportId);

  if (!report) {
    throw Object.assign(new Error("Report not found."), { statusCode: 404 });
  }

  return {
    report,
    events: await repositories.reports.listReportEvents(report.id)
  };
}

export async function updateReportForAdmin(
  adminId: string,
  input: UpdateReportStatusInput & { reportId: string }
): Promise<UserReport> {
  if (!reportStatuses.has(input.status)) {
    throw Object.assign(new Error("Invalid report status."), { statusCode: 400 });
  }

  const existingReport = await repositories.reports.findReportById(input.reportId);

  if (!existingReport) {
    throw Object.assign(new Error("Report not found."), { statusCode: 404 });
  }

  const updatedReport = await repositories.reports.updateReportStatus(input.reportId, {
    status: input.status,
    resolvedBy: adminId,
    actionTaken: input.actionTaken,
    adminNote: input.adminNote
  });

  await repositories.reports.createReportEvent({
    reportId: updatedReport.id,
    actorId: adminId,
    actorRole: "admin",
    eventType:
      input.status === "resolved"
        ? "resolved"
        : input.status === "dismissed"
          ? "dismissed"
          : "status_changed",
    previousStatus: existingReport.status,
    nextStatus: updatedReport.status,
    note: input.adminNote,
    metadata: {
      actionTaken: input.actionTaken
    }
  });

  return updatedReport;
}
