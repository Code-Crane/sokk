process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

const { app } = require("../dist/server/app");

const results = [];

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function signup(baseUrl, label) {
  const result = await api(baseUrl, "/api/auth/signup", undefined, {
    method: "POST",
    body: JSON.stringify({
      email: `restaurant-${label}-${Date.now()}@example.com`,
      nickname: `${label}-tester`,
      phoneNumber: "01012345678"
    })
  });
  record(`${label} signup`, result.status === 201, `status=${result.status}`);
  return { token: result.payload?.token, userId: result.payload?.user?.id };
}

async function verify(baseUrl, token, label) {
  const result = await api(baseUrl, "/api/auth/verification/mock", token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  record(`${label} verification`, result.status === 200, `status=${result.status}`);
}

async function main() {
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const a = await signup(baseUrl, "a");
    const b = await signup(baseUrl, "b");
    await verify(baseUrl, a.token, "a");

    const restaurantInput = {
      name: "메모리 테스트 식당",
      address: "서울시 강남구 테스트로 1",
      latitude: 37.4979,
      longitude: 127.0276,
      category: "korean",
      placeProvider: "fixture",
      placeProviderId: `restaurant-${Date.now()}`
    };
    const restaurant = await api(baseUrl, "/api/restaurants", a.token, {
      method: "POST",
      body: JSON.stringify(restaurantInput)
    });
    record("restaurant create", restaurant.status === 201, `status=${restaurant.status}`);

    const duplicate = await api(baseUrl, "/api/restaurants", a.token, {
      method: "POST",
      body: JSON.stringify(restaurantInput)
    });
    record("duplicate provider place rejected", duplicate.status === 409, `status=${duplicate.status}`);

    const list = await api(
      baseUrl,
      "/api/restaurants?lat=37.4979&lng=127.0276&radiusKm=1&category=korean",
      a.token
    );
    record(
      "restaurant nearby list",
      list.status === 200 && list.payload?.[0]?.id === restaurant.payload?.id,
      `status=${list.status}`
    );

    const favorite = await api(
      baseUrl,
      `/api/restaurants/${restaurant.payload?.id}/favorite`,
      a.token,
      { method: "POST" }
    );
    record(
      "favorite create",
      favorite.status === 201 && favorite.payload?.isFavorite === true,
      `status=${favorite.status}`
    );

    const duplicateFavorite = await api(
      baseUrl,
      `/api/restaurants/${restaurant.payload?.id}/favorite`,
      a.token,
      { method: "POST" }
    );
    record("duplicate favorite rejected", duplicateFavorite.status === 409, `status=${duplicateFavorite.status}`);

    const ownFavorites = await api(baseUrl, "/api/restaurants/favorites/me", a.token);
    record(
      "own favorites only",
      ownFavorites.status === 200 && ownFavorites.payload?.length === 1,
      `status=${ownFavorites.status}, count=${ownFavorites.payload?.length}`
    );

    const otherFavorites = await api(baseUrl, "/api/restaurants/favorites/me", b.token);
    record(
      "other user favorites isolated",
      otherFavorites.status === 200 && otherFavorites.payload?.length === 0,
      `status=${otherFavorites.status}, count=${otherFavorites.payload?.length}`
    );

    const post = await api(baseUrl, "/api/matching/posts", a.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId: restaurant.payload?.id,
        restaurantName: restaurantInput.name,
        address: restaurantInput.address,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 2,
        intro: "식당 연결 회귀 테스트"
      })
    });
    record(
      "matching post restaurant link",
      post.status === 201 && post.payload?.restaurantId === restaurant.payload?.id,
      `status=${post.status}`
    );

    const detail = await api(baseUrl, `/api/restaurants/${restaurant.payload?.id}`, a.token);
    record(
      "active party count from matching",
      detail.status === 200 && detail.payload?.activePartyCount === 1,
      `status=${detail.status}, count=${detail.payload?.activePartyCount}`
    );

    const remove = await api(
      baseUrl,
      `/api/restaurants/${restaurant.payload?.id}/favorite`,
      a.token,
      { method: "DELETE" }
    );
    record("favorite delete", remove.status === 200, `status=${remove.status}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  for (const result of results) {
    console.log(`[RESTAURANT] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[RESTAURANT] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
