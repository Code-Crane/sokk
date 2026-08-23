process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

const { app } = require("../dist/server/app");
const results = [];
const record = (name, pass, details = "") => results.push({ name, pass, details });

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function user(baseUrl, label) {
  const signup = await api(baseUrl, "/api/auth/signup", undefined, { method: "POST", body: JSON.stringify({ email: `rating-memory-${label}-${Date.now()}@example.com`, nickname: label, phoneNumber: "01012345678" }) });
  const token = signup.payload?.token;
  const verify = await api(baseUrl, "/api/auth/verification/mock", token, { method: "POST", body: JSON.stringify({ legalName: "먹킹테스터", birthDate: "1995-01-01", gender: "other", phoneNumber: "01012345678" }) });
  record(`${label} setup`, signup.status === 201 && verify.status === 200, `signup=${signup.status}, verify=${verify.status}`);
  return { id: signup.payload?.user?.id, token };
}

async function main() {
  const server = await new Promise((resolve, reject) => { const value = app.listen(0, "127.0.0.1", () => resolve(value)); value.once("error", reject); });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  try {
    const host = await user(baseUrl, "host");
    const guest = await user(baseUrl, "guest");
    const post = await api(baseUrl, "/api/matching/posts", host.token, { method: "POST", body: JSON.stringify({ restaurantName: "평가 메모리 식당", address: "서울시 테스트구", scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 1, intro: "평가 테스트" }) });
    const join = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/requests`, guest.token, { method: "POST" });
    await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, { method: "POST", body: JSON.stringify({ decision: "accepted" }) });
    const complete = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/complete`, host.token, { method: "POST" });
    const hostPending = await api(baseUrl, "/api/rating/pending", host.token);
    const guestPending = await api(baseUrl, "/api/rating/pending", guest.token);
    record("completion creates mutual pending", complete.status === 200 && hostPending.payload?.length === 1 && guestPending.payload?.length === 1, `complete=${complete.status}`);
    const gated = await api(baseUrl, "/api/matching/posts", host.token, { method: "POST", body: JSON.stringify({ restaurantName: "게이트", address: "서울", scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 1, intro: "blocked" }) });
    record("pending blocks next matching", gated.status === 403, `status=${gated.status}`);
    const rating = await api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: post.payload?.id, revieweeId: guest.id, reviewerId: guest.id, score: 5, tags: ["on_time", "kind"] }) });
    record("JWT reviewer and score applied", rating.status === 201 && rating.payload?.previousScore === 36.5 && rating.payload?.nextScore === 38.8 && rating.payload?.nextGrade === "regular", `status=${rating.status}`);
    const duplicate = await api(baseUrl, "/api/rating/reviews", host.token, { method: "POST", body: JSON.stringify({ matchId: post.payload?.id, revieweeId: guest.id, score: 5, tags: [] }) });
    record("duplicate rating rejected", duplicate.status === 404, `status=${duplicate.status}`);
    const guestProfile = await api(baseUrl, "/api/auth/me", guest.token);
    record("manner profile exposed", guestProfile.status === 200 && guestProfile.payload?.mannerScore === 38.8 && guestProfile.payload?.mannerGrade === "regular", `status=${guestProfile.status}`);
  } finally { await new Promise((resolve) => server.close(resolve)); }
  for (const result of results) console.log(`[RATING_MEMORY] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}
main().catch((error) => { console.error(`[RATING_MEMORY] FAIL ${error instanceof Error ? error.message : "unknown error"}`); process.exitCode = 1; });
