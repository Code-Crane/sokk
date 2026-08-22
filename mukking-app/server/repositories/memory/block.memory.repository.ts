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
    const blockedId = input.blockedId ?? input.blockedUserId;

    if (!blockedId) {
      throw Object.assign(new Error("blockedId is required."), { statusCode: 400 });
    }

    const existing = Array.from(blocks.values()).find(
      (block) =>
        block.blockerId === blockerId &&
        block.blockedId === blockedId &&
        isActive(block)
    );

    if (existing) {
      throw Object.assign(new Error("This user is already blocked."), {
        statusCode: 409
      });
    }

    const block: UserBlock = {
      id: createEntityId("block"),
      blockerId,
      blockedId,
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
        block.blockedId === blockedUserId &&
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
        filter.blockedId ? block.blockedId === filter.blockedId : true
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
        (block.blockerId === userAId && block.blockedId === userBId) ||
        (block.blockerId === userBId && block.blockedId === userAId);
      const scopeMatches = block.scope === "all" || block.scope === scope;

      return blocksPair && scopeMatches && isActive(block);
    });
  }
};
