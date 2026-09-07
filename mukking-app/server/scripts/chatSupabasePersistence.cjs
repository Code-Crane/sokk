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

function randomEmail(label) {
  return `mukking-chat-${label}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
}

function base32Decode(input) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const normalized = input.replace(/=+$/, "").replace(/\s+/g, "").toUpperCase();
  const bytes = [];
  let bits = 0;
  let value = 0;
  for (const char of normalized) {
    const index = alphabet.indexOf(char);
    if (index === -1) throw new Error("Invalid TOTP secret.");
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function generateTotp(secret) {
  const counter = Math.floor(Date.now() / 30_000);
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeUInt32BE(Math.floor(counter / 0x100000000), 0);
  counterBuffer.writeUInt32BE(counter >>> 0, 4);
  const hmac = crypto.createHmac("sha1", base32Decode(secret)).update(counterBuffer).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const code =
    (((hmac[offset] & 0x7f) << 24) |
      ((hmac[offset + 1] & 0xff) << 16) |
      ((hmac[offset + 2] & 0xff) << 8) |
      (hmac[offset + 3] & 0xff)) %
    1_000_000;
  return String(code).padStart(6, "0");
}

async function createAal2Token(authenticated) {
  const enroll = await authenticated.auth.mfa.enroll({
    factorType: "totp",
    friendlyName: `chat-persistence-${Date.now()}`
  });
  if (enroll.error) throw new Error("Admin MFA enrollment failed.");
  const challenge = await authenticated.auth.mfa.challenge({ factorId: enroll.data.id });
  if (challenge.error) throw new Error("Admin MFA challenge failed.");
  const verified = await authenticated.auth.mfa.verify({
    factorId: enroll.data.id,
    challengeId: challenge.data.id,
    code: generateTotp(enroll.data.totp.secret)
  });
  if (verified.error) throw new Error("Admin MFA verification failed.");
  const session = verified.data.session ?? (await authenticated.auth.getSession()).data.session;
  if (!session?.access_token) throw new Error("Admin aal2 session is missing.");
  return session.access_token;
}

async function createUser(label) {
  const email = randomEmail(label);
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-chat`, phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) throw new Error(`${label} user creation failed.`);

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) {
    throw new Error(`${label} sign-in failed.`);
  }
  return {
    id: created.data.user.id,
    email,
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

function startServer(app) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
    server.once("error", reject);
  });
}

