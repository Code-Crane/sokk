import { randomUUID } from "node:crypto";
import type { PetXpEvent, UserPet } from "../../../shared/types/pet";
import type { PetRepository } from "../interfaces/pet.repository";
const pets = new Map<string, UserPet>();
const events = new Map<string, PetXpEvent>();
export const memoryPetRepository: PetRepository = {
  async findByUser(userId) { const pet = pets.get(userId); return pet ? { ...pet } : null; },
  async create(userId, petType) {
    if (pets.has(userId)) throw Object.assign(new Error("A pet has already been selected."), { statusCode: 409 });
    const timestamp = new Date().toISOString();
    const pet: UserPet = { id: randomUUID(), userId, petType, name: null, xp: 0, createdAt: timestamp, updatedAt: timestamp };
    pets.set(userId, pet);
    return { ...pet };
  },
  async award(userId, sourceType, sourceId, amount) {
    if (!Number.isSafeInteger(amount) || amount <= 0 || !sourceId.trim()) throw new Error("Invalid XP event.");
    const pet = pets.get(userId);
    if (!pet) return false;
    const key = JSON.stringify([userId, sourceType, sourceId]);
    if (events.has(key)) return false;
    if (!Number.isSafeInteger(pet.xp + amount)) throw new Error("Pet XP overflow.");
    // No await between ledger insertion and total update: one memory transaction.
    events.set(key, { id: randomUUID(), userId, sourceType, sourceId,
      xpAmount: amount, createdAt: new Date().toISOString() });
    pet.xp += amount;
    pet.updatedAt = new Date().toISOString();
    return true;
  }
};
