import type { RepositoryListOptions } from "./repository.types";

export type BlockScope = "all" | "matching" | "chat";

export interface UserBlock {
  id: string;
  blockerId: string;
  blockedUserId: string;
  scope: BlockScope;
  reason?: string;
  createdAt: string;
  expiresAt?: string;
  revokedAt?: string;
}

export interface CreateBlockInput {
  blockedUserId: string;
  scope?: BlockScope;
  reason?: string;
  expiresAt?: string;
}

export interface BlockFilter extends RepositoryListOptions {
  blockerId?: string;
  blockedUserId?: string;
  scope?: BlockScope;
  includeRevoked?: boolean;
}

export interface BlockRepository {
  createBlock(blockerId: string, input: CreateBlockInput): Promise<UserBlock>;
  revokeBlock(blockerId: string, blockedUserId: string): Promise<void>;
  listBlocks(filter?: BlockFilter): Promise<UserBlock[]>;
  hasActiveBlockBetween(
    userAId: string,
    userBId: string,
    scope?: BlockScope
  ): Promise<boolean>;
}
