process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

const { app } = require("../dist/server/app");
const { db } = require("../dist/server/models/inMemoryDb");
const { repositories } = require("../dist/server/repositories");
const results = [];

function record(name, pass, details = "") {
  results.push({ name, pass, details });
}

async function api(baseUrl, path, token, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  return { status: response.status, payload: await response.json().catch(() => undefined) };
}

async function createUser(baseUrl, label) {
  const signup = await api(baseUrl, "/api/auth/signup", undefined, {
    method: "POST",
    body: JSON.stringify({
      email: `matching-chat-recovery-${label}-${Date.now()}@example.com`,
      nickname: `${label}-recovery`,
      phoneNumber: "01012345678"
    })
  });
  const token = signup.payload?.token;
  const verification = await api(baseUrl, "/api/auth/verification/mock", token, {
    method: "POST",
    body: JSON.stringify({
      legalName: "먹킹테스터",
      birthDate: "1995-01-01",
      gender: "other",
      phoneNumber: "01012345678"
    })
  });
  record(`${label} setup`, signup.status === 201 && verification.status === 200);
  return { id: signup.payload?.user?.id, token };
}

async function createAcceptedFixture(baseUrl, host, guest, label, inject) {
  const post = await api(baseUrl, "/api/matching/posts", host.token, {
    method: "POST",
    body: JSON.stringify({
      restaurantName: `복구 테스트 식당 ${label}`,
      address: "서울시 테스트구 복구로 1",
      scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
      maxParticipants: 1,
      intro: `matching chat recovery ${label}`
    })
  });
  const join = await api(
    baseUrl,
    `/api/matching/posts/${post.payload?.id}/requests`,
    guest.token,
    { method: "POST" }
  );
  const restore = inject ? inject() : () => {};
  const accepted = await api(
    baseUrl,
    `/api/matching/requests/${join.payload?.id}/respond`,
    host.token,
    { method: "POST", body: JSON.stringify({ decision: "accepted" }) }
  );
  restore();
  return { post, join, accepted };
}

function activeRooms(postId) {
  return Array.from(db.chatRooms.values()).filter(
    (room) => room.postId === postId && room.status === "active"
  );
}

function openedMessages(roomId) {
  return (db.chatMessages.get(roomId) ?? []).filter(
    (message) =>
      message.senderId === "system" &&
      message.text === "매칭이 성사되어 채팅방이 열렸습니다."
  );
}

async function retryAccept(baseUrl, fixture, host) {
  return api(
    baseUrl,
    `/api/matching/requests/${fixture.join.payload?.id}/respond`,
    host.token,
    { method: "POST", body: JSON.stringify({ decision: "accepted" }) }
  );
}

async function main() {
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve, reject) => {
    server.once("listening", resolve);
    server.once("error", reject);
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const originalEnsureRoom = repositories.chat.ensureRoom.bind(repositories.chat);
  const originalEnsureSystemMessage = repositories.chat.ensureSystemMessage.bind(
    repositories.chat
  );

  try {
    const host = await createUser(baseUrl, "host");
    const guest = await createUser(baseUrl, "guest");

    const caseA = await createAcceptedFixture(baseUrl, host, guest, "case-a", () => {
      repositories.chat.ensureRoom = async () => {
        throw new Error("injected room failure");
      };
      return () => {
        repositories.chat.ensureRoom = originalEnsureRoom;
      };
    });
    const acceptedAfterRoomFailure = await repositories.matching.findJoinRequestById(
      caseA.join.payload?.id
    );
    record(
      "CASE A accepted state survives room failure",
      caseA.accepted.status === 500 &&
        acceptedAfterRoomFailure?.status === "accepted" &&
        activeRooms(caseA.post.payload?.id).length === 0,
      `status=${caseA.accepted.status}`
    );
    const repairedA = await retryAccept(baseUrl, caseA, host);
    const roomA = activeRooms(caseA.post.payload?.id)[0];
    record(
      "CASE A retry repairs one room and membership",
      repairedA.status === 200 &&
        activeRooms(caseA.post.payload?.id).length === 1 &&
        roomA?.participantIds.includes(host.id) &&
        roomA?.participantIds.includes(guest.id),
      `status=${repairedA.status}`
    );

    const caseB = await createAcceptedFixture(baseUrl, host, guest, "case-b", () => {
      repositories.chat.ensureSystemMessage = async () => {
        throw new Error("injected system message failure");
      };
      return () => {
        repositories.chat.ensureSystemMessage = originalEnsureSystemMessage;
      };
    });
    const roomB = activeRooms(caseB.post.payload?.id)[0];
    record(
      "CASE B room survives system message failure",
      caseB.accepted.status === 500 && Boolean(roomB) && openedMessages(roomB?.id).length === 0,
      `status=${caseB.accepted.status}`
    );
    const repairedB = await retryAccept(baseUrl, caseB, host);
    record(
      "CASE B retry repairs system message",
      repairedB.status === 200 && openedMessages(roomB.id).length === 1,
      `status=${repairedB.status}`
    );

    roomB.participantIds = roomB.participantIds.filter((id) => id !== guest.id);
    db.chatRooms.set(roomB.id, roomB);
    const repairedMember = await retryAccept(baseUrl, caseB, host);
    record(
      "missing participant is repaired",
      repairedMember.status === 200 &&
        activeRooms(caseB.post.payload?.id)[0].participantIds.includes(guest.id)
    );

    const repeatOne = await retryAccept(baseUrl, caseB, host);
    const repeatTwo = await retryAccept(baseUrl, caseB, host);
    const repairedRoomB = activeRooms(caseB.post.payload?.id)[0];
    record(
      "CASE C repeated recovery is idempotent",
      repeatOne.status === 200 &&
        repeatTwo.status === 200 &&
        activeRooms(caseB.post.payload?.id).length === 1 &&
        new Set(repairedRoomB.participantIds).size === repairedRoomB.participantIds.length &&
        openedMessages(repairedRoomB.id).length === 1
    );

    const concurrent = await Promise.all([
      retryAccept(baseUrl, caseB, host),
      retryAccept(baseUrl, caseB, host)
    ]);
    record(
      "CASE D concurrent recovery keeps one room",
      concurrent.every((result) => result.status === 200) &&
        activeRooms(caseB.post.payload?.id).length === 1 &&
        openedMessages(repairedRoomB.id).length === 1,
      `statuses=${concurrent.map((result) => result.status).join(",")}`
    );

    const caseE = await createAcceptedFixture(baseUrl, host, guest, "case-e");
    record(
      "CASE E normal accept regression",
      caseE.accepted.status === 200 &&
        caseE.accepted.payload?.request?.status === "accepted" &&
        Boolean(caseE.accepted.payload?.chatRoom?.id),
      `status=${caseE.accepted.status}`
    );
  } finally {
    repositories.chat.ensureRoom = originalEnsureRoom;
    repositories.chat.ensureSystemMessage = originalEnsureSystemMessage;
    await new Promise((resolve) => server.close(resolve));
  }

  for (const result of results) {
    console.log(
      `[MATCHING_CHAT_RECOVERY_MEMORY] ${result.pass ? "PASS" : "FAIL"} ${result.name}${
        result.details ? ` - ${result.details}` : ""
      }`
    );
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(
    `[MATCHING_CHAT_RECOVERY_MEMORY] FAIL ${
      error instanceof Error ? error.message : "unknown error"
    }`
  );
  process.exitCode = 1;
});
