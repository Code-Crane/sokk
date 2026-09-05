const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const MARKER = "[TEST][JOIN_FLOW_VALIDATION]";
const CENTER = {
  latitude: 35.11462876256979,
  longitude: 129.03702048811923,
  radiusKm: 2
};
const command = process.argv[2] ?? "audit";
const requestedParticipantEmail =
  process.env.JOIN_FLOW_PARTICIPANT_EMAIL?.trim().toLowerCase() ?? "";

function required(name, value) {
  if (!value?.trim()) throw new Error(`${name} is missing.`);
}

function serviceClient() {
  return createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

function isAuthorProfile(profile) {
  return (
    String(profile.nickname).toLowerCase() === "test" &&
    String(profile.email).toLowerCase() === "test@mukking.local"
  );
}

function isParticipantProfile(profile) {
  if (requestedParticipantEmail) {
    return String(profile.email).toLowerCase() === requestedParticipantEmail;
  }
  return (
    String(profile.nickname).toLowerCase() === "postgis-tester" &&
    String(profile.email).toLowerCase().endsWith("@example.com")
  );
}

async function listAuthUsers(client) {
  const users = [];
  for (let page = 1; ; page += 1) {
    const result = await client.auth.admin.listUsers({ page, perPage: 1000 });
    if (result.error) throw result.error;
    users.push(...result.data.users);
    if (result.data.users.length < 1000) break;
  }
  return users;
}

async function accountAudit(client) {
  const profilesResult = await client
    .from("user_profiles")
    .select("user_id,email,nickname,verification_status,account_status");
  if (profilesResult.error) throw profilesResult.error;

  const profiles = profilesResult.data ?? [];
  const authUsers = await listAuthUsers(client);
  const authById = new Map(authUsers.map((user) => [user.id, user]));
  const author = profiles.find(isAuthorProfile);
  const participant = profiles
    .filter(isParticipantProfile)
    .sort((left, right) => left.user_id.localeCompare(right.user_id))[0];
  if (!author || !participant) {
    const requestedAuthUser = requestedParticipantEmail
      ? authUsers.find(
          (user) => String(user.email).toLowerCase() === requestedParticipantEmail
        )
      : null;
    if (requestedParticipantEmail) {
      console.log(
        `[JOIN_FLOW] PARTICIPANT_AUDIT email=${requestedParticipantEmail} ` +
          `auth=${requestedAuthUser ? "present" : "missing"} ` +
          `emailConfirmed=${Boolean(requestedAuthUser?.email_confirmed_at)} ` +
          `profile=${participant ? "present" : "missing"}`
      );
    }
    throw new Error(
      "[TEST USER REQUIRED] Existing author and participant test profiles were not both found."
    );
  }
  if (author.user_id === participant.user_id) {
    throw new Error("Author and participant must be different users.");
  }
  const accounts = [
    { role: "A", purpose: "author", profile: author },
    { role: "B", purpose: "participant", profile: participant }
  ];

  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  const { assertCanUseMatching } = require("../dist/server/services/auth/auth.service");

  for (const account of accounts) {
    const authUser = authById.get(account.profile.user_id);
    if (!authUser) {
      throw new Error(`Auth user missing for test role ${account.role}.`);
    }
    if (!authUser.email_confirmed_at) {
      throw new Error(`Auth email is not confirmed for test role ${account.role}.`);
    }

    const sanctions = await client
      .from("sanctions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", account.profile.user_id)
      .eq("status", "active");
    if (sanctions.error) throw sanctions.error;
    const pending = await client
      .from("pending_evaluations")
      .select("id", { count: "exact", head: true })
      .eq("reviewer_id", account.profile.user_id);
    if (pending.error) throw pending.error;
    const manner = await client
      .from("user_manner_profiles")
      .select("manner_score,manner_grade")
      .eq("user_id", account.profile.user_id)
      .maybeSingle();
    if (manner.error) throw manner.error;

    await assertCanUseMatching(account.profile.user_id);
    console.log(
      `[JOIN_FLOW] ACCOUNT ${account.role} purpose=${account.purpose} ` +
        `email=${account.profile.email} userId=${account.profile.user_id} ` +
        `auth=confirmed verification=${account.profile.verification_status} ` +
        `account=${account.profile.account_status} sanctions=${sanctions.count ?? 0} ` +
        `pendingEvaluations=${pending.count ?? 0} ` +
        `mannerGrade=${manner.data?.manner_grade ?? "default"} matching=PASS`
    );
  }

  return { author, participant };
}

async function findValidationPosts(client) {
  const result = await client
    .from("matching_posts")
    .select(
      "id,author_id,restaurant_id,restaurant_name,address,scheduled_at,max_participants,intro,status,participant_ids"
    )
    .like("intro", `${MARKER}%`)
    .order("created_at", { ascending: true });
  if (result.error) throw result.error;
  return result.data ?? [];
}

function printPosts(label, rows) {
  console.log(`[JOIN_FLOW] ${label} count=${rows.length}`);
  for (const row of rows) {
    console.log(
      `[JOIN_FLOW] PARTY id=${row.id} restaurantId=${row.restaurant_id} ` +
        `restaurant=${row.restaurant_name} scheduledAt=${row.scheduled_at} ` +
        `status=${row.status} members=${(row.participant_ids ?? []).length + 1}/${row.max_participants}`
    );
  }
}

async function deleteRows(client, table, column, ids) {
  if (ids.length === 0) return;
  const result = await client.from(table).delete().in(column, ids);
  if (result.error && !["42P01", "PGRST205"].includes(result.error.code)) {
    throw result.error;
  }
}

async function cleanup(client) {
  const rows = await findValidationPosts(client);
  printPosts("cleanup targets", rows);
  if (rows.length === 0) return;

  const postIds = rows.map((row) => row.id);
  const rooms = await client
    .from("chat_rooms")
    .select("id")
    .in("matching_post_id", postIds);
  if (rooms.error && !["42P01", "PGRST205"].includes(rooms.error.code)) {
    throw rooms.error;
  }
  const roomIds = (rooms.data ?? []).map((room) => room.id);

  await deleteRows(client, "chat_messages", "room_id", roomIds);
  await deleteRows(client, "chat_room_participants", "room_id", roomIds);
  await deleteRows(client, "chat_rooms", "matching_post_id", postIds);
  await deleteRows(client, "pending_evaluations", "matching_post_id", postIds);
  await deleteRows(client, "manner_ratings", "matching_post_id", postIds);
  await deleteRows(client, "notifications", "matching_post_id", postIds);
  await deleteRows(client, "join_requests", "post_id", postIds);
  await deleteRows(client, "matching_posts", "id", postIds);

  const remaining = await findValidationPosts(client);
  if (remaining.length !== 0) {
    throw new Error("Validation party cleanup did not reach zero rows.");
  }
  console.log(`[JOIN_FLOW] CLEANUP PASS deletedParties=${postIds.length}`);
}

function tomorrowKst(hour, minute) {
  const offsetMs = 9 * 60 * 60 * 1000;
  const nowKst = new Date(Date.now() + offsetMs);
  return new Date(
    Date.UTC(
      nowKst.getUTCFullYear(),
      nowKst.getUTCMonth(),
      nowKst.getUTCDate() + 1,
      hour - 9,
      minute
    )
  ).toISOString();
}

async function chooseRestaurant(client, authorId) {
  const { listRestaurants } = require("../dist/server/services/restaurant/restaurant.service");
  const nearby = await listRestaurants(authorId, {
    lat: CENTER.latitude,
    lng: CENTER.longitude,
    radiusKm: CENTER.radiusKm,
    limit: 50,
    offset: 0
  });
  const candidates = nearby.filter(
    (restaurant) =>
      restaurant.placeProvider === "kakao" &&
      Number.isFinite(restaurant.latitude) &&
      Number.isFinite(restaurant.longitude)
  );
  if (candidates.length === 0) {
    throw new Error("No nearby Kakao restaurant is available for validation.");
  }

  const favorites = await client
    .from("restaurant_favorites")
    .select("restaurant_id")
    .in("restaurant_id", candidates.map((restaurant) => restaurant.id));
  if (favorites.error) throw favorites.error;
  const favoritedIds = new Set((favorites.data ?? []).map((row) => row.restaurant_id));
  const restaurant = candidates.find((candidate) => !favoritedIds.has(candidate.id));
  if (!restaurant) {
    throw new Error(
      "No nearby Kakao restaurant without favorites is available; seed stopped to avoid test notifications."
    );
  }
  return restaurant;
}

async function seed(client) {
  const accounts = await accountAudit(client);
  await cleanup(client);

  const restaurant = await chooseRestaurant(client, accounts.author.user_id);
  const { createMatchingPost, listMatchingPosts } = require("../dist/server/services/matching/matching.service");
  const post = await createMatchingPost(accounts.author.user_id, {
    restaurantId: restaurant.id,
    restaurantName: restaurant.name,
    address: restaurant.roadAddress || restaurant.address,
    location: {
      latitude: restaurant.latitude,
      longitude: restaurant.longitude
    },
    scheduledAt: tomorrowKst(19, 30),
    maxParticipants: 4,
    intro: `${MARKER} 같이 가요 → 승인 → 채팅 수동 검증`
  });

  const listed = (await listMatchingPosts()).filter((row) => row.id === post.id);
  if (
    listed.length !== 1 ||
    post.status !== "open" ||
    post.participantIds.length !== 0 ||
    Date.parse(post.scheduledAt) <= Date.now()
  ) {
    throw new Error("Validation party contract check failed.");
  }

  const nearby = await require("../dist/server/services/restaurant/restaurant.service").listRestaurants(
    accounts.author.user_id,
    {
      lat: CENTER.latitude,
      lng: CENTER.longitude,
      radiusKm: CENTER.radiusKm,
      limit: 50,
      offset: 0
    }
  );
  if (!nearby.some((row) => row.id === restaurant.id)) {
    throw new Error("Validation party restaurant is not present in nearby results.");
  }

  console.log(
    `[JOIN_FLOW] RESTAURANT id=${restaurant.id} name=${restaurant.name} ` +
      `lat=${restaurant.latitude} lng=${restaurant.longitude} ` +
      `distanceMeters=${restaurant.distanceMeters}`
  );
  console.log(
    `[JOIN_FLOW] PARTICIPANT_READY email=${accounts.participant.email} ` +
      `userId=${accounts.participant.user_id}`
  );
  printPosts("seeded", [
    {
      id: post.id,
      author_id: post.authorId,
      restaurant_id: post.restaurantId,
      restaurant_name: post.restaurantName,
      scheduled_at: post.scheduledAt,
      max_participants: post.maxParticipants,
      status: post.status,
      participant_ids: post.participantIds
    }
  ]);
  console.log("[JOIN_FLOW] SEED PASS readyForManualValidation=true");
}

async function fetchMatchingApi() {
  const { app } = require("../dist/server/app");
  const server = await new Promise((resolve, reject) => {
    const listening = app.listen(0, "127.0.0.1", () => resolve(listening));
    listening.once("error", reject);
  });
  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/matching/posts`
    );
    return {
      status: response.status,
      body: await response.json()
    };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function validate(client) {
  const accounts = await accountAudit(client);
  const rows = await findValidationPosts(client);
  if (rows.length !== 1) {
    throw new Error(`Expected one validation party, found ${rows.length}.`);
  }
  const post = rows[0];
  if (
    post.author_id !== accounts.author.user_id ||
    post.status !== "open" ||
    (post.participant_ids ?? []).length !== 0 ||
    post.max_participants < 2 ||
    Date.parse(post.scheduled_at) <= Date.now()
  ) {
    throw new Error("Validation party readiness check failed.");
  }

  const { assertNoActiveBlockBetween } = require("../dist/server/services/block/block.service");
  await assertNoActiveBlockBetween(
    accounts.participant.user_id,
    accounts.author.user_id,
    "matching"
  );

  const requests = await client
    .from("join_requests")
    .select("id", { count: "exact", head: true })
    .eq("post_id", post.id);
  if (requests.error) throw requests.error;
  const participantPendingRequests = await client
    .from("join_requests")
    .select("id", { count: "exact", head: true })
    .eq("post_id", post.id)
    .eq("requester_id", accounts.participant.user_id)
    .eq("status", "pending");
  if (participantPendingRequests.error) throw participantPendingRequests.error;
  if ((participantPendingRequests.count ?? 0) !== 0) {
    throw new Error("Participant already has a pending request for the validation party.");
  }
  const rooms = await client
    .from("chat_rooms")
    .select("id", { count: "exact", head: true })
    .eq("matching_post_id", post.id);
  if (rooms.error) throw rooms.error;

  const api = await fetchMatchingApi();
  const apiRows = Array.isArray(api.body)
    ? api.body.filter((row) => row.id === post.id)
    : [];
  if (api.status !== 200 || apiRows.length !== 1) {
    throw new Error(
      `Matching API validation failed: status=${api.status}, count=${apiRows.length}.`
    );
  }

  const restaurant = await client
    .from("restaurants")
    .select("id,name,latitude,longitude")
    .eq("id", post.restaurant_id)
    .maybeSingle();
  if (restaurant.error || !restaurant.data) {
    throw restaurant.error ?? new Error("Validation restaurant not found.");
  }

  printPosts("validated", rows);
  console.log(
    `[JOIN_FLOW] VALIDATE apiStatus=${api.status} apiCount=${apiRows.length} ` +
      `joinRequests=${requests.count ?? 0} chatRooms=${rooms.count ?? 0} ` +
      `participantPendingRequests=${participantPendingRequests.count ?? 0} ` +
      `distinctUsers=true matchingBlock=none ` +
      `participant=${accounts.participant.email} ready=true`
  );
}

async function main() {
  required("SUPABASE_URL", process.env.SUPABASE_URL);
  required("SUPABASE_SERVICE_ROLE_KEY", process.env.SUPABASE_SERVICE_ROLE_KEY);
  const client = serviceClient();

  if (command === "audit") return accountAudit(client);
  if (command === "seed") return seed(client);
  if (command === "list") return printPosts("current", await findValidationPosts(client));
  if (command === "validate") return validate(client);
  if (command === "cleanup") return cleanup(client);
  throw new Error(
    "Usage: matchingJoinFlowValidation.cjs [audit|seed|list|validate|cleanup]"
  );
}

main().catch((error) => {
  console.error(
    `[JOIN_FLOW] FAIL ${error instanceof Error ? error.message : "unknown error"}`
  );
  process.exitCode = 1;
});
