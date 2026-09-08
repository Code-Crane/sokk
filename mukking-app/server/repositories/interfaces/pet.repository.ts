import type { PetType, PetXpSource, UserPet } from "../../../shared/types/pet";
export interface PetRepository {
  findByUser(userId: string): Promise<UserPet | null>;
  create(userId: string, petType: PetType): Promise<UserPet>;
  award(userId: string, sourceType: PetXpSource, sourceId: string, amount: number): Promise<boolean>;
}
