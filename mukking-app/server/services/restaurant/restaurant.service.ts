import type {
  CreateRestaurantInput,
  Restaurant,
  RestaurantListQuery,
  RestaurantResponse
} from "../../../shared/types";
import { repositories } from "../../repositories";

function invalid(message: string): never {
  throw Object.assign(new Error(message), { statusCode: 400 });
}

function requireText(value: unknown, name: string): string {
  if (typeof value !== "string" || !value.trim()) {
    return invalid(`${name} is required.`);
  }

  return value.trim();
}

function validateCoordinate(value: unknown, name: string, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    return invalid(`${name} must be a number between ${min} and ${max}.`);
  }

  return value;
}

function parseOptionalNumber(value: unknown, name: string): number | undefined {
  if (value === undefined) return undefined;
  const parsed = typeof value === "number" ? value : Number(value);

  if (!Number.isFinite(parsed)) {
    return invalid(`${name} must be a valid number.`);
  }

  return parsed;
}

function normalizeListQuery(query: RestaurantListQuery): RestaurantListQuery {
  const lat = parseOptionalNumber(query.lat, "lat");
  const lng = parseOptionalNumber(query.lng, "lng");
  const radiusKm = parseOptionalNumber(query.radiusKm, "radiusKm");
  const limit = parseOptionalNumber(query.limit, "limit");
  const offset = parseOptionalNumber(query.offset, "offset");

  if ((lat === undefined) !== (lng === undefined)) {
    return invalid("lat and lng must be provided together.");
  }

  if (lat !== undefined) validateCoordinate(lat, "lat", -90, 90);
  if (lng !== undefined) validateCoordinate(lng, "lng", -180, 180);
  if (radiusKm !== undefined && (radiusKm <= 0 || radiusKm > 100)) {
    return invalid("radiusKm must be greater than 0 and at most 100.");
  }
  if (limit !== undefined && (!Number.isInteger(limit) || limit < 1 || limit > 100)) {
    return invalid("limit must be an integer between 1 and 100.");
  }
  if (offset !== undefined && (!Number.isInteger(offset) || offset < 0)) {
    return invalid("offset must be a non-negative integer.");
  }

  return {
    category: query.category?.trim() || undefined,
    lat,
    lng,
    radiusKm,
    limit,
    offset
  };
}

function normalizeCreateInput(input: CreateRestaurantInput): CreateRestaurantInput {
  const metadata = input.metadata;

  if (metadata !== undefined && (typeof metadata !== "object" || Array.isArray(metadata))) {
    return invalid("metadata must be an object.");
  }

  return {
    name: requireText(input.name, "name"),
    address: requireText(input.address, "address"),
    latitude: validateCoordinate(input.latitude, "latitude", -90, 90),
    longitude: validateCoordinate(input.longitude, "longitude", -180, 180),
    category: requireText(input.category, "category"),
    placeProvider: requireText(input.placeProvider, "placeProvider"),
    placeProviderId: requireText(input.placeProviderId, "placeProviderId"),
    imageUrl: input.imageUrl?.trim() || undefined,
    phone: input.phone?.trim() || undefined,
    roadAddress: input.roadAddress?.trim() || undefined,
    metadata: metadata ?? {}
  };
}

async function toResponse(
  restaurant: Restaurant,
  userId: string,
  distanceMeters?: number
): Promise<RestaurantResponse> {
  const [isFavorite, posts] = await Promise.all([
    repositories.restaurantFavorites.exists(userId, restaurant.id),
    repositories.matching.listPosts({ status: "open" })
  ]);

  return {
    ...restaurant,
    isFavorite,
    activePartyCount: posts.filter((post) => post.restaurantId === restaurant.id).length,
    distanceMeters
  };
}

export async function createRestaurant(input: CreateRestaurantInput): Promise<Restaurant> {
  const normalized = normalizeCreateInput(input);
  const existing = await repositories.restaurants.findByProviderId(
    normalized.placeProvider,
    normalized.placeProviderId
  );

  if (existing) {
    throw Object.assign(new Error("Restaurant already exists for this provider place."), {
      statusCode: 409
    });
  }

  return repositories.restaurants.create(normalized);
}

export async function listRestaurants(
  userId: string,
  query: RestaurantListQuery
): Promise<RestaurantResponse[]> {
  const normalized = normalizeListQuery(query);
  const rows = await repositories.restaurants.list({
    category: normalized.category,
    nearby:
      normalized.lat !== undefined && normalized.lng !== undefined
        ? {
            latitude: normalized.lat,
            longitude: normalized.lng,
            radiusKm: normalized.radiusKm ?? 5
          }
        : undefined,
    limit: normalized.limit,
    offset: normalized.offset
  });

  return Promise.all(
    rows.map(({ restaurant, distanceMeters }) => toResponse(restaurant, userId, distanceMeters))
  );
}

export async function getRestaurant(
  userId: string,
  restaurantId: string
): Promise<RestaurantResponse> {
  const restaurant = await repositories.restaurants.findById(restaurantId);

  if (!restaurant) {
    throw Object.assign(new Error("Restaurant not found."), { statusCode: 404 });
  }

  return toResponse(restaurant, userId);
}

export async function addRestaurantFavorite(
  userId: string,
  restaurantId: string
): Promise<RestaurantResponse> {
  const restaurant = await repositories.restaurants.findById(restaurantId);

  if (!restaurant) {
    throw Object.assign(new Error("Restaurant not found."), { statusCode: 404 });
  }

  await repositories.restaurantFavorites.create(userId, restaurantId);
  return toResponse(restaurant, userId);
}

export async function removeRestaurantFavorite(
  userId: string,
  restaurantId: string
): Promise<{ ok: true }> {
  await repositories.restaurantFavorites.delete(userId, restaurantId);
  return { ok: true };
}

export async function listMyRestaurantFavorites(userId: string): Promise<RestaurantResponse[]> {
  const favorites = await repositories.restaurantFavorites.listByUser(userId);
  const restaurants = await Promise.all(
    favorites.map((favorite) => repositories.restaurants.findById(favorite.restaurantId))
  );

  return Promise.all(
    restaurants
      .filter((restaurant): restaurant is Restaurant => restaurant !== null)
      .map((restaurant) => toResponse(restaurant, userId))
  );
}
