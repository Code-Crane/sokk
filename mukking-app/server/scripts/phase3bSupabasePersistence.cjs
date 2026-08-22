const crypto = require("crypto");
const path = require("path");
const { spawn } = require("child_process");
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
}

function requireEnv(name, value) {
  if (!value) {
    throw new Error(`${name} is missing.`);
  }
}

function randomEmail(label) {
  return `mukking-persist-${label}-${Date.now()}-${crypto
    .randomBytes(4)
    .toString("hex")}@gmail.com`;
}

function randomPassword() {
  return `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
}

function createAnonClient() {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

function createServiceClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

async function assertMigrationApplied() {
  const supabase = createServiceClient();
  const tables = ["reports", "report_events", "blocks", "sanctions", "admin_audit_logs"];

  for (const table of tables) {
    const { error } = await supabase.from(table).select("id").limit(1);

    if (error) {
      record(
        "MIGRATION",
        `${table} table reachable`,
        false,
        `error=${error.message}`
      );
      throw new Error(
        `Migration is not applied or ${table} is unreachable. Apply supabase/migrations/202608210001_phase3b_reports_blocks_sanctions_audit.sql first.`
      );
    }

    record("MIGRATION", `${table} table reachable`, true);
  }
}

async function createConfirmedUser(label) {
  const email = randomEmail(label);
  const password = randomPassword();
  const admin = createServiceClient();
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

  const client = createAnonClient();
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
    friendlyName: `persist-${Date.now()}`
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

async function api(baseUrl, pathName, token, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers ?? {})
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${baseUrl}${pathName}`, {
    ...options,
    headers
  });
  const payload = await response.json().catch(() => undefined);

  return { status: response.status, payload };
}

async function waitForServer(baseUrl) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < 10_000) {
    try {
      const response = await fetch(`${baseUrl}/api/health`);

      if (response.ok) return;
    } catch {
      // retry
    }

    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  throw new Error("Server did not start in time.");
}

async function startServer(port, env) {
  const serverPath = path.join(__dirname, "../dist/server/server.js");
  const child = spawn(process.execPath, [serverPath], {
    cwd: path.join(__dirname, ".."),
    env: {
      ...process.env,
      ...env,
      PORT: String(port),
      AUTH_PROVIDER: "supabase",
      REPOSITORY_PROVIDER: "supabase",
      ADMIN_REQUIRE_MFA: "true",
      RATE_LIMIT_REPORT_CREATE_MAX: "100",
      RATE_LIMIT_BLOCK_CREATE_MAX: "100",
      RATE_LIMIT_ADMIN_AUTH_MAX: "200",
      RATE_LIMIT_ADMIN_SENSITIVE_MAX: "200"
    },
    stdio: ["ignore", "pipe", "pipe"]
  });

  const baseUrl = `http://127.0.0.1:${port}`;
  await waitForServer(baseUrl);
  return { child, baseUrl };
}

