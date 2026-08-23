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
  return createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
}

function randomEmail(label) {
  return `mukking-matching-security-${label}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
}

async function createUser(label) {
  const email = randomEmail(label);
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const service = client(serviceRoleKey);
  const created = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nickname: `${label}-tester`, phoneNumber: "01012345678" }
  });
  if (created.error || !created.data.user) throw new Error(`${label} creation failed.`);
  const authenticated = client(anonKey);
  const signedIn = await authenticated.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session?.access_token) throw new Error(`${label} sign-in failed.`);
  return { id: created.data.user.id, email, token: signedIn.data.session.access_token, client: authenticated };
}

function base32Decode(input) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const normalized = input.replace(/=+$/, "").replace(/\s+/g, "").toUpperCase();
  const bytes = [];
  let bits = 0;
  let value = 0;
  for (const char of normalized) {
    const index = alphabet.indexOf(char);
    if (index < 0) throw new Error("Invalid TOTP secret.");
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function totp(secret) {
  const counter = Math.floor(Date.now() / 30_000);
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeUInt32BE(Math.floor(counter / 0x100000000), 0);
  counterBuffer.writeUInt32BE(counter >>> 0, 4);
  const hmac = crypto.createHmac("sha1", base32Decode(secret)).update(counterBuffer).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const value = (((hmac[offset] & 0x7f) << 24) | ((hmac[offset + 1] & 0xff) << 16) | ((hmac[offset + 2] & 0xff) << 8) | (hmac[offset + 3] & 0xff)) % 1_000_000;
  return String(value).padStart(6, "0");
}

async function aal2Token(user) {
  const enrollment = await user.client.auth.mfa.enroll({ factorType: "totp", friendlyName: `matching-${Date.now()}` });
  if (enrollment.error) throw new Error(enrollment.error.message);
  const challenge = await user.client.auth.mfa.challenge({ factorId: enrollment.data.id });
  if (challenge.error) throw new Error(challenge.error.message);
  const verified = await user.client.auth.mfa.verify({
    factorId: enrollment.data.id,
    challengeId: challenge.data.id,
    code: totp(enrollment.data.totp.secret)
  });
  const session = verified.data.session ?? (await user.client.auth.getSession()).data.session;
  if (verified.error || !session?.access_token) throw new Error("MFA verification failed.");
  return session.access_token;
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
  if (me.status !== 200) throw new Error("Profile synchronization failed.");
  const result = await api(baseUrl, "/api/auth/verification/mock", user.token, {
    method: "POST",
    body: JSON.stringify({ legalName: "먹킹테스터", birthDate: "1995-01-01", gender: "other", phoneNumber: "01012345678" })
  });
  if (result.status !== 200) throw new Error("Verification failed.");
}

async function main() {
  required("SUPABASE_URL", url);
  required("SUPABASE_ANON_KEY", anonKey);
  required("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  process.env.ADMIN_REQUIRE_MFA = "true";

  const host = await createUser("host");
  const blocked = await createUser("blocked");
  const suspended = await createUser("suspended");
  const banned = await createUser("banned");
  const admin = await createUser("admin");
  process.env.ADMIN_UID_WHITELIST = admin.id;
  process.env.ADMIN_EMAIL_WHITELIST = admin.email;

  const service = client(serviceRoleKey);
  const { app } = require("../dist/server/app");
  let server;
  let baseUrl;
  const postIds = [];
  const sanctionIds = [];
  let blockId;
  let restaurantId;

  try {
    server = await startServer(app);
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    for (const user of [host, blocked, suspended, banned, admin]) await verify(baseUrl, user);
    const adminToken = await aal2Token(admin);

    const restaurant = await api(baseUrl, "/api/restaurants", host.token, {
      method: "POST",
      body: JSON.stringify({
        name: "매칭 보안 테스트 식당",
        address: "서울시 테스트구 보안로 1",
        latitude: 37.4979,
        longitude: 127.0276,
        category: "test",
        placeProvider: "fixture",
        placeProviderId: `matching-security-${Date.now()}`
      })
    });
    restaurantId = restaurant.payload?.id;

    const post = await api(baseUrl, "/api/matching/posts", host.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantId,
        restaurantName: restaurant.payload?.name,
        address: restaurant.payload?.address,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 2,
        intro: "차단 정책 테스트"
      })
    });
    if (post.payload?.id) postIds.push(post.payload.id);

    const block = await api(baseUrl, "/api/blocks", host.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: blocked.id })
    });
    blockId = block.payload?.id;
    const blockedJoin = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, blocked.token, { method: "POST" });
    record("blocked user join rejected", block.status === 201 && blockedJoin.status === 403, `status=${blockedJoin.status}`);

    const suspension = await api(baseUrl, "/api/admin/sanctions", adminToken, {
      method: "POST",
      body: JSON.stringify({ userId: suspended.id, type: "matching_suspension", reason: "matching security test" })
    });
    if (suspension.payload?.id) sanctionIds.push(suspension.payload.id);
    const suspendedPost = await api(baseUrl, "/api/matching/posts", suspended.token, {
      method: "POST",
      body: JSON.stringify({ restaurantName: "정지 테스트", address: "서울시 테스트구", scheduledAt: new Date(Date.now() + 86_400_000).toISOString(), maxParticipants: 2, intro: "정지" })
    });
    record("matching suspension rejected", suspension.status === 201 && suspendedPost.status === 403, `status=${suspendedPost.status}`);

    const ban = await api(baseUrl, "/api/admin/sanctions", adminToken, {
      method: "POST",
      body: JSON.stringify({ userId: banned.id, type: "permanent_ban", reason: "matching security test" })
    });
    if (ban.payload?.id) sanctionIds.push(ban.payload.id);
    const bannedMe = await api(baseUrl, "/api/auth/me", banned.token);
    record("permanent ban access rejected", ban.status === 201 && bannedMe.status === 403, `status=${bannedMe.status}`);
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    if (sanctionIds.length > 0) {
      await service.from("admin_audit_logs").delete().in("target_id", sanctionIds);
      await service.from("sanctions").delete().in("id", sanctionIds);
    }
    if (blockId) await service.from("blocks").delete().eq("id", blockId);
    if (postIds.length > 0) await service.from("matching_posts").delete().in("id", postIds);
    if (restaurantId) await service.from("restaurants").delete().eq("id", restaurantId);
    for (const user of [host, blocked, suspended, banned, admin]) await service.auth.admin.deleteUser(user.id);
  }

  for (const result of results) {
    console.log(`[MATCHING_SECURITY] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[MATCHING_SECURITY] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
