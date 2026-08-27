process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";

const {
  KakaoLocalHttpClient,
  normalizeKakaoCategorySearchInput
} = require("../dist/server/integrations/kakao/kakao-local.client");
const {
  normalizeKakaoRestaurant
} = require("../dist/server/integrations/kakao/kakao-restaurant.normalizer");
const {
  KakaoRestaurantDiscoveryService
} = require("../dist/server/services/restaurant/kakao-restaurant-discovery.service");
const {
  memoryRestaurantRepository
} = require("../dist/server/repositories/memory/restaurant.memory.repository");
const { db } = require("../dist/server/models/inMemoryDb");

const results = [];

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

function document(overrides = {}) {
  return {
    id: "kakao-place-1",
    place_name: "Kakao test restaurant",
    category_name: "음식점 > 한식 > 국밥",
    category_group_code: "FD6",
    category_group_name: "음식점",
    phone: "051-000-0000",
    address_name: "부산 동구 지번 1",
    road_address_name: "부산 동구 도로 1",
    x: "129.037020",
    y: "35.114628",
    place_url: "https://place.map.kakao.com/test",
    distance: "120",
    ...overrides
  };
}

function response(documents, isEnd = true) {
  return {
    meta: {
      total_count: documents.length,
      pageable_count: documents.length,
      is_end: isEnd
    },
    documents
  };
}

function errorStatus(error) {
  return typeof error?.statusCode === "number" ? error.statusCode : undefined;
}

async function expectReject(name, action, expectedStatus) {
  try {
    await action();
    record(name, false, "did not reject");
  } catch (error) {
    record(name, errorStatus(error) === expectedStatus, `status=${errorStatus(error)}`);
    return error;
  }
  return undefined;
}

async function testNormalization() {
  const normalized = normalizeKakaoRestaurant(document());
  record(
    "road address has priority",
    normalized?.address === "부산 동구 도로 1" &&
      normalized?.roadAddress === "부산 동구 도로 1"
  );
  record(
    "x and y map to longitude and latitude",
    normalized?.longitude === 129.03702 && normalized?.latitude === 35.114628
  );
  record(
    "provider namespace mapping",
    normalized?.placeProvider === "kakao" &&
      normalized?.placeProviderId === "kakao-place-1"
  );
  record(
    "category leaf and minimal metadata",
    normalized?.category === "국밥" &&
      normalized?.metadata?.categoryGroupCode === "FD6" &&
      normalized?.metadata?.placeUrl === "https://place.map.kakao.com/test"
  );

  const fallback = normalizeKakaoRestaurant(
    document({ road_address_name: "", address_name: "부산 동구 지번 2" })
  );
  record(
    "address fallback",
    fallback?.address === "부산 동구 지번 2" && fallback?.roadAddress === undefined
  );
}

async function testRepositoryUpsert() {
  db.restaurants.clear();
  db.restaurantFavorites.clear();
  const first = normalizeKakaoRestaurant(document());
  if (!first) throw new Error("normalization fixture failed");

  const [created] = await memoryRestaurantRepository.upsertMany([first]);
  db.restaurantFavorites.set(`user:${created.id}`, {
    userId: "user",
    restaurantId: created.id,
    createdAt: new Date().toISOString()
  });
  const updatedInput = normalizeKakaoRestaurant(
    document({ place_name: "Updated Kakao restaurant", phone: "" })
  );
  if (!updatedInput) throw new Error("updated normalization fixture failed");
  const [updated] = await memoryRestaurantRepository.upsertMany([
    updatedInput,
    updatedInput
  ]);

  record(
    "repeated provider place does not duplicate",
    db.restaurants.size === 1 && created.id === updated.id
  );
  record(
    "updated Kakao data updates existing row",
    updated.name === "Updated Kakao restaurant" && updated.phone === undefined
  );
  record(
    "stable provider id preserves relations",
    created.id.startsWith("restaurant_kakao_") &&
      db.restaurantFavorites.get(`user:${created.id}`)?.restaurantId === updated.id
  );
}

