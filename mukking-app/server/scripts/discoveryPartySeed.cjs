const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const TEST_PREFIX = "[TEST][DISCOVERY_PARTY_SEED:";
const SEED_CENTER = {
  latitude: 35.11462876256979,
  longitude: 129.03702048811923,
  radiusKm: 2
};
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const command = process.argv[2] ?? "list";

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

function kstDateParts(timestamp = Date.now()) {
  const date = new Date(timestamp + KST_OFFSET_MS);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate()
  };
}

function kstIso(dayOffset, hour, minute) {
  const { year, month, day } = kstDateParts();
  return new Date(
    Date.UTC(year, month, day + dayOffset, hour - 9, minute, 0, 0)
  ).toISOString();
}

function nextKstOccurrence(hour, minute) {
  const today = kstIso(0, hour, minute);
  return Date.parse(today) > Date.now() + 5 * 60 * 1000
    ? today
    : kstIso(1, hour, minute);
}

function kstDayLabel(iso) {
  const target = kstDateParts(Date.parse(iso));
  const today = kstDateParts();
  const tomorrow = kstDateParts(Date.now() + 24 * 60 * 60 * 1000);
  const key = ({ year, month, day }) => `${year}-${month}-${day}`;
  if (key(target) === key(today)) return "오늘";
  if (key(target) === key(tomorrow)) return "내일";
  return `${target.month + 1}/${target.day}`;
}

function marker(key, title) {
  return `${TEST_PREFIX}${key}] ${title}`;
}

function buildMatrix(restaurantIds) {
  if (restaurantIds.length !== 3) {
    throw new Error("Exactly three nearby Kakao restaurants are required.");
  }
  const lunchA = nextKstOccurrence(12, 0);
  const dinnerB = nextKstOccurrence(19, 30);
  const nightC = nextKstOccurrence(22, 0);
  const tomorrowDinner = kstIso(1, 19, 0);
  const fullDinner = nextKstOccurrence(20, 30);
  const tomorrowLunch = kstIso(1, 13, 0);

  return [
    {
      key: "lunch_a",
      restaurantId: restaurantIds[0],
      scheduledAt: lunchA,
      maxParticipants: 4,
      acceptedGuests: 0,
      title: `${kstDayLabel(lunchA)} 점심 모집 A`
    },
    {
      key: "dinner_b",
      restaurantId: restaurantIds[0],
      scheduledAt: dinnerB,
      maxParticipants: 4,
      acceptedGuests: 1,
      title: `${kstDayLabel(dinnerB)} 저녁 모집 B`
    },
    {
      key: "night_c",
      restaurantId: restaurantIds[1],
      scheduledAt: nightC,
      maxParticipants: 3,
      acceptedGuests: 0,
      title: `${kstDayLabel(nightC)} 밤 모집 C`
    },
    {
      key: "tomorrow_dinner_d",
      restaurantId: restaurantIds[1],
      scheduledAt: tomorrowDinner,
      maxParticipants: 4,
      acceptedGuests: 0,
      title: "내일 저녁 모집 D"
    },
    {
      key: "full_e",
      restaurantId: restaurantIds[2],
      scheduledAt: fullDinner,
      maxParticipants: 2,
      acceptedGuests: 1,
      title: `${kstDayLabel(fullDinner)} 저녁 정원 마감 E`
    },
    {
      key: "tomorrow_lunch_f",
      restaurantId: restaurantIds[2],
      scheduledAt: tomorrowLunch,
      maxParticipants: 5,
      acceptedGuests: 0,
      title: "내일 점심 모집 F"
    }
  ];
}

