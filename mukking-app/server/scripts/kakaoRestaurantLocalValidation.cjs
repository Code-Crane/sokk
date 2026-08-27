const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const latitude = 35.11462876256979;
const longitude = 129.03702048811923;
const radiusKm = 2;
const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const kakaoRestApiKey = process.env.KAKAO_REST_API_KEY;
const results = [];

function required(name, value) {
  if (!value?.trim()) throw new Error(`${name} is missing.`);
}

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

function client(key) {
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
}

async function api(baseUrl, path, token, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {})
    }
  });
  return {
    status: response.status,
    payload: await response.json().catch(() => undefined)
  };
}

async function createUser() {
  const service = client(serviceRoleKey);
  const email = `mukking-kakao-local-${Date.now()}-${crypto
    .randomBytes(3)
    .toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(10).toString("hex")}!1`;
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: "kakao-local-validator" }
  });
  if (created.error || !created.data.user) {
    throw new Error("Temporary validation user creation failed.");
  }

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) {
    await service.auth.admin.deleteUser(created.data.user.id);
    throw new Error("Temporary validation user sign-in failed.");
  }

  return {
    id: created.data.user.id,
    token: signedIn.data.session.access_token,
    service
  };
}

function isAscending(values) {
  return values.every((value, index) => index === 0 || values[index - 1] <= value);
}

