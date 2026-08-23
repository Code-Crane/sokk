process.env.AUTH_PROVIDER = "signed_mock";
process.env.REPOSITORY_PROVIDER = "memory";
process.env.RATE_LIMIT_MATCHING_REQUEST_MAX = "100";

const { app } = require("../dist/server/app");
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
      email: `chat-memory-${label}-${Date.now()}@example.com`,
      nickname: `${label}-chat`,
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
  record(`${label} setup`, signup.status === 201 && verification.status === 200, `signup=${signup.status}, verify=${verification.status}`);
  return { id: signup.payload?.user?.id, token };
}

async function joinAndAccept(baseUrl, postId, host, guest) {
  const join = await api(baseUrl, `/api/matching/posts/${postId}/requests`, guest.token, { method: "POST" });
  const accepted = await api(baseUrl, `/api/matching/requests/${join.payload?.id}/respond`, host.token, {
    method: "POST",
    body: JSON.stringify({ decision: "accepted" })
  });
  return { join, accepted };
}

async function main() {
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve, reject) => {
    server.once("listening", resolve);
    server.once("error", reject);
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const host = await createUser(baseUrl, "host");
    const guestA = await createUser(baseUrl, "guest-a");
    const guestB = await createUser(baseUrl, "guest-b");
    const outsider = await createUser(baseUrl, "outsider");

    const post = await api(baseUrl, "/api/matching/posts", host.token, {
      method: "POST",
      body: JSON.stringify({
        restaurantName: "채팅 메모리 식당",
        address: "서울시 테스트구 채팅로 1",
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        maxParticipants: 2,
        intro: "채팅 영속화 회귀 테스트"
      })
    });
    const first = await joinAndAccept(baseUrl, post.payload?.id, host, guestA);
    const second = await joinAndAccept(baseUrl, post.payload?.id, host, guestB);
    const roomId = first.accepted.payload?.chatRoom?.id;
    record("first accept creates room", first.accepted.status === 200 && Boolean(roomId), `status=${first.accepted.status}`);
    record(
      "second accept reuses room",
      second.accepted.status === 200 && second.accepted.payload?.chatRoom?.id === roomId && second.accepted.payload?.chatRoom?.participantIds?.length === 3,
      `status=${second.accepted.status}`
    );

    const hostRooms = await api(baseUrl, "/api/chat/rooms", host.token);
    record("participant room list", hostRooms.status === 200 && hostRooms.payload?.length === 1, `status=${hostRooms.status}`);

    const firstMessage = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, host.token, {
      method: "POST",
      body: JSON.stringify({ text: "첫 번째", senderId: outsider.id })
    });
    const secondMessage = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "두 번째" })
    });
    record(
      "sender uses JWT",
      firstMessage.status === 201 && firstMessage.payload?.senderId === host.id,
      `status=${firstMessage.status}`
    );
    record("participant sends message", secondMessage.status === 201, `status=${secondMessage.status}`);

    const messages = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestB.token);
    record(
      "messages ordered",
      messages.status === 200 && messages.payload?.map((message) => message.text).join("|") === "매칭이 성사되어 채팅방이 열렸습니다.|첫 번째|두 번째",
      `status=${messages.status}`
    );

    const outsiderRead = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, outsider.token);
    const outsiderSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, outsider.token, {
      method: "POST",
      body: JSON.stringify({ text: "침입 메시지" })
    });
    record("outsider read rejected", outsiderRead.status === 403, `status=${outsiderRead.status}`);
    record("outsider send rejected", outsiderSend.status === 403, `status=${outsiderSend.status}`);

    const block = await api(baseUrl, "/api/blocks", host.token, {
      method: "POST",
      body: JSON.stringify({ blockedId: guestA.id, scope: "chat" })
    });
    const blockedSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token, {
      method: "POST",
      body: JSON.stringify({ text: "차단 후 메시지" })
    });
    record("chat block enforcement", block.status === 201 && blockedSend.status === 403, `status=${blockedSend.status}`);

    const sanction = await repositories.sanctions.createSanction("memory-admin", {
      userId: guestB.id,
      type: "chat_suspension",
      reason: "chat memory smoke"
    });
    const suspendedSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestB.token, {
      method: "POST",
      body: JSON.stringify({ text: "정지 후 메시지" })
    });
    await repositories.sanctions.revokeSanction("memory-admin", sanction.id);
    const restoredSend = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestB.token, {
      method: "POST",
      body: JSON.stringify({ text: "정지 해제 후 메시지" })
    });
    record(
      "chat sanction enforcement and restore",
      suspendedSend.status === 403 && restoredSend.status === 201,
      `suspended=${suspendedSend.status}, restored=${restoredSend.status}`
    );

    const completed = await api(baseUrl, `/api/matching/posts/${post.payload?.id}/complete`, host.token, { method: "POST" });
    const pending = await api(baseUrl, "/api/rating/pending", host.token);
    record("completion rating compatibility", completed.status === 200 && pending.status === 200 && pending.payload?.length > 0, `complete=${completed.status}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  for (const result of results) {
    console.log(`[CHAT_MEMORY] ${result.pass ? "PASS" : "FAIL"} ${result.name} - ${result.details}`);
  }
  if (results.some((result) => !result.pass)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[CHAT_MEMORY] FAIL ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
