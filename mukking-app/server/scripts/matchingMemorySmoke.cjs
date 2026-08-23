process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

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

async function user(baseUrl, label) {
  const signup = await api(baseUrl, "/api/auth/signup", undefined, {
    method: "POST",
    body: JSON.stringify({
      email: `matching-${label}-${Date.now()}@example.com`,
      nickname: `${label}-tester`,
      phoneNumber: "01012345678"
    })
  });
  record(`${label} signup`, signup.status === 201, `status=${signup.status}`);
  const token = signup.payload?.token;
  const verification = await api(baseUrl, "/api/auth/verification/mock", token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  record(`${label} verification`, verification.status === 200, `status=${verification.status}`);
  return { id: signup.payload?.user?.id, token };
}

async function main() {
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  try {
    const host = await user(baseUrl, "host");
    const guest = await user(baseUrl, "guest");
    const blocked = await user(baseUrl, "blocked");
    const blockHost = await user(baseUrl, "block-host");

    const restaurant = await api(baseUrl, "/api/restaurants", host.token, {
      method: "POST",
      body: JSON.stringify({
        name: "매칭 메모리 식당",
        address: "서울시 테스트구 매칭로 1",
        latitude: 37.5,
        longitude: 127.0,
        category: "test",
        placeProvider: "fixture",
        placeProviderId: `matching-${Date.now()}`
      })
    });
    record("restaurant setup", restaurant.status === 201, `status=${restaurant.status}`);

    const post = await api(baseUrl, "/api/matching/posts", host.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId: restaurant.payload?.id,
        restaurantName: restaurant.payload?.name,
        address: restaurant.payload?.address,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 1,
        intro: "매칭 영속화 회귀 테스트"
      })
    });
    record(
      "restaurant-linked post create",
      post.status === 201 && post.payload?.restaurantId === restaurant.payload?.id,
      `status=${post.status}`
    );

    const join = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, guest.token, {
      method: "POST"
    });
    record("join request create", join.status === 201, `status=${join.status}`);

    const duplicate = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, guest.token, {
      method: "POST"
    });
    record("pending join duplicate rejected", duplicate.status === 409, `status=${duplicate.status}`);

    const forbiddenList = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, guest.token);
    record("non-author request list rejected", forbiddenList.status === 403, `status=${forbiddenList.status}`);

    const requestList = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, host.token);
    record("author request list", requestList.status === 200 && requestList.payload?.length === 1, `status=${requestList.status}`);

    const accepted = await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, {
      method: "POST",
      body: JSON.stringify({ decision: "accepted" })
    });
    record(
      "accept closes capacity and creates chat",
      accepted.status === 200 && accepted.payload?.request?.status === "accepted" && Boolean(accepted.payload?.chatRoom?.id),
      `status=${accepted.status}`
    );

    const completed = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/complete`, host.token, {
      method: "POST"
    });
    record("complete matched post", completed.status === 200 && completed.payload?.status === "completed", `status=${completed.status}`);

    const pendingRating = await api(baseUrl, "/api/rating/pending", host.token);
    record("completion creates pending rating", pendingRating.status === 200 && pendingRating.payload?.length > 0, `status=${pendingRating.status}`);

    const blockedPost = await api(baseUrl, "/api/matching/posts", blockHost.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId: restaurant.payload?.id,
        restaurantName: restaurant.payload?.name,
        address: restaurant.payload?.address,
        scheduledAt: new Date(Date.now() + 172_800_000).toISOString(),
        maxParticipants: 2,
        intro: "차단 회귀 테스트"
      })
    });
    const block = await api(baseUrl, "/api/blocks", blockHost.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: blocked.id })
    });
    record("block setup", block.status === 201, `status=${block.status}`);
    const blockedJoin = await api(baseUrl, `/api/matching/posts/${blockedPost.payload?.id}/requests`, blocked.token, {
      method: "POST"
    });
    record("block enforcement on join", blockedJoin.status === 403, `status=${blockedJoin.status}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  for (const result of results) {
    console.log(`[MATCHING_MEMORY] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[MATCHING_MEMORY] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
