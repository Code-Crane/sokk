import type {
  CreateSanctionInput,
  SanctionFilter,
  UserSanction
} from "../../repositories/interfaces/sanction.repository";
import { repositories } from "../../repositories";

function getAccountStatusForSanction(
  sanction: UserSanction
): "active" | "suspended" | "banned" {
  if (sanction.status !== "active") {
    return "active";
  }

  if (sanction.type === "permanent_ban") {
    return "banned";
  }

  if (
    sanction.type === "matching_suspension" ||
    sanction.type === "chat_suspension" ||
    sanction.type === "temporary_suspension"
  ) {
    return "suspended";
  }

  return "active";
}

async function syncUserStatusFromActiveSanctions(userId: string): Promise<void> {
  const activeSanctions = await repositories.sanctions.listActiveSanctionsForUser(userId);

  if (activeSanctions.some((sanction) => sanction.type === "permanent_ban")) {
    await repositories.users.setAccountStatus(userId, "banned");
    return;
  }

  if (
    activeSanctions.some(
      (sanction) =>
        sanction.type === "matching_suspension" ||
        sanction.type === "chat_suspension" ||
        sanction.type === "temporary_suspension"
    )
  ) {
    await repositories.users.setAccountStatus(userId, "suspended");
    return;
  }

  await repositories.users.setAccountStatus(userId, "active");
}

export async function createSanction(
  adminId: string,
  input: CreateSanctionInput
): Promise<UserSanction> {
  const user = await repositories.users.findById(input.userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  if (!input.reason || !input.type) {
    throw Object.assign(new Error("type and reason are required."), {
      statusCode: 400
    });
  }

  const sanction = await repositories.sanctions.createSanction(adminId, input);
  await repositories.users.setAccountStatus(
    sanction.userId,
    getAccountStatusForSanction(sanction)
  );

  await repositories.admin.createAuditLog({
    actorId: adminId,
    action: "sanction.created",
    targetType: "sanction",
    targetId: sanction.id,
    reason: sanction.reason,
    metadata: {
      userId: sanction.userId,
      reportId: sanction.reportId,
      type: sanction.type,
      status: sanction.status,
      startedAt: sanction.startedAt,
      expiresAt: sanction.expiresAt
    }
  });

  if (sanction.reportId) {
    await repositories.reports.createReportEvent({
      reportId: sanction.reportId,
      actorId: adminId,
      actorRole: "admin",
      eventType: "sanction_created",
      metadata: {
        sanctionId: sanction.id,
        type: sanction.type
      }
    });
  }

  return sanction;
}

export async function revokeSanction(
  adminId: string,
  sanctionId: string,
  reason?: string
): Promise<UserSanction> {
  const sanction = await repositories.sanctions.revokeSanction(
    adminId,
    sanctionId,
    reason
  );
  await syncUserStatusFromActiveSanctions(sanction.userId);

  await repositories.admin.createAuditLog({
    actorId: adminId,
    action: "sanction.revoked",
    targetType: "sanction",
    targetId: sanction.id,
    reason,
    metadata: {
      userId: sanction.userId,
      reportId: sanction.reportId,
      type: sanction.type,
      status: sanction.status
    }
  });

  return sanction;
}

export async function listSanctions(
  filter?: SanctionFilter
): Promise<UserSanction[]> {
  return repositories.sanctions.listSanctions(filter);
}

export async function assertNoActiveRestriction(
  userId: string,
  action: "matching" | "chat" | "login"
): Promise<void> {
  const hasRestriction = await repositories.sanctions.hasActiveRestriction(
    userId,
    action
  );

  if (hasRestriction) {
    const message =
      action === "login"
        ? "This account is banned."
        : `This account is restricted from ${action}.`;

    throw Object.assign(new Error(message), { statusCode: 403 });
  }
}
