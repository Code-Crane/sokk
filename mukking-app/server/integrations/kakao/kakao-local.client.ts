export const KAKAO_LOCAL_CATEGORY_URL =
  "https://dapi.kakao.com/v2/local/search/category.json";
export const KAKAO_FOOD_CATEGORY_CODE = "FD6";
export const KAKAO_MAX_RADIUS_METERS = 20_000;
export const KAKAO_MAX_PAGE = 45;
export const KAKAO_MAX_PAGE_SIZE = 15;

export interface KakaoPlaceDocument {
  id: string;
  place_name: string;
  category_name: string;
  category_group_code: string;
  category_group_name: string;
  phone: string;
  address_name: string;
  road_address_name: string;
  x: string;
  y: string;
  place_url: string;
  distance: string;
}

export interface KakaoCategorySearchResponse {
  meta: {
    total_count: number;
    pageable_count: number;
    is_end: boolean;
  };
  documents: KakaoPlaceDocument[];
}

export interface KakaoCategorySearchInput {
  latitude: number;
  longitude: number;
  radiusMeters: number;
  page?: number;
  size?: number;
}

export interface NormalizedKakaoCategorySearchInput {
  latitude: number;
  longitude: number;
  radiusMeters: number;
  page: number;
  size: number;
}

export interface KakaoLocalClient {
  searchRestaurantsByCategory(
    input: KakaoCategorySearchInput
  ): Promise<KakaoCategorySearchResponse>;
}

export class KakaoLocalApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code: string,
    public readonly providerStatus?: number
  ) {
    super(message);
    this.name = "KakaoLocalApiError";
  }
}

function validateCoordinate(
  value: number,
  label: string,
  minimum: number,
  maximum: number
): number {
  if (!Number.isFinite(value) || value < minimum || value > maximum) {
    throw Object.assign(
      new Error(`${label} must be between ${minimum} and ${maximum}.`),
      { statusCode: 400 }
    );
  }
  return value;
}

function clampInteger(
  value: number | undefined,
  minimum: number,
  maximum: number,
  fallback: number
): number {
  if (value === undefined || !Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.trunc(value), minimum), maximum);
}

export function normalizeKakaoCategorySearchInput(
  input: KakaoCategorySearchInput
): NormalizedKakaoCategorySearchInput {
  return {
    latitude: validateCoordinate(input.latitude, "latitude", -90, 90),
    longitude: validateCoordinate(input.longitude, "longitude", -180, 180),
    radiusMeters: clampInteger(
      input.radiusMeters,
      1,
      KAKAO_MAX_RADIUS_METERS,
      KAKAO_MAX_RADIUS_METERS
    ),
    page: clampInteger(input.page, 1, KAKAO_MAX_PAGE, 1),
    size: clampInteger(input.size, 1, KAKAO_MAX_PAGE_SIZE, KAKAO_MAX_PAGE_SIZE)
  };
}

function isKakaoCategorySearchResponse(
  value: unknown
): value is KakaoCategorySearchResponse {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return Array.isArray(record.documents) && Boolean(record.meta);
}

function providerError(status: number): KakaoLocalApiError {
  if (status === 401 || status === 403) {
    return new KakaoLocalApiError(
      "Restaurant discovery provider authentication failed.",
      502,
      "KAKAO_AUTH_ERROR",
      status
    );
  }
  if (status === 429) {
    return new KakaoLocalApiError(
      "Restaurant discovery is temporarily rate limited.",
      429,
      "KAKAO_RATE_LIMITED",
      status
    );
  }
  if (status >= 500) {
    return new KakaoLocalApiError(
      "Restaurant discovery provider is unavailable.",
      502,
      "KAKAO_UPSTREAM_ERROR",
      status
    );
  }
  return new KakaoLocalApiError(
    "Restaurant discovery provider rejected the request.",
    502,
    "KAKAO_REQUEST_REJECTED",
    status
  );
}

export class KakaoLocalHttpClient implements KakaoLocalClient {
  constructor(
    private readonly apiKey: string,
    private readonly request: typeof fetch = fetch,
    private readonly timeoutMs = 5_000
  ) {}

  async searchRestaurantsByCategory(
    input: KakaoCategorySearchInput
  ): Promise<KakaoCategorySearchResponse> {
    if (!this.apiKey.trim()) {
      throw new KakaoLocalApiError(
        "Restaurant discovery is not configured.",
        503,
        "KAKAO_NOT_CONFIGURED"
      );
    }

    const normalized = normalizeKakaoCategorySearchInput(input);
    const url = new URL(KAKAO_LOCAL_CATEGORY_URL);
    url.searchParams.set("category_group_code", KAKAO_FOOD_CATEGORY_CODE);
    url.searchParams.set("x", String(normalized.longitude));
    url.searchParams.set("y", String(normalized.latitude));
    url.searchParams.set("radius", String(normalized.radiusMeters));
    url.searchParams.set("sort", "distance");
    url.searchParams.set("page", String(normalized.page));
    url.searchParams.set("size", String(normalized.size));

    const abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), this.timeoutMs);

    try {
      const response = await this.request(url, {
        method: "GET",
        headers: {
          Authorization: `KakaoAK ${this.apiKey}`,
          Accept: "application/json"
        },
        signal: abortController.signal
      });

      if (!response.ok) throw providerError(response.status);
      const payload: unknown = await response.json();
      if (!isKakaoCategorySearchResponse(payload)) {
        throw new KakaoLocalApiError(
          "Restaurant discovery provider returned an invalid response.",
          502,
          "KAKAO_INVALID_RESPONSE"
        );
      }
      return payload;
    } catch (error) {
      if (error instanceof KakaoLocalApiError) throw error;
      if (abortController.signal.aborted) {
        throw new KakaoLocalApiError(
          "Restaurant discovery provider timed out.",
          504,
          "KAKAO_TIMEOUT"
        );
      }
      throw new KakaoLocalApiError(
        "Restaurant discovery provider is unavailable.",
        502,
        "KAKAO_NETWORK_ERROR"
      );
    } finally {
      clearTimeout(timeout);
    }
  }
}
