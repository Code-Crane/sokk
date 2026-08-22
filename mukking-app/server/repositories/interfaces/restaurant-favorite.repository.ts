import type { RestaurantFavorite } from "../../../shared/types";

export interface RestaurantFavoriteRepository {
  listByUser(userId: string): Promise<RestaurantFavorite[]>;
  exists(userId: string, restaurantId: string): Promise<boolean>;
  create(userId: string, restaurantId: string): Promise<RestaurantFavorite>;
  delete(userId: string, restaurantId: string): Promise<void>;
  listUserIdsByRestaurant(restaurantId: string): Promise<string[]>;
}
