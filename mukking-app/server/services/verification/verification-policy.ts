import type { VerificationClaim } from "../../../shared/types";
import { environment } from "../../config/environment";

export function isVerificationAcceptedForEnvironment(
  profile: { id: string; verificationStatus: string },
  claim: VerificationClaim | null,
  nodeEnv = environment.nodeEnv
): boolean {
  if (profile.verificationStatus !== "verified") return false;
  if (nodeEnv === "development" || nodeEnv === "test") return true;
  return nodeEnv === "production" && claim?.userId === profile.id &&
    claim.status === "verified" && claim.provider === "pass" &&
    Boolean(claim.verifiedAt && Number.isFinite(Date.parse(claim.verifiedAt)));
}

export function assertMockVerificationEnabled(): void {
  if (environment.nodeEnv === "production" || !environment.mockVerificationEnabled) {
    throw Object.assign(new Error("Mock verification is unavailable."), { statusCode: 403 });
  }
}
