import type {
  MockVerificationInput,
  VerificationClaim,
  VerificationResult,
  VerificationStatus,
  VerificationStatusSnapshot
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { repositories } from "../../repositories";
import { assertMockVerificationEnabled, isVerificationAcceptedForEnvironment } from "./verification-policy";

const verificationLabels: Record<
  VerificationStatus,
  VerificationStatusSnapshot["label"]
> = {
  unverified: "미인증",
  pending: "인증중",
  verified: "인증완료"
};

export async function getVerificationClaim(
  userId: string
): Promise<VerificationClaim | null> {
  return repositories.verification.findClaimByUserId(userId);
}

export async function getVerificationStatusSnapshot(
  userId: string
): Promise<VerificationStatusSnapshot> {
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  const accepted = isVerificationAcceptedForEnvironment(user, await getVerificationClaim(userId));
  return {
    status: user.verificationStatus,
    label: verificationLabels[user.verificationStatus],
    canUseMatching: accepted,
    canUseChat: accepted
  };
}

export async function startMockVerification(
  userId: string
): Promise<VerificationResult> {
  assertMockVerificationEnabled();
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  if (user.verificationStatus === "verified") {
    const existingClaim = await repositories.verification.findClaimByUserId(userId);

    return {
      status: "verified",
      claim: existingClaim ?? {
        userId,
        provider: "pass_mock",
        status: "verified",
        verifiedAt: nowIso()
      }
    };
  }

  const claim: VerificationClaim = {
    userId,
    provider: "pass_mock",
    status: "pending",
    requestedAt: nowIso()
  };

  await repositories.users.setVerificationStatus(userId, "pending");
  await repositories.verification.upsertClaim(claim);

  return {
    status: "pending",
    claim
  };
}

export async function completeMockVerification(
  userId: string,
  input: MockVerificationInput
): Promise<VerificationResult> {
  assertMockVerificationEnabled();
  if (!input.legalName || !input.birthDate || !input.gender || !input.phoneNumber) {
    throw Object.assign(new Error("Mock verification input is incomplete."), {
      statusCode: 400
    });
  }

  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  if (user.verificationStatus !== "pending") {
    throw Object.assign(new Error("Verification must be pending before completion."), {
      statusCode: 409
    });
  }

  const existingClaim = await repositories.verification.findClaimByUserId(userId);
  const claim: VerificationClaim = {
    userId,
    provider: "pass_mock",
    status: "verified",
    requestedAt: existingClaim?.requestedAt,
    verifiedAt: nowIso()
  };

  await repositories.users.setVerificationStatus(userId, "verified");
  await repositories.verification.upsertClaim(claim);

  return {
    status: "verified",
    claim
  };
}

export async function submitMockVerification(
  userId: string,
  input: MockVerificationInput
): Promise<VerificationResult> {
  assertMockVerificationEnabled();
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  if (user.verificationStatus === "unverified") {
    await startMockVerification(userId);
  }

  return completeMockVerification(userId, input);
}
