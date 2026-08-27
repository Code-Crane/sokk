import type {
  RestaurantListQuery,
  RestaurantResponse
} from "../../../shared/types";
import { environment } from "../../config/environment";
import {
  KAKAO_MAX_PAGE_SIZE,
  KakaoLocalHttpClient,
  type KakaoLocalClient,
  type KakaoPlaceDocument
} from "../../integrations/kakao/kakao-local.client";
import { normalizeKakaoRestaurants } from "../../integrations/kakao/kakao-restaurant.normalizer";
import { repositories } from "../../repositories";
import type { RestaurantRepository } from "../../repositories/interfaces/restaurant.repository";
import { listRestaurants } from "./restaurant.service";

const MAX_RADIUS_KM = 20;
const MAX_KAKAO_PAGES = 3;
const DEFAULT_RADIUS_KM = 5;
const DEFAULT_CACHE_TTL_MS = 30_000;

export interface RestaurantDiscoveryInput {
  latitude: unknown;
  longitude: unknown;
  radiusKm?: unknown;
}

export interface RestaurantDiscoverySummary {
  fetchedCount: number;
  normalizedCount: number;
  upsertedCount: number;
  cacheHit: boolean;
}

type ListNearbyRestaurants = (
  userId: string,
  query: RestaurantListQuery
) => Promise<RestaurantResponse[]>;

interface DiscoveryDependencies {
  client: KakaoLocalClient;
  restaurantRepository: RestaurantRepository;
  listNearbyRestaurants: ListNearbyRestaurants;
  cacheTtlMs?: number;
  now?: () => number;
}

interface NormalizedDiscoveryInput {
  latitude: number;
  longitude: number;
  radiusKm: number;
}

interface CacheEntry {
  expiresAt: number;
  promise: Promise<Omit<RestaurantDiscoverySummary, "cacheHit">>;
}

function invalid(message: string): never {
  throw Object.assign(new Error(message), { statusCode: 400 });
}

function requiredNumber(value: unknown, name: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return invalid(`${name} must be a valid number.`);
  }
  return value;
}

function normalizeDiscoveryInput(
  input: RestaurantDiscoveryInput
): NormalizedDiscoveryInput {
  const latitude = requiredNumber(input.latitude, "latitude");
  const longitude = requiredNumber(input.longitude, "longitude");
  const radiusKm =
    input.radiusKm === undefined
      ? DEFAULT_RADIUS_KM
      : requiredNumber(input.radiusKm, "radiusKm");

  if (latitude < -90 || latitude > 90) {
    return invalid("latitude must be between -90 and 90.");
  }
  if (longitude < -180 || longitude > 180) {
    return invalid("longitude must be between -180 and 180.");
  }
  if (radiusKm <= 0 || radiusKm > MAX_RADIUS_KM) {
    return invalid(`radiusKm must be greater than 0 and at most ${MAX_RADIUS_KM}.`);
  }

  return { latitude, longitude, radiusKm };
}

function cacheKey(input: NormalizedDiscoveryInput): string {
  return [
    input.latitude.toFixed(4),
    input.longitude.toFixed(4),
    input.radiusKm.toFixed(3)
  ].join(":");
}

export class KakaoRestaurantDiscoveryService {
  private readonly cache = new Map<string, CacheEntry>();
  private readonly cacheTtlMs: number;
  private readonly now: () => number;

  constructor(private readonly dependencies: DiscoveryDependencies) {
    this.cacheTtlMs = dependencies.cacheTtlMs ?? DEFAULT_CACHE_TTL_MS;
    this.now = dependencies.now ?? Date.now;
  }

  async discover(
    userId: string,
    input: RestaurantDiscoveryInput
  ): Promise<RestaurantResponse[]> {
    const normalized = normalizeDiscoveryInput(input);
    await this.sync(normalized);

    return this.dependencies.listNearbyRestaurants(userId, {
      lat: normalized.latitude,
      lng: normalized.longitude,
      radiusKm: normalized.radiusKm,
      limit: 100,
      offset: 0
    });
  }

  async sync(
    input: RestaurantDiscoveryInput | NormalizedDiscoveryInput
  ): Promise<RestaurantDiscoverySummary> {
    const normalized = normalizeDiscoveryInput(input);
    const key = cacheKey(normalized);
    const currentTime = this.now();
    const cached = this.cache.get(key);

    if (cached && cached.expiresAt > currentTime) {
      return { ...(await cached.promise), cacheHit: true };
    }

    const promise = this.fetchAndUpsert(normalized);
    const entry: CacheEntry = {
      expiresAt: currentTime + Math.max(this.cacheTtlMs, 1),
      promise
    };
    this.cache.set(key, entry);

    try {
      return { ...(await promise), cacheHit: false };
    } catch (error) {
      if (this.cache.get(key) === entry) this.cache.delete(key);
      throw error;
    }
  }

  clearCache(): void {
    this.cache.clear();
  }

  private async fetchAndUpsert(
    input: NormalizedDiscoveryInput
  ): Promise<Omit<RestaurantDiscoverySummary, "cacheHit">> {
    const documents: KakaoPlaceDocument[] = [];

    for (let page = 1; page <= MAX_KAKAO_PAGES; page += 1) {
      const response = await this.dependencies.client.searchRestaurantsByCategory({
        latitude: input.latitude,
        longitude: input.longitude,
        radiusMeters: Math.round(input.radiusKm * 1000),
        page,
        size: KAKAO_MAX_PAGE_SIZE
      });
      documents.push(...response.documents);
      if (response.meta.is_end) break;
    }

    const restaurants = normalizeKakaoRestaurants(documents);
    const upserted = await this.dependencies.restaurantRepository.upsertMany(
      restaurants
    );

    return {
      fetchedCount: documents.length,
      normalizedCount: restaurants.length,
      upsertedCount: upserted.length
    };
  }
}

const kakaoRestaurantDiscoveryService = new KakaoRestaurantDiscoveryService({
  client: new KakaoLocalHttpClient(environment.kakaoRestApiKey),
  restaurantRepository: repositories.restaurants,
  listNearbyRestaurants: listRestaurants
});

export function discoverNearbyRestaurantsFromKakao(
  userId: string,
  input: RestaurantDiscoveryInput
): Promise<RestaurantResponse[]> {
  return kakaoRestaurantDiscoveryService.discover(userId, input);
}

export function syncNearbyRestaurantsFromKakao(
  input: RestaurantDiscoveryInput
): Promise<RestaurantDiscoverySummary> {
  return kakaoRestaurantDiscoveryService.sync(input);
}