async function findSeedRows(client) {
  const { data, error } = await client
    .from("matching_posts")
    .select(
      "id,author_id,restaurant_id,restaurant_name,address,scheduled_at,max_participants,intro,status,participant_ids"
    )
    .like("intro", `${TEST_PREFIX}%`)
    .order("scheduled_at", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

function printRows(label, rows) {
  console.log(`[DISCOVERY_PARTY_SEED] ${label} count=${rows.length}`);
  for (const row of rows) {
    const restaurantId = row.restaurant_id ?? row.restaurantId;
    const scheduledAt = row.scheduled_at ?? row.scheduledAt;
    const maxParticipants = row.max_participants ?? row.maxParticipants;
    const participantIds = row.participant_ids ?? row.participantIds ?? [];
    console.log(
      `[DISCOVERY_PARTY_SEED] ${row.id} | ${restaurantId} | backend=${row.status} | ` +
        `members=${participantIds.length + 1}/${maxParticipants} | ` +
        `${scheduledAt} | ${row.intro}`
    );
  }
}

function flutterStatus(row) {
  const participants = row.participantIds ?? row.participant_ids ?? [];
  const maxParticipants = row.maxParticipants ?? row.max_participants;
  if (row.status !== "open" || participants.length + 1 >= maxParticipants) {
    return "full";
  }
  return "recruiting";
}

function matrixKey(row) {
  const match = String(row.intro).match(
    /^\[TEST\]\[DISCOVERY_PARTY_SEED:([^\]]+)\]/
  );
  return match?.[1];
}

function matchesKstDay(iso, offset) {
  const target = kstDateParts(Date.parse(iso));
  const expected = kstDateParts(Date.now() + offset * 24 * 60 * 60 * 1000);
  return (
    target.year === expected.year &&
    target.month === expected.month &&
    target.day === expected.day
  );
}

function kstHour(iso) {
  return new Date(Date.parse(iso) + KST_OFFSET_MS).getUTCHours();
}

function printExpectedFilters(rows) {
  const keys = (predicate) =>
    rows.filter(predicate).map(matrixKey).sort().join(",") || "none";
  const scheduledAt = (row) => row.scheduledAt ?? row.scheduled_at;
  const participants = (row) => row.participantIds ?? row.participant_ids ?? [];
  const maxParticipants = (row) => row.maxParticipants ?? row.max_participants;
  const available = (row) => participants(row).length + 1 < maxParticipants(row);
  const recruiting = (row) => flutterStatus(row) !== "full";
  const evening = (row) => {
    const hour = kstHour(scheduledAt(row));
    return hour >= 15 && hour < 21;
  };

  console.log(`[DISCOVERY_PARTY_SEED] EXPECT today=${keys((row) => matchesKstDay(scheduledAt(row), 0))}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT tomorrow=${keys((row) => matchesKstDay(scheduledAt(row), 1))}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT lunch=${keys((row) => { const hour = kstHour(scheduledAt(row)); return hour >= 11 && hour < 15; })}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT evening=${keys(evening)}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT night=${keys((row) => { const hour = kstHour(scheduledAt(row)); return hour >= 21 || hour < 5; })}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT availableSeats=${keys(available)}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT recruiting=${keys(recruiting)}`);
  console.log(`[DISCOVERY_PARTY_SEED] EXPECT today+evening+available+recruiting=${keys((row) => matchesKstDay(scheduledAt(row), 0) && evening(row) && available(row) && recruiting(row))}`);
}

async function cleanup(client) {
  const rows = await findSeedRows(client);
  printRows("cleanup targets", rows);
  if (rows.length === 0) return [];

  const ids = rows.map((row) => row.id);
  for (const table of ["pending_evaluations", "manner_ratings"]) {
    const result = await client.from(table).delete().in("matching_post_id", ids);
    if (result.error && !["42P01", "PGRST205"].includes(result.error.code)) {
      throw result.error;
    }
  }

  const chats = await client.from("chat_rooms").delete().in("matching_post_id", ids);
  if (chats.error && !["42P01", "PGRST205"].includes(chats.error.code)) {
    throw chats.error;
  }

  const posts = await client.from("matching_posts").delete().in("id", ids);
  if (posts.error) throw posts.error;
  console.log(`[DISCOVERY_PARTY_SEED] cleanup deleted=${ids.length}`);
  return ids;
}

function isDedicatedTestProfile(profile) {
  const email = String(profile.email ?? "").toLowerCase();
  const nickname = String(profile.nickname ?? "").toLowerCase();
  return (
    profile.verification_status === "verified" &&
    profile.account_status === "active" &&
    ((nickname === "test" && email.endsWith("@mukking.local")) ||
      (nickname === "postgis-tester" && email.endsWith("@example.com")))
  );
}

async function resolveTestUsers(client) {
  const { data, error } = await client
    .from("user_profiles")
    .select("user_id,email,nickname,verification_status,account_status");
  if (error) throw error;

  const candidates = (data ?? []).filter(isDedicatedTestProfile);
  const author = candidates.find(
    (profile) =>
      String(profile.nickname).toLowerCase() === "test" &&
      String(profile.email).toLowerCase().endsWith("@mukking.local")
  );
  const guests = candidates
    .filter(
      (profile) =>
        String(profile.nickname).toLowerCase() === "postgis-tester" &&
        String(profile.email).toLowerCase().endsWith("@example.com")
    )
    .sort((left, right) => left.user_id.localeCompare(right.user_id))
    .slice(0, 2);

  if (!author || guests.length < 2) {
    throw new Error(
      "[TEST USER REQUIRED] One verified test@mukking.local author and two verified postgis-tester@example.com guests are required."
    );
  }
  return { author, guests };
}

async function readNearbyKakaoRestaurants(userId) {
  const {
    listRestaurants
  } = require("../dist/server/services/restaurant/restaurant.service");
  const nearby = await listRestaurants(userId, {
    lat: SEED_CENTER.latitude,
    lng: SEED_CENTER.longitude,
    radiusKm: SEED_CENTER.radiusKm,
    limit: 50,
    offset: 0
  });
  return nearby.filter(
    (restaurant) =>
      restaurant.placeProvider === "kakao" &&
      Number.isFinite(restaurant.latitude) &&
      Number.isFinite(restaurant.longitude) &&
      Number.isFinite(restaurant.distanceMeters)
  );
}

async function selectSeedRestaurants(userId) {
  const nearby = await readNearbyKakaoRestaurants(userId);
  const selected = nearby.slice(0, 3);
  if (selected.length !== 3) {
    throw new Error("Three queryable Kakao restaurants were not found near the 부산 seed center.");
  }
  console.log(
    `[DISCOVERY_PARTY_SEED] nearby candidates count=${nearby.length}, ` +
      `lat=${SEED_CENTER.latitude}, lng=${SEED_CENTER.longitude}, radiusKm=${SEED_CENTER.radiusKm}`
  );
  for (const restaurant of selected) {
    console.log(
      `[DISCOVERY_PARTY_SEED] selected restaurant ${restaurant.id} | ${restaurant.name} | ` +
        `lat=${restaurant.latitude}, lng=${restaurant.longitude}, distanceMeters=${restaurant.distanceMeters}`
    );
  }
  return selected;
}

async function verifyTestUsersCanMatch(userIds) {
  const { assertCanUseMatching } = require("../dist/server/services/auth/auth.service");
  for (const userId of userIds) await assertCanUseMatching(userId);
}

async function createTestAccessToken(service, email) {
  const generated = await service.auth.admin.generateLink({
    type: "magiclink",
    email
  });
  if (generated.error || !generated.data.properties?.hashed_token) {
    throw new Error("Existing test user magic-link generation failed.");
  }
  const authenticated = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
  const verified = await authenticated.auth.verifyOtp({
    token_hash: generated.data.properties.hashed_token,
    type: "magiclink"
  });
  if (verified.error || !verified.data.session?.access_token) {
    throw new Error("Existing test user temporary authentication failed.");
  }
  return verified.data.session.access_token;
}

async function fetchThroughApi(token) {
  const { app } = require("../dist/server/app");
  const server = await new Promise((resolve, reject) => {
    const listening = app.listen(0, "127.0.0.1", () => resolve(listening));
    listening.once("error", reject);
  });
  try {
    const matchingResponse = await fetch(
      `http://127.0.0.1:${server.address().port}/api/matching/posts`
    );
    const matchingPayload = await matchingResponse.json();
    const restaurantResponse = await fetch(
      `http://127.0.0.1:${server.address().port}/api/restaurants?` +
        `lat=${SEED_CENTER.latitude}&lng=${SEED_CENTER.longitude}&` +
        `radiusKm=${SEED_CENTER.radiusKm}&limit=50&offset=0`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    const restaurantPayload = await restaurantResponse.json();
    return {
      matchingStatus: matchingResponse.status,
      matchingRows: Array.isArray(matchingPayload)
        ? matchingPayload.filter((row) => String(row.intro).startsWith(TEST_PREFIX))
        : [],
      restaurantStatus: restaurantResponse.status,
      nearbyRows: Array.isArray(restaurantPayload) ? restaurantPayload : []
    };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function seed(client) {
  const users = await resolveTestUsers(client);
  await verifyTestUsersCanMatch([
    users.author.user_id,
    ...users.guests.map((guest) => guest.user_id)
  ]);
  const selectedRestaurants = await selectSeedRestaurants(users.author.user_id);
  const restaurants = new Map(
    selectedRestaurants.map((restaurant) => [restaurant.id, restaurant])
  );
  await cleanup(client);

  const {
    createJoinRequest,
    createMatchingPost,
    respondToJoinRequest
  } = require("../dist/server/services/matching/matching.service");
  const created = [];
  const matrix = buildMatrix(selectedRestaurants.map((restaurant) => restaurant.id));

  for (const definition of matrix) {
    const restaurant = restaurants.get(definition.restaurantId);
    const post = await createMatchingPost(users.author.user_id, {
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      address: restaurant.address,
      location:
        Number.isFinite(restaurant.latitude) && Number.isFinite(restaurant.longitude)
          ? { latitude: restaurant.latitude, longitude: restaurant.longitude }
          : undefined,
      scheduledAt: definition.scheduledAt,
      maxParticipants: definition.maxParticipants,
      intro: marker(definition.key, definition.title)
    });

    for (let index = 0; index < definition.acceptedGuests; index += 1) {
      const request = await createJoinRequest(users.guests[index].user_id, post.id);
      await respondToJoinRequest(users.author.user_id, request.id, {
        decision: "accepted"
      });
    }
    created.push(post.id);
  }

  const token = await createTestAccessToken(client, users.author.email);
  const api = await fetchThroughApi(token);
  if (api.matchingStatus !== 200 || api.matchingRows.length !== 6) {
    throw new Error(
      `Matching API validation failed: status=${api.matchingStatus}, count=${api.matchingRows.length}.`
    );
  }
  for (const definition of matrix) {
    const expectedIntro = marker(definition.key, definition.title);
    const row = api.matchingRows.find((candidate) => candidate.intro === expectedIntro);
    if (
      !row ||
      row.restaurantId !== definition.restaurantId ||
      Date.parse(row.scheduledAt) !== Date.parse(definition.scheduledAt) ||
      row.maxParticipants !== definition.maxParticipants ||
      row.participantIds.length !== definition.acceptedGuests
    ) {
      throw new Error(`API contract mismatch for ${definition.key}.`);
    }
  }
  const fullRow = api.matchingRows.find((row) => matrixKey(row) === "full_e");
  if (!fullRow || flutterStatus(fullRow) !== "full") {
    throw new Error("The full_e fixture does not map to Flutter full status.");
  }
  const nearbyIds = new Set(api.nearbyRows.map((restaurant) => restaurant.id));
  const partyRestaurantIds = new Set(
    api.matchingRows.map((row) => row.restaurantId)
  );
  const intersection = [...partyRestaurantIds].filter((id) => nearbyIds.has(id));
  if (
    api.restaurantStatus !== 200 ||
    !selectedRestaurants.every((restaurant) => nearbyIds.has(restaurant.id)) ||
    intersection.length !== 3
  ) {
    throw new Error(
      `Nearby API intersection failed: status=${api.restaurantStatus}, intersection=${intersection.length}.`
    );
  }
  const rowDate = (row) => row.scheduledAt;
  const rowHour = (row) => kstHour(row.scheduledAt);
  const rowAvailable = (row) => row.participantIds.length + 1 < row.maxParticipants;
  const rowRecruiting = (row) => flutterStatus(row) !== "full";
  const filters = {
    today: (row) => matchesKstDay(rowDate(row), 0),
    tomorrow: (row) => matchesKstDay(rowDate(row), 1),
    lunch: (row) => rowHour(row) >= 11 && rowHour(row) < 15,
    evening: (row) => rowHour(row) >= 15 && rowHour(row) < 21,
    night: (row) => rowHour(row) >= 21 || rowHour(row) < 5,
    availableSeats: rowAvailable,
    recruiting: rowRecruiting,
    combined: (row) =>
      matchesKstDay(rowDate(row), 0) &&
      rowHour(row) >= 15 &&
      rowHour(row) < 21 &&
      rowAvailable(row) &&
      rowRecruiting(row)
  };
  for (const [name, predicate] of Object.entries(filters)) {
    const ids = [
      ...new Set(
        api.matchingRows
          .filter(predicate)
          .map((row) => row.restaurantId)
          .filter((id) => nearbyIds.has(id))
      )
    ];
    if (ids.length === 0) {
      throw new Error(`Party filter intersection is empty for ${name}.`);
    }
    console.log(
      `[DISCOVERY_PARTY_SEED] FILTER INTERSECTION ${name} count=${ids.length} ids=${ids.join(",")}`
    );
  }
  printRows("created through API contract", api.matchingRows);
  printExpectedFilters(api.matchingRows);
  console.log(
    `[DISCOVERY_PARTY_SEED] nearby API status=${api.restaurantStatus}, ` +
      `count=${api.nearbyRows.length}, partyRestaurantIntersection=${intersection.length}`
  );
  console.log(
    `[DISCOVERY_PARTY_SEED] PASS created=${created.length}, ` +
      `matchingApiStatus=${api.matchingStatus}, matchingApiCount=${api.matchingRows.length}`
  );
}

async function main() {
  required("SUPABASE_URL", process.env.SUPABASE_URL);
  required("SUPABASE_ANON_KEY", process.env.SUPABASE_ANON_KEY);
  required("SUPABASE_SERVICE_ROLE_KEY", process.env.SUPABASE_SERVICE_ROLE_KEY);
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

  const client = serviceClient();
  if (command === "seed") {
    await seed(client);
    return;
  }
  if (command === "cleanup") {
    await cleanup(client);
    return;
  }
  if (command === "list") {
    printRows("current", await findSeedRows(client));
    return;
  }
  throw new Error("Usage: discoveryPartySeed.cjs [seed|list|cleanup]");
}

main().catch((error) => {
  console.error(
    `[DISCOVERY_PARTY_SEED] FAIL ${error instanceof Error ? error.message : "unknown error"}`
  );
  process.exitCode = 1;
});