async function testDiscoveryFlow() {
  db.restaurants.clear();
  db.restaurantFavorites.clear();
  let clientCalls = 0;
  let capturedQuery;
  const client = {
    async searchRestaurantsByCategory(input) {
      clientCalls += 1;
      return response([document()]);
    }
  };
  const service = new KakaoRestaurantDiscoveryService({
    client,
    restaurantRepository: memoryRestaurantRepository,
    cacheTtlMs: 30_000,
    listNearbyRestaurants: async (_userId, query) => {
      capturedQuery = query;
      const rows = await memoryRestaurantRepository.list({
        nearby: {
          latitude: query.lat,
          longitude: query.lng,
          radiusKm: query.radiusKm
        },
        limit: query.limit,
        offset: query.offset
      });
      return rows.map(({ restaurant, distanceMeters }) => ({
        ...restaurant,
        distanceMeters,
        isFavorite: false,
        activePartyCount: 0
      }));
    }
  });

  const input = { latitude: 35.114628, longitude: 129.03702, radiusKm: 2 };
  const first = await service.discover("user", input);
  const secondSummary = await service.sync(input);

  record(
    "discovery returns existing nearby contract",
    first.length === 1 &&
      typeof first[0].distanceMeters === "number" &&
      first[0].isFavorite === false &&
      first[0].activePartyCount === 0
  );
  record(
    "nearby query preserves requested coordinates and radius",
    capturedQuery?.lat === input.latitude &&
      capturedQuery?.lng === input.longitude &&
      capturedQuery?.radiusKm === input.radiusKm &&
      capturedQuery?.limit === 100
  );
  record(
    "TTL cache prevents duplicate external calls",
    clientCalls === 1 && secondSummary.cacheHit === true && db.restaurants.size === 1
  );

  await expectReject(
    "invalid coordinates rejected before Kakao call",
    () => service.discover("user", { latitude: 91, longitude: 129, radiusKm: 2 }),
    400
  );
  await expectReject(
    "radius over official limit rejected",
    () => service.discover("user", { latitude: 35, longitude: 129, radiusKm: 21 }),
    400
  );
  record("invalid input did not call Kakao", clientCalls === 1);

  const pageCalls = [];
  const pagedService = new KakaoRestaurantDiscoveryService({
    client: {
      async searchRestaurantsByCategory(input) {
        pageCalls.push(input.page);
        return input.page === 1
          ? response([document({ id: "page-1" })], false)
          : response([document({ id: "page-2" })], true);
      }
    },
    restaurantRepository: memoryRestaurantRepository,
    listNearbyRestaurants: async () => []
  });
  const pagedSummary = await pagedService.sync(input);
  record(
    "pagination stops at provider end marker",
    pageCalls.join(",") === "1,2" && pagedSummary.upsertedCount === 2
  );

  db.restaurants.clear();
  const failingService = new KakaoRestaurantDiscoveryService({
    client: {
      async searchRestaurantsByCategory(input) {
        if (input.page === 1) return response([document()], false);
        throw Object.assign(new Error("upstream failed"), { statusCode: 502 });
      }
    },
    restaurantRepository: memoryRestaurantRepository,
    listNearbyRestaurants: async () => []
  });
  await expectReject("external failure is propagated", () => failingService.sync(input), 502);
  record("external failure causes no partial upsert", db.restaurants.size === 0);
}

