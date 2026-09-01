export type VerificationStatus = "unverified" | "pending" | "verified";

export interface VerificationClaim {
  userId: string;
  provider: "pass_mock" | "pass";
  status: VerificationStatus;
  requestedAt?: string;
  verifiedAt?: string;
}

export interface VerificationStatusSnapshot {
  status: VerificationStatus;
  label: "미인증" | "인증중" | "인증완료";
  canUseMatching: boolean;
  canUseChat: boolean;
}

export interface MockVerificationInput {
  legalName: string;
  birthDate: string;
  gender: "male" | "female" | "other";
  phoneNumber: string;
}

export interface VerificationResult {
  status: VerificationStatus;
  claim: VerificationClaim;
}
