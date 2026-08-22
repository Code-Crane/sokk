import type { RestaurantFavorite } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { db } from "../../models/inMemoryDb";
import type { RestaurantFavoriteRepository } from "../interfaces/restaurant-favorite.repository";

function favoriteKey(userId: string, restaurantId: string): string {
  return `${userId}:${restaurantId}`;
}

export const memoryRestaurantFavoriteRepository: RestaurantFavoriteRepository = {
  async listByUser(userId) {
    return Array.from(db.restaurantFavorites.values())
      .filter((favorite) => favorite.userId === userId)
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  },

  async exists(userId, restaurantId) {
    return db.restaurantFavorites.has(favoriteKey(userId, restaurantId));
  },

  async create(userId, restaurantId) {
    const key = favoriteKey(userId, restaurantId);
    if (db.restaurantFavorites.has(key)) {
      throw Object.assign(new Error("Restaurant is already in favorites."), {
        statusCode: 409
      });
    }

    const favorite: RestaurantFavorite = { userId, restaurantId, createdAt: nowIso() };
    db.restaurantFavorites.set(key, favorite);
    return favorite;
  },

  async delete(userId, restaurantId) {
    db.restaurantFavorites.delete(favoriteKey(userId, restaurantId));
  },

  async listUserIdsByRestaurant(restaurantId) {
    return Array.from(db.restaurantFavorites.values())
      .filter((favorite) => favorite.restaurantId === restaurantId)
      .map((favorite) => favorite.userId);
  }
};
