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

type NearbyRestaurantRow = RestaurantRow & {
  distance_meters: number | string;
};

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
    if (filter.nearby) {
      const { data, error } = await getSupabaseServiceRoleClient().rpc(
        "nearby_restaurants",
        {
          p_latitude: filter.nearby.latitude,
          p_longitude: filter.nearby.longitude,
          p_radius_meters: filter.nearby.radiusKm * 1000,
          p_category: filter.category ?? null,
          p_place_provider: filter.placeProvider ?? null,
          p_place_provider_id: filter.placeProviderId ?? null,
          p_limit: filter.limit ?? 100,
          p_offset: filter.offset ?? 0
        }
      );

      if (error) throwSupabaseError(error);
      return ((data ?? []) as NearbyRestaurantRow[]).map((row) => ({
        restaurant: toRestaurant(row),
        distanceMeters: Number(row.distance_meters)
      }));
    }

    let query = getSupabaseServiceRoleClient().from("restaurants").select("*");

    if (filter.category) query = query.eq("category", filter.category);
    if (filter.placeProvider) query = query.eq("place_provider", filter.placeProvider);
    if (filter.placeProviderId) query = query.eq("place_provider_id", filter.placeProviderId);

    query = query.order("created_at", { ascending: false });
    if (filter.limit !== undefined) {
      const offset = filter.offset ?? 0;
      query = query.range(offset, offset + filter.limit - 1);
    } else if (filter.offset !== undefined) {
      query = query.range(filter.offset, filter.offset + 99);
    }

    const { data, error } = await query
      .returns<RestaurantRow[]>();

    if (error) throwSupabaseError(error);
    const rows = (data ?? []).map((row): RestaurantWithDistance => ({
      restaurant: toRestaurant(row)
    }));
    return filter.limit === undefined && filter.offset !== undefined
      ? rows.slice(filter.offset)
      : rows;
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
