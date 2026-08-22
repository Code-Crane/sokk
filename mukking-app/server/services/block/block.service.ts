import type {
  CreateBlockInput,
  UserBlock
} from "../../repositories/interfaces/block.repository";
import { repositories } from "../../repositories";

async function assertUserExists(userId: string, label: string): Promise<void> {
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error(`${label} user not found.`), { statusCode: 404 });
  }
}

export async function createBlock(
  blockerId: string,
  input: CreateBlockInput
): Promise<UserBlock> {
  const blockedId = input.blockedId ?? input.blockedUserId;

  if (!blockedId) {
    throw Object.assign(new Error("blockedId is required."), { statusCode: 400 });
  }

  if (blockedId === blockerId) {
    throw Object.assign(new Error("You cannot block yourself."), { statusCode: 400 });
  }

  await assertUserExists(blockerId, "Blocker");
  await assertUserExists(blockedId, "Blocked");

  return repositories.blocks.createBlock(blockerId, {
    ...input,
    blockedId
  });
}

export async function revokeBlock(
  blockerId: string,
  blockedId: string
): Promise<{ ok: true }> {
  if (!blockedId) {
    throw Object.assign(new Error("blockedId is required."), { statusCode: 400 });
  }

  await repositories.blocks.revokeBlock(blockerId, blockedId);

  return { ok: true };
}

export async function listMyBlocks(blockerId: string): Promise<UserBlock[]> {
  return repositories.blocks.listBlocks({ blockerId });
}

export async function assertNoActiveBlockBetween(
  userAId: string,
  userBId: string,
  action: "matching" | "chat"
): Promise<void> {
  const hasBlock = await repositories.blocks.hasActiveBlockBetween(
    userAId,
    userBId,
    action
  );

  if (hasBlock) {
    throw Object.assign(
      new Error(`This ${action} action is blocked by a user block.`),
      { statusCode: 403 }
    );
  }
}
