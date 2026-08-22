import type { RestaurantFavorite } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import type { RestaurantFavoriteRepository } from "../interfaces/restaurant-favorite.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type FavoriteRow = {
  user_id: string;
  restaurant_id: string;
  created_at: string;
};

function toFavorite(row: FavoriteRow): RestaurantFavorite {
  return {
    userId: row.user_id,
    restaurantId: row.restaurant_id,
    createdAt: row.created_at
  };
}

export const supabaseRestaurantFavoriteRepository: RestaurantFavoriteRepository = {
  async listByUser(userId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurant_favorites")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .returns<FavoriteRow[]>();

    if (error) throwSupabaseError(error);
    return (data ?? []).map(toFavorite);
  },

  async exists(userId, restaurantId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurant_favorites")
      .select("restaurant_id")
      .eq("user_id", userId)
      .eq("restaurant_id", restaurantId)
      .maybeSingle();

    if (error) throwSupabaseError(error);
    return Boolean(data);
  },

  async create(userId, restaurantId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurant_favorites")
      .insert({ user_id: userId, restaurant_id: restaurantId, created_at: nowIso() })
      .select("*")
      .single<FavoriteRow>();

    if (error) throwSupabaseError(error);
    return toFavorite(ensureRow(data, "Restaurant favorite was not created."));
  },

  async delete(userId, restaurantId) {
    const { error } = await getSupabaseServiceRoleClient()
      .from("restaurant_favorites")
      .delete()
      .eq("user_id", userId)
      .eq("restaurant_id", restaurantId);

    if (error) throwSupabaseError(error);
  },

  async listUserIdsByRestaurant(restaurantId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurant_favorites")
      .select("user_id")
      .eq("restaurant_id", restaurantId)
      .returns<Array<Pick<FavoriteRow, "user_id">>>();

    if (error) throwSupabaseError(error);
    return (data ?? []).map((row) => row.user_id);
  }
};
