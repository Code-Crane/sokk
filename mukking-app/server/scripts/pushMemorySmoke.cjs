process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.PUSH_PROVIDER = "mock";
process.env.RATE_LIMIT_PUSH_DEVICE_MAX = "10";
process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

const { app } = require("../dist/server/app");
const { repositories } = require("../dist/server/repositories");
const {
  createFavoriteRestaurantPartyNotifications
} = require("../dist/server/services/notification/notification.service");
const {
  getMockPushProviderForTests
} = require("../dist/server/services/push/providers");
const {
  NoopPushProvider
} = require("../dist/server/services/push/providers/noop.push-provider");

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
  const response = await api(baseUrl, "/api/auth/signup", undefined, {
    method: "POST",
    body: JSON.stringify({
      email: `push-${label}-${Date.now()}@example.com`,
      nickname: `${label}-push`,
      phoneNumber: "01012345678"
    })
  });
  record(`${label} signup`, response.status === 201, `status=${response.status}`);
  return { token: response.payload?.token, userId: response.payload?.user?.id };
}

async function verify(baseUrl, token) {
  const response = await api(baseUrl, "/api/auth/verification/mock", token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  record("author verification", response.status === 200, `status=${response.status}`);
}

async function register(baseUrl, user, token, platform = "android", extra = {}) {
  return api(baseUrl, "/api/push/devices", user.token, {
    method: "POST",
    body: JSON.stringify({ token, platform, ...extra })
  });
}

async function main() {
  const mockProvider = getMockPushProviderForTests();
  mockProvider.reset();
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const author = await signup(baseUrl, "author");
    const b = await signup(baseUrl, "b");
    const c = await signup(baseUrl, "c");
    const d = await signup(baseUrl, "d");
    await verify(baseUrl, author.token);

    const unauthenticated = await api(baseUrl, "/api/push/devices", undefined, {
      method: "POST",
      body: JSON.stringify({ token: "mock-sent-unauthenticated-device", platform: "android" })
    });
    const invalid = await register(baseUrl, b, "short", "android");
    record(
      "push registration auth and validation",
      unauthenticated.status === 401 && invalid.status === 400,
      `unauth=${unauthenticated.status}, invalid=${invalid.status}`
    );

    const sentToken = "mock-sent-device-b-000000000001";
    const invalidToken = "mock-invalid-device-b-0000000002";
    const transientToken = "mock-transient-device-b-000003";
    const sent = await register(baseUrl, b, sentToken, "android", { userId: c.userId });
    const replay = await register(baseUrl, b, sentToken, "ios");
    const invalidDevice = await register(baseUrl, b, invalidToken);
    const transientDevice = await register(baseUrl, b, transientToken);
    const sentStored = await repositories.pushDevices.findByToken("fcm", sentToken);
    record(
      "JWT ownership and token-safe response",
      sent.status === 201 && sentStored?.userId === b.userId &&
        !("token" in (sent.payload ?? {})) && !("userId" in (sent.payload ?? {})),
      `status=${sent.status}, owner=${sentStored?.userId === b.userId}`
    );
    record(
      "same token re-registration",
      replay.status === 201 && replay.payload?.id === sent.payload?.id &&
        replay.payload?.platform === "ios",
      `sameId=${replay.payload?.id === sent.payload?.id}`
    );
    record(
      "multi-device registration",
      (await repositories.pushDevices.listActiveDevicesByUser(b.userId)).length === 3,
      "expected=3"
    );

    const otherDelete = await api(
      baseUrl,
      `/api/push/devices/${sent.payload?.id}`,
      c.token,
      { method: "DELETE" }
    );
    record("other user device delete rejected", otherDelete.status === 403, `status=${otherDelete.status}`);

    const transferToken = "mock-sent-transfer-device-0000004";
    const transferFromB = await register(baseUrl, b, transferToken);
    const transferToD = await register(baseUrl, d, transferToken, "web");
    const transferred = await repositories.pushDevices.findByToken("fcm", transferToken);
    const oldOwnerDelete = await api(
      baseUrl,
      `/api/push/devices/${transferFromB.payload?.id}`,
      b.token,
      { method: "DELETE" }
    );
    const newOwnerDelete = await api(
      baseUrl,
      `/api/push/devices/${transferToD.payload?.id}`,
      d.token,
      { method: "DELETE" }
    );
    record(
      "same token account transfer ownership",
      transferFromB.payload?.id === transferToD.payload?.id &&
        transferred?.userId === d.userId && oldOwnerDelete.status === 403 &&
        newOwnerDelete.status === 200,
      `old=${oldOwnerDelete.status}, new=${newOwnerDelete.status}`
    );

    const restaurant = await api(baseUrl, "/api/restaurants", author.token, {
      method: "POST",
      body: JSON.stringify({
        name: "푸시 메모리 식당",
        address: "서울시 테스트구 푸시로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "push-test",
        placeProvider: "push-memory",
        placeProviderId: `push-${Date.now()}`
      })
    });
    for (const user of [b, c]) {
      await api(baseUrl, `/api/restaurants/${restaurant.payload?.id}/favorite`, user.token, {
        method: "POST"
      });
    }

    const loggedErrors = [];
    const originalConsoleError = console.error;
    console.error = (...args) => loggedErrors.push(JSON.stringify(args));
    let post;
    try {
      post = await api(baseUrl, "/api/matching/posts", author.token, {
        method: "POST",
        body: JSON.stringify({
          restaurantId: restaurant.payload?.id,
          restaurantName: restaurant.payload?.name,
          address: restaurant.payload?.address,
          scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
          maxParticipants: 2,
          intro: "푸시 dispatch 테스트"
        })
      });
    } finally {
      console.error = originalConsoleError;
    }

    const bNotifications = await api(baseUrl, "/api/notifications", b.token);
    const cNotifications = await api(baseUrl, "/api/notifications", c.token);
    record(
      "notification and matching survive push outcomes",
      post.status === 201 && bNotifications.payload?.length === 1 &&
        cNotifications.payload?.length === 1,
      `post=${post.status}, b=${bNotifications.payload?.length}, c=${cNotifications.payload?.length}`
    );
    record(
      "mock dispatch and no-device policy",
      mockProvider.dispatches.length === 1 &&
        mockProvider.dispatches[0].deviceIds.length === 3,
      `dispatches=${mockProvider.dispatches.length}`
    );

    const invalidStored = await repositories.pushDevices.findById(invalidDevice.payload?.id);
    const transientStored = await repositories.pushDevices.findById(transientDevice.payload?.id);
    record(
      "invalid disabled and transient retained",
      invalidStored?.enabled === false && transientStored?.enabled === true,
      `invalid=${invalidStored?.enabled}, transient=${transientStored?.enabled}`
    );
    record(
      "failure log excludes delivery tokens",
      loggedErrors.length === 1 &&
        !loggedErrors.some((line) =>
          [sentToken, invalidToken, transientToken].some((token) => line.includes(token))
        ),
      `entries=${loggedErrors.length}`
    );

    const payload = mockProvider.dispatches[0].payload;
    const forbiddenPayloadKeys = [
      "phoneNumber",
      "birthDate",
      "gender",
      "verification",
      "latitude",
      "longitude",
      "accessToken",
      "pushToken"
    ];
    record(
      "minimal push payload",
      payload.data.notificationId === bNotifications.payload?.[0]?.id &&
        payload.data.matchingPostId === post.payload?.id &&
        forbiddenPayloadKeys.every((key) => !(key in payload.data)),
      `keys=${Object.keys(payload.data).sort().join(",")}`
    );

    const dispatchCount = mockProvider.dispatches.length;
    const duplicateRows = await createFavoriteRestaurantPartyNotifications(post.payload);
    record(
      "duplicate notification does not resend push",
      duplicateRows.length === 0 && mockProvider.dispatches.length === dispatchCount,
      `rows=${duplicateRows.length}, dispatches=${mockProvider.dispatches.length}`
    );

    const noop = new NoopPushProvider();
    const noopResult = await noop.sendBatch(
      [{ deviceId: "fixture", token: "not-transmitted" }],
      { title: "fixture", body: "fixture", data: {} }
    );
    record(
      "noop provider performs no external delivery",
      noopResult[0]?.status === "skipped",
      `status=${noopResult[0]?.status}`
    );

    const rateLimitResponses = [];
    for (let index = 0; index < 4; index += 1) {
      rateLimitResponses.push(
        await register(
          baseUrl,
          b,
          `mock-sent-rate-device-${index}-0000000000`
        )
      );
    }
    record(
      "device mutation rate limit",
      rateLimitResponses.slice(0, 3).every((response) => response.status === 201) &&
        rateLimitResponses[3]?.status === 429 &&
        rateLimitResponses[3]?.payload?.code === "RATE_LIMIT_EXCEEDED",
      `statuses=${rateLimitResponses.map((response) => response.status).join(",")}`
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  for (const result of results) {
    console.log(`[PUSH_MEMORY] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[PUSH_MEMORY] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
