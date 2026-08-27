import type {
  CreateRestaurantInput,
  Restaurant,
  UpdateRestaurantInput
} from "../../../shared/types";
import type { RepositoryListOptions } from "./repository.types";

export interface RestaurantNearbyFilter {
  latitude: number;
  longitude: number;
  radiusKm: number;
}

export interface RestaurantFilter extends RepositoryListOptions {
  category?: string;
  placeProvider?: string;
  placeProviderId?: string;
  nearby?: RestaurantNearbyFilter;
}

export interface RestaurantWithDistance {
  restaurant: Restaurant;
  distanceMeters?: number;
}

export interface RestaurantRepository {
  findById(restaurantId: string): Promise<Restaurant | null>;
  findByProviderId(
    placeProvider: string,
    placeProviderId: string
  ): Promise<Restaurant | null>;
  list(filter?: RestaurantFilter): Promise<RestaurantWithDistance[]>;
  create(input: CreateRestaurantInput): Promise<Restaurant>;
  upsertMany(inputs: CreateRestaurantInput[]): Promise<Restaurant[]>;
  update(restaurantId: string, input: UpdateRestaurantInput): Promise<Restaurant>;
}
