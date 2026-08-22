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

function randomEmail(label) {
  return `mukking-restaurant-${label}-${Date.now()}-${crypto
    .randomBytes(3)
    .toString("hex")}@example.com`;
}

async function createConfirmedUser(label) {
  const email = randomEmail(label);
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-restaurant`, phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) {
    throw new Error(`${label} user creation failed.`);
  }

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) {
    throw new Error(`${label} sign-in failed.`);
  }

  return { id: created.data.user.id, token: signedIn.data.session.access_token, client: authenticated };
}

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function verify(baseUrl, user) {
  const me = await api(baseUrl, "/api/auth/me", user.token);
  if (me.status !== 200) throw new Error("Supabase profile synchronization failed.");
  const verification = await api(baseUrl, "/api/auth/verification/mock", user.token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  if (verification.status !== 200) throw new Error("Mock verification failed.");
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

  const a = await createConfirmedUser("a");
  const b = await createConfirmedUser("b");
  const anon = client(anonKey);
  const { app } = require("../dist/server/app");
  let server = app.listen(0);
  let restaurantId;

  try {
    let baseUrl = `http://127.0.0.1:${server.address().port}`;
    await verify(baseUrl, a);
    await verify(baseUrl, b);

    const created = await api(baseUrl, "/api/restaurants", a.token, {
      method: "POST",
      body: JSON.stringify({
        name: "Supabase 영속성 테스트 식당",
        address: "서울시 테스트구 영속성로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "test",
        placeProvider: "fixture",
        placeProviderId: `persistence-${Date.now()}`
      })
    });
    restaurantId = created.payload?.id;
    record("restaurant row created", created.status === 201 && Boolean(restaurantId), `status=${created.status}`);

    const duplicateRestaurant = await api(baseUrl, "/api/restaurants", a.token, {
      method: "POST",
      body: JSON.stringify({
        name: "중복 식당",
        address: "서울시 테스트구 영속성로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "test",
        placeProvider: "fixture",
        placeProviderId: created.payload?.placeProviderId
      })
    });
    record(
      "provider place duplicate rejected",
      duplicateRestaurant.status === 409,
      `status=${duplicateRestaurant.status}`
    );

    const detail = await api(baseUrl, `/api/restaurants/${restaurantId}`, a.token);
    record("restaurant detail", detail.status === 200 && detail.payload?.id === restaurantId, `status=${detail.status}`);

    const nearby = await api(
      baseUrl,
      "/api/restaurants?category=test&lat=37.4979&lng=127.0276&radiusKm=1",
      a.token
    );
    record(
      "category and nearby query",
      nearby.status === 200 && nearby.payload?.some((item) => item.id === restaurantId),
      `status=${nearby.status}`
    );

    const directRestaurantRead = await a.client
      .from("restaurants")
      .select("id")
      .eq("id", restaurantId);
    record(
      "RLS authenticated restaurant read",
      !directRestaurantRead.error && directRestaurantRead.data?.length === 1,
      directRestaurantRead.error ? "query error" : `count=${directRestaurantRead.data?.length}`
    );

    const anonRestaurantRead = await anon.from("restaurants").select("id").eq("id", restaurantId);
    record(
      "RLS anon restaurant blocked",
      Boolean(anonRestaurantRead.error) || anonRestaurantRead.data?.length === 0,
      anonRestaurantRead.error ? "permission blocked" : `count=${anonRestaurantRead.data?.length}`
    );

    const favorite = await api(baseUrl, `/api/restaurants/${restaurantId}/favorite`, a.token, {
      method: "POST"
    });
    record("favorite row created", favorite.status === 201, `status=${favorite.status}`);

    const duplicate = await api(baseUrl, `/api/restaurants/${restaurantId}/favorite`, a.token, {
      method: "POST"
    });
    record("duplicate favorite rejected", duplicate.status === 409, `status=${duplicate.status}`);

    const ownFavorites = await api(baseUrl, "/api/restaurants/favorites/me", a.token);
    record(
      "my favorites endpoint",
      ownFavorites.status === 200 && ownFavorites.payload?.some((item) => item.id === restaurantId),
      `status=${ownFavorites.status}`
    );

    const linkedPost = await api(baseUrl, "/api/matching/posts", a.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId,
        restaurantName: created.payload?.name,
        address: created.payload?.address,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 2,
        intro: "Supabase 식당 연결 테스트"
      })
    });
    record(
      "restaurant-linked matching post",
      linkedPost.status === 201 && linkedPost.payload?.restaurantId === restaurantId,
      `status=${linkedPost.status}`
    );

    const partyCount = await api(baseUrl, `/api/restaurants/${restaurantId}`, a.token);
    record(
      "active party count",
      partyCount.status === 200 && partyCount.payload?.activePartyCount === 1,
      `status=${partyCount.status}, count=${partyCount.payload?.activePartyCount}`
    );

    const ownDirect = await a.client
      .from("restaurant_favorites")
      .select("restaurant_id")
      .eq("restaurant_id", restaurantId);
    record(
      "RLS own favorite direct read",
      !ownDirect.error && ownDirect.data?.length === 1,
      ownDirect.error ? "blocked unexpectedly" : `count=${ownDirect.data?.length}`
    );

    const otherDirect = await b.client
      .from("restaurant_favorites")
      .select("restaurant_id")
      .eq("restaurant_id", restaurantId);
    record(
      "RLS other favorite hidden",
      !otherDirect.error && otherDirect.data?.length === 0,
      otherDirect.error ? "query error" : `count=${otherDirect.data?.length}`
    );

    const unauthorizedInsert = await b.client.from("restaurant_favorites").insert({
      user_id: a.id,
      restaurant_id: restaurantId
    });
    record("RLS favorite spoof rejected", Boolean(unauthorizedInsert.error), "authenticated direct insert");

    await new Promise((resolve) => server.close(resolve));
    server = app.listen(0);
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    const afterRestart = await api(baseUrl, `/api/restaurants/${restaurantId}`, a.token);
    record(
      "restart persistence",
      afterRestart.status === 200 && afterRestart.payload?.isFavorite === true,
      `status=${afterRestart.status}`
    );

    const linkedPostAfterRestart = await api(baseUrl, "/api/matching/posts", a.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId,
        restaurantName: afterRestart.payload?.name,
        address: afterRestart.payload?.address,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 2,
        intro: "재시작 후 식당 연결 테스트"
      })
    });
    record(
      "restaurant-linked party works after restart",
      linkedPostAfterRestart.status === 201 && linkedPostAfterRestart.payload?.restaurantId === restaurantId,
      `status=${linkedPostAfterRestart.status}`
    );

    const removeFavorite = await api(baseUrl, `/api/restaurants/${restaurantId}/favorite`, a.token, {
      method: "DELETE"
    });
    record("favorite delete", removeFavorite.status === 200, `status=${removeFavorite.status}`);

    const afterDelete = await api(baseUrl, "/api/restaurants/favorites/me", a.token);
    record(
      "favorite removed from my list",
      afterDelete.status === 200 && !afterDelete.payload?.some((item) => item.id === restaurantId),
      `status=${afterDelete.status}`
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
    const service = client(serviceRoleKey);
    if (restaurantId) {
      await service.from("restaurant_favorites").delete().eq("restaurant_id", restaurantId);
      await service.from("restaurants").delete().eq("id", restaurantId);
    }
    await service.auth.admin.deleteUser(a.id);
    await service.auth.admin.deleteUser(b.id);
  }

  for (const result of results) {
    console.log(`[RESTAURANT_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[RESTAURANT_SUPABASE] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
