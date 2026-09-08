// Memory-only HTTP/domain regression; never contacts Supabase or changes live data.
process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
const assert = require("node:assert/strict");
const { app } = require("../dist/server/app");
const { repositories } = require("../dist/server/repositories");
const petService = require("../dist/server/services/pet/pet.service");
const curve = require("../dist/shared/utils/pet");
let checks = 0;
function check(value, name) { assert.ok(value, name); checks++; console.log("[PET_MEMORY] PASS " + name); }
async function main() {
  let threshold = 0;
  for (let level = 1; level <= 30; level++) {
    check(curve.levelFromXp(threshold) === level, "level boundary " + level);
    if (level > 1) check(curve.levelFromXp(threshold - 1) === level - 1, "previous boundary " + level);
    if (level < 30) threshold += curve.xpForLevel(level);
  }
  check(curve.levelFromXp(threshold + 10000) === 30 && curve.progressToNextLevel(threshold).progress === 1, "level cap with total XP retained");
  check(curve.progressToNextLevel(150).levelXp === 50 && curve.progressToNextLevel(150).remainingXp === 75, "progress uses current level requirement");
  check([1,4,5,9,10,19,20,29,30].map(curve.growthStageFromLevel).join("|") === "꼬마|꼬마|새싹 친구|새싹 친구|단골 친구|단골 친구|식탁 친구|식탁 친구|먹킹 마스터", "growth boundaries");
  for (const xp of [-1, 1.5, NaN, Infinity]) assert.throws(() => curve.levelFromXp(xp));
  const server = await new Promise(resolve => { const s = app.listen(0, "127.0.0.1", () => resolve(s)); });
  const base = "http://127.0.0.1:" + server.address().port;
  async function api(path, token, body, method = body === undefined ? "GET" : "POST") {
    const r = await fetch(base + path, { method, headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: r.status, data: await r.json().catch(() => null) };
  }
  async function user(label) {
    const r = await api("/api/auth/signup", null, { email: "pet-" + label + "-" + Date.now() + "@example.com", nickname: label, phoneNumber: "01012345678" });
    assert.equal(r.status, 201);
    assert.equal((await api("/api/auth/verification/mock", r.data.token, { legalName: "먹킹테스터", birthDate: "1995-01-01", gender: "other", phoneNumber: "01012345678" })).status, 200);
    return { id: r.data.user.id, token: r.data.token };
  }
  try {
    check((await api("/api/pets/me")).status === 401, "read requires auth");
    check((await api("/api/pets/me", null, { petType: "healthy" })).status === 401, "selection requires auth");
    const users = [];
    for (const type of ["healthy", "night", "hearty"]) {
      const u = await user(type); users.push(u);
      const empty = await api("/api/pets/me", u.token);
      check(empty.status === 200 && empty.data === null, "no pet returns null " + type);
      const pet = await api("/api/pets/me", u.token, { petType: type });
      check(pet.status === 201 && pet.data.userId === u.id && pet.data.petType === type && pet.data.level === 1 && pet.data.xp === 0, "select " + type);
      check((await api("/api/pets/me", u.token, { petType: type })).status === 409, "no species overwrite " + type);
    }
    const [host, guest, other] = users;
    for (const input of [{}, {petType:"fake"}, {petType:"healthy",xp:999}, {petType:"healthy",userId:guest.id}, []]) {
      check((await api("/api/pets/me", host.token, input)).status === 400, "invalid or privileged payload rejected");
    }
    check((await api("/api/pets/me?userId=" + host.id, guest.token)).data.userId === guest.id, "query cannot read another user");
    check((await api("/api/pets/" + host.id, guest.token)).status === 404, "no other-user endpoint");
    const withoutPet = await user("without");
    await petService.awardPetXpBestEffort(withoutPet.id, "matching_completed", "before-selection");
    check(await petService.getMyPet(withoutPet.id) === null, "no retroactive pet creation");
    const race = await Promise.allSettled([petService.selectPet(withoutPet.id,{petType:"healthy"}),petService.selectPet(withoutPet.id,{petType:"night"})]);
    check(race.filter(r=>r.status==="fulfilled").length === 1, "concurrent selection one winner");
    await Promise.all(Array.from({length:20},()=>petService.awardPetXpBestEffort(other.id,"matching_completed","same")));
    check((await petService.getMyPet(other.id)).xp === 30, "concurrent award deduplicated");
    await petService.awardPetXpBestEffort(other.id,"matching_completed","different");
    check((await petService.getMyPet(other.id)).xp === 60, "different event awarded");
    const p = await api("/api/matching/posts", host.token, {restaurantName:"[TEST] pet memory", address:"테스트", scheduledAt:new Date(Date.now()+86400000).toISOString(), maxParticipants:1, intro:"[TEST] pet memory"});
    assert.equal(p.status,201);
    const join = await api("/api/matching/posts/"+p.data.id+"/requests",guest.token,{}, "POST");
    assert.equal(join.status,201);
    assert.equal((await api("/api/matching/requests/"+join.data.id+"/respond",host.token,{decision:"accepted"})).status,200);
    check((await petService.getMyPet(host.id)).xp === 0 && (await petService.getMyPet(guest.id)).xp === 0, "join/approval alone do not grant completion XP");
    assert.equal((await api("/api/matching/posts/"+p.data.id+"/complete",host.token,{})).status,200);
    check((await petService.getMyPet(host.id)).xp === 50 && (await petService.getMyPet(guest.id)).xp === 30, "real completion host50 participant30");
    await api("/api/matching/posts/"+p.data.id+"/complete",host.token,{});
    check((await petService.getMyPet(host.id)).xp === 50, "completion replay does not double award");
    const rating = {matchId:p.data.id,revieweeId:guest.id,score:5,tags:[]};
    assert.equal((await api("/api/rating/reviews",host.token,rating)).status,201);
    check((await petService.getMyPet(host.id)).xp === 65, "actual rating grants15");
    await api("/api/rating/reviews",host.token,rating);
    check((await petService.getMyPet(host.id)).xp === 65, "duplicate rating no XP");
    // Simulate unavailable ledger during an actual successful rating.
    const award = repositories.pets.award;
    repositories.pets.award = async () => {throw Error("simulated");};
    try {
      check((await api("/api/rating/reviews",guest.token,{matchId:p.data.id,revieweeId:host.id,score:5,tags:[]})).status === 201, "XP outage preserves rating business action");
      await petService.awardPetXpBestEffort(guest.id,"matching_completed","outage");
    } finally { repositories.pets.award = award; }
    const capPet = await repositories.pets.findByUser(other.id);
    await repositories.pets.award(other.id,"matching_completed","cap",threshold+1000);
    check((await petService.getMyPet(other.id)).xp === capPet.xp+threshold+1000 && (await petService.getMyPet(other.id)).level === 30, "XP total continues above cap");
    check((await api("/api/pets/me",host.token)).data.xp === 65, "reload reads durable repository state for account");
    check((await api("/api/pets/me/xp",host.token,{xp:1000})).status === 404, "no client XP mutation endpoint");
  } finally { await new Promise(resolve=>server.close(resolve)); }
  console.log("[PET_MEMORY] " + checks + " checks PASS");
}
main().catch(() => { console.error("[PET_MEMORY] FAIL (inspect assertion locally; no tokens logged)"); process.exitCode=1; });
