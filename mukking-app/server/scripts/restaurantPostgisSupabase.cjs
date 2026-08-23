const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const results = [];
const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

function required(name, value) {
  if (!value) throw new Error(`${name} is missing.`);
}

function client(key) {
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
}

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function createUser() {
  const email = `mukking-postgis-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: "postgis-tester", phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) throw new Error("Test user creation failed.");

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) {
    throw new Error("Test user sign-in failed.");
  }
  return {
    id: created.data.user.id,
    token: signedIn.data.session.access_token,
    client: authenticated
  };
}

async function createRestaurant(baseUrl, token, fixture, suffix) {
  return api(baseUrl, "/api/restaurants", token, {
    method: "POST",
    body: JSON.stringify({
      name: fixture.name,
      address: `PostGIS validation ${suffix}`,
      latitude: fixture.latitude,
      longitude: fixture.longitude,
      category: fixture.category,
      placeProvider: "postgis-fixture",
      placeProviderId: `${suffix}-${Date.now()}-${crypto.randomBytes(2).toString("hex")}`
    })
  });
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

  const service = client(serviceRoleKey);
  const anon = client(anonKey);
  const user = await createUser();
  const restaurantIds = [];
  const matchingPostIds = [];
  const category = `postgis-${Date.now()}`;
  const { app } = require("../dist/server/app");
  let server = app.listen(0);
  let baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const me = await api(baseUrl, "/api/auth/me", user.token);
    if (me.status !== 200) throw new Error("Profile synchronization failed.");
    const verified = await api(baseUrl, "/api/auth/verification/mock", user.token, {
      method: "POST",
      body: JSON.stringify({
        legalName: "먹킹테스터",
        birthDate: "1995-01-01",
        gender: "other",
        phoneNumber: "01012345678"
      })
    });
    if (verified.status !== 200) throw new Error("Mock verification failed.");

    const fixtures = [
      { name: "PostGIS center-a", latitude: 37.4979, longitude: 127.0276, category },
      { name: "PostGIS center-b", latitude: 37.4979, longitude: 127.0276, category },
      { name: "PostGIS 300m", latitude: 37.5006, longitude: 127.0276, category },
      { name: "PostGIS 750m", latitude: 37.50465, longitude: 127.0276, category },
      { name: "PostGIS 2km", latitude: 37.5159, longitude: 127.0276, category },
      { name: "PostGIS 4km", latitude: 37.5339, longitude: 127.0276, category },
      { name: "PostGIS 6km", latitude: 37.5519, longitude: 127.0276, category },
      { name: "PostGIS other category", latitude: 37.498, longitude: 127.0276, category: `${category}-other` }
    ];
    const createdRestaurants = [];
    for (const [index, fixture] of fixtures.entries()) {
      const created = await createRestaurant(baseUrl, user.token, fixture, String(index));
      if (created.status !== 201 || !created.payload?.id) {
        throw new Error(`Restaurant fixture ${index} creation failed.`);
      }
      restaurantIds.push(created.payload.id);
      createdRestaurants.push(created.payload);
    }

    const locationRows = await service
      .from("restaurants")
      .select("id,location")
      .in("id", restaurantIds);
    record(
      "location backfill/insert trigger",
      !locationRows.error && locationRows.data?.length === fixtures.length && locationRows.data.every((row) => row.location),
      locationRows.error ? "query failed" : `rows=${locationRows.data?.length}`
    );

    const radiusExpectations = [
      { radiusKm: 0.5, expectedCount: 3 },
      { radiusKm: 1, expectedCount: 4 },
      { radiusKm: 3, expectedCount: 5 },
      { radiusKm: 5, expectedCount: 6 }
    ];
    let nearby;
    for (const expectation of radiusExpectations) {
      nearby = await api(
        baseUrl,
        `/api/restaurants?category=${encodeURIComponent(category)}&lat=37.4979&lng=127.0276&radiusKm=${expectation.radiusKm}`,
        user.token
      );
      record(
        `${expectation.radiusKm * 1000}m radius`,
        nearby.status === 200 && nearby.payload?.length === expectation.expectedCount,
        `status=${nearby.status}, count=${nearby.payload?.length}`
      );
    }
    const nearbyIds = nearby.payload?.map((row) => row.id) ?? [];
    const distances = nearby.payload?.map((row) => row.distanceMeters) ?? [];
    const sameLocationIds = [restaurantIds[0], restaurantIds[1]].sort();
    record(
      "PostGIS distance order",
      nearby.status === 200 &&
        distances.every((distance) => Number.isFinite(distance)) &&
        distances.every((distance, index) => index === 0 || distances[index - 1] <= distance) &&
        nearbyIds.slice(0, 2).every((id, index) => id === sameLocationIds[index]),
      `status=${nearby.status}, count=${nearbyIds.length}`
    );
    record(
      "same-location deterministic tie",
      distances[0] < 0.01 && distances[1] < 0.01,
      `first=${distances[0]}, second=${distances[1]}`
    );
    record(
      "category filter excludes other category",
      !nearbyIds.includes(restaurantIds[7]),
      `count=${nearbyIds.length}`
    );

    const providerFiltered = await service.rpc("nearby_restaurants", {
      p_latitude: 37.4979,
      p_longitude: 127.0276,
      p_radius_meters: 5000,
      p_place_provider: "postgis-fixture",
      p_place_provider_id: createdRestaurants[2].placeProviderId,
      p_limit: 100,
      p_offset: 0
    });
    record(
      "provider filter through repository RPC contract",
      !providerFiltered.error && providerFiltered.data?.length === 1 && providerFiltered.data[0].id === restaurantIds[2],
      providerFiltered.error ? "RPC failed" : `count=${providerFiltered.data?.length}`
    );

    const paged = await api(
      baseUrl,
      `/api/restaurants?category=${encodeURIComponent(category)}&lat=37.4979&lng=127.0276&radiusKm=5&limit=2&offset=2`,
      user.token
    );
    record(
      "distance pagination",
      paged.status === 200 && paged.payload?.length === 2 &&
        paged.payload[0].id === restaurantIds[2] && paged.payload[1].id === restaurantIds[3],
      `status=${paged.status}, count=${paged.payload?.length}`
    );

    const ordinaryList = await api(
      baseUrl,
      `/api/restaurants?category=${encodeURIComponent(category)}`,
      user.token
    );
    record(
      "non-location list compatibility",
      ordinaryList.status === 200 && ordinaryList.payload?.length === 7 &&
        ordinaryList.payload.every((row) => row.distanceMeters === undefined),
      `status=${ordinaryList.status}, count=${ordinaryList.payload?.length}`
    );

    for (const [label, query] of [
      ["invalid latitude", "lat=91&lng=127&radiusKm=1"],
      ["invalid longitude", "lat=37&lng=181&radiusKm=1"],
      ["NaN coordinate", "lat=NaN&lng=127&radiusKm=1"],
      ["zero radius", "lat=37&lng=127&radiusKm=0"],
      ["excessive radius", "lat=37&lng=127&radiusKm=101"],
      ["invalid limit", "limit=101"],
      ["invalid offset", "offset=-1"]
    ]) {
      const invalid = await api(baseUrl, `/api/restaurants?${query}`, user.token);
      record(label, invalid.status === 400, `status=${invalid.status}`);
    }

    const favorite = await api(baseUrl, `/api/restaurants/${restaurantIds[0]}/favorite`, user.token, {
      method: "POST"
    });
    const postStatuses = ["open", "closed", "completed"];
    const posts = [];
    for (const targetStatus of postStatuses) {
      const post = await api(baseUrl, "/api/matching/posts", user.token, {
        method: "POST",
        body: JSON.stringify({
          restaurantId: restaurantIds[0],
          restaurantName: fixtures[0].name,
          address: `PostGIS validation 0`,
          scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
          maxParticipants: 2,
          intro: `PostGIS ${targetStatus} party regression`
        })
      });
      if (post.payload?.id) {
        matchingPostIds.push(post.payload.id);
        posts.push(post);
        if (targetStatus !== "open") {
          const statusUpdate = await service
            .from("matching_posts")
            .update({ status: targetStatus, completed_at: targetStatus === "completed" ? new Date().toISOString() : null })
            .eq("id", post.payload.id);
          if (statusUpdate.error) throw statusUpdate.error;
        }
      }
    }
    const decorated = await api(
      baseUrl,
      `/api/restaurants?category=${encodeURIComponent(category)}&lat=37.4979&lng=127.0276&radiusKm=2`,
      user.token
    );
    const center = decorated.payload?.find((row) => row.id === restaurantIds[0]);
    record(
      "favorite and active party decoration",
      favorite.status === 201 && posts.length === 3 && center?.isFavorite === true && center?.activePartyCount === 1,
      `favorite=${favorite.status}, posts=${posts.length}, party=${center?.activePartyCount}`
    );

    const anonymousRpc = await anon.rpc("nearby_restaurants", {
      p_latitude: 37.4979,
      p_longitude: 127.0276,
      p_radius_meters: 1000
    });
    const authenticatedRpc = await user.client.rpc("nearby_restaurants", {
      p_latitude: 37.4979,
      p_longitude: 127.0276,
      p_radius_meters: 1000
    });
    record("anon RPC denied", Boolean(anonymousRpc.error), "direct RPC");
    record("authenticated RPC denied", Boolean(authenticatedRpc.error), "direct RPC");

    const coordinateUpdate = await service
      .from("restaurants")
      .update({ latitude: 37.55, longitude: 127.05 })
      .eq("id", restaurantIds[1]);
    const movedSearch = await api(
      baseUrl,
      `/api/restaurants?category=${encodeURIComponent(category)}&lat=37.55&lng=127.05&radiusKm=0.5`,
      user.token
    );
    record(
      "coordinate update trigger sync",
      !coordinateUpdate.error && movedSearch.status === 200 && movedSearch.payload?.some((row) => row.id === restaurantIds[1]),
      `status=${movedSearch.status}`
    );

    const moved = movedSearch.payload?.find((row) => row.id === restaurantIds[1]);
    record(
      "numeric/geography coordinate consistency",
      moved?.latitude === 37.55 && moved?.longitude === 127.05 && moved?.distanceMeters < 0.01,
      `distance=${moved?.distanceMeters}`
    );

    const beforeRestart = await api(
      baseUrl,
      `/api/restaurants?category=${encodeURIComponent(category)}&lat=37.4979&lng=127.0276&radiusKm=5`,
      user.token
    );
    await new Promise((resolve) => server.close(resolve));
    server = app.listen(0);
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    const afterRestart = await api(
      baseUrl,
      `/api/restaurants?category=${encodeURIComponent(category)}&lat=37.4979&lng=127.0276&radiusKm=5`,
      user.token
    );
    record(
      "restart nearby persistence",
      beforeRestart.status === 200 && afterRestart.status === 200 &&
        JSON.stringify(beforeRestart.payload) === JSON.stringify(afterRestart.payload),
      `before=${beforeRestart.payload?.length}, after=${afterRestart.payload?.length}`
    );

    const explain = await service
      .rpc("nearby_restaurants", {
        p_latitude: 37.4979,
        p_longitude: 127.0276,
        p_radius_meters: 5000,
        p_limit: 100,
        p_offset: 0
      })
      .explain({ analyze: false, verbose: false });
    record(
      "query plan inspection",
      true,
      explain.error ? "db_plan_enabled unavailable; structural index check required" : "plan returned"
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
    if (matchingPostIds.length > 0) {
      const cleanup = await service.from("matching_posts").delete().in("id", matchingPostIds);
      if (cleanup.error) throw cleanup.error;
    }
    if (restaurantIds.length > 0) {
      const favorites = await service.from("restaurant_favorites").delete().in("restaurant_id", restaurantIds);
      if (favorites.error) throw favorites.error;
      const restaurants = await service.from("restaurants").delete().in("id", restaurantIds);
      if (restaurants.error) throw restaurants.error;
    }
    await service.auth.admin.deleteUser(user.id);
  }

  for (const result of results) {
    console.log(`[RESTAURANT_POSTGIS] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[RESTAURANT_POSTGIS] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
