import type {
  VerificationClaim,
  VerificationStatus
} from "../../../shared/types";
import type { RepositoryDateRange, RepositoryListOptions } from "./repository.types";

export interface UpsertVerificationClaimInput {
  userId: string;
  provider: VerificationClaim["provider"];
  status: VerificationStatus;
  requestedAt?: string;
  verifiedAt?: string;
  encryptedPayload?: {
    legalName?: string;
    birthDate?: string;
    gender?: string;
    phoneNumber?: string;
  };
  providerTransactionId?: string;
  metadata?: Record<string, unknown>;
}

export interface VerificationFailureLog {
  id: string;
  userId?: string;
  provider: VerificationClaim["provider"];
  reasonCode: string;
  message?: string;
  createdAt: string;
}

export interface CreateVerificationFailureLogInput {
  userId?: string;
  provider: VerificationClaim["provider"];
  reasonCode: string;
  message?: string;
  requestPayloadHash?: string;
  ipHash?: string;
  userAgentHash?: string;
  metadata?: Record<string, unknown>;
}

export interface VerificationFailureLogFilter
  extends RepositoryDateRange,
    RepositoryListOptions {
  userId?: string;
  provider?: VerificationClaim["provider"];
  reasonCode?: string;
}

export interface VerificationRepository {
  findClaimByUserId(userId: string): Promise<VerificationClaim | null>;
  upsertClaim(input: UpsertVerificationClaimInput): Promise<VerificationClaim>;
  listFailureLogsForAdmin(
    filter?: VerificationFailureLogFilter
  ): Promise<VerificationFailureLog[]>;
  createFailureLog(
    input: CreateVerificationFailureLogInput
  ): Promise<VerificationFailureLog>;
}