async function testClientLimitsAndErrors() {
  const normalized = normalizeKakaoCategorySearchInput({
    latitude: 35,
    longitude: 129,
    radiusMeters: 99_999,
    page: 99,
    size: 99
  });
  record(
    "official radius page and size limits are clamped",
    normalized.radiusMeters === 20_000 && normalized.page === 45 && normalized.size === 15
  );

  const placeholderKey = "unit-test-rest-key";
  for (const status of [401, 403]) {
    const client = new KakaoLocalHttpClient(
      placeholderKey,
      async () => new Response("{}", { status })
    );
    const error = await expectReject(
      `external ${status} mapped safely`,
      () =>
        client.searchRestaurantsByCategory({
          latitude: 35,
          longitude: 129,
          radiusMeters: 1000
        }),
      502
    );
    record(
      `external ${status} does not expose key`,
      !String(error?.message).includes(placeholderKey)
    );
  }

  await expectReject(
    "external 429 preserved",
    () =>
      new KakaoLocalHttpClient(
        placeholderKey,
        async () => new Response("{}", { status: 429 })
      ).searchRestaurantsByCategory({
        latitude: 35,
        longitude: 129,
        radiusMeters: 1000
      }),
    429
  );
  await expectReject(
    "external 5xx mapped to provider error",
    () =>
      new KakaoLocalHttpClient(
        placeholderKey,
        async () => new Response("{}", { status: 503 })
      ).searchRestaurantsByCategory({
        latitude: 35,
        longitude: 129,
        radiusMeters: 1000
      }),
    502
  );

  const timeoutClient = new KakaoLocalHttpClient(
    placeholderKey,
    (_url, options) =>
      new Promise((_resolve, reject) => {
        options.signal.addEventListener("abort", () => {
          const error = new Error("aborted");
          error.name = "AbortError";
          reject(error);
        });
      }),
    5
  );
  await expectReject(
    "external timeout mapped to gateway timeout",
    () =>
      timeoutClient.searchRestaurantsByCategory({
        latitude: 35,
        longitude: 129,
        radiusMeters: 1000
      }),
    504
  );

  let requestUrl;
  let authorizationPresent = false;
  const serializationClient = new KakaoLocalHttpClient(
    placeholderKey,
    async (url, options) => {
      requestUrl = String(url);
      authorizationPresent = options.headers.Authorization === `KakaoAK ${placeholderKey}`;
      return new Response(JSON.stringify(response([])), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }
  );
  await serializationClient.searchRestaurantsByCategory({
    latitude: 35,
    longitude: 129,
    radiusMeters: 1000,
    page: 2,
    size: 10
  });
  const parsedUrl = new URL(requestUrl);
  record(
    "Kakao category query and authorization serialized",
    authorizationPresent &&
      parsedUrl.searchParams.get("category_group_code") === "FD6" &&
      parsedUrl.searchParams.get("sort") === "distance" &&
      parsedUrl.searchParams.get("page") === "2" &&
      parsedUrl.searchParams.get("size") === "10"
  );
}

async function testEndpointSafety() {
  const { app } = require("../dist/server/app");
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const api = async (path, token, options = {}) => {
    const result = await fetch(`${baseUrl}${path}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {})
      }
    });
    return {
      status: result.status,
      payload: await result.json().catch(() => undefined)
    };
  };

  try {
    const signup = await api("/api/auth/signup", undefined, {
      method: "POST",
      body: JSON.stringify({
        email: `kakao-endpoint-${Date.now()}@example.com`,
        nickname: "kakao-endpoint-tester",
        phoneNumber: "01012345678"
      })
    });
    const unauthenticated = await api("/api/restaurants/discover", undefined, {
      method: "POST",
      body: JSON.stringify({ latitude: 35, longitude: 129, radiusKm: 2 })
    });
    record("discovery endpoint requires authentication", unauthenticated.status === 401);

    const invalid = await api("/api/restaurants/discover", signup.payload?.token, {
      method: "POST",
      body: JSON.stringify({ latitude: null, longitude: 129, radiusKm: 2 })
    });
    record("discovery endpoint validates body", invalid.status === 400);

    const missingConfig = await api(
      "/api/restaurants/discover",
      signup.payload?.token,
      {
        method: "POST",
        body: JSON.stringify({ latitude: 35, longitude: 129, radiusKm: 2 })
      }
    );
    record(
      "missing server key is a safe configuration error",
      missingConfig.status === 503 &&
        missingConfig.payload?.message === "Restaurant discovery is not configured."
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function main() {
  try {
    await testNormalization();
    await testRepositoryUpsert();
    await testDiscoveryFlow();
    await testClientLimitsAndErrors();
    await testEndpointSafety();
  } finally {
    db.restaurantFavorites.clear();
    db.restaurants.clear();
  }

  for (const result of results) {
    console.log(
      `[KAKAO_DISCOVERY] ${result.pass ? "PASS" : "FAIL"} ${result.name}` +
        (result.details ? ` - ${result.details}` : "")
    );
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(
    `[KAKAO_DISCOVERY] FAIL ${error instanceof Error ? error.message : "unknown error"}`
  );
  process.exitCode = 1;
});