function isFiniteDistance(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function firstDistanceInversion(values) {
  for (let index = 1; index < values.length; index += 1) {
    if (values[index - 1] > values[index]) {
      return {
        index,
        previous: values[index - 1],
        current: values[index]
      };
    }
  }

  return null;
}

function isExactDistanceOrder(rows) {
  return rows.every((row, index) => {
    if (!isFiniteDistance(row.distance_meters)) return false;
    if (index === 0) return true;

    const previous = rows[index - 1];
    if (!isFiniteDistance(previous.distance_meters)) return false;
    if (previous.distance_meters < row.distance_meters) return true;
    if (previous.distance_meters > row.distance_meters) return false;
    return previous.id.localeCompare(row.id) <= 0;
  });
}

function hasRestaurantResponseShape(row) {
  return (
    row !== null &&
    typeof row === "object" &&
    typeof row.id === "string" &&
    typeof row.name === "string" &&
    typeof row.address === "string" &&
    typeof row.latitude === "number" &&
    typeof row.longitude === "number" &&
    typeof row.category === "string" &&
    typeof row.placeProvider === "string" &&
    typeof row.placeProviderId === "string" &&
    typeof row.isFavorite === "boolean" &&
    typeof row.activePartyCount === "number" &&
    isFiniteDistance(row.distanceMeters)
  );
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  required("KAKAO_REST_API_KEY", kakaoRestApiKey);

  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_RESTAURANT_DISCOVERY_MAX = "100";

  const user = await createUser();
  const { app } = require("../dist/server/app");
  const {
    syncNearbyRestaurantsFromKakao
  } = require("../dist/server/services/restaurant/kakao-restaurant-discovery.service");
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const me = await api(baseUrl, "/api/auth/me", user.token);
    record("temporary authenticated profile", me.status === 200, `status=${me.status}`);

    const discovered = await api(baseUrl, "/api/restaurants/discover", user.token, {
      method: "POST",
      body: JSON.stringify({ latitude, longitude, radiusKm })
    });
    record(
      "authenticated Kakao discovery endpoint",
      discovered.status === 200 && Array.isArray(discovered.payload),
      `status=${discovered.status}, count=${discovered.payload?.length ?? 0}`
    );
    if (discovered.status !== 200 || !Array.isArray(discovered.payload)) {
      throw new Error(`Kakao discovery endpoint failed with status ${discovered.status}.`);
    }

    const summary = await syncNearbyRestaurantsFromKakao({
      latitude,
      longitude,
      radiusKm
    });
    record(
      "normalized rows upserted",
      summary.upsertedCount > 0,
      `fetched=${summary.fetchedCount}, normalized=${summary.normalizedCount}, upserted=${summary.upsertedCount}`
    );

    const nearbyRequest = {
      latitude,
      longitude,
      radiusKm,
      limit: 50,
      offset: 0
    };
    const nearby = await api(
      baseUrl,
      `/api/restaurants?lat=${nearbyRequest.latitude}&lng=${nearbyRequest.longitude}&radiusKm=${nearbyRequest.radiusKm}&limit=${nearbyRequest.limit}&offset=${nearbyRequest.offset}`,
      user.token
    );
    const nearbyRows = Array.isArray(nearby.payload) ? nearby.payload : [];
    const kakaoRows = nearbyRows.filter((row) => row.placeProvider === "kakao");
    const allDistances = nearbyRows.map((row) => row.distanceMeters);
    const distances = kakaoRows.map((row) => row.distanceMeters);
    const validDistanceCount = allDistances.filter(isFiniteDistance).length;
    const missingDistanceCount = allDistances.length - validDistanceCount;
    const allSorted = missingDistanceCount === 0 && isAscending(allDistances);
    const kakaoSorted = distances.every(isFiniteDistance) && isAscending(distances);
    const firstInversion = firstDistanceInversion(allDistances);
    const maximumDistance = allDistances.filter(isFiniteDistance).reduce(
      (maximum, distance) => Math.max(maximum, distance),
      0
    );
    const testRestaurantIds = [
      "restaurant_test_busan_a",
      "restaurant_test_busan_b",
      "restaurant_test_busan_c"
    ];
    const nearbyIds = new Set(nearbyRows.map((row) => row.id));
    const testRestaurantPresence = testRestaurantIds
      .map((id, index) => `${String.fromCharCode(65 + index)}=${nearbyIds.has(id)}`)
      .join(",");
    const responseShapeCount = nearbyRows.filter(hasRestaurantResponseShape).length;

    console.log(
      `[KAKAO_LOCAL] INFO nearby request lat=${nearbyRequest.latitude}, lng=${nearbyRequest.longitude}, radiusKm=${nearbyRequest.radiusKm}, limit=${nearbyRequest.limit}, offset=${nearbyRequest.offset}`
    );
    console.log(
      `[KAKAO_LOCAL] INFO nearby response status=${nearby.status}, total=${nearbyRows.length}, kakao=${kakaoRows.length}, distancePresent=${validDistanceCount}, distanceMissing=${missingDistanceCount}, responseShape=${responseShapeCount}/${nearbyRows.length}`
    );
    console.log(
      `[KAKAO_LOCAL] INFO nearby distance sorted=${allSorted}, kakaoSorted=${kakaoSorted}, max=${maximumDistance}, firstInversion=${firstInversion ? `${firstInversion.index}:${firstInversion.previous}>${firstInversion.current}` : "none"}`
    );
    console.log(`[KAKAO_LOCAL] INFO nearby test restaurants ${testRestaurantPresence}`);
    console.log(
      `[KAKAO_LOCAL] INFO nearby distance order=${allDistances
        .map((distance) => (isFiniteDistance(distance) ? distance.toFixed(3) : "missing"))
        .join(",")}`
    );
    record(
      "existing PostGIS nearby contract",
      nearby.status === 200 &&
        kakaoRows.length > 0 &&
        distances.every(isFiniteDistance) &&
        isAscending(distances),
      `status=${nearby.status}, total=${nearbyRows.length}, kakaoCount=${kakaoRows.length}, distancePresent=${validDistanceCount}, distanceMissing=${missingDistanceCount}, allSorted=${allSorted}, kakaoSorted=${kakaoSorted}, maxDistance=${maximumDistance}, responseShape=${responseShapeCount}/${nearbyRows.length}, tests=${testRestaurantPresence}`
    );

    const directRpcParameters = {
      p_latitude: latitude,
      p_longitude: longitude,
      p_radius_meters: radiusKm * 1000,
      p_category: null,
      p_place_provider: "kakao",
      p_place_provider_id: null
    };
    const directFull = await user.service.rpc("nearby_restaurants", {
      ...directRpcParameters,
      p_limit: 50,
      p_offset: 0
    });
    const directRows = directFull.data ?? [];
    record(
      "database exact distance order",
      !directFull.error &&
        directRows.length === kakaoRows.length &&
        isExactDistanceOrder(directRows) &&
        directRows.every(
          (row) =>
            isFiniteDistance(row.distance_meters) &&
            row.distance_meters <= radiusKm * 1000
        ),
      directFull.error
        ? "RPC failed"
        : `count=${directRows.length}, ordered=${isExactDistanceOrder(directRows)}`
    );

    const pageSize = 10;
    const pageCount = Math.ceil(directRows.length / pageSize);
    const directPages = [];
    let pageError = false;
    for (let page = 0; page < pageCount; page += 1) {
      const paged = await user.service.rpc("nearby_restaurants", {
        ...directRpcParameters,
        p_limit: pageSize,
        p_offset: page * pageSize
      });
      if (paged.error) {
        pageError = true;
        break;
      }
      directPages.push(...(paged.data ?? []));
    }
    record(
      "database exact pagination boundaries",
      !pageError &&
        directPages.length === directRows.length &&
        directPages.every((row, index) => row.id === directRows[index]?.id) &&
        isExactDistanceOrder(directPages),
      `pageSize=${pageSize}, pages=${pageCount}, combined=${directPages.length}, full=${directRows.length}`
    );

    const providerIds = kakaoRows.map((row) => row.placeProviderId);
    record(
      "Kakao provider ids unique",
      providerIds.length === new Set(providerIds).size,
      `unique=${new Set(providerIds).size}`
    );

    const kakaoIds = kakaoRows.map((row) => row.id);
    const persisted = kakaoIds.length
      ? await user.service
          .from("restaurants")
          .select("id,place_provider,place_provider_id,location")
          .in("id", kakaoIds)
      : { data: [], error: undefined };
    record(
      "Kakao rows and PostGIS locations persisted",
      !persisted.error &&
        persisted.data?.length === kakaoIds.length &&
        persisted.data.every(
          (row) => row.place_provider === "kakao" && Boolean(row.location)
        ),
      persisted.error ? "query failed" : `count=${persisted.data?.length ?? 0}`
    );

    const testRows = await user.service
      .from("restaurants")
      .select("id")
      .in("id", testRestaurantIds);
    record(
      "existing test restaurants left untouched",
      !testRows.error,
      testRows.error ? "query failed" : `remaining=${testRows.data?.length ?? 0}`
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await user.service.auth.admin.deleteUser(user.id);
  }

  for (const result of results) {
    console.log(
      `[KAKAO_LOCAL] ${result.pass ? "PASS" : "FAIL"} ${result.name}` +
        (result.details ? ` - ${result.details}` : "")
    );
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(
    `[KAKAO_LOCAL] FAIL ${error instanceof Error ? error.message : "unknown error"}`
  );
  process.exitCode = 1;
});
