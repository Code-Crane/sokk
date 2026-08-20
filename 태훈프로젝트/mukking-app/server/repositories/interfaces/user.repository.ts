import type {
  MannerGrade,
  PublicUserProfile,
  SignupInput,
  UserAccount,
  VerificationStatus
} from "../../../shared/types";
import type { AccountStatus, RepositoryListOptions } from "./repository.types";

export interface CreateUserRecordInput extends SignupInput {
  id?: string;
  createdAt?: string;
  verificationStatus?: VerificationStatus;
  mannerScore?: number;
  mannerGrade?: MannerGrade;
}

export interface UpdateUserProfileInput {
  nickname?: string;
  phoneNumber?: string;
  verificationStatus?: VerificationStatus;
  mannerScore?: number;
  mannerGrade?: MannerGrade;
  accountStatus?: AccountStatus;
}

export interface AdminUserListFilter extends RepositoryListOptions {
  query?: string;
  verificationStatus?: VerificationStatus;
  accountStatus?: AccountStatus;
}

export interface AdminUserSummary extends PublicUserProfile {
  accountStatus: AccountStatus;
  activeSanctionCount: number;
  reportCount: number;
}

export interface UserRepository {
  findById(userId: string): Promise<UserAccount | null>;
  findByEmail(email: string): Promise<UserAccount | null>;
  create(input: CreateUserRecordInput): Promise<UserAccount>;
  update(userId: string, input: UpdateUserProfileInput): Promise<UserAccount>;
  setVerificationStatus(
    userId: string,
    status: VerificationStatus
  ): Promise<UserAccount>;
  updateMannerProfile(
    userId: string,
    mannerScore: number,
    mannerGrade: MannerGrade
  ): Promise<UserAccount>;
  setAccountStatus(userId: string, status: AccountStatus): Promise<UserAccount>;
  toPublicProfile(
    user: UserAccount,
    pendingEvaluationCount: number
  ): PublicUserProfile;
  listForAdmin(filter?: AdminUserListFilter): Promise<AdminUserSummary[]>;
}