async function stopServer(child) {
  if (child.exitCode !== null) return;
  child.kill();
  await new Promise((resolve) => child.once("exit", resolve));
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

async function main() {
  requireEnv("SUPABASE_URL", SUPABASE_URL);
  requireEnv("SUPABASE_ANON_KEY", SUPABASE_ANON_KEY);
  requireEnv("SUPABASE_SERVICE_ROLE_KEY", SUPABASE_SERVICE_ROLE_KEY);

  await assertMigrationApplied();

  const reporter = await createConfirmedUser("reporter");
  const target = await createConfirmedUser("target");
  const admin = await createConfirmedUser("admin");
  const adminAal2Token = await createAal2Token(admin.client);
  const serverEnv = {
    ADMIN_EMAIL_WHITELIST: admin.email,
    ADMIN_UID_WHITELIST: admin.userId
  };

  const port = 4301 + Math.floor(Math.random() * 100);
  let running = await startServer(port, serverEnv);
  let reportId;
  let sanctionId;

  try {
    await syncAndVerify(running.baseUrl, reporter);
    await syncAndVerify(running.baseUrl, target);
    await syncAndVerify(running.baseUrl, admin);

    const report = await api(running.baseUrl, "/api/reports", reporter.token, {
      method: "POST",
      body: JSON.stringify({
        reportedUserId: target.userId,
        targetType: "user",
        targetId: target.userId,
        reason: "spam",
        description: "Supabase persistence test"
      })
    });
    assertStatus("REPORT", "사용자 신고 생성", report, 201);
    reportId = report.payload?.id;

    const serviceReport = await createServiceClient()
      .from("reports")
      .select("*")
      .eq("id", reportId)
      .maybeSingle();
    record(
      "REPORT",
      "reports row 생성 확인",
      !serviceReport.error && Boolean(serviceReport.data),
      serviceReport.error?.message ?? "row_found=true"
    );

    const directReportRead = await reporter.client
      .from("reports")
      .select("*")
      .eq("id", reportId);
    record(
      "SECURITY",
      "일반 사용자 reports 직접 조회 차단",
      Boolean(directReportRead.error) || (directReportRead.data ?? []).length === 0,
      directReportRead.error ? "blocked_by_rls_or_grant=true" : `rows=${directReportRead.data?.length ?? 0}`
    );

    const adminReport = await api(running.baseUrl, `/api/admin/reports/${reportId}`, admin.token);
    assertStatus("REPORT", "관리자 API report 조회", adminReport, 200);

    const reportUpdate = await api(
      running.baseUrl,
      `/api/admin/reports/${reportId}`,
      adminAal2Token,
      {
        method: "PATCH",
        body: JSON.stringify({ status: "reviewing", adminNote: "persistence check" })
      }
    );
    assertStatus("REPORT", "report 처리", reportUpdate, 200);

    const eventRows = await createServiceClient()
      .from("report_events")
      .select("*")
      .eq("report_id", reportId);
    record(
      "REPORT",
      "report_events 생성 확인",
      !eventRows.error && (eventRows.data?.length ?? 0) >= 2,
      eventRows.error?.message ?? `count=${eventRows.data?.length ?? 0}`
    );

    const block = await api(running.baseUrl, "/api/blocks", reporter.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: target.userId, reason: "persistence block" })
    });
    assertStatus("BLOCK", "A -> B 차단", block, 201);

    const duplicateBlock = await api(running.baseUrl, "/api/blocks", reporter.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: target.userId })
    });
    assertStatus("BLOCK", "duplicate block 차단", duplicateBlock, 409);

    const unblock = await api(running.baseUrl, `/api/blocks/${target.userId}`, reporter.token, {
      method: "DELETE"
    });
    assertStatus("BLOCK", "unblock", unblock, 200);

    const reblock = await api(running.baseUrl, "/api/blocks", reporter.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: target.userId, reason: "restart persistence block" })
    });
    assertStatus("BLOCK", "차단 관계 persistence 준비", reblock, 201);

    const sanction = await api(running.baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: target.userId,
        type: "matching_suspension",
        reason: "persistence suspension"
      })
    });
    assertStatus("SANCTION", "suspend persistence 준비", sanction, 201);
    sanctionId = sanction.payload?.id;

    const revoke = await api(
      running.baseUrl,
      `/api/admin/sanctions/${sanctionId}/revoke`,
      adminAal2Token,
      {
        method: "POST",
        body: JSON.stringify({ reason: "revoke persistence" })
      }
    );
    assertStatus("SANCTION", "revoke persistence 준비", revoke, 200);

    const ban = await api(running.baseUrl, "/api/admin/sanctions", adminAal2Token, {
      method: "POST",
      body: JSON.stringify({
        userId: target.userId,
        type: "permanent_ban",
        reason: "ban persistence"
      })
    });
    assertStatus("SANCTION", "ban persistence 준비", ban, 201);

    const directSanctionUpdate = await reporter.client
      .from("sanctions")
      .update({ status: "revoked" })
      .eq("id", ban.payload?.id);
    record(
      "SECURITY",
      "일반 사용자 sanctions 직접 수정 차단",
      Boolean(directSanctionUpdate.error),
      directSanctionUpdate.error ? "blocked_by_rls_or_grant=true" : "unexpected_update_allowed"
    );

    const directAuditRead = await reporter.client.from("admin_audit_logs").select("*");
    record(
      "SECURITY",
      "일반 사용자 admin_audit_logs 접근 차단",
      Boolean(directAuditRead.error) || (directAuditRead.data ?? []).length === 0,
      directAuditRead.error ? "blocked_by_rls_or_grant=true" : `rows=${directAuditRead.data?.length ?? 0}`
    );
  } finally {
    await stopServer(running.child);
  }

  running = await startServer(port, serverEnv);

  try {
    const persistedReport = await api(running.baseUrl, `/api/admin/reports/${reportId}`, admin.token);
    assertStatus("PERSISTENCE", "서버 재시작 후 신고 유지", persistedReport, 200);

    const persistedBlocks = await api(running.baseUrl, "/api/blocks", reporter.token);
    record(
      "PERSISTENCE",
      "서버 재시작 후 차단 유지",
      persistedBlocks.status === 200 &&
        Array.isArray(persistedBlocks.payload) &&
        persistedBlocks.payload.some((block) => block.blockedId === target.userId && !block.revokedAt),
      `status=${persistedBlocks.status}`
    );

    const persistedSanctions = await api(
      running.baseUrl,
      `/api/admin/sanctions?userId=${target.userId}`,
      admin.token
    );
    record(
      "PERSISTENCE",
      "서버 재시작 후 제재 유지",
      persistedSanctions.status === 200 &&
        Array.isArray(persistedSanctions.payload) &&
        persistedSanctions.payload.length >= 2,
      `status=${persistedSanctions.status}, count=${Array.isArray(persistedSanctions.payload) ? persistedSanctions.payload.length : "n/a"}`
    );

    const persistedAudit = await api(running.baseUrl, "/api/admin/audit-logs", admin.token);
    record(
      "PERSISTENCE",
      "서버 재시작 후 감사 로그 유지",
      persistedAudit.status === 200 &&
        Array.isArray(persistedAudit.payload) &&
        persistedAudit.payload.length > 0,
      `status=${persistedAudit.status}, count=${Array.isArray(persistedAudit.payload) ? persistedAudit.payload.length : "n/a"}`
    );

    const bannedAccess = await api(running.baseUrl, "/api/auth/me", target.token);
    assertStatus("PERSISTENCE", "서버 재시작 후 ban 제한 유지", bannedAccess, 403);
  } finally {
    await stopServer(running.child);
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
  for (const result of results) {
    console.log(
      `[${result.section}] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`
    );
  }
  console.error(`[PERSISTENCE] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
