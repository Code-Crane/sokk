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

async function createUser(label) {
  const email = `mukking-push-${label}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-push`, phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) throw new Error(`${label} user creation failed.`);

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) {
    throw new Error(`${label} sign-in failed.`);
  }

  return {
    id: created.data.user.id,
    token: signedIn.data.session.access_token,
    client: authenticated
  };
}

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function register(baseUrl, user, token, platform = "android", extra = {}) {
  return api(baseUrl, "/api/push/devices", user.token, {
    method: "POST",
    body: JSON.stringify({ token, platform, ...extra })
  });
}

async function startServer(app) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
    server.once("error", reject);
  });
}

async function stopServer(server) {
  if (!server?.listening) return;
  await new Promise((resolve) => server.close(resolve));
}

async function verify(baseUrl, user) {
  const response = await api(baseUrl, "/api/auth/verification/mock", user.token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  if (response.status !== 200) throw new Error("Mock verification failed.");
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);

  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.PUSH_PROVIDER = "mock";
  process.env.RATE_LIMIT_PUSH_DEVICE_MAX = "10";
  process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

  const service = client(serviceRoleKey);
  const anon = client(anonKey);
  const users = [];
  const matchingPostIds = [];
  let restaurantId;
  const { app } = require("../dist/server/app");
  const { repositories } = require("../dist/server/repositories");
  const {
    createFavoriteRestaurantPartyNotifications
  } = require("../dist/server/services/notification/notification.service");
  const {
    getMockPushProviderForTests,
    getPushProvider
  } = require("../dist/server/services/push/providers");
  let server = await startServer(app);
  let baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const health = await api(baseUrl, "/api/health");
    record(
      "mock provider starts without Firebase credentials",
      health.status === 200 && getPushProvider().name === "mock",
      `health=${health.status}, provider=${getPushProvider().name}`
    );

    const a = await createUser("a");
    const b = await createUser("b");
    const c = await createUser("c-no-device");
    users.push(a, b, c);

    for (const user of users) {
      const me = await api(baseUrl, "/api/auth/me", user.token);
      if (me.status !== 200) throw new Error("Application profile synchronization failed.");
    }
    await verify(baseUrl, b);

    const sharedToken = `mock-sent-shared-${Date.now()}-${crypto.randomBytes(8).toString("hex")}`;
    const successToken = `mock-sent-success-${Date.now()}-${crypto.randomBytes(8).toString("hex")}`;
    const transientToken = `mock-transient-${Date.now()}-${crypto.randomBytes(8).toString("hex")}`;
    const invalidToken = `mock-invalid-${Date.now()}-${crypto.randomBytes(8).toString("hex")}`;

    const aFirst = await register(baseUrl, a, sharedToken, "android", { userId: b.id });
    const firstStored = await service
      .from("user_push_devices")
      .select("id,user_id,provider,platform,enabled,created_at,updated_at,last_seen_at")
      .eq("id", aFirst.payload?.id)
      .single();
    record(
      "JWT-owned device registration",
      aFirst.status === 201 && !firstStored.error &&
        firstStored.data?.user_id === a.id && firstStored.data?.provider === "fcm" &&
        firstStored.data?.platform === "android" && firstStored.data?.enabled === true &&
        !("token" in (aFirst.payload ?? {})) && !("pushToken" in (aFirst.payload ?? {})) &&
        !("userId" in (aFirst.payload ?? {})),
      `status=${aFirst.status}, owner=${firstStored.data?.user_id === a.id}`
    );

    const aSecond = await register(baseUrl, a, successToken, "web");
    const initialActiveA = await repositories.pushDevices.listActiveDevicesByUser(a.id);
    const initialRows = await service
      .from("user_push_devices")
      .select("id")
      .eq("user_id", a.id)
      .eq("enabled", true);
    record(
      "multiple independent devices",
      aSecond.status === 201 && initialActiveA.length === 2 &&
        !initialRows.error && initialRows.data?.length === 2,
      `api=${aSecond.status}, active=${initialActiveA.length}`
    );

    await new Promise((resolve) => setTimeout(resolve, 5));
    const aReplay = await register(baseUrl, a, sharedToken, "ios");
    const replayRows = await service
      .from("user_push_devices")
      .select("id,user_id,platform,enabled,updated_at,last_seen_at", { count: "exact" })
      .eq("provider", "fcm")
      .eq("push_token", sharedToken);
    record(
      "same token re-registration is idempotent",
      aReplay.status === 201 && aReplay.payload?.id === aFirst.payload?.id &&
        replayRows.count === 1 && replayRows.data?.[0]?.platform === "ios" &&
        replayRows.data?.[0]?.enabled === true &&
        replayRows.data?.[0]?.updated_at !== firstStored.data?.updated_at &&
        replayRows.data?.[0]?.last_seen_at !== firstStored.data?.last_seen_at,
      `status=${aReplay.status}, rows=${replayRows.count}, sameId=${aReplay.payload?.id === aFirst.payload?.id}`
    );

    const bTransfer = await register(baseUrl, b, sharedToken, "android");
    const transferRows = await service
      .from("user_push_devices")
      .select("id,user_id,enabled", { count: "exact" })
      .eq("provider", "fcm")
      .eq("push_token", sharedToken);
    const activeAfterTransferA = await repositories.pushDevices.listActiveDevicesByUser(a.id);
    const activeAfterTransferB = await repositories.pushDevices.listActiveDevicesByUser(b.id);
    record(
      "token ownership transfer",
      bTransfer.status === 201 && bTransfer.payload?.id === aFirst.payload?.id &&
        transferRows.count === 1 && transferRows.data?.[0]?.user_id === b.id &&
        activeAfterTransferA.length === 1 && activeAfterTransferB.length === 1,
      `rows=${transferRows.count}, a=${activeAfterTransferA.length}, b=${activeAfterTransferB.length}`
    );

    const otherDisable = await api(
      baseUrl,
      `/api/push/devices/${bTransfer.payload?.id}`,
      a.token,
      { method: "DELETE" }
    );
    const ownDisable = await api(
      baseUrl,
      `/api/push/devices/${bTransfer.payload?.id}`,
      b.token,
      { method: "DELETE" }
    );
    const missingDisable = await api(
      baseUrl,
      "/api/push/devices/push_device_missing_fixture",
      a.token,
      { method: "DELETE" }
    );
    const disabledStored = await service
      .from("user_push_devices")
      .select("id,user_id,enabled")
      .eq("id", bTransfer.payload?.id)
      .single();
    const activeB = await repositories.pushDevices.listActiveDevicesByUser(b.id);
    record(
      "disable ownership and row retention",
      otherDisable.status === 403 && ownDisable.status === 200 &&
        missingDisable.status === 404 && !disabledStored.error &&
        disabledStored.data?.enabled === false && activeB.length === 0,
      `other=${otherDisable.status}, own=${ownDisable.status}, missing=${missingDisable.status}`
    );

    const anonSelect = await anon.from("user_push_devices").select("id").limit(1);
    const anonInsert = await anon.from("user_push_devices").insert({
      id: `push_device_anon_${Date.now()}`,
      user_id: a.id,
      provider: "fcm",
      platform: "android",
      push_token: `mock-anon-${Date.now()}-000000000000`
    });
    const anonUpdate = await anon
      .from("user_push_devices")
      .update({ enabled: false })
      .eq("id", aSecond.payload?.id);
    const anonDelete = await anon
      .from("user_push_devices")
      .delete()
      .eq("id", aSecond.payload?.id);

    const authSelect = await a.client.from("user_push_devices").select("id").limit(1);
    const authInsert = await a.client.from("user_push_devices").insert({
      id: `push_device_auth_${Date.now()}`,
      user_id: b.id,
      provider: "fcm",
      platform: "android",
      push_token: `mock-auth-${Date.now()}-000000000000`
    });
    const authUpdate = await a.client
      .from("user_push_devices")
      .update({ enabled: false })
      .eq("id", aSecond.payload?.id);
    const authDelete = await a.client
      .from("user_push_devices")
      .delete()
      .eq("id", aSecond.payload?.id);
    record(
      "anon RLS denies all operations",
      [anonSelect, anonInsert, anonUpdate, anonDelete].every(
        (response) => response.error?.code === "42501"
      ),
      `codes=${[anonSelect, anonInsert, anonUpdate, anonDelete].map((response) => response.error?.code).join(",")}`
    );
    record(
      "authenticated RLS denies all operations",
      [authSelect, authInsert, authUpdate, authDelete].every(
        (response) => response.error?.code === "42501"
      ),
      `codes=${[authSelect, authInsert, authUpdate, authDelete].map((response) => response.error?.code).join(",")}`
    );

    const transientDevice = await register(baseUrl, a, transientToken, "android");
    const invalidDevice = await register(baseUrl, a, invalidToken, "android");
    const dispatchReady = await repositories.pushDevices.listActiveDevicesByUser(a.id);
    if (dispatchReady.length !== 3) throw new Error("Partial-failure device setup failed.");

    const restaurant = await api(baseUrl, "/api/restaurants", b.token, {
      method: "POST",
      body: JSON.stringify({
        name: "푸시 Supabase 테스트 식당",
        address: "서울시 테스트구 푸시영속로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "push-test",
        placeProvider: "push-supabase",
        placeProviderId: `push-${Date.now()}`
      })
    });
    restaurantId = restaurant.payload?.id;
    if (restaurant.status !== 201 || !restaurantId) throw new Error("Restaurant setup failed.");

    for (const user of [a, c]) {
      const favorite = await api(
        baseUrl,
        `/api/restaurants/${restaurantId}/favorite`,
        user.token,
        { method: "POST" }
      );
      if (favorite.status !== 201) throw new Error("Favorite setup failed.");
    }

    const mockProvider = getMockPushProviderForTests();
    mockProvider.reset();
    const loggedErrors = [];
    const originalConsoleError = console.error;
    let post;
    console.error = (...args) => loggedErrors.push(JSON.stringify(args));
    try {
      post = await api(baseUrl, "/api/matching/posts", b.token, {
        method: "POST",
        body: JSON.stringify({
          restaurantId,
          restaurantName: restaurant.payload?.name,
          address: restaurant.payload?.address,
          scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
          maxParticipants: 2,
          intro: "Push Supabase dispatch 테스트"
        })
      });
    } finally {
      console.error = originalConsoleError;
    }
    if (post.payload?.id) matchingPostIds.push(post.payload.id);

    const aNotifications = await api(baseUrl, "/api/notifications", a.token);
    const cNotifications = await api(baseUrl, "/api/notifications", c.token);
    const storedNotifications = await service
      .from("notifications")
      .select("id,user_id,matching_post_id")
      .eq("matching_post_id", post.payload?.id);
    record(
      "persistent notification dispatches through mock provider",
      post.status === 201 && aNotifications.payload?.length === 1 &&
        cNotifications.payload?.length === 1 && !storedNotifications.error &&
        storedNotifications.data?.length === 2 && mockProvider.dispatches.length === 1 &&
        mockProvider.dispatches[0]?.deviceIds.length === 3,
      `post=${post.status}, notifications=${storedNotifications.data?.length}, dispatches=${mockProvider.dispatches.length}`
    );
    record(
      "device-less recipient keeps notification",
      cNotifications.payload?.[0]?.matchingPostId === post.payload?.id,
      `count=${cNotifications.payload?.length}`
    );

    const successStored = await repositories.pushDevices.findById(aSecond.payload?.id);
    const transientStored = await repositories.pushDevices.findById(transientDevice.payload?.id);
    const invalidStored = await repositories.pushDevices.findById(invalidDevice.payload?.id);
    record(
      "multi-device partial failure policy",
      successStored?.enabled === true && transientStored?.enabled === true &&
        invalidStored?.enabled === false && aNotifications.payload?.length === 1 &&
        post.status === 201,
      `success=${successStored?.enabled}, transient=${transientStored?.enabled}, invalid=${invalidStored?.enabled}`
    );
    record(
      "delivery logs exclude raw tokens",
      loggedErrors.length === 1 &&
        !loggedErrors.some((entry) =>
          [sharedToken, successToken, transientToken, invalidToken].some((token) =>
            entry.includes(token)
          )
        ),
      `entries=${loggedErrors.length}`
    );

    const dispatchCount = mockProvider.dispatches.length;
    const duplicateNotifications = await createFavoriteRestaurantPartyNotifications(post.payload);
    record(
      "duplicate notification does not resend",
      duplicateNotifications.length === 0 &&
        mockProvider.dispatches.length === dispatchCount,
      `rows=${duplicateNotifications.length}, dispatches=${mockProvider.dispatches.length}`
    );

    const beforeRestartA = await repositories.pushDevices.listActiveDevicesByUser(a.id);
    await stopServer(server);
    server = await startServer(app);
    baseUrl = `http://127.0.0.1:${server.address().port}`;

    const afterRestartA = await repositories.pushDevices.listActiveDevicesByUser(a.id);
    const afterRestartB = await repositories.pushDevices.listActiveDevicesByUser(b.id);
    const restartRows = await service
      .from("user_push_devices")
      .select("id,user_id,enabled")
      .in("user_id", [a.id, b.id]);
    const restartNotifications = await api(baseUrl, "/api/notifications", a.token);
    const restartPost = await service
      .from("matching_posts")
      .select("id")
      .eq("id", post.payload?.id)
      .single();
    record(
      "restart persistence",
      beforeRestartA.length === 2 && afterRestartA.length === 2 &&
        afterRestartB.length === 0 && restartRows.data?.length === 4 &&
        restartRows.data?.find((row) => row.id === bTransfer.payload?.id)?.user_id === b.id &&
        restartRows.data?.find((row) => row.id === bTransfer.payload?.id)?.enabled === false &&
        restartRows.data?.find((row) => row.id === invalidDevice.payload?.id)?.enabled === false &&
        restartNotifications.payload?.length === 1 && !restartPost.error,
      `a=${afterRestartA.length}, b=${afterRestartB.length}, rows=${restartRows.data?.length}`
    );

    const rateResponses = [];
    for (let index = 0; index < 4; index += 1) {
      rateResponses.push(
        await register(
          baseUrl,
          a,
          `mock-sent-rate-${index}-${Date.now()}-000000000000`
        )
      );
    }
    record(
      "push device rate limit",
      rateResponses.slice(0, 3).every((response) => response.status === 201) &&
        rateResponses[3]?.status === 429 &&
        rateResponses[3]?.payload?.code === "RATE_LIMIT_EXCEEDED",
      `statuses=${rateResponses.map((response) => response.status).join(",")}`
    );
  } finally {
    await stopServer(server);

    if (matchingPostIds.length > 0) {
      const notifications = await service
        .from("notifications")
        .delete()
        .in("matching_post_id", matchingPostIds);
      if (notifications.error) throw notifications.error;

      const posts = await service.from("matching_posts").delete().in("id", matchingPostIds);
      if (posts.error) throw posts.error;
    }

    if (restaurantId) {
      const favorites = await service
        .from("restaurant_favorites")
        .delete()
        .eq("restaurant_id", restaurantId);
      if (favorites.error) throw favorites.error;

      const restaurant = await service.from("restaurants").delete().eq("id", restaurantId);
      if (restaurant.error) throw restaurant.error;
    }

    if (users.length > 0) {
      const userIds = users.map((user) => user.id);
      const devices = await service.from("user_push_devices").delete().in("user_id", userIds);
      if (devices.error) throw devices.error;

      const mannerProfiles = await service
        .from("user_manner_profiles")
        .delete()
        .in("user_id", userIds);
      if (mannerProfiles.error) throw mannerProfiles.error;

      for (const user of users) {
        const deleted = await service.auth.admin.deleteUser(user.id);
        if (deleted.error) throw deleted.error;
      }

      const remainingDevices = await service
        .from("user_push_devices")
        .select("id", { count: "exact", head: true })
        .in("user_id", userIds);
      record(
        "exact fixture cleanup",
        !remainingDevices.error && remainingDevices.count === 0,
        `remainingDevices=${remainingDevices.count}`
      );
    }
  }

  for (const result of results) {
    console.log(
      `[PUSH_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`
    );
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(
    `[PUSH_SUPABASE] FAIL ${error instanceof Error ? error.name : "UnknownError"}`
  );
  process.exitCode = 1;
});
