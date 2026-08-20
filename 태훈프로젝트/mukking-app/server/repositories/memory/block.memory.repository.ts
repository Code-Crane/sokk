import { nowIso } from "../../../shared/utils/date";
import { createEntityId } from "../../models/id";
import type {
  BlockFilter,
  BlockRepository,
  CreateBlockInput,
  UserBlock
} from "../interfaces/block.repository";

const blocks = new Map<string, UserBlock>();

function isActive(block: UserBlock): boolean {
  return !block.revokedAt && (!block.expiresAt || block.expiresAt > nowIso());
}

export const memoryBlockRepository: BlockRepository = {
  async createBlock(blockerId, input: CreateBlockInput) {
    const block: UserBlock = {
      id: createEntityId("block"),
      blockerId,
      blockedUserId: input.blockedUserId,
      scope: input.scope ?? "all",
      reason: input.reason,
      expiresAt: input.expiresAt,
      createdAt: nowIso()
    };

    blocks.set(block.id, block);
    return block;
  },

  async revokeBlock(blockerId, blockedUserId) {
    for (const block of blocks.values()) {
      if (
        block.blockerId === blockerId &&
        block.blockedUserId === blockedUserId &&
        !block.revokedAt
      ) {
        blocks.set(block.id, { ...block, revokedAt: nowIso() });
      }
    }
  },

  async listBlocks(filter: BlockFilter = {}) {
    const filtered = Array.from(blocks.values())
      .filter((block) => (filter.blockerId ? block.blockerId === filter.blockerId : true))
      .filter((block) =>
        filter.blockedUserId ? block.blockedUserId === filter.blockedUserId : true
      )
      .filter((block) => (filter.scope ? block.scope === filter.scope : true))
      .filter((block) => (filter.includeRevoked ? true : !block.revokedAt));

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? filtered.length;

    return filtered.slice(offset, offset + limit);
  },

  async hasActiveBlockBetween(userAId, userBId, scope = "all") {
    return Array.from(blocks.values()).some((block) => {
      const blocksPair =
        (block.blockerId === userAId && block.blockedUserId === userBId) ||
        (block.blockerId === userBId && block.blockedUserId === userAId);
      const scopeMatches = block.scope === "all" || block.scope === scope;

      return blocksPair && scopeMatches && isActive(block);
    });
  }
};
