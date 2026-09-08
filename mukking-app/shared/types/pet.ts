export type PetType = "healthy" | "night" | "hearty";
export type PetGrowthStage = "꼬마" | "새싹 친구" | "단골 친구" | "식탁 친구" | "먹킹 마스터";
export type PetXpSource = "matching_completed" | "hosted_matching_completed" | "manner_rating_completed";
export interface UserPet {
  id: string;
  userId: string;
  petType: PetType;
  name: string | null;
  xp: number;
  createdAt: string;
  updatedAt: string;
}
export interface PetResponse extends UserPet {
  level: number;
  growthStage: PetGrowthStage;
  levelXp: number;
  nextLevelXp: number | null;
  remainingXp: number;
  progress: number;
}
export interface PetXpEvent {
  id: string;
  userId: string;
  sourceType: PetXpSource;
  sourceId: string;
  xpAmount: number;
  createdAt: string;
}
