import type { PetResponse, PetType, PetXpSource, UserPet } from "../../../shared/types/pet";
import { growthStageFromLevel, levelFromXp, progressToNextLevel } from "../../../shared/utils/pet";
import { repositories } from "../../repositories";
export const PET_XP_REWARDS: Readonly<Record<PetXpSource, number>> = Object.freeze({
  matching_completed: 30, hosted_matching_completed: 50, manner_rating_completed: 15
});
function response(pet: UserPet): PetResponse {
  const level = levelFromXp(pet.xp);
  return { ...pet, level, growthStage: growthStageFromLevel(level), ...progressToNextLevel(pet.xp) };
}
export async function getMyPet(userId: string): Promise<PetResponse | null> {
  const pet = await repositories.pets.findByUser(userId);
  return pet ? response(pet) : null;
}
export async function selectPet(userId: string, input: unknown): Promise<PetResponse> {
  if (!input || typeof input !== "object" || Array.isArray(input) ||
      Object.keys(input).some(key => key !== "petType") ||
      !["healthy", "night", "hearty"].includes((input as { petType: string }).petType)) {
    throw Object.assign(new Error("petType must be healthy, night or hearty."), { statusCode: 400 });
  }
  return response(await repositories.pets.create(userId, (input as { petType: PetType }).petType));
}
// Internal domain hook only. There is deliberately no public award endpoint.
export async function awardPetXpBestEffort(userId: string, sourceType: PetXpSource, sourceId: string): Promise<void> {
  try {
    await repositories.pets.award(userId, sourceType, sourceId, PET_XP_REWARDS[sourceType]);
  } catch {
    // Never log credentials, user identifiers or raw database errors.
    console.warn("[PET_XP] Award failed; primary action preserved.");
  }
}
