const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const url = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const results = [];

function required(name, value) {
  if (!value?.trim()) throw new Error(`${name} is missing.`);
}

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  process.env.REPOSITORY_PROVIDER = "supabase";

  const service = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
  const providerId = `upsert-fixture-${Date.now()}-${crypto
    .randomBytes(3)
    .toString("hex")}`;
  const createdUser = await service.auth.admin.createUser({
    email: `kakao-upsert-${providerId}@example.com`,
    password: `Mukking-${crypto.randomBytes(10).toString("hex")}!1`,
    email_confirm: true
  });
  if (createdUser.error || !createdUser.data.user) {
    throw new Error("Temporary upsert user creation failed.");
  }

  const userId = createdUser.data.user.id;
  let restaurantId;

  try {
    const {
      supabaseRestaurantRepository
    } = require("../dist/server/repositories/supabase/restaurant.supabase.repository");
    const baseInput = {
      name: "[TEST] Kakao upsert fixture",
      address: "부산 동구 테스트로 1",
      latitude: 35.114628,
      longitude: 129.03702,
      category: "테스트 음식점",
      placeProvider: "kakao",
      placeProviderId: providerId,
      phone: "051-000-0000",
      roadAddress: "부산 동구 테스트로 1",
      metadata: { placeUrl: "https://place.map.kakao.com/test" }
    };

    const [created] = await supabaseRestaurantRepository.upsertMany([baseInput]);
    restaurantId = created.id;
    record(
      "deterministic Kakao restaurant id",
      restaurantId.startsWith("restaurant_kakao_")
    );

    const favorite = await service.from("restaurant_favorites").insert({
      user_id: userId,
      restaurant_id: restaurantId
    });
    if (favorite.error) throw favorite.error;

    const [updated] = await supabaseRestaurantRepository.upsertMany([
      {
        ...baseInput,
        name: "[TEST] Updated Kakao upsert fixture",
        phone: "051-111-2222",
        metadata: {
          ...baseInput.metadata,
          placeUrl: "https://place.map.kakao.com/updated"
        }
      },
      {
        ...baseInput,
        name: "[TEST] Updated Kakao upsert fixture",
        phone: "051-111-2222",
        metadata: {
          ...baseInput.metadata,
          placeUrl: "https://place.map.kakao.com/updated"
        }
      }
    ]);
    record(
      "repeat upsert preserves primary key and updates fields",
      updated.id === restaurantId &&
        updated.name === "[TEST] Updated Kakao upsert fixture" &&
        updated.phone === "051-111-2222" &&
        updated.metadata.placeUrl === "https://place.map.kakao.com/updated"
    );

    const rows = await service
      .from("restaurants")
      .select("id,location")
      .eq("place_provider", "kakao")
      .eq("place_provider_id", providerId);
    record(
      "provider uniqueness and location trigger",
      !rows.error && rows.data?.length === 1 && Boolean(rows.data[0]?.location),
      rows.error ? "query failed" : `count=${rows.data?.length ?? 0}`
    );

    const favorites = await service
      .from("restaurant_favorites")
      .select("restaurant_id")
      .eq("user_id", userId)
      .eq("restaurant_id", restaurantId);
    record(
      "favorite relation survives Kakao update",
      !favorites.error && favorites.data?.length === 1
    );
  } finally {
    if (restaurantId) {
      await service
        .from("restaurant_favorites")
        .delete()
        .eq("restaurant_id", restaurantId);
      await service.from("restaurants").delete().eq("id", restaurantId);
    }
    await service.auth.admin.deleteUser(userId);
  }

  for (const result of results) {
    console.log(
      `[KAKAO_UPSERT] ${result.pass ? "PASS" : "FAIL"} ${result.name}` +
        (result.details ? ` - ${result.details}` : "")
    );
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(
    `[KAKAO_UPSERT] FAIL ${error instanceof Error ? error.message : "unknown error"}`
  );
  process.exitCode = 1;
});