async function stopServer(server) {
  if (server) await new Promise((resolve) => server.close(resolve));
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

async function joinAndAccept(baseUrl, postId, host, guest) {
  const join = await api(baseUrl, `/api/matching/posts/${postId}/requests`, guest.token, {
    method: "POST"
  });
  const accepted = await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, {
    method: "POST",
    body: JSON.stringify({ decision: "accepted" })
  });
  return { join, accepted };
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

  const service = client(serviceRoleKey);
  const anon = client(anonKey);
  const users = [];
  let server;
  let restaurantId;
  let postId;
  let roomId;
  let blockId;
  let adminUser;
  const sanctionIds = [];
  const cleanupErrors = [];

  try {
    const host = await createUser("host");
    users.push(host);
    const guestA = await createUser("guest-a");
    users.push(guestA);
    const guestB = await createUser("guest-b");
    users.push(guestB);
    const outsider = await createUser("outsider");
    users.push(outsider);
    adminUser = await createUser("admin");
    users.push(adminUser);

    process.env.ADMIN_EMAIL_WHITELIST = adminUser.email;
    process.env.ADMIN_UID_WHITELIST = adminUser.id;
    process.env.ADMIN_REQUIRE_MFA = "true";
    process.env.RATE_LIMIT_ADMIN_AUTH_MAX = "100";
    process.env.RATE_LIMIT_ADMIN_SENSITIVE_MAX = "100";
    const adminAal2Token = await createAal2Token(adminUser.client);

    const { app } = require("../dist/server/app");
    server = await startServer(app);
    let baseUrl = `http://127.0.0.1:${server.address().port}`;
    for (const user of users) await verify(baseUrl, user);

    const restaurant = await api(baseUrl, "/api/restaurants", host.token, {
      method: "POST",
      body: JSON.stringify({
        name: "채팅 Supabase 영속성 테스트 식당",
        address: "서울시 테스트구 채팅로 2",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "test",
        placeProvider: "fixture",
        placeProviderId: `chat-persistence-${Date.now()}`
      })
    });
    restaurantId = restaurant.payload?.id;

    const post = await api(baseUrl, "/api/matching/posts", host.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId,
        restaurantName: "채팅 Supabase 영속성 테스트 식당",
        address: "서울시 테스트구 채팅로 2",
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 2,
        intro: "채팅 영속화 검증"
      })
    });
    postId = post.payload?.id;

    const first = await joinAndAccept(baseUrl, postId, host, guestA);
    const second = await joinAndAccept(baseUrl, postId, host, guestB);
    roomId = first.accepted.payload?.chatRoom?.id;
    record("accept creates persisted room", first.accepted.status === 200 && Boolean(roomId), `status=${first.accepted.status}`);
    record(
      "group accept reuses one room",
      second.accepted.status === 200 &&
        second.accepted.payload?.chatRoom?.id === roomId &&
        second.accepted.payload?.chatRoom?.participantIds?.length === 3,
      `status=${second.accepted.status}`
    );

    const roomRows = await service.from("chat_rooms").select("id,matching_post_id").eq("id", roomId);
    const participantRows = await service
      .from("chat_room_participants")
      .select("user_id")
      .eq("room_id", roomId);
    record(
      "room and participants stored",
      !roomRows.error && roomRows.data?.length === 1 && participantRows.data?.length === 3,
      `rooms=${roomRows.data?.length ?? 0}, participants=${participantRows.data?.length ?? 0}`
    );
    const duplicateAttempt = await service.rpc("create_or_reuse_chat_room", {
      p_room_id: `room_duplicate_${Date.now()}`,
      p_matching_post_id: postId,
      p_title: "중복 방 생성 시도",
      p_participant_ids: [host.id, guestA.id],
      p_status: "active"
    });
    const activeRoomCount = await service
      .from("chat_rooms")
      .select("id", { count: "exact", head: true })
      .eq("matching_post_id", postId)
      .eq("status", "active");
    record(
      "duplicate active room prevented",
      !duplicateAttempt.error &&
        duplicateAttempt.data?.id === roomId &&
        activeRoomCount.count === 1,
      `count=${activeRoomCount.count ?? "n/a"}`
    );

    const firstMessage = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, host.token, {
      method: "POST",
      body: JSON.stringify({ text: "첫 번째", senderId: outsider.id })
    });
    const secondMessage = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "두 번째" })
    });
    record(
      "sender comes from JWT",
      firstMessage.status === 201 && firstMessage.payload?.senderId === host.id,
      `status=${firstMessage.status}`
    );
    record("participant sends message", secondMessage.status === 201, `status=${secondMessage.status}`);
    const messageNotifications = await service.from("notifications")
      .select("user_id,chat_room_id,matching_post_id,event_key,body")
      .eq("type", "chat_message_created").eq("event_key", firstMessage.payload.id);
    record("chat event targets other participants with exact room and no message text",
      !messageNotifications.error && messageNotifications.data?.length === 2 &&
      messageNotifications.data.every((row) => [guestA.id, guestB.id].includes(row.user_id) &&
        row.chat_room_id === roomId && row.matching_post_id === postId &&
        !row.body.includes(firstMessage.payload.text)),
      `notifications=${messageNotifications.data?.length}`);
    const blankMessage = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "   " })
    });
    record("blank message rejected", blankMessage.status === 400, `status=${blankMessage.status}`);

    const messages = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestB.token);
    record(
      "messages have deterministic order",
      messages.status === 200 &&
        messages.payload?.map((message) => message.text).join("|") ===
          "매칭이 성사되어 채팅방이 열렸습니다.|첫 번째|두 번째",
      `status=${messages.status}`
    );

    const hostRooms = await api(baseUrl, "/api/chat/rooms", host.token);
    const outsiderRead = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, outsider.token);
    const outsiderSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, outsider.token, {
      method: "POST",
      body: JSON.stringify({ text: "침입 메시지" })
    });
    record("participant room list", hostRooms.status === 200 && hostRooms.payload?.some((room) => room.id === roomId), `status=${hostRooms.status}`);
    const outsiderRooms = await api(baseUrl, "/api/chat/rooms", outsider.token);
    record(
      "outsider room list excludes room",
      outsiderRooms.status === 200 && !outsiderRooms.payload?.some((room) => room.id === roomId),
      `status=${outsiderRooms.status}`
    );
    record("outsider read rejected", outsiderRead.status === 403, `status=${outsiderRead.status}`);
    record("outsider send rejected", outsiderSend.status === 403, `status=${outsiderSend.status}`);

    for (const table of ["chat_rooms", "chat_room_participants", "chat_messages"]) {
      const anonRead = await anon.from(table).select("*").limit(1);
      const authRead = await outsider.client.from(table).select("*").limit(1);
      record(`RLS anon ${table} blocked`, Boolean(anonRead.error) || anonRead.data?.length === 0, "direct read");
      record(`RLS authenticated ${table} blocked`, Boolean(authRead.error) || authRead.data?.length === 0, "direct read");
    }

    const block = await api(baseUrl, "/api/blocks", host.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: guestA.id, scope: "chat" })
    });
    blockId = block.payload?.id;
    const blockedSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "차단 후 메시지" })
    });
    record("chat block enforcement", block.status === 201 && blockedSend.status === 403, `status=${blockedSend.status}`);
    const unblock = await api(baseUrl, `/api/blocks/${guestA.id}`, host.token, { method: "DELETE" });
    record("chat block revoke", unblock.status === 200, `status=${unblock.status}`);

    const chatSanction = await api(baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: guestA.id,
        type: "chat_suspension",
        reason: "chat persistence validation"
      })
    });
    if (chatSanction.payload?.id) sanctionIds.push(chatSanction.payload.id);
    const suspendedSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "정지 상태 메시지" })
    });
    const revokeSanction = await api(
      baseUrl,
      `/api/admin/sanctions/${chatSanction.payload?.id}/revoke`,
      adminAal2Token,
      { method: "POST", body: JSON.stringify({ reason: "validation restore" }) }
    );
    const restoredSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "정지 해제 후 메시지" })
    });
    record(
      "chat suspension and restore",
      chatSanction.status === 201 &&
        suspendedSend.status === 403 &&
        revokeSanction.status === 200 &&
        restoredSend.status === 201,
      `create=${chatSanction.status}, suspended=${suspendedSend.status}, restored=${restoredSend.status}`
    );

    const permanentBan = await api(baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: outsider.id,
        type: "permanent_ban",
        reason: "chat persistence validation"
      })
    });
    if (permanentBan.payload?.id) sanctionIds.push(permanentBan.payload.id);
    const bannedAccess = await api(baseUrl, "/api/auth/me", outsider.token);
    record(
      "permanent ban blocks access",
      permanentBan.status === 201 && bannedAccess.status === 403,
      `create=${permanentBan.status}, access=${bannedAccess.status}`
    );

    await stopServer(server);
    server = undefined;
    server = await startServer(app);
    baseUrl = `http://127.0.0.1:${server.address().port}`;

    const roomsAfterRestart = await api(baseUrl, "/api/chat/rooms", host.token);
    const messagesAfterRestart = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestB.token);
    const matchingAfterRestart = await api(baseUrl, "/api/matching/posts", host.token);
    const requestsAfterRestart = await api(baseUrl, `/api/matching/posts/${postId}/requests`, host.token);
    record(
      "room and participants persist after restart",
      roomsAfterRestart.status === 200 &&
        roomsAfterRestart.payload?.some(
          (room) => room.id === roomId && room.participantIds?.length === 3
        ),
      `status=${roomsAfterRestart.status}`
    );
    record(
      "messages persist after restart",
      messagesAfterRestart.status === 200 &&
        messagesAfterRestart.payload?.map((message) => message.text).join("|") ===
          "매칭이 성사되어 채팅방이 열렸습니다.|첫 번째|두 번째|정지 해제 후 메시지",
      `status=${messagesAfterRestart.status}`
    );
    const persistedPost = matchingAfterRestart.payload?.find((item) => item.id === postId);
    record(
      "matching state persists with chat",
      matchingAfterRestart.status === 200 &&
        persistedPost?.participantIds?.length === 2 &&
        requestsAfterRestart.payload?.filter((item) => item.status === "accepted").length === 2,
      `posts=${matchingAfterRestart.status}, requests=${requestsAfterRestart.status}`
    );

    const completed = await api(baseUrl, `/api/matching/posts/${postId}/complete`, host.token, {
      method: "POST"
    });
    const pending = await api(baseUrl, "/api/rating/pending", host.token);
    record(
      "completion keeps pending evaluation flow",
      completed.status === 200 && pending.status === 200 && pending.payload?.length > 0,
      `complete=${completed.status}, pending=${pending.status}`
    );
  } finally {
    await stopServer(server);
    if (blockId) {
      const result = await service.from("blocks").delete().eq("id", blockId);
      if (result.error) cleanupErrors.push("block");
    }
    if (postId) {
      for (const table of ["pending_evaluations", "manner_ratings"]) {
        const ratingCleanup = await service.from(table).delete().eq("matching_post_id", postId);
        if (ratingCleanup.error && ratingCleanup.error.code !== "42P01" && ratingCleanup.error.code !== "PGRST205") cleanupErrors.push(table);
      }
      const roomResult = await service.from("chat_rooms").delete().eq("matching_post_id", postId);
      if (roomResult.error) cleanupErrors.push("chat");
      const postResult = await service.from("matching_posts").delete().eq("id", postId);
      if (postResult.error) cleanupErrors.push("matching");
    }
    if (restaurantId) {
      const favoriteResult = await service
        .from("restaurant_favorites")
        .delete()
        .eq("restaurant_id", restaurantId);
      if (favoriteResult.error) cleanupErrors.push("favorite");
      const restaurantResult = await service.from("restaurants").delete().eq("id", restaurantId);
      if (restaurantResult.error) cleanupErrors.push("restaurant");
    }
    if (adminUser) {
      const auditResult = await service
        .from("admin_audit_logs")
        .delete()
        .eq("actor_admin_id", adminUser.id);
      if (auditResult.error) cleanupErrors.push("audit");
    }
    if (sanctionIds.length > 0) {
      const sanctionResult = await service.from("sanctions").delete().in("id", sanctionIds);
      if (sanctionResult.error) cleanupErrors.push("sanction");
    }
    if (users.length > 0) {
      const mannerCleanup = await service.from("user_manner_profiles").delete().in("user_id", users.map((user) => user.id));
      if (mannerCleanup.error) cleanupErrors.push("manner-profile");
    }
    for (const user of users) {
      const userResult = await service.auth.admin.deleteUser(user.id);
      if (userResult.error) cleanupErrors.push("auth-user");
    }
    record(
      "test data cleanup",
      cleanupErrors.length === 0,
      cleanupErrors.length === 0 ? "exact test IDs removed" : `failed=${cleanupErrors.join(",")}`
    );
  }

  for (const result of results) {
    console.log(`[CHAT_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[CHAT_SUPABASE] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
