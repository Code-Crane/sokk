import type { UserReport } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  ReportEvent,
  ReportRepository
} from "../interfaces/report.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type ReportRow = {
  id: string;
  reporter_id: string;
  reported_user_id: string;
  target_type: UserReport["targetType"];
  target_id: string;
  chat_room_id?: string | null;
  message_id?: string | null;
  reason: UserReport["reason"];
  description?: string | null;
  status: UserReport["status"];
  resolved_at?: string | null;
  resolved_by?: string | null;
  action_taken?: string | null;
  admin_note?: string | null;
  created_at: string;
  updated_at: string;
};

type ReportEventRow = {
  id: string;
  report_id: string;
  actor_id?: string | null;
  actor_role: ReportEvent["actorRole"];
  event_type: ReportEvent["eventType"];
  previous_status?: UserReport["status"] | null;
  next_status?: UserReport["status"] | null;
  note?: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
};

function toReport(row: ReportRow): UserReport {
  return {
    id: row.id,
    reporterId: row.reporter_id,
    reportedUserId: row.reported_user_id,
    targetType: row.target_type,
    targetId: row.target_id,
    chatRoomId: row.chat_room_id ?? undefined,
    messageId: row.message_id ?? undefined,
    reason: row.reason,
    description: row.description ?? undefined,
    status: row.status,
    resolvedAt: row.resolved_at ?? undefined,
    resolvedBy: row.resolved_by ?? undefined,
    actionTaken: row.action_taken ?? undefined,
    adminNote: row.admin_note ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function toReportEvent(row: ReportEventRow): ReportEvent {
  return {
    id: row.id,
    reportId: row.report_id,
    actorId: row.actor_id ?? undefined,
    actorRole: row.actor_role,
    eventType: row.event_type,
    previousStatus: row.previous_status ?? undefined,
    nextStatus: row.next_status ?? undefined,
    note: row.note ?? undefined,
    metadata: row.metadata ?? {},
    createdAt: row.created_at
  };
}

export const supabaseReportRepository: ReportRepository = {
  async createReport(reporterId, input) {
    const timestamp = nowIso();
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("reports")
      .insert({
        id: createEntityId("report"),
        reporter_id: reporterId,
        reported_user_id: input.reportedUserId,
        target_type: input.targetType,
        target_id: input.targetId,
        chat_room_id: input.chatRoomId,
        message_id: input.messageId,
        reason: input.reason,
        description: input.description,
        status: "pending",
        created_at: timestamp,
        updated_at: timestamp
      })
      .select("*")
      .single<ReportRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toReport(ensureRow(data, "Report was not created."));
  },

  async findReportById(reportId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("reports")
      .select("*")
      .eq("id", reportId)
      .maybeSingle<ReportRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return data ? toReport(data) : null;
  },

  async listReports(filter = {}) {
    let query = getSupabaseServiceRoleClient()
      .from("reports")
      .select("*")
      .order("created_at", { ascending: false });

    if (filter.reporterId) query = query.eq("reporter_id", filter.reporterId);
    if (filter.reportedUserId) query = query.eq("reported_user_id", filter.reportedUserId);
    if (filter.targetType) query = query.eq("target_type", filter.targetType);
    if (filter.targetId) query = query.eq("target_id", filter.targetId);
    if (filter.status) query = query.eq("status", filter.status);
    if (filter.reason) query = query.eq("reason", filter.reason);
    if (filter.from) query = query.gte("created_at", filter.from);
    if (filter.to) query = query.lte("created_at", filter.to);

    if (typeof filter.offset === "number" || typeof filter.limit === "number") {
      const offset = filter.offset ?? 0;
      const limit = filter.limit ?? 50;
      query = query.range(offset, offset + limit - 1);
    }

    const { data, error } = await query.returns<ReportRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toReport);
  },

  async updateReportStatus(reportId, input) {
    const timestamp = nowIso();
    const isTerminal = input.status === "resolved" || input.status === "dismissed";
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("reports")
      .update({
        status: input.status,
        resolved_at: isTerminal ? timestamp : undefined,
        resolved_by: isTerminal ? input.resolvedBy : undefined,
        action_taken: input.actionTaken,
        admin_note: input.adminNote,
        updated_at: timestamp
      })
      .eq("id", reportId)
      .select("*")
      .single<ReportRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toReport(ensureRow(data, "Report not found."));
  },

  async createReportEvent(input) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("report_events")
      .insert({
        id: createEntityId("revent"),
        report_id: input.reportId,
        actor_id: input.actorId,
        actor_role: input.actorRole,
        event_type: input.eventType,
        previous_status: input.previousStatus,
        next_status: input.nextStatus,
        note: input.note,
        metadata: input.metadata ?? {},
        created_at: nowIso()
      })
      .select("*")
      .single<ReportEventRow>();

    if (error) {
      throwSupabaseError(error);
    }

    return toReportEvent(ensureRow(data, "Report event was not created."));
  },

  async listReportEvents(reportId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("report_events")
      .select("*")
      .eq("report_id", reportId)
      .order("created_at", { ascending: true })
      .returns<ReportEventRow[]>();

    if (error) {
      throwSupabaseError(error);
    }

    return (data ?? []).map(toReportEvent);
  }
};
