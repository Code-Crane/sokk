import type { PetGrowthStage } from "../types/pet";
export const PET_MAX_LEVEL = 30;
export function xpForLevel(level: number): number {
  if (!Number.isInteger(level) || level < 1 || level > PET_MAX_LEVEL) throw new Error("Invalid pet level.");
  return 100 + (level - 1) * 25;
}
function validXp(xp: number): void {
  if (!Number.isSafeInteger(xp) || xp < 0) throw new Error("Invalid pet XP.");
}
export function levelFromXp(xp: number): number {
  validXp(xp);
  let level = 1;
  while (level < PET_MAX_LEVEL && xp >= xpForLevel(level)) {
    xp -= xpForLevel(level++);
  }
  return level;
}
export function progressToNextLevel(xp: number) {
  const level = levelFromXp(xp);
  if (level === PET_MAX_LEVEL) return { levelXp: 0, nextLevelXp: null, remainingXp: 0, progress: 1 };
  let levelXp = xp;
  for (let i = 1; i < level; i++) levelXp -= xpForLevel(i);
  const nextLevelXp = xpForLevel(level);
  return { levelXp, nextLevelXp, remainingXp: nextLevelXp - levelXp, progress: levelXp / nextLevelXp };
}
export function growthStageFromLevel(level: number): PetGrowthStage {
  xpForLevel(level);
  return level < 5 ? "꼬마" : level < 10 ? "새싹 친구" : level < 20 ? "단골 친구" : level < 30 ? "식탁 친구" : "먹킹 마스터";
}
