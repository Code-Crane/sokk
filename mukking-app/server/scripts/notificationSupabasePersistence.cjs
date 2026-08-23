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
  const email = `mukking-notification-${label}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-notification`, phoneNumber: "01012345678" }
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

async function ensureProfile(baseUrl, user) {
  const me = await api(baseUrl, "/api/auth/me", user.token);
  if (me.status !== 200) throw new Error("Profile synchronization failed.");
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
  process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

  const service = client(serviceRoleKey);
  const anon = client(anonKey);
  const users = [];
  let restaurantId;
  const matchingPostIds = [];
  const { app } = require("../dist/server/app");
  const {
    createFavoriteRestaurantPartyNotifications
  } = require("../dist/server/services/notification/notification.service");
  const { repositories } = require("../dist/server/repositories");
  let server = app.listen(0);
  let baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const author = await createUser("author");
    users.push(author);
    const b = await createUser("b");
    users.push(b);
    const c = await createUser("c");
    users.push(c);
    for (const user of users) await ensureProfile(baseUrl, user);
    await verify(baseUrl, author);

    const restaurant = await api(baseUrl, "/api/restaurants", author.token, {
      method: "POST",
      body: JSON.stringify({
        name: "알림 Supabase 테스트 식당",
        address: "서울시 테스트구 알림영속로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "notification-test",
        placeProvider: "notification-fixture",
        placeProviderId: `notification-${Date.now()}`
      })
    });
    restaurantId = restaurant.payload?.id;
    if (restaurant.status !== 201 || !restaurantId) throw new Error("Restaurant creation failed.");

    for (const user of users) {
      const favorite = await api(baseUrl, `/api/restaurants/${restaurantId}/favorite`, user.token, {
        method: "POST"
      });
      if (favorite.status !== 201) throw new Error("Favorite setup failed.");
    }

    const createPost = (intro, linkedRestaurantId = restaurantId) =>
      api(baseUrl, "/api/matching/posts", author.token, {
        method: "POST",
        body: JSON.stringify({
          ...(linkedRestaurantId ? { restaurantId: linkedRestaurantId } : {}),
          restaurantName: linkedRestaurantId ? restaurant.payload.name : "Legacy 알림 테스트 식당",
          address: linkedRestaurantId ? restaurant.payload.address : "서울시 legacy 주소",
          scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
          maxParticipants: 2,
          intro
        })
      });

    const firstPost = await createPost("첫 번째 찜 식당 알림 영속성 테스트");
    if (firstPost.payload?.id) matchingPostIds.push(firstPost.payload.id);
    await new Promise((resolve) => setTimeout(resolve, 2));
    const secondPost = await createPost("두 번째 찜 식당 알림 영속성 테스트");
    if (secondPost.payload?.id) matchingPostIds.push(secondPost.payload.id);
    record(
      "matching events created",
      firstPost.status === 201 && secondPost.status === 201 && matchingPostIds.length === 2,
      `first=${firstPost.status}, second=${secondPost.status}`
    );

    await createFavoriteRestaurantPartyNotifications(firstPost.payload);
    const fixedCreatedAt = new Date().toISOString();
    const alignCreatedAt = await service
      .from("notifications")
      .update({ created_at: fixedCreatedAt })
      .in("matching_post_id", matchingPostIds);
    if (alignCreatedAt.error) throw alignCreatedAt.error;

    const authorList = await api(baseUrl, "/api/notifications", author.token);
    const bList = await api(baseUrl, "/api/notifications", b.token);
    const cList = await api(baseUrl, "/api/notifications", c.token);
    record(
      "recipient rows and author exclusion",
      authorList.payload?.length === 0 && bList.payload?.length === 2 && cList.payload?.length === 2,
      `author=${authorList.payload?.length}, b=${bList.payload?.length}, c=${cList.payload?.length}`
    );
    record(
      "duplicate event prevented",
      bList.payload?.filter((item) => item.matchingPostId === firstPost.payload?.id).length === 1 &&
        cList.payload?.filter((item) => item.matchingPostId === firstPost.payload?.id).length === 1,
      `b=${bList.payload?.length}, c=${cList.payload?.length}`
    );
    const duplicateConstraint = await service.from("notifications").insert({
      id: `notification_duplicate_${Date.now()}`,
      user_id: b.id,
      type: "favorite_restaurant_party_created",
      title: "duplicate",
      body: "duplicate",
      restaurant_id: restaurantId,
      matching_post_id: firstPost.payload?.id,
      actor_user_id: author.id
    });
    record(
      "database unique event constraint",
      duplicateConstraint.error?.code === "23505",
      `code=${duplicateConstraint.error?.code}`
    );
    record(
      "notification event fields",
      [...(bList.payload ?? []), ...(cList.payload ?? [])].every(
        (item) =>
          item.type === "favorite_restaurant_party_created" &&
          item.restaurantId === restaurantId &&
          matchingPostIds.includes(item.matchingPostId) &&
          item.actorUserId === author.id &&
          item.title === "찜한 식당에 새 파티가 열렸어요" &&
          item.body === "가고 싶어한 식당의 새 식사 동행 모집을 확인해 보세요."
      ),
      `rows=${(bList.payload?.length ?? 0) + (cList.payload?.length ?? 0)}`
    );
    record(
      "createdAt and secondary id ordering",
      bList.payload?.every(
        (item, index, rows) =>
          index === 0 ||
          rows[index - 1].createdAt > item.createdAt ||
          (rows[index - 1].createdAt === item.createdAt && rows[index - 1].id > item.id)
      ),
      `count=${bList.payload?.length}`
    );

    const paged = await api(baseUrl, "/api/notifications?limit=1&offset=1", b.token);
    const invalidPage = await api(baseUrl, "/api/notifications?limit=101&offset=-1", b.token);
    record(
      "pagination and validation",
      paged.status === 200 && paged.payload?.length === 1 &&
        paged.payload[0].id === bList.payload?.[1]?.id && invalidPage.status === 400,
      `paged=${paged.status}, invalid=${invalidPage.status}`
    );

    const unreadBefore = await api(baseUrl, "/api/notifications/unread-count", b.token);
    const read = await api(baseUrl, `/api/notifications/${bList.payload?.[0]?.id}/read`, b.token, {
      method: "PATCH"
    });
    const unreadAfter = await api(baseUrl, "/api/notifications/unread-count", b.token);
    const cUnread = await api(baseUrl, "/api/notifications/unread-count", c.token);
    record(
      "read state isolation",
      unreadBefore.payload?.unreadCount === 2 && read.status === 200 &&
        unreadAfter.payload?.unreadCount === 1 && cUnread.payload?.unreadCount === 2,
      `before=${unreadBefore.payload?.unreadCount}, after=${unreadAfter.payload?.unreadCount}, c=${cUnread.payload?.unreadCount}`
    );

    const replayRead = await api(baseUrl, `/api/notifications/${bList.payload?.[0]?.id}/read`, b.token, {
      method: "PATCH",
      body: JSON.stringify({ userId: c.id })
    });
    record(
      "read replay preserves readAt and ignores body userId",
      replayRead.status === 200 && replayRead.payload?.readAt === read.payload?.readAt,
      `status=${replayRead.status}`
    );

    const otherRead = await api(baseUrl, `/api/notifications/${cList.payload?.[0]?.id}/read`, b.token, {
      method: "PATCH"
    });
    record("other user read rejected", otherRead.status === 403, `status=${otherRead.status}`);

    const unknownRead = await api(baseUrl, "/api/notifications/notification_missing_fixture/read", b.token, {
      method: "PATCH"
    });
    record("missing notification policy", unknownRead.status === 404, `status=${unknownRead.status}`);

    const legacyPost = await createPost("restaurantId 없는 legacy 알림 테스트", null);
    if (legacyPost.payload?.id) matchingPostIds.push(legacyPost.payload.id);
    const bAfterLegacy = await api(baseUrl, "/api/notifications", b.token);
    record(
      "legacy post creates no notification",
      legacyPost.status === 201 && bAfterLegacy.payload?.length === 2,
      `post=${legacyPost.status}, notifications=${bAfterLegacy.payload?.length}`
    );

    const originalCreateMany = repositories.notifications.createMany;
    const originalConsoleError = console.error;
    let failurePost;
    try {
      repositories.notifications.createMany = async () => {
        throw new Error("simulated notification persistence failure");
      };
      console.error = () => undefined;
      failurePost = await createPost("알림 실패 best-effort 테스트");
    } finally {
      repositories.notifications.createMany = originalCreateMany;
      console.error = originalConsoleError;
    }
    if (failurePost.payload?.id) matchingPostIds.push(failurePost.payload.id);
    const bAfterFailure = await api(baseUrl, "/api/notifications", b.token);
    record(
      "best-effort notification failure boundary",
      failurePost.status === 201 && bAfterFailure.payload?.length === 2,
      `post=${failurePost.status}, notifications=${bAfterFailure.payload?.length}`
    );

    const anonRead = await anon.from("notifications").select("id").limit(1);
    const authenticatedRead = await b.client.from("notifications").select("id").limit(1);
    const directPayload = {
      id: `notification_spoof_${Date.now()}`,
      user_id: b.id,
      type: "favorite_restaurant_party_created",
      title: "spoof",
      body: "spoof",
      restaurant_id: restaurantId,
      matching_post_id: firstPost.payload?.id,
      actor_user_id: author.id
    };
    const anonInsert = await anon.from("notifications").insert(directPayload);
    const authenticatedInsert = await b.client.from("notifications").insert(directPayload);
    const authenticatedUpdate = await b.client
      .from("notifications")
      .update({ read_at: new Date().toISOString() })
      .eq("id", bList.payload?.[1]?.id);
    record("anon direct table access denied", anonRead.error?.code === "42501", `code=${anonRead.error?.code}`);
    record("authenticated direct table access denied", authenticatedRead.error?.code === "42501", `code=${authenticatedRead.error?.code}`);
    record("anon direct insert denied", anonInsert.error?.code === "42501", `code=${anonInsert.error?.code}`);
    record("authenticated direct insert denied", authenticatedInsert.error?.code === "42501", `code=${authenticatedInsert.error?.code}`);
    record("authenticated direct update denied", authenticatedUpdate.error?.code === "42501", `code=${authenticatedUpdate.error?.code}`);

    const storedRows = await service
      .from("notifications")
      .select("*")
      .in("matching_post_id", [firstPost.payload?.id, secondPost.payload?.id]);
    const forbiddenColumns = ["phone", "phoneNumber", "phone_number", "birthDate", "birth_date", "gender", "verification", "latitude", "longitude", "location"];
    record(
      "notification row privacy",
      !storedRows.error && storedRows.data?.length === 4 && storedRows.data.every(
        (row) => forbiddenColumns.every((column) => !(column in row))
      ) && bList.payload.every((row) => forbiddenColumns.every((column) => !(column in row))),
      storedRows.error ? "query failed" : `rows=${storedRows.data?.length}`
    );

    await new Promise((resolve) => server.close(resolve));
    server = app.listen(0);
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    const afterRestart = await api(baseUrl, "/api/notifications", b.token);
    const unreadAfterRestart = await api(baseUrl, "/api/notifications/unread-count", b.token);
    const cUnreadAfterRestart = await api(baseUrl, "/api/notifications/unread-count", c.token);
    record(
      "restart persistence and read state",
      afterRestart.status === 200 && afterRestart.payload?.length === 2 &&
        afterRestart.payload.map((item) => item.id).join(",") === bList.payload.map((item) => item.id).join(",") &&
        afterRestart.payload.find((item) => item.id === bList.payload[0].id)?.readAt === read.payload.readAt &&
        unreadAfterRestart.payload?.unreadCount === 1 && cUnreadAfterRestart.payload?.unreadCount === 2,
      `status=${afterRestart.status}, count=${afterRestart.payload?.length}, bUnread=${unreadAfterRestart.payload?.unreadCount}, cUnread=${cUnreadAfterRestart.payload?.unreadCount}`
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
    if (matchingPostIds.length > 0) {
      const notifications = await service.from("notifications").delete().in("matching_post_id", matchingPostIds);
      if (notifications.error) throw notifications.error;
      const post = await service.from("matching_posts").delete().in("id", matchingPostIds);
      if (post.error) throw post.error;
      const remaining = await service
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .in("matching_post_id", matchingPostIds);
      record(
        "notification cleanup",
        !remaining.error && remaining.count === 0,
        remaining.error ? "query failed" : `remaining=${remaining.count}`
      );
    }
    if (restaurantId) {
      const favorites = await service.from("restaurant_favorites").delete().eq("restaurant_id", restaurantId);
      if (favorites.error) throw favorites.error;
      const restaurant = await service.from("restaurants").delete().eq("id", restaurantId);
      if (restaurant.error) throw restaurant.error;
    }
    if (users.length > 0) {
      const userIds = users.map((user) => user.id);
      const mannerProfiles = await service
        .from("user_manner_profiles")
        .delete()
        .in("user_id", userIds);
      if (mannerProfiles.error) throw mannerProfiles.error;

      for (const user of users) {
        const deletedUser = await service.auth.admin.deleteUser(user.id);
        if (deletedUser.error) throw deletedUser.error;
      }
    }
  }

  for (const result of results) {
    console.log(`[NOTIFICATION_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[NOTIFICATION_SUPABASE] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
