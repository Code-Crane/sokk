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

function randomEmail(label) {
  return `mukking-p3b-${label}-${Date.now()}-${crypto
    .randomBytes(4)
    .toString("hex")}@gmail.com`;
}

function randomPassword() {
  return `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
}

function authClient() {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

function serviceRoleClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

async function createConfirmedUser(label) {
  const email = randomEmail(label);
  const password = randomPassword();
  const admin = serviceRoleClient();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      nickname: `${label}-tester`,
      phoneNumber: "01012345678"
    }
  });

  if (error || !data.user) {
    throw new Error(`${label} user creation failed: ${error?.message ?? "missing user"}`);
  }

  const client = authClient();
  const signedIn = await client.auth.signInWithPassword({ email, password });

  if (signedIn.error || !signedIn.data.session?.access_token) {
    throw new Error(`${label} signin failed: ${signedIn.error?.message ?? "missing session"}`);
  }

  return {
    client,
    email,
    password,
    userId: data.user.id,
    token: signedIn.data.session.access_token
  };
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

async function createAal2Token(client) {
  const enroll = await client.auth.mfa.enroll({
    factorType: "totp",
    friendlyName: `phase3b-${Date.now()}`
  });

  if (enroll.error) {
    throw new Error(enroll.error.message);
  }

  const factorId = enroll.data.id;
  const challenge = await client.auth.mfa.challenge({ factorId });

  if (challenge.error) {
    throw new Error(challenge.error.message);
  }

  const verify = await client.auth.mfa.verify({
    factorId,
    challengeId: challenge.data.id,
    code: generateTotp(enroll.data.totp.secret)
  });

  if (verify.error) {
    throw new Error(verify.error.message);
  }

  const session = verify.data.session ?? (await client.auth.getSession()).data.session;

  if (!session?.access_token) {
    throw new Error("MFA verify did not return a session.");
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

async function syncAndVerify(baseUrl, user) {
  const me = await api(baseUrl, "/api/auth/me", user.token);
  assertStatus("SETUP", `profile sync ${user.email}`, me, 200);

  const verification = await api(baseUrl, "/api/auth/verification/mock", user.token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  assertStatus("SETUP", `mock verification ${user.email}`, verification, 200);
}

async function createPost(baseUrl, user, label, maxParticipants = 1) {
  return api(baseUrl, "/api/matching/posts", user.token, {
    method: "POST",
    body: JSON.stringify({
      restaurantName: `${label} 식당`,
      address: "서울시 테스트구",
      scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
      maxParticipants,
      intro: `${label} 테스트`
    })
  });
}

async function createMatchedRoom(baseUrl, host, guest, label) {
  const post = await createPost(baseUrl, host, label, 1);
  assertStatus("SETUP", `${label} room post`, post, 201);

  const join = await api(
    baseUrl,
    `/api/matching/posts/${post.payload?.id}/requests`,
    guest.token,
    { method: "POST" }
  );
  assertStatus("SETUP", `${label} room join`, join, 201);

  const accept = await api(
    baseUrl,
    `/api/matching/requests/${join.payload?.id}/respond`,
    host.token,
    {
      method: "POST",
      body: JSON.stringify({ decision: "accepted" })
    }
  );
  assertStatus("SETUP", `${label} room accept`, accept, 200);

  return {
    post: post.payload,
    joinRequest: join.payload,
    room: accept.payload?.chatRoom
  };
}

async function main() {
  requireEnv("SUPABASE_URL", SUPABASE_URL);
  requireEnv("SUPABASE_ANON_KEY", SUPABASE_ANON_KEY);
  requireEnv("SUPABASE_SERVICE_ROLE_KEY", SUPABASE_SERVICE_ROLE_KEY);

  process.env.AUTH_PROVIDER = "supabase";
  process.env.ADMIN_REQUIRE_MFA = "true";
  process.env.RATE_LIMIT_REPORT_CREATE_MAX = "2";
  process.env.RATE_LIMIT_BLOCK_CREATE_MAX = "50";
  process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";
  process.env.RATE_LIMIT_ADMIN_AUTH_MAX = "200";
  process.env.RATE_LIMIT_ADMIN_SENSITIVE_MAX = "200";

  const users = {};
  for (const label of [
    "a",
    "b",
    "c",
    "d",
    "rate",
    "matchSuspend",
    "chatHost",
    "chatSuspend",
    "banned",
    "regHost",
    "regGuest",
    "outsider",
    "admin"
  ]) {
    users[label] = await createConfirmedUser(label);
  }

  process.env.ADMIN_EMAIL_WHITELIST = users.admin.email;
  process.env.ADMIN_UID_WHITELIST = users.admin.userId;

  const adminAal2Token = await createAal2Token(users.admin.client);
  const { app } = require("../dist/server/app");
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    for (const user of Object.values(users)) {
      await syncAndVerify(baseUrl, user);
    }

    const unauthReport = await api(baseUrl, "/api/reports", undefined, {
      method: "POST",
      body: JSON.stringify({})
    });
    assertStatus("REPORT", "비로그인 신고 차단", unauthReport, 401);

    const report = await api(baseUrl, "/api/reports", users.a.token, {
      method: "POST",
      body: JSON.stringify({
        reportedUserId: users.b.userId,
        targetType: "user",
        targetId: users.b.userId,
        reason: "spam",
        description: "반복 홍보"
      })
    });
    assertStatus("REPORT", "일반 사용자 신고 생성", report, 201);

    const invalidReport = await api(baseUrl, "/api/reports", users.a.token, {
      method: "POST",
      body: JSON.stringify({
        reportedUserId: users.b.userId,
        targetType: "user",
        targetId: "wrong-target",
        reason: "spam"
      })
    });
    assertStatus("REPORT", "잘못된 target validation", invalidReport, 400);

    const userReportRead = await api(baseUrl, "/api/admin/reports", users.b.token);
    assertStatus("REPORT", "일반 사용자 신고 데이터 조회 차단", userReportRead, 403);

    const adminReportList = await api(baseUrl, "/api/admin/reports", users.admin.token);
    assertStatus("REPORT", "관리자 신고 목록 조회", adminReportList, 200);

    const adminReportUpdate = await api(
      baseUrl,
      `/api/admin/reports/${report.payload?.id}`,
      adminAal2Token,
      {
        method: "PATCH",
        body: JSON.stringify({
          status: "reviewing",
          adminNote: "검토 시작"
        })
      }
    );
    assertStatus("REPORT", "관리자 신고 처리 이력 생성", adminReportUpdate, 200);

    for (let index = 0; index < 3; index += 1) {
      const rateReport = await api(baseUrl, "/api/reports", users.rate.token, {
        method: "POST",
        body: JSON.stringify({
          reportedUserId: users.b.userId,
          targetType: "user",
          targetId: users.b.userId,
          reason: "other",
          description: `rate-${index}`
        })
      });

      if (index < 2) {
        assertStatus("REPORT", `신고 rate limit 준비 ${index + 1}`, rateReport, 201);
      } else {
        assertStatus("REPORT", "신고 API 반복 호출 rate limit", rateReport, 429);
      }
    }

    const block = await api(baseUrl, "/api/blocks", users.a.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: users.b.userId, reason: "원치 않는 상호작용" })
    });
    assertStatus("BLOCK", "A -> B 차단", block, 201);

    const duplicateBlock = await api(baseUrl, "/api/blocks", users.a.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: users.b.userId })
    });
    assertStatus("BLOCK", "동일 차단 중복", duplicateBlock, 409);

    const unblock = await api(baseUrl, `/api/blocks/${users.b.userId}`, users.a.token, {
      method: "DELETE"
    });
    assertStatus("BLOCK", "차단 해제", unblock, 200);

    await api(baseUrl, "/api/blocks", users.a.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: users.b.userId })
    });
    const blockedPost = await createPost(baseUrl, users.a, "blocked-request", 1);
    assertStatus("BLOCK", "차단 테스트 모집글 생성", blockedPost, 201);
    const blockedJoin = await api(
      baseUrl,
      `/api/matching/posts/${blockedPost.payload?.id}/requests`,
      users.b.token,
      { method: "POST" }
    );
    assertStatus("BLOCK", "차단된 사용자의 신규 매칭 요청", blockedJoin, 403);

    const pendingChatPost = await createPost(baseUrl, users.c, "blocked-chat", 1);
    const pendingJoin = await api(
      baseUrl,
      `/api/matching/posts/${pendingChatPost.payload?.id}/requests`,
      users.d.token,
      { method: "POST" }
    );
    assertStatus("BLOCK", "채팅 차단 전 참가 요청 생성", pendingJoin, 201);
    await api(baseUrl, "/api/blocks", users.c.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: users.d.userId })
    });
    const blockedAccept = await api(
      baseUrl,
      `/api/matching/requests/${pendingJoin.payload?.id}/respond`,
      users.c.token,
      {
        method: "POST",
        body: JSON.stringify({ decision: "accepted" })
      }
    );
    assertStatus("BLOCK", "차단된 사용자의 신규 채팅 생성", blockedAccept, 403);

    const matchingSanction = await api(baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: users.matchSuspend.userId,
        type: "matching_suspension",
        reason: "테스트 매칭 정지"
      })
    });
    assertStatus("SANCTION", "관리자 매칭 정지 생성", matchingSanction, 201);

    const suspendedMatching = await createPost(
      baseUrl,
      users.matchSuspend,
      "suspended-matching",
      1
    );
    assertStatus("SANCTION", "정지 상태에서 매칭 제한", suspendedMatching, 403);

    const revokeMatching = await api(
      baseUrl,
      `/api/admin/sanctions/${matchingSanction.payload?.id}/revoke`,
      adminAal2Token,
      {
        method: "POST",
        body: JSON.stringify({ reason: "테스트 복구" })
      }
    );
    assertStatus("SANCTION", "active 상태 복구", revokeMatching, 200);

    const restoredMatching = await createPost(
      baseUrl,
      users.matchSuspend,
      "restored-matching",
      1
    );
    assertStatus("SANCTION", "복구 후 매칭 허용", restoredMatching, 201);

    const chatSetup = await createMatchedRoom(
      baseUrl,
      users.chatHost,
      users.chatSuspend,
      "chat-sanction"
    );
    const chatSanction = await api(baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: users.chatSuspend.userId,
        type: "chat_suspension",
        reason: "테스트 채팅 정지"
      })
    });
    assertStatus("SANCTION", "관리자 채팅 정지 생성", chatSanction, 201);

    const suspendedChat = await api(
      baseUrl,
      `/api/chat/rooms/${chatSetup.room?.id}/messages`,
      users.chatSuspend.token,
      {
        method: "POST",
        body: JSON.stringify({ text: "정지 상태 메시지" })
      }
    );
    assertStatus("SANCTION", "정지 상태에서 채팅 제한", suspendedChat, 403);

    await api(
      baseUrl,
      `/api/admin/sanctions/${chatSanction.payload?.id}/revoke`,
      adminAal2Token,
      {
        method: "POST",
        body: JSON.stringify({ reason: "테스트 채팅 복구" })
      }
    );
    const restoredChat = await api(
      baseUrl,
      `/api/chat/rooms/${chatSetup.room?.id}/messages`,
      users.chatSuspend.token,
      {
        method: "POST",
        body: JSON.stringify({ text: "복구 후 메시지" })
      }
    );
    assertStatus("SANCTION", "복구 후 채팅 허용", restoredChat, 201);

    const ban = await api(baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: users.banned.userId,
        type: "permanent_ban",
        reason: "테스트 영구 차단"
      })
    });
    assertStatus("SANCTION", "영구 차단 생성", ban, 201);

    const bannedAccess = await api(baseUrl, "/api/auth/me", users.banned.token);
    assertStatus("SANCTION", "banned 상태 접근 제한", bannedAccess, 403);

    const auditLogs = await api(baseUrl, "/api/admin/audit-logs", users.admin.token);
    record(
      "SANCTION",
      "관리자 감사 로그 생성 확인",
      auditLogs.status === 200 && Array.isArray(auditLogs.payload) && auditLogs.payload.length > 0,
      `status=${auditLogs.status}, count=${Array.isArray(auditLogs.payload) ? auditLogs.payload.length : "n/a"}`
    );

    const normalUserAdmin = await api(baseUrl, "/api/admin/sanctions", users.a.token, {
      method: "POST",
      body: JSON.stringify({
        userId: users.b.userId,
        type: "warning",
        reason: "should fail"
      })
    });
    assertStatus("SECURITY", "일반 사용자의 관리자 endpoint", normalUserAdmin, 403);

    const noJwtBlock = await api(baseUrl, "/api/blocks", undefined, {
      method: "POST",
      body: JSON.stringify({ blockedId: users.b.userId })
    });
    assertStatus("SECURITY", "JWT 없는 API", noJwtBlock, 401);

    const regression = await createMatchedRoom(
      baseUrl,
      users.regHost,
      users.regGuest,
      "regression"
    );
    record("REGRESSION", "정상 사용자 간 채팅방", Boolean(regression.room?.id), "room check");

    const regressionMessage = await api(
      baseUrl,
      `/api/chat/rooms/${regression.room?.id}/messages`,
      users.regGuest.token,
      {
        method: "POST",
        body: JSON.stringify({ text: "회귀 테스트 메시지" })
      }
    );
    assertStatus("REGRESSION", "정상 사용자 채팅", regressionMessage, 201);

    const regressionComplete = await api(
      baseUrl,
      `/api/matching/posts/${regression.post?.id}/complete`,
      users.regHost.token,
      { method: "POST" }
    );
    assertStatus("REGRESSION", "정상 사용자 만남 완료", regressionComplete, 200);

    const pending = await api(baseUrl, "/api/rating/pending", users.regHost.token);
    record(
      "REGRESSION",
      "정상 사용자 평가 대기",
      pending.status === 200 && Array.isArray(pending.payload) && pending.payload.length > 0,
      `status=${pending.status}`
    );

    const rating = await api(baseUrl, "/api/rating/reviews", users.regHost.token, {
      method: "POST",
      body: JSON.stringify({
        matchId: regression.post?.id,
        revieweeId: users.regGuest.userId,
        score: 5,
        tags: ["on_time", "kind"]
      })
    });
    assertStatus("REGRESSION", "정상 사용자 평가/먹킹 등급", rating, 201);
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
  console.error(`[PHASE3B] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
