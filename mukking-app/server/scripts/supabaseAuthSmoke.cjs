const crypto = require("crypto");
const dotenv = require("dotenv");
const { createClient } = require("@supabase/supabase-js");

dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const results = [];

function record(section, name, pass, details = "") {
  results.push({ section, name, pass, details });
}

function assertStatus(section, name, response, expectedStatus) {
  const pass = response.status === expectedStatus;
  record(section, name, pass, `status=${response.status}, expected=${expectedStatus}`);
  return pass;
}

function requireEnv(name, value) {
  if (!value) {
    throw new Error(`${name} is missing.`);
  }
}

function createSupabaseClient() {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

function createSupabaseServiceRoleClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

function randomEmail(label) {
  return `mukking-${label}-${Date.now()}-${crypto
    .randomBytes(4)
    .toString("hex")}@gmail.com`;
}

function randomPassword() {
  return `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
}

async function signUpUser(label) {
  const email = randomEmail(label);
  const password = randomPassword();
  const client = createSupabaseClient();
  const { data, error } = await client.auth.signUp({
    email,
    password,
    options: {
      data: {
        nickname: `${label}-tester`,
        phoneNumber: "01012345678"
      }
    }
  });

  if (error) {
    record(
      "AUTH",
      `${label} public signup active session`,
      false,
      `public_signup_failed=${error.message}`
    );

    return createConfirmedUser(`${label}-confirmed`);
  }

  if (!data.user || !data.session?.access_token) {
    record(
      "AUTH",
      `${label} public signup active session`,
      false,
      "email_confirmation_enabled_or_no_session"
    );

    return createConfirmedUser(`${label}-confirmed`);
  }

  record("AUTH", `${label} public signup active session`, true, "access_token_present=true");

  return {
    client,
    email,
    password,
    userId: data.user.id,
    token: data.session.access_token
  };
}

async function probePublicSignup() {
  const email = randomEmail("public-signup");
  const password = randomPassword();
  const client = createSupabaseClient();
  const { data, error } = await client.auth.signUp({
    email,
    password,
    options: {
      data: {
        nickname: "public-signup-probe",
        phoneNumber: "01012345678"
      }
    }
  });

  if (error) {
    record(
      "AUTH",
      "public Supabase signup active session",
      false,
      `public_signup_failed=${error.message}`
    );
    return;
  }

  record(
    "AUTH",
    "public Supabase signup active session",
    Boolean(data.user && data.session?.access_token),
    data.session?.access_token
      ? "access_token_present=true"
      : "email_confirmation_enabled_or_no_session"
  );
}

async function createConfirmedUser(label) {
  const email = randomEmail(label);
  const password = randomPassword();
  const serviceRoleClient = createSupabaseServiceRoleClient();
  const { data, error } = await serviceRoleClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      nickname: `${label}-tester`,
      phoneNumber: "01012345678"
    }
  });

  if (error) {
    throw new Error(`${label} confirmed user creation failed: ${error.message}`);
  }

  if (!data.user) {
    throw new Error(`${label} confirmed user creation did not return a user.`);
  }

  const signedIn = await signInUser(email, password);

  return {
    client: signedIn.client,
    email,
    password,
    userId: data.user.id,
    token: signedIn.token
  };
}

async function signInUser(email, password) {
  const client = createSupabaseClient();
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password
  });

  if (error) {
    throw new Error(`signin failed: ${error.message}`);
  }

  if (!data.session?.access_token || !data.user) {
    throw new Error("signin did not return a session.");
  }

  return {
    client,
    userId: data.user.id,
    token: data.session.access_token
  };
}

function mutateToken(token) {
  const parts = token.split(".");

  if (parts.length !== 3 || parts[2].length === 0) {
    return `${token}a`;
  }

  const signature = parts[2];
  const index = Math.floor(signature.length / 2);
  const current = signature[index];
  const replacement = current === "a" ? "b" : "a";
  parts[2] = `${signature.slice(0, index)}${replacement}${signature.slice(index + 1)}`;

  return parts.join(".");
}

function base32Decode(input) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const normalized = input.replace(/=+$/, "").replace(/\s+/g, "").toUpperCase();
  const bytes = [];
  let bits = 0;
  let value = 0;

  for (const char of normalized) {
    const index = alphabet.indexOf(char);

    if (index === -1) {
      throw new Error("Invalid TOTP secret.");
    }

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
  const key = base32Decode(secret);
  const counter = Math.floor(Date.now() / 30_000);
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeUInt32BE(Math.floor(counter / 0x100000000), 0);
  counterBuffer.writeUInt32BE(counter >>> 0, 4);
  const hmac = crypto.createHmac("sha1", key).update(counterBuffer).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const code =
    (((hmac[offset] & 0x7f) << 24) |
      ((hmac[offset + 1] & 0xff) << 16) |
      ((hmac[offset + 2] & 0xff) << 8) |
      (hmac[offset + 3] & 0xff)) %
    1_000_000;

  return String(code).padStart(6, "0");
}

async function tryCreateAal2Session(adminClient) {
  const enroll = await adminClient.auth.mfa.enroll({
    factorType: "totp",
    friendlyName: `codex-smoke-${Date.now()}`
  });

  if (enroll.error) {
    throw new Error(enroll.error.message);
  }

  const factorId = enroll.data.id;
  const secret = enroll.data.totp.secret;
  const challenge = await adminClient.auth.mfa.challenge({ factorId });

  if (challenge.error) {
    throw new Error(challenge.error.message);
  }

  const verify = await adminClient.auth.mfa.verify({
    factorId,
    challengeId: challenge.data.id,
    code: generateTotp(secret)
  });

  if (verify.error) {
    throw new Error(verify.error.message);
  }

  const session = verify.data.session ?? (await adminClient.auth.getSession()).data.session;

  if (!session?.access_token) {
    throw new Error("MFA verify did not return an aal2 session.");
  }

  return session.access_token;
}

async function api(baseUrl, path, token, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers ?? {})
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers
  });
  const payload = await response.json().catch(() => undefined);

  return {
    status: response.status,
    payload
  };
}

async function main() {
  requireEnv("SUPABASE_URL", SUPABASE_URL);
  requireEnv("SUPABASE_ANON_KEY", SUPABASE_ANON_KEY);
  requireEnv("SUPABASE_SERVICE_ROLE_KEY", SUPABASE_SERVICE_ROLE_KEY);

  process.env.AUTH_PROVIDER = "supabase";
  process.env.ADMIN_REQUIRE_MFA = "true";
  process.env.RATE_LIMIT_AUTH_SIGNUP_MAX = "200";
  process.env.RATE_LIMIT_AUTH_LOGIN_MAX = "200";
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "200";
  process.env.RATE_LIMIT_ADMIN_AUTH_MAX = "200";
  process.env.RATE_LIMIT_ADMIN_SENSITIVE_MAX = "200";

  await probePublicSignup();

  const regular = await createConfirmedUser("regular");
  const guest = await createConfirmedUser("guest");
  const outsider = await createConfirmedUser("outsider");
  const admin = await createConfirmedUser("admin");

  process.env.ADMIN_EMAIL_WHITELIST = admin.email;
  process.env.ADMIN_UID_WHITELIST = admin.userId;

  const { app } = require("../dist/server/app");
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const login = await signInUser(regular.email, regular.password);
    record("AUTH", "Supabase login", Boolean(login.token), "access_token_present=true");

    const sessionBeforeRefresh = await login.client.auth.getSession();
    record(
      "AUTH",
      "session 유지",
      Boolean(sessionBeforeRefresh.data.session?.access_token),
      "session_present=true"
    );

    const refresh = await login.client.auth.refreshSession();
    record(
      "AUTH",
      "session refresh",
      !refresh.error && Boolean(refresh.data.session?.access_token),
      refresh.error ? refresh.error.message : "refresh_session_present=true"
    );

    const me = await api(baseUrl, "/api/auth/me", login.token);
    assertStatus("TOKEN", "정상 JWT /api/auth/me", me, 200);

    const tampered = await api(baseUrl, "/api/auth/me", mutateToken(login.token));
    assertStatus("TOKEN", "변조 JWT", tampered, 401);

    const malformed = await api(baseUrl, "/api/auth/me", "not-a-valid-jwt");
    assertStatus("TOKEN", "잘못된 JWT", malformed, 401);

    const rawUserId = await api(baseUrl, "/api/auth/me", regular.userId);
    assertStatus("TOKEN", "raw userId token", rawUserId, 401);

    const spoof = await api(baseUrl, "/api/auth/me", undefined, {
      headers: {
        "x-user-id": admin.userId
      }
    });
    assertStatus("TOKEN", "x-user-id spoofing", spoof, 401);

    const serverLogin = await api(baseUrl, "/api/auth/login", undefined, {
      method: "POST",
      body: JSON.stringify({
        email: regular.email,
        password: regular.password
      })
    });
    assertStatus("AUTH", "server login API", serverLogin, 200);

    const regularAdmin = await api(baseUrl, "/api/admin/security-status", login.token);
    assertStatus("ADMIN", "일반 사용자 관리자 API", regularAdmin, 403);

    const outsiderAdmin = await api(baseUrl, "/api/admin/security-status", outsider.token);
    assertStatus("ADMIN", "whitelist 외 사용자", outsiderAdmin, 403);

    const adminStatus = await api(baseUrl, "/api/admin/security-status", admin.token);
    assertStatus("ADMIN", "whitelist 관리자", adminStatus, 200);

    const adminSensitiveAal1 = await api(
      baseUrl,
      "/api/admin/sensitive-security-status",
      admin.token
    );
    assertStatus("MFA", "aal1 관리자 민감 API", adminSensitiveAal1, 403);

    try {
      const aal2Token = await tryCreateAal2Session(admin.client);
      const adminSensitiveAal2 = await api(
        baseUrl,
        "/api/admin/sensitive-security-status",
        aal2Token
      );
      assertStatus("MFA", "aal2 관리자 민감 API", adminSensitiveAal2, 200);
      record(
        "MFA",
        "aal2 claim 판별",
        adminSensitiveAal2.payload?.aal === "aal2",
        `aal=${adminSensitiveAal2.payload?.aal ?? "missing"}`
      );
    } catch (error) {
      record(
        "MFA",
        "aal2 관리자 민감 API",
        false,
        `blocked=${error instanceof Error ? error.message : "unknown"}`
      );
    }

    for (const user of [regular, guest]) {
      const verification = await api(baseUrl, "/api/auth/verification/mock", user.token, {
        method: "POST",
        body: JSON.stringify({
          legalName: "먹킹테스터",
          birthDate: "1995-01-01",
          gender: "other",
          phoneNumber: "01012345678"
        })
      });
      assertStatus("REGRESSION", `인증 상태 ${user === regular ? "host" : "guest"}`, verification, 200);
    }

    const post = await api(baseUrl, "/api/matching/posts", regular.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantName: "테스트 국밥",
        address: "서울시 테스트구",
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 1,
        intro: "Supabase Auth 회귀 테스트"
      })
    });
    assertStatus("REGRESSION", "모집글 생성", post, 201);

    const listPosts = await api(baseUrl, "/api/matching/posts");
    record(
      "REGRESSION",
      "모집글 조회",
      listPosts.status === 200 && Array.isArray(listPosts.payload),
      `status=${listPosts.status}`
    );

    const joinRequest = await api(
      baseUrl,
      `/api/matching/posts/${post.payload?.id}/requests`,
      guest.token,
      { method: "POST" }
    );
    assertStatus("REGRESSION", "참가 요청", joinRequest, 201);

    const accepted = await api(
      baseUrl,
      `/api/matching/requests/${joinRequest.payload?.id}/respond`,
      regular.token,
      {
        method: "POST",
        body: JSON.stringify({ decision: "accepted" })
      }
    );
    assertStatus("REGRESSION", "참가 요청 수락", accepted, 200);

    const roomId = accepted.payload?.chatRoom?.id;
    record("REGRESSION", "채팅방 생성", Boolean(roomId), `room=${roomId ? "created" : "missing"}`);

    const message = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guest.token, {
      method: "POST",
      body: JSON.stringify({ text: "안녕하세요!" })
    });
    assertStatus("REGRESSION", "메시지 전송", message, 201);

    const messages = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, regular.token);
    record(
      "REGRESSION",
      "메시지 조회",
      messages.status === 200 && Array.isArray(messages.payload),
      `status=${messages.status}`
    );

    const completed = await api(
      baseUrl,
      `/api/matching/posts/${post.payload?.id}/complete`,
      regular.token,
      { method: "POST" }
    );
    assertStatus("REGRESSION", "만남 완료", completed, 200);

    const pending = await api(baseUrl, "/api/rating/pending", regular.token);
    record(
      "REGRESSION",
      "평가 대기 생성",
      pending.status === 200 && Array.isArray(pending.payload) && pending.payload.length > 0,
      `status=${pending.status}, count=${Array.isArray(pending.payload) ? pending.payload.length : "n/a"}`
    );

    const rating = await api(baseUrl, "/api/rating/reviews", regular.token, {
      method: "POST",
      body: JSON.stringify({
        matchId: post.payload?.id,
        revieweeId: guest.userId,
        score: 5,
        tags: ["on_time", "kind"]
      })
    });
    assertStatus("REGRESSION", "상호 평가/먹킹 등급", rating, 201);

    const logoutUser = await createConfirmedUser("logout");
    const signOut = await logoutUser.client.auth.signOut();
    record("AUTH", "logout", !signOut.error, signOut.error?.message ?? "signed_out=true");
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  const failed = results.filter((result) => !result.pass);

  for (const result of results) {
    console.log(
      `[${result.section}] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`
    );
  }

  if (failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(`[SMOKE] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
