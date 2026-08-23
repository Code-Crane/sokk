const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");
dotenv.config();

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const results = [];
const record = (name, pass, details = "") => results.push({ name, pass, details });
const client = (key) => createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

async function createUser(label) {
  const email = `mukking-rating-${label}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceKey);
  const created = await service.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { nickname: `${label}-rating`, phoneNumber: "01012345678" } });
  if (created.error || !created.data.user) throw new Error(`${label} user creation failed.`);
  const authenticated = client(anonKey);
  const login = await authenticated.auth.signInWithPassword({ email, password });
  if (login.error || !login.data.session?.access_token) throw new Error(`${label} login failed.`);
  return { id: created.data.user.id, token: login.data.session.access_token, client: authenticated };
}

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}
const start = (app) => new Promise((resolve, reject) => { const server = app.listen(0, "127.0.0.1", () => resolve(server)); server.once("error", reject); });
const stop = (server) => server ? new Promise((resolve) => server.close(resolve)) : Promise.resolve();

async function verify(baseUrl, user) {
  if ((await api(baseUrl, "/api/auth/me", user.token)).status !== 200) throw new Error("Profile sync failed.");
  const response = await api(baseUrl, "/api/auth/verification/mock", user.token, { method: "POST", body: JSON.stringify({ legalName: "먹킹테스터", birthDate: "1995-01-01", gender: "other", phoneNumber: "01012345678" }) });
  if (response.status !== 200) throw new Error("Verification failed.");
}

async function main() {
  if (!url || !anonKey || !serviceKey) throw new Error("Supabase server environment is missing.");
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";
  const service = client(serviceKey);
  const anon = client(anonKey);
  const users = [];
  let server;
  let restaurantId;
  let postId;
  let sanctionId;
  let temporarySanctionId;
  const cleanupErrors = [];
  try {
    const host = await createUser("host"); users.push(host);
    const guest = await createUser("guest"); users.push(guest);
    const outsider = await createUser("outsider"); users.push(outsider);
    const { app } = require("../dist/server/app");
    server = await start(app);
    let baseUrl = `http://127.0.0.1:${server.address().port}`;
    for (const user of users) await verify(baseUrl, user);

    const restaurant = await api(baseUrl, "/api/restaurants", host.token, { method: "POST", body: JSON.stringify({ name: "평가 Supabase 영속성 식당", address: "서울시 평가구", latitude: 37.5, longitude: 127.0, category: "test", placeProvider: "fixture", placeProviderId: `rating-${Date.now()}` }) });
    restaurantId = restaurant.payload?.id;
    const post = await api(baseUrl, "/api/matching/posts", host.token, { method: "POST", body: JSON.stringify({ restaurantId, restaurantName: "평가 Supabase 영속성 식당", address: "서울시 평가구", scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 1, intro: "평가 영속성" }) });
    postId = post.payload?.id;
    const join = await api(baseUrl, `/api/matching/posts/${postId}/requests`, guest.token, { method: "POST" });
    const accepted = await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, { method: "POST", body: JSON.stringify({ decision: "accepted" }) });
    const completed = await api(baseUrl, `/api/matching/posts/${postId}/complete`, host.token, { method: "POST" });
    const hostPending = await api(baseUrl, "/api/rating/pending", host.token);
    const guestPending = await api(baseUrl, "/api/rating/pending", guest.token);
    record("completion creates mutual pending rows", accepted.status === 200 && completed.status === 200 && hostPending.payload?.length === 1 && guestPending.payload?.length === 1, `complete=${completed.status}`);

    const pendingRows = await service.from("pending_evaluations").select("id").eq("matching_post_id", postId);
    const pendingDetails = await service.from("pending_evaluations").select("reviewer_id,reviewee_id").eq("matching_post_id", postId);
    record("pending rows persisted without self pairs", !pendingRows.error && pendingRows.data?.length === 2 && pendingDetails.data?.every((row) => row.reviewer_id !== row.reviewee_id), `count=${pendingRows.data?.length ?? 0}`);
    const duplicateComplete = await api(baseUrl, `/api/matching/posts/${postId}/complete`, host.token, { method: "POST" });
    const pendingAfterDuplicate = await service.from("pending_evaluations").select("id", { count: "exact", head: true }).eq("matching_post_id", postId);
    record("duplicate completion does not duplicate pending", duplicateComplete.status === 409 && pendingAfterDuplicate.count === 2, `status=${duplicateComplete.status}, count=${pendingAfterDuplicate.count}`);
    const matchingGate = await api(baseUrl, "/api/matching/posts", host.token, { method: "POST", body: JSON.stringify({ restaurantName: "평가 게이트", address: "서울", scheduledAt: new Date(Date.now() + 172800000).toISOString(), maxParticipants: 1, intro: "pending gate" }) });
    record("pending blocks new matching", matchingGate.status === 403, `status=${matchingGate.status}`);
    const spoof = await api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: postId, revieweeId: outsider.id, reviewerId: guest.id, score: 5, tags: [] }) });
    record("evaluatee spoof rejected", spoof.status === 404, `status=${spoof.status}`);
    const invalidLow = await api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: postId, revieweeId: guest.id, score: 0, tags: [] }) });
    const invalidHigh = await api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: postId, revieweeId: guest.id, score: 6, tags: [] }) });
    record("score range validation", invalidLow.status === 400 && invalidHigh.status === 400, `low=${invalidLow.status}, high=${invalidHigh.status}`);
    const concurrent = await Promise.all([
      api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: postId, revieweeId: guest.id, reviewerId: guest.id, score: 5, tags: ["on_time", "kind"] }) }),
      api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: postId, revieweeId: guest.id, reviewerId: outsider.id, score: 5, tags: ["on_time", "kind"] }) })
    ]);
    const successes = concurrent.filter((response) => response.status === 201);
    const submitted = successes[0];
    record("atomic concurrent submit and JWT reviewer", successes.length === 1 && submitted?.payload?.previousScore === 36.5 && submitted?.payload?.nextScore === 38.8, `statuses=${concurrent.map((response) => response.status).join(",")}`);
    const duplicate = await api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: postId, revieweeId: guest.id, score: 5, tags: [] }) });
    record("duplicate review rejected", duplicate.status === 404, `status=${duplicate.status}`);

    const ratingRows = await service.from("manner_ratings").select("reviewer_id,reviewee_id,next_score").eq("matching_post_id", postId);
    const profile = await service.from("user_manner_profiles").select("manner_score,manner_grade").eq("user_id", guest.id).single();
    const remainingExactPending = await service.from("pending_evaluations").select("id", { count: "exact", head: true }).eq("matching_post_id", postId).eq("reviewer_id", host.id).eq("reviewee_id", guest.id);
    record("rating and manner profile persisted atomically", ratingRows.data?.length === 1 && ratingRows.data[0]?.reviewer_id === host.id && Number(ratingRows.data[0]?.next_score) === 38.8 && Number(profile.data?.manner_score) === 38.8 && profile.data?.manner_grade === "regular" && remainingExactPending.count === 0, `ratings=${ratingRows.data?.length ?? 0}, pending=${remainingExactPending.count}`);

    temporarySanctionId = `sanction_rating_temp_${Date.now()}`;
    await service.from("sanctions").insert({ id: temporarySanctionId, user_id: outsider.id, type: "temporary_suspension", status: "active", reason: "rating persistence policy check" });
    const suspendedPending = await api(baseUrl, "/api/rating/pending", outsider.token);
    record("temporary suspension current rating policy measured", suspendedPending.status === 200, `status=${suspendedPending.status}`);
    sanctionId = `sanction_rating_${Date.now()}`;
    const bannedFixture = await service.from("sanctions").insert({ id: sanctionId, user_id: outsider.id, type: "permanent_ban", status: "active", reason: "rating persistence validation" });
    const bannedPending = await api(baseUrl, "/api/rating/pending", outsider.token);
    record("permanent ban blocks rating access", !bannedFixture.error && bannedPending.status === 403, `status=${bannedPending.status}`);

    for (const table of ["pending_evaluations", "manner_ratings", "user_manner_profiles"]) {
      const anonRead = await anon.from(table).select("*").limit(1);
      const authRead = await outsider.client.from(table).select("*").limit(1);
      record(`RLS anon ${table} blocked`, Boolean(anonRead.error) || anonRead.data?.length === 0, "direct read");
      record(`RLS authenticated ${table} blocked`, Boolean(authRead.error) || authRead.data?.length === 0, "direct read");
    }

    await stop(server); server = undefined;
    server = await start(app); baseUrl = `http://127.0.0.1:${server.address().port}`;
    const pendingAfter = await api(baseUrl, "/api/rating/pending", host.token);
    const guestAfter = await api(baseUrl, "/api/auth/me", guest.token);
    const roomsAfter = await api(baseUrl, "/api/chat/rooms", host.token);
    record("pending completion persists after restart", pendingAfter.status === 200 && pendingAfter.payload?.length === 0, `status=${pendingAfter.status}`);
    record("manner score and grade persist after restart", guestAfter.status === 200 && guestAfter.payload?.mannerScore === 38.8 && guestAfter.payload?.mannerGrade === "regular", `status=${guestAfter.status}`);
    record("matching and chat remain compatible", roomsAfter.status === 200 && roomsAfter.payload?.some((room) => room.id === accepted.payload?.chatRoom?.id), `status=${roomsAfter.status}`);
  } finally {
    await stop(server);
    const sanctionIds = [sanctionId, temporarySanctionId].filter(Boolean);
    if (sanctionIds.length) {
      const result = await service.from("sanctions").delete().in("id", sanctionIds);
      if (result.error) cleanupErrors.push("sanctions");
    }
    if (postId) {
      for (const table of ["pending_evaluations", "manner_ratings", "chat_rooms"]) {
        const result = await service.from(table).delete().eq("matching_post_id", postId);
        if (result.error) cleanupErrors.push(table);
      }
      const result = await service.from("matching_posts").delete().eq("id", postId);
      if (result.error) cleanupErrors.push("matching_posts");
    }
    if (restaurantId) {
      const favorite = await service.from("restaurant_favorites").delete().eq("restaurant_id", restaurantId);
      const restaurant = await service.from("restaurants").delete().eq("id", restaurantId);
      if (favorite.error) cleanupErrors.push("favorites");
      if (restaurant.error) cleanupErrors.push("restaurants");
    }
    if (users.length) {
      const profiles = await service.from("user_manner_profiles").delete().in("user_id", users.map((user) => user.id));
      if (profiles.error) cleanupErrors.push("manner_profiles");
    }
    for (const user of users) {
      const result = await service.auth.admin.deleteUser(user.id);
      if (result.error) cleanupErrors.push("auth_users");
    }
    record("test data cleanup", cleanupErrors.length === 0, cleanupErrors.length ? `failed=${cleanupErrors.join(",")}` : "exact test IDs removed");
  }
  for (const result of results) console.log(`[RATING_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}
main().catch((error) => { console.error(`[RATING_SUPABASE] FAIL ${error instanceof Error ? error.message : "unknown error"}`); process.exitCode = 1; });
