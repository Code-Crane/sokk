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

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, body: await response.json().catch(() => undefined) };
}

function start(app) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
    server.once("error", reject);
  });
}
const stop = (server) => server ? new Promise((resolve) => server.close(resolve)) : Promise.resolve();

async function main() {
  if (!url || !anonKey || !serviceKey) throw new Error("Supabase environment missing.");
  process.env.AUTH_PROVIDER = "supabase";
  process.env.REPOSITORY_PROVIDER = "supabase";
  const service = client(serviceKey);
  const auth = client(anonKey);
  const email = `mukking-profile-followup-${Date.now()}-${crypto.randomBytes(3).toString("hex")}@example.com`;
  const password = `Mukking-${crypto.randomBytes(8).toString("hex")}!1`;
  const payload = { legalName: "먹킹테스터", birthDate: "1995-01-01", gender: "other", phoneNumber: "01012345678" };
  let userId;
  let postId;
  let server;
  try {
    const created = await service.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { nickname: "후속검증", phoneNumber: "01012345678" } });
    if (created.error || !created.data.user) throw new Error("Test user creation failed.");
    userId = created.data.user.id;
    const firstLogin = await auth.auth.signInWithPassword({ email, password });
    const firstToken = firstLogin.data.session?.access_token;
    const { app } = require("../dist/server/app");
    server = await start(app);
    let baseUrl = `http://127.0.0.1:${server.address().port}`;
    const firstMe = await api(baseUrl, "/api/auth/me", firstToken);
    const started = await api(baseUrl, "/api/auth/verification/mock/start", firstToken, { method: "POST" });
    const completed = await api(baseUrl, "/api/auth/verification/mock/complete", firstToken, { method: "POST", body: JSON.stringify(payload) });
    const replay = await api(baseUrl, "/api/auth/verification/mock/complete", firstToken, { method: "POST", body: JSON.stringify(payload) });
    record("valid verification replay", started.status === 200 && completed.status === 200 && replay.status === 409, `start=${started.status}, complete=${completed.status}, replay=${replay.status}`);

    await service.from("user_manner_profiles").upsert({ user_id: userId, manner_score: 45, manner_grade: "mukking" });
    await auth.auth.signOut();
    const secondLogin = await auth.auth.signInWithPassword({ email, password });
    const secondToken = secondLogin.data.session?.access_token;
    const secondMe = await api(baseUrl, "/api/auth/me", secondToken);
    const profileCount = await service.from("user_profiles").select("user_id", { count: "exact", head: true }).eq("user_id", userId);
    record("logout and login restore profile", firstMe.status === 200 && secondMe.status === 200 && Boolean(secondToken) && secondMe.body?.id === userId && secondMe.body?.nickname === "후속검증" && secondMe.body?.verificationStatus === "verified" && secondMe.body?.mannerScore === 45 && secondMe.body?.mannerGrade === "mukking" && profileCount.count === 1, `status=${secondMe.status}, profiles=${profileCount.count}`);

    await stop(server);
    server = await start(app);
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    const matching = await api(baseUrl, "/api/matching/posts", secondToken, { method: "POST", body: JSON.stringify({ restaurantName: "재시작 후 식당", address: "서울시 테스트구", scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 1, intro: "재인증 없이 생성" }) });
    postId = matching.body?.id;
    const row = postId ? await service.from("matching_posts").select("author_id").eq("id", postId).single() : { data: null };
    record("restart matching with persisted verification", matching.status === 201 && row.data?.author_id === userId, `status=${matching.status}`);
  } finally {
    await stop(server);
    if (postId) await service.from("matching_posts").delete().eq("id", postId);
    if (userId) {
      await service.from("user_manner_profiles").delete().eq("user_id", userId);
      await service.auth.admin.deleteUser(userId);
    }
  }
  for (const result of results) console.log(`[PROFILE_FOLLOWUP] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}
main().catch((error) => { console.error(`[PROFILE_FOLLOWUP] FAIL ${error.message}`); process.exitCode = 1; });
