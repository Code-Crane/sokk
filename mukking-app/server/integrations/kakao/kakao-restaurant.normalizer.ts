import type { CreateRestaurantInput } from "../../../shared/types";
import type { KakaoPlaceDocument } from "./kakao-local.client";

export const KAKAO_PLACE_PROVIDER = "kakao";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function categoryFrom(document: KakaoPlaceDocument): string {
  const categoryParts = text(document.category_name)
    .split(">")
    .map((part) => part.trim())
    .filter(Boolean);

  return (
    categoryParts[categoryParts.length - 1] ||
    text(document.category_group_name) ||
    "음식점"
  );
}

export function normalizeKakaoRestaurant(
  document: KakaoPlaceDocument
): CreateRestaurantInput | null {
  const providerId = text(document.id);
  const name = text(document.place_name);
  const roadAddress = text(document.road_address_name);
  const address = roadAddress || text(document.address_name);
  const latitude = Number(document.y);
  const longitude = Number(document.x);

  if (
    !providerId ||
    !name ||
    !address ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    return null;
  }

  const metadata: Record<string, unknown> = {};
  const placeUrl = text(document.place_url);
  const categoryGroupCode = text(document.category_group_code);
  if (placeUrl) metadata.placeUrl = placeUrl;
  if (categoryGroupCode) metadata.categoryGroupCode = categoryGroupCode;

  return {
    name,
    address,
    latitude,
    longitude,
    category: categoryFrom(document),
    placeProvider: KAKAO_PLACE_PROVIDER,
    placeProviderId: providerId,
    phone: text(document.phone) || undefined,
    roadAddress: roadAddress || undefined,
    metadata
  };
}

export function normalizeKakaoRestaurants(
  documents: KakaoPlaceDocument[]
): CreateRestaurantInput[] {
  const restaurants = new Map<string, CreateRestaurantInput>();

  for (const document of documents) {
    const restaurant = normalizeKakaoRestaurant(document);
    if (restaurant) restaurants.set(restaurant.placeProviderId, restaurant);
  }

  return Array.from(restaurants.values());
}
