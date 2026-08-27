import type {
  CreateRestaurantInput,
  Restaurant,
  UpdateRestaurantInput
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { createEntityId, createProviderEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type {
  RestaurantFilter,
  RestaurantRepository,
  RestaurantWithDistance
} from "../interfaces/restaurant.repository";

const EARTH_RADIUS_METERS = 6_371_000;

function distanceMeters(
  from: { latitude: number; longitude: number },
  to: { latitude: number; longitude: number }
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

function applyFilter(
  restaurant: Restaurant,
  filter: RestaurantFilter
): RestaurantWithDistance | null {
  if (filter.category && restaurant.category !== filter.category) {
    return null;
  }

  if (filter.placeProvider && restaurant.placeProvider !== filter.placeProvider) {
    return null;
  }

  if (filter.placeProviderId && restaurant.placeProviderId !== filter.placeProviderId) {
    return null;
  }

  const distance = filter.nearby
    ? distanceMeters(filter.nearby, restaurant)
    : undefined;

  if (distance !== undefined && distance > filter.nearby!.radiusKm * 1000) {
    return null;
  }

  return { restaurant, distanceMeters: distance };
}

export const memoryRestaurantRepository: RestaurantRepository = {
  async findById(restaurantId) {
    return db.restaurants.get(restaurantId) ?? null;
  },

  async findByProviderId(placeProvider, placeProviderId) {
    return (
      Array.from(db.restaurants.values()).find(
        (restaurant) =>
          restaurant.placeProvider === placeProvider &&
          restaurant.placeProviderId === placeProviderId
      ) ?? null
    );
  },

  async list(filter: RestaurantFilter = {}) {
    const rows = Array.from(db.restaurants.values())
      .map((restaurant) => applyFilter(restaurant, filter))
      .filter((entry): entry is RestaurantWithDistance => entry !== null)
      .sort((left, right) => {
        if (left.distanceMeters !== undefined && right.distanceMeters !== undefined) {
          return left.distanceMeters - right.distanceMeters;
        }

        if (left.distanceMeters !== undefined) return -1;
        if (right.distanceMeters !== undefined) return 1;
        return right.restaurant.createdAt.localeCompare(left.restaurant.createdAt);
      });
    const offset = filter.offset ?? 0;
    const limit = filter.limit ?? rows.length;

    return rows.slice(offset, offset + limit);
  },

  async create(input: CreateRestaurantInput) {
    const duplicate = await this.findByProviderId(input.placeProvider, input.placeProviderId);

    if (duplicate) {
      throw Object.assign(new Error("Restaurant already exists for this provider place."), {
        statusCode: 409
      });
    }

    const timestamp = nowIso();
    const restaurant: Restaurant = {
      id: createEntityId("restaurant"),
      ...input,
      metadata: input.metadata ?? {},
      createdAt: timestamp,
      updatedAt: timestamp
    };

    db.restaurants.set(restaurant.id, restaurant);
    return restaurant;
  },

  async upsertMany(inputs: CreateRestaurantInput[]) {
    const uniqueInputs = Array.from(
      new Map(
        inputs.map((input) => [
          `${input.placeProvider}:${input.placeProviderId}`,
          input
        ])
      ).values()
    );
    const timestamp = nowIso();
    const rows = uniqueInputs.map((input): Restaurant => {
      const existing = Array.from(db.restaurants.values()).find(
        (restaurant) =>
          restaurant.placeProvider === input.placeProvider &&
          restaurant.placeProviderId === input.placeProviderId
      );

      if (existing) {
        return {
          ...existing,
          name: input.name,
          address: input.address,
          latitude: input.latitude,
          longitude: input.longitude,
          category: input.category,
          phone: input.phone,
          roadAddress: input.roadAddress,
          metadata: { ...existing.metadata, ...(input.metadata ?? {}) },
          updatedAt: timestamp
        };
      }

      return {
        id: createProviderEntityId(
          "restaurant",
          input.placeProvider,
          input.placeProviderId
        ),
        ...input,
        metadata: input.metadata ?? {},
        createdAt: timestamp,
        updatedAt: timestamp
      };
    });

    for (const restaurant of rows) {
      db.restaurants.set(restaurant.id, restaurant);
    }

    return rows;
  },

  async update(restaurantId, input: UpdateRestaurantInput) {
    const restaurant = db.restaurants.get(restaurantId);

    if (!restaurant) {
      throw Object.assign(new Error("Restaurant not found."), { statusCode: 404 });
    }

    const updated: Restaurant = {
      ...restaurant,
      ...input,
      imageUrl: input.imageUrl === null ? undefined : input.imageUrl ?? restaurant.imageUrl,
      phone: input.phone === null ? undefined : input.phone ?? restaurant.phone,
      roadAddress:
        input.roadAddress === null ? undefined : input.roadAddress ?? restaurant.roadAddress,
      metadata: input.metadata ?? restaurant.metadata,
      updatedAt: nowIso()
    };

    db.restaurants.set(restaurantId, updated);
    return updated;
  }
};
