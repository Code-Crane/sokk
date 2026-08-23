const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const results = [];

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

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function createUser(label) {
  const email = `mukking-chat-recovery-${label}-${Date.now()}-${crypto
    .randomBytes(3)
    .toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-chat-recovery`, phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) throw new Error(`${label} user creation failed.`);

  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) {
    await service.auth.admin.deleteUser(created.data.user.id);
    throw new Error(`${label} sign-in failed.`);
  }
  return { id: created.data.user.id, token: signedIn.data.session.access_token };
}

async function prepareUser(baseUrl, label, users) {
  const user = await createUser(label);
  users.push(user);
  const me = await api(baseUrl, "/api/auth/me", user.token);
  const verification = await api(baseUrl, "/api/auth/verification/mock", user.token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  if (me.status !== 200 || verification.status !== 200) {
    throw new Error(`${label} profile setup failed.`);
  }
  return user;
}

async function createFixture(baseUrl, host, guest, label, postIds) {
  const post = await api(baseUrl, "/api/matching/posts", host.token, {
    method: "POST",
    body: JSON.stringify({
      restaurantName: `Supabase 복구 테스트 식당 ${label}`,
      address: "서울시 테스트구 Supabase 복구로 1",
      scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
      maxParticipants: 1,
      intro: `matching chat recovery supabase ${label}`
    })
  });
  if (post.status !== 201 || !post.payload?.id) throw new Error(`${label} post failed.`);
  postIds.push(post.payload.id);
  const join = await api(
    baseUrl,
    `/api/matching/posts/${post.payload.id}/requests`,
    guest.token,
    { method: "POST" }
  );
  if (join.status !== 201 || !join.payload?.id) throw new Error(`${label} join failed.`);
  return { post, join };
}

async function accept(baseUrl, fixture, host) {
  return api(
    baseUrl,
    `/api/matching/requests/${fixture.join.payload.id}/respond`,
    host.token,
    { method: "POST", body: JSON.stringify({ decision: "accepted" }) }
  );
}

async function countRows(query) {
  const { count, error } = await query;
  if (error) throw error;
  return count ?? 0;
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

  const service = client(serviceRoleKey);
  const users = [];
  const postIds = [];
  const { app } = require("../dist/server/app");
  const { repositories } = require("../dist/server/repositories");
  const originalEnsureRoom = repositories.chat.ensureRoom;
  const originalEnsureSystemMessage = repositories.chat.ensureSystemMessage;
  let server;

  try {
    server = app.listen(0, "127.0.0.1");
    await new Promise((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const host = await prepareUser(baseUrl, "host", users);
    const guest = await prepareUser(baseUrl, "guest", users);

    const caseA = await createFixture(baseUrl, host, guest, "case-a", postIds);
    repositories.chat.ensureRoom = async () => {
      throw new Error("injected room failure");
    };
    const failedA = await accept(baseUrl, caseA, host);
    repositories.chat.ensureRoom = originalEnsureRoom;
    const requestA = await repositories.matching.findJoinRequestById(caseA.join.payload.id);
    const roomCountAfterA = await countRows(
      service
        .from("chat_rooms")
        .select("id", { count: "exact", head: true })
        .eq("matching_post_id", caseA.post.payload.id)
    );
    record(
      "CASE A accepted state survives room failure",
      failedA.status === 500 && requestA?.status === "accepted" && roomCountAfterA === 0,
      `status=${failedA.status}, rooms=${roomCountAfterA}`
    );
    const repairedA = await accept(baseUrl, caseA, host);
    record(
      "CASE A retry repairs room",
      repairedA.status === 200 && repairedA.payload?.chatRoom?.participantIds?.length === 2,
      `status=${repairedA.status}`
    );

    const caseB = await createFixture(baseUrl, host, guest, "case-b", postIds);
    repositories.chat.ensureSystemMessage = async () => {
      throw new Error("injected system message failure");
    };
    const failedB = await accept(baseUrl, caseB, host);
    repositories.chat.ensureSystemMessage = originalEnsureSystemMessage;
    const roomB = await repositories.chat.findActiveRoomByPostId(caseB.post.payload.id);
    const messageCountAfterB = roomB
      ? await countRows(
          service
            .from("chat_messages")
            .select("id", { count: "exact", head: true })
            .eq("room_id", roomB.id)
        )
      : -1;
    record(
      "CASE B room survives system message failure",
      failedB.status === 500 && Boolean(roomB) && messageCountAfterB === 0,
      `status=${failedB.status}, messages=${messageCountAfterB}`
    );
    const repairedB = await accept(baseUrl, caseB, host);
    const messageCountAfterRepair = await countRows(
      service
        .from("chat_messages")
        .select("id", { count: "exact", head: true })
        .eq("room_id", roomB.id)
    );
    record(
      "CASE B retry repairs system message",
      repairedB.status === 200 && messageCountAfterRepair === 1,
      `status=${repairedB.status}, messages=${messageCountAfterRepair}`
    );

    const deletedMember = await service
      .from("chat_room_participants")
      .delete()
      .eq("room_id", roomB.id)
      .eq("user_id", guest.id);
    if (deletedMember.error) throw deletedMember.error;
    const repairedMember = await accept(baseUrl, caseB, host);
    record(
      "missing participant is repaired",
      repairedMember.status === 200 &&
        repairedMember.payload?.chatRoom?.participantIds?.includes(guest.id),
      `status=${repairedMember.status}`
    );

    const repeated = await Promise.all([
      accept(baseUrl, caseB, host),
      accept(baseUrl, caseB, host)
    ]);
    const roomCountB = await countRows(
      service
        .from("chat_rooms")
        .select("id", { count: "exact", head: true })
        .eq("matching_post_id", caseB.post.payload.id)
        .eq("status", "active")
    );
    const finalMessageCountB = await countRows(
      service
        .from("chat_messages")
        .select("id", { count: "exact", head: true })
        .eq("room_id", roomB.id)
    );
    record(
      "CASE C/D repeated concurrent recovery is idempotent",
      repeated.every((response) => response.status === 200) &&
        roomCountB === 1 &&
        finalMessageCountB === 1,
      `statuses=${repeated.map((response) => response.status).join(",")}`
    );

    const caseE = await createFixture(baseUrl, host, guest, "case-e", postIds);
    const acceptedE = await accept(baseUrl, caseE, host);
    record(
      "CASE E normal accept regression",
      acceptedE.status === 200 &&
        acceptedE.payload?.request?.status === "accepted" &&
        Boolean(acceptedE.payload?.chatRoom?.id),
      `status=${acceptedE.status}`
    );
  } finally {
    repositories.chat.ensureRoom = originalEnsureRoom;
    repositories.chat.ensureSystemMessage = originalEnsureSystemMessage;
    if (server) await new Promise((resolve) => server.close(resolve));

    if (postIds.length > 0) {
      const rooms = await service
        .from("chat_rooms")
        .select("id")
        .in("matching_post_id", postIds);
      if (rooms.error) throw rooms.error;
      const roomIds = (rooms.data ?? []).map((room) => room.id);
      if (roomIds.length > 0) {
        const messages = await service.from("chat_messages").delete().in("room_id", roomIds);
        if (messages.error) throw messages.error;
        const participants = await service
          .from("chat_room_participants")
          .delete()
          .in("room_id", roomIds);
        if (participants.error) throw participants.error;
        const roomDelete = await service.from("chat_rooms").delete().in("id", roomIds);
        if (roomDelete.error) throw roomDelete.error;
      }
      const requests = await service.from("join_requests").delete().in("post_id", postIds);
      if (requests.error) throw requests.error;
      const posts = await service.from("matching_posts").delete().in("id", postIds);
      if (posts.error) throw posts.error;
    }

    if (users.length > 0) {
      const userIds = users.map((user) => user.id);
      const mannerProfiles = await service
        .from("user_manner_profiles")
        .delete()
        .in("user_id", userIds);
      if (mannerProfiles.error) throw mannerProfiles.error;
      for (const user of users) {
        const deleted = await service.auth.admin.deleteUser(user.id);
        if (deleted.error) throw deleted.error;
      }
    }
  }

  for (const result of results) {
    console.log(
      `[MATCHING_CHAT_RECOVERY_SUPABASE] ${result.pass ? "PASS" : "FAIL"} ${
        result.name
      }${result.details ? ` - ${result.details}` : ""}`
    );
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(
    `[MATCHING_CHAT_RECOVERY_SUPABASE] FAIL ${
      error instanceof Error ? error.message : "unknown error"
    }`
  );
  process.exitCode = 1;
});
