import type { PetType, UserPet } from "../../../shared/types/pet";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import type { PetRepository } from "../interfaces/pet.repository";
import { throwSupabaseError, ensureRow } from "./helpers";
type Row = { id: string; user_id: string; pet_type: PetType; name: string | null; xp: number; created_at: string; updated_at: string };
function map(row: Row): UserPet {
  return { id: row.id, userId: row.user_id, petType: row.pet_type, name: row.name, xp: Number(row.xp), createdAt: row.created_at, updatedAt: row.updated_at };
}
export const supabasePetRepository: PetRepository = {
  async findByUser(userId) {
    const { data, error } = await getSupabaseServiceRoleClient().from("user_pets").select("*").eq("user_id", userId).maybeSingle<Row>();
    if (error) throwSupabaseError(error);
    return data ? map(data) : null;
  },
  async create(userId, petType) {
    const { data, error } = await getSupabaseServiceRoleClient().from("user_pets").insert({ user_id: userId, pet_type: petType }).select("*").single<Row>();
    if (error) throwSupabaseError(error);
    return map(ensureRow(data, "Pet was not created."));
  },
  async award(userId, sourceType, sourceId, amount) {
    const { data, error } = await getSupabaseServiceRoleClient().rpc("award_pet_xp", {
      p_user_id: userId, p_source_type: sourceType, p_source_id: sourceId, p_amount: amount
    });
    if (error) throwSupabaseError(error);
    return data === true;
  }
};
