export interface RestaurantLocation {
  latitude: number;
  longitude: number;
}

export interface Restaurant {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  category: string;
  placeProvider: string;
  placeProviderId: string;
  imageUrl?: string;
  phone?: string;
  roadAddress?: string;
  metadata: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface CreateRestaurantInput {
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  category: string;
  placeProvider: string;
  placeProviderId: string;
  imageUrl?: string;
  phone?: string;
  roadAddress?: string;
  metadata?: Record<string, unknown>;
}

export interface UpdateRestaurantInput {
  name?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  category?: string;
  imageUrl?: string | null;
  phone?: string | null;
  roadAddress?: string | null;
  metadata?: Record<string, unknown>;
}

export interface RestaurantFavorite {
  userId: string;
  restaurantId: string;
  createdAt: string;
}

export interface RestaurantListQuery {
  category?: string;
  lat?: number;
  lng?: number;
  radiusKm?: number;
  limit?: number;
  offset?: number;
}

export interface RestaurantResponse extends Restaurant {
  isFavorite: boolean;
  activePartyCount: number;
  distanceMeters?: number;
}
