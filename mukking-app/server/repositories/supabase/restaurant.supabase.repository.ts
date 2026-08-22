import type {
  CreateRestaurantInput,
  Restaurant,
  UpdateRestaurantInput
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  RestaurantFilter,
  RestaurantRepository,
  RestaurantWithDistance
} from "../interfaces/restaurant.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type RestaurantRow = {
  id: string;
  name: string;
  address: string;
  latitude: number | string;
  longitude: number | string;
  category: string;
  place_provider: string;
  place_provider_id: string;
  image_url?: string | null;
  phone?: string | null;
  road_address?: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
};

const EARTH_RADIUS_METERS = 6_371_000;

function toRestaurant(row: RestaurantRow): Restaurant {
  return {
    id: row.id,
    name: row.name,
    address: row.address,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    category: row.category,
    placeProvider: row.place_provider,
    placeProviderId: row.place_provider_id,
    imageUrl: row.image_url ?? undefined,
    phone: row.phone ?? undefined,
    roadAddress: row.road_address ?? undefined,
    metadata: row.metadata ?? {},
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function calculateDistanceMeters(
  from: { latitude: number; longitude: number },
  to: Restaurant
): number {
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(toRadians(from.latitude)) *
      Math.cos(toRadians(to.latitude)) *
      Math.sin(longitudeDelta / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export const supabaseRestaurantRepository: RestaurantRepository = {
  async findById(restaurantId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurants")
      .select("*")
      .eq("id", restaurantId)
      .maybeSingle<RestaurantRow>();

    if (error) throwSupabaseError(error);
    return data ? toRestaurant(data) : null;
  },

  async findByProviderId(placeProvider, placeProviderId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurants")
      .select("*")
      .eq("place_provider", placeProvider)
      .eq("place_provider_id", placeProviderId)
      .maybeSingle<RestaurantRow>();

    if (error) throwSupabaseError(error);
    return data ? toRestaurant(data) : null;
  },

  async list(filter: RestaurantFilter = {}) {
    let query = getSupabaseServiceRoleClient().from("restaurants").select("*");

    if (filter.category) query = query.eq("category", filter.category);
    if (filter.placeProvider) query = query.eq("place_provider", filter.placeProvider);
    if (filter.placeProviderId) query = query.eq("place_provider_id", filter.placeProviderId);

    const { data, error } = await query
      .order("created_at", { ascending: false })
      .returns<RestaurantRow[]>();

    if (error) throwSupabaseError(error);

    const nearbyRows = (data ?? [])
      .map(toRestaurant)
      .map((restaurant): RestaurantWithDistance => ({
        restaurant,
        distanceMeters: filter.nearby
          ? calculateDistanceMeters(filter.nearby, restaurant)
          : undefined
      }))
      .filter(
        (entry) =>
          entry.distanceMeters === undefined ||
          entry.distanceMeters <= (filter.nearby?.radiusKm ?? Infinity) * 1000
      )
      .sort((left, right) => {
        if (left.distanceMeters !== undefined && right.distanceMeters !== undefined) {
          return left.distanceMeters - right.distanceMeters;
        }
        return right.restaurant.createdAt.localeCompare(left.restaurant.createdAt);
      });

    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? nearbyRows.length;
    return nearbyRows.slice(offset, offset + limit);
  },

  async create(input: CreateRestaurantInput) {
    const timestamp = nowIso();
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurants")
      .insert({
        id: createEntityId("restaurant"),
        name: input.name,
        address: input.address,
        latitude: input.latitude,
        longitude: input.longitude,
        category: input.category,
        place_provider: input.placeProvider,
        place_provider_id: input.placeProviderId,
        image_url: input.imageUrl,
        phone: input.phone,
        road_address: input.roadAddress,
        metadata: input.metadata ?? {},
        created_at: timestamp,
        updated_at: timestamp
      })
      .select("*")
      .single<RestaurantRow>();

    if (error) throwSupabaseError(error);
    return toRestaurant(ensureRow(data, "Restaurant was not created."));
  },

  async update(restaurantId, input: UpdateRestaurantInput) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("restaurants")
      .update({
        name: input.name,
        address: input.address,
        latitude: input.latitude,
        longitude: input.longitude,
        category: input.category,
        image_url: input.imageUrl,
        phone: input.phone,
        road_address: input.roadAddress,
        metadata: input.metadata,
        updated_at: nowIso()
      })
      .eq("id", restaurantId)
      .select("*")
      .single<RestaurantRow>();

    if (error) throwSupabaseError(error);
    return toRestaurant(ensureRow(data, "Restaurant not found."));
  }
};
