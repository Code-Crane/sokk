process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.RATE_LIMIT_RESTAURANT_WRITE_MAX = "100";

const { app } = require("../dist/server/app");
const {
  createFavoriteRestaurantPartyNotifications
} = require("../dist/server/services/notification/notification.service");
const { repositories } = require("../dist/server/repositories");

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
      email: `notification-${label}-${Date.now()}@example.com`,
      nickname: `${label}-notification`,
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

async function main() {
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const author = await signup(baseUrl, "author");
    const b = await signup(baseUrl, "b");
    const c = await signup(baseUrl, "c");
    await verify(baseUrl, author.token);

    const restaurant = await api(baseUrl, "/api/restaurants", author.token, {
      method: "POST",
      body: JSON.stringify({
        name: "알림 메모리 식당",
        address: "서울시 테스트구 알림로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "notification-test",
        placeProvider: "notification-memory",
        placeProviderId: `notification-${Date.now()}`
      })
    });
    record("restaurant create", restaurant.status === 201, `status=${restaurant.status}`);

    for (const user of [author, b, c]) {
      const favorite = await api(
        baseUrl,
        `/api/restaurants/${restaurant.payload?.id}/favorite`,
        user.token,
        { method: "POST" }
      );
      record(`favorite ${user.userId}`, favorite.status === 201, `status=${favorite.status}`);
    }

    const createPost = (label) =>
      api(baseUrl, "/api/matching/posts", author.token, {
        method: "POST",
        body: JSON.stringify({
          restaurantId: restaurant.payload?.id,
          restaurantName: restaurant.payload?.name,
          address: restaurant.payload?.address,
          scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
          maxParticipants: 2,
          intro: label
        })
      });

    const firstPost = await createPost("첫 번째 찜 식당 파티");
    await new Promise((resolve) => setTimeout(resolve, 2));
    const secondPost = await createPost("두 번째 찜 식당 파티");
    record(
      "matching posts created",
      firstPost.status === 201 && secondPost.status === 201,
      `first=${firstPost.status}, second=${secondPost.status}`
    );

    const originalCreateMany = repositories.notifications.createMany;
    const originalConsoleError = console.error;
    let notificationFailurePost;
    try {
      repositories.notifications.createMany = async () => {
        throw new Error("simulated notification persistence failure");
      };
      console.error = () => undefined;
      notificationFailurePost = await createPost("알림 실패 경계 테스트");
    } finally {
      repositories.notifications.createMany = originalCreateMany;
      console.error = originalConsoleError;
    }
    record(
      "notification failure does not roll back matching",
      notificationFailurePost.status === 201,
      `status=${notificationFailurePost.status}`
    );

    await createFavoriteRestaurantPartyNotifications(firstPost.payload);
    const authorList = await api(baseUrl, "/api/notifications", author.token);
    const bList = await api(baseUrl, "/api/notifications", b.token);
    const cList = await api(baseUrl, "/api/notifications", c.token);
    record(
      "favorite recipients and author exclusion",
      authorList.status === 200 && authorList.payload?.length === 0 &&
        bList.payload?.length === 2 && cList.payload?.length === 2,
      `author=${authorList.payload?.length}, b=${bList.payload?.length}, c=${cList.payload?.length}`
    );
    record(
      "duplicate event idempotency",
      bList.payload?.filter((item) => item.matchingPostId === firstPost.payload?.id).length === 1,
      `count=${bList.payload?.length}`
    );
    record(
      "deterministic ordering",
      bList.payload?.every(
        (item, index, rows) =>
          index === 0 ||
          rows[index - 1].createdAt > item.createdAt ||
          (rows[index - 1].createdAt === item.createdAt && rows[index - 1].id > item.id)
      ),
      `count=${bList.payload?.length}`
    );

    const paged = await api(baseUrl, "/api/notifications?limit=1&offset=1", b.token);
    record("notification pagination", paged.status === 200 && paged.payload?.length === 1, `status=${paged.status}`);
    const invalidPage = await api(baseUrl, "/api/notifications?limit=101&offset=-1", b.token);
    record("invalid pagination rejected", invalidPage.status === 400, `status=${invalidPage.status}`);
    const unauthenticated = await api(baseUrl, "/api/notifications");
    record("unauthenticated list rejected", unauthenticated.status === 401, `status=${unauthenticated.status}`);

    const bUnreadBefore = await api(baseUrl, "/api/notifications/unread-count", b.token);
    const cUnreadBefore = await api(baseUrl, "/api/notifications/unread-count", c.token);
    record(
      "unread count",
      bUnreadBefore.payload?.unreadCount === 2 && cUnreadBefore.payload?.unreadCount === 2,
      `b=${bUnreadBefore.payload?.unreadCount}, c=${cUnreadBefore.payload?.unreadCount}`
    );

    const bNotificationId = bList.payload?.[0]?.id;
    const cNotificationId = cList.payload?.[0]?.id;
    const read = await api(baseUrl, `/api/notifications/${bNotificationId}/read`, b.token, {
      method: "PATCH",
      body: JSON.stringify({ userId: c.userId })
    });
    const replay = await api(baseUrl, `/api/notifications/${bNotificationId}/read`, b.token, {
      method: "PATCH"
    });
    record(
      "own read and idempotent replay",
      read.status === 200 && Boolean(read.payload?.readAt) && replay.payload?.readAt === read.payload?.readAt,
      `read=${read.status}, replay=${replay.status}`
    );

    const otherRead = await api(baseUrl, `/api/notifications/${cNotificationId}/read`, b.token, {
      method: "PATCH"
    });
    record("other user read rejected", otherRead.status === 403, `status=${otherRead.status}`);

    const bUnreadAfter = await api(baseUrl, "/api/notifications/unread-count", b.token);
    const cUnreadAfter = await api(baseUrl, "/api/notifications/unread-count", c.token);
    record(
      "read isolation",
      bUnreadAfter.payload?.unreadCount === 1 && cUnreadAfter.payload?.unreadCount === 2,
      `b=${bUnreadAfter.payload?.unreadCount}, c=${cUnreadAfter.payload?.unreadCount}`
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  for (const result of results) {
    console.log(`[NOTIFICATION_MEMORY] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[NOTIFICATION_MEMORY] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
