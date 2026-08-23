const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const results = [];

function required(name, value) {
  if (!value) throw new Error(`${name} is missing.`);
}

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

function client(key) {
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
}

function email(label) {
  return `mukking-matching-${label}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
}

async function createUser(label) {
  const accountEmail = email(label);
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email: accountEmail,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-matching`, phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) throw new Error(`${label} user creation failed.`);

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email: accountEmail, password });
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

function startServer(app) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
    server.once("error", reject);
  });
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
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

  const host = await createUser("host");
  const guest = await createUser("guest");
  const rejectGuest = await createUser("reject");
  const overflowGuest = await createUser("overflow");
  const anon = client(anonKey);
  const service = client(serviceRoleKey);
  const { app } = require("../dist/server/app");
  let server;
  const postIds = [];
  let restaurantId;

  try {
    server = await startServer(app);
    let baseUrl = `http://127.0.0.1:${server.address().port}`;
    await verify(baseUrl, host);
    await verify(baseUrl, guest);
    await verify(baseUrl, rejectGuest);
    await verify(baseUrl, overflowGuest);

    const restaurant = await api(baseUrl, "/api/restaurants", host.token, {
      method: "POST",
      body: JSON.stringify({
        name: "매칭 영속성 테스트 식당",
        address: "서울시 테스트구 영속성로 2",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "test",
        placeProvider: "fixture",
        placeProviderId: `matching-persistence-${Date.now()}`
      })
    });
    restaurantId = restaurant.payload?.id;
    record("restaurant setup", restaurant.status === 201 && Boolean(restaurantId), `status=${restaurant.status}`);

    const createPost = async (intro, maxParticipants = 2, restaurantIdOverride = restaurantId) => {
      const result = await api(baseUrl, "/api/matching/posts", host.token, {
        method: "POST",
        body: JSON.stringify({
          restaurantId: restaurantIdOverride,
          authorId: rejectGuest.id,
          restaurantName: restaurant.payload?.name,
          address: restaurant.payload?.address,
          scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
          maxParticipants,
          intro
        })
      });
      if (result.payload?.id) postIds.push(result.payload.id);
      return result;
    };

    const post = await createPost("영속성 참여 요청 테스트");
    record("matching post row created", post.status === 201, `status=${post.status}`);
    record(
      "author derived from JWT",
      post.payload?.authorId === host.id && post.payload?.maxParticipants === 2 && Boolean(post.payload?.scheduledAt),
      `author=${post.payload?.authorId === host.id ? "jwt" : "unexpected"}`
    );

    const legacyPost = await createPost("legacy 식당명 게시글", 2, null);
    record(
      "legacy post without restaurantId",
      legacyPost.status === 201 && !legacyPost.payload?.restaurantId,
      `status=${legacyPost.status}`
    );

    const unknownRestaurantPost = await createPost("없는 식당 거부", 2, "restaurant_missing_fixture");
    record("unknown restaurantId rejected", unknownRestaurantPost.status === 404, `status=${unknownRestaurantPost.status}`);

    const join = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, guest.token, {
      method: "POST",
      body: JSON.stringify({ requesterId: host.id })
    });
    record("join request row created", join.status === 201, `status=${join.status}`);
    record("requester derived from JWT", join.payload?.requesterId === guest.id, `requester=${join.payload?.requesterId === guest.id ? "jwt" : "unexpected"}`);

    const duplicateJoin = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, guest.token, {
      method: "POST"
    });
    record("pending join duplicate rejected", duplicateJoin.status === 409, `status=${duplicateJoin.status}`);

    const directAuthRead = await host.client.from("matching_posts").select("id").eq("id", post.payload?.id);
    record(
      "RLS authenticated matching direct read blocked",
      Boolean(directAuthRead.error) || directAuthRead.data?.length === 0,
      directAuthRead.error ? "permission blocked" : `count=${directAuthRead.data?.length}`
    );

    const anonPostRead = await anon.from("matching_posts").select("id").eq("id", post.payload?.id);
    const authJoinRead = await host.client.from("join_requests").select("id").eq("id", join.payload?.id);
    const anonJoinRead = await anon.from("join_requests").select("id").eq("id", join.payload?.id);
    record("RLS anon matching direct read blocked", Boolean(anonPostRead.error) || anonPostRead.data?.length === 0, "anon matching_posts");
    record("RLS authenticated join direct read blocked", Boolean(authJoinRead.error) || authJoinRead.data?.length === 0, "authenticated join_requests");
    record("RLS anon join direct read blocked", Boolean(anonJoinRead.error) || anonJoinRead.data?.length === 0, "anon join_requests");

    await new Promise((resolve) => server.close(resolve));
    server = await startServer(app);
    baseUrl = `http://127.0.0.1:${server.address().port}`;

    const afterRestartPosts = await api(baseUrl, "/api/matching/posts", host.token);
    record(
      "post persists after restart",
      afterRestartPosts.status === 200 && afterRestartPosts.payload?.some((item) => item.id === post.payload?.id),
      `status=${afterRestartPosts.status}`
    );

    const afterRestartRequests = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, host.token);
    record(
      "join request persists after restart",
      afterRestartRequests.status === 200 && afterRestartRequests.payload?.length === 1,
      `status=${afterRestartRequests.status}`
    );

    const partyCount = await api(baseUrl, `/api/restaurants/${restaurantId}`, host.token);
    record(
      "restaurant active party count from persisted post",
      partyCount.status === 200 && partyCount.payload?.activePartyCount === 1,
      `status=${partyCount.status}, count=${partyCount.payload?.activePartyCount}`
    );

    const accepted = await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, {
      method: "POST",
      body: JSON.stringify({ decision: "accepted" })
    });
    record(
      "accept persisted request and chat compatibility",
      accepted.status === 200 && accepted.payload?.request?.status === "accepted" && Boolean(accepted.payload?.chatRoom?.id),
      `status=${accepted.status}`
    );

    const acceptedPost = await api(baseUrl, "/api/matching/posts", host.token);
    const persistedPost = acceptedPost.payload?.find((item) => item.id === post.payload?.id);
    record(
      "accepted participant persisted",
      Array.isArray(persistedPost?.participantIds) && persistedPost.participantIds.includes(guest.id),
      "participant ids"
    );
    record("capacity remains open below limit", persistedPost?.status === "open", `status=${persistedPost?.status}`);

    const repeatAccept = await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, {
      method: "POST",
      body: JSON.stringify({ decision: "accepted" })
    });
    record("processed request cannot be accepted twice", repeatAccept.status === 409, `status=${repeatAccept.status}`);

    const rejectPost = await createPost("영속성 거절 테스트");
    const rejectJoin = await api(baseUrl, `/api/matching/posts/${rejectPost.payload?.id}/requests`, rejectGuest.token, {
      method: "POST"
    });
    const rejected = await api(baseUrl, `/api/matching/requests/${rejectJoin.payload?.id}/respond`, host.token, {
      method: "POST",
      body: JSON.stringify({ decision: "rejected" })
    });
    record("rejected join persisted", rejected.status === 200 && rejected.payload?.request?.status === "rejected", `status=${rejected.status}`);

    const capacityPost = await createPost("정원 경합 테스트", 1);
    const capacityJoinA = await api(baseUrl, `/api/matching/posts/${capacityPost.payload?.id}/requests`, rejectGuest.token, { method: "POST" });
    const capacityJoinB = await api(baseUrl, `/api/matching/posts/${capacityPost.payload?.id}/requests`, overflowGuest.token, { method: "POST" });
    const concurrentAccepts = await Promise.all([
      api(baseUrl, `/api/matching/requests/${capacityJoinA.payload?.id}/respond`, host.token, {
        method: "POST",
        body: JSON.stringify({ decision: "accepted" })
      }),
      api(baseUrl, `/api/matching/requests/${capacityJoinB.payload?.id}/respond`, host.token, {
        method: "POST",
        body: JSON.stringify({ decision: "accepted" })
      })
    ]);
    const acceptedCount = concurrentAccepts.filter((result) => result.status === 200).length;
    const rejectedCount = concurrentAccepts.filter((result) => result.status === 409).length;
    record("atomic accept prevents double acceptance", acceptedCount === 1 && rejectedCount === 1, `accepted=${acceptedCount}, rejected=${rejectedCount}`);

    const capacityPosts = await api(baseUrl, "/api/matching/posts", host.token);
    const closedPost = capacityPosts.payload?.find((item) => item.id === capacityPost.payload?.id);
    record("capacity closes persisted post", closedPost?.status === "closed" && closedPost?.participantIds?.length === 1, `status=${closedPost?.status}, participants=${closedPost?.participantIds?.length}`);

    const completed = await api(baseUrl, `/api/matching/posts/${capacityPost.payload?.id}/complete`, host.token, { method: "POST" });
    record("complete persisted matching post", completed.status === 200 && completed.payload?.status === "completed" && Boolean(completed.payload?.completedAt), `status=${completed.status}`);
    const pendingRatings = await api(baseUrl, "/api/rating/pending", host.token);
    record("completion keeps rating integration", pendingRatings.status === 200 && pendingRatings.payload?.length > 0, `status=${pendingRatings.status}`);

    await new Promise((resolve) => server.close(resolve));
    server = await startServer(app);
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    const finalPosts = await api(baseUrl, "/api/matching/posts", host.token);
    const finalCompleted = finalPosts.payload?.find((item) => item.id === capacityPost.payload?.id);
    record(
      "completed status and participant persist after second restart",
      finalCompleted?.status === "completed" && Boolean(finalCompleted?.completedAt) && finalCompleted?.participantIds?.length === 1,
      `status=${finalCompleted?.status}`
    );
    const finalAcceptedRequests = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, host.token);
    const finalRejectedRequests = await api(baseUrl, `/api/matching/posts/${rejectPost.payload?.id}/requests`, host.token);
    record(
      "accepted request persists after second restart",
      finalAcceptedRequests.payload?.some((item) => item.id === join.payload?.id && item.status === "accepted"),
      `status=${finalAcceptedRequests.status}`
    );
    record(
      "rejected request persists after second restart",
      finalRejectedRequests.payload?.some((item) => item.id === rejectJoin.payload?.id && item.status === "rejected"),
      `status=${finalRejectedRequests.status}`
    );
    const finalPartyCount = await api(baseUrl, `/api/restaurants/${restaurantId}`, host.token);
    record(
      "active party count includes only open posts",
      finalPartyCount.status === 200 && finalPartyCount.payload?.activePartyCount === 2,
      `status=${finalPartyCount.status}, count=${finalPartyCount.payload?.activePartyCount}`
    );
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    if (postIds.length > 0) {
      for (const table of ["pending_evaluations", "manner_ratings"]) {
        const ratingCleanup = await service.from(table).delete().in("matching_post_id", postIds);
        if (
          ratingCleanup.error &&
          ratingCleanup.error.code !== "42P01" &&
          ratingCleanup.error.code !== "PGRST205"
        ) {
          throw ratingCleanup.error;
        }
      }
      // Chat persistence uses ON DELETE RESTRICT from rooms to matching posts.
      // Delete only rooms created from this script's exact post IDs first.
      const chatCleanup = await service.from("chat_rooms").delete().in("matching_post_id", postIds);
      if (
        chatCleanup.error &&
        chatCleanup.error.code !== "42P01" &&
        chatCleanup.error.code !== "PGRST205"
      ) {
        throw chatCleanup.error;
      }
      await service.from("matching_posts").delete().in("id", postIds);
    }
    if (restaurantId) {
      await service.from("restaurant_favorites").delete().eq("restaurant_id", restaurantId);
      await service.from("restaurants").delete().eq("id", restaurantId);
    }
    await service.auth.admin.deleteUser(host.id);
    await service.auth.admin.deleteUser(guest.id);
    await service.auth.admin.deleteUser(rejectGuest.id);
    await service.auth.admin.deleteUser(overflowGuest.id);
  }

  for (const result of results) {
    console.log(`[MATCHING_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[MATCHING_SUPABASE] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
