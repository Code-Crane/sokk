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

    const send = (user) => api(baseUrl, `/api/chat/rooms/${roomId}/messages`, user.token, {
      method: "POST", body: JSON.stringify({ text: "[TEST] moderation" })
    });
    record("blocker also cannot send", (await send(host)).status === 403);
    const retained = await api(baseUrl, `/api/chat/rooms/${roomId}/messages`, guestA.token);
    record("blocked participant retains history", retained.status === 200 && retained.payload.length === messages.payload.length);
    const reportInput = {
      reportedUserId: host.id, targetType: "chat_message", targetId: firstMessage.payload.id,
      chatRoomId: roomId, messageId: firstMessage.payload.id, reason: "spam"
    };
    const report = await api(baseUrl, "/api/reports", guestA.token, {
      method: "POST", body: JSON.stringify(reportInput)
    });
    record("message report remains available while blocked", report.status === 201);
    record("unrelated room participant can send", (await send(guestB)).status === 201);
    await api(baseUrl, `/api/blocks/${guestA.id}`, host.token, { method: "DELETE" });
    record("unblock restores both directions", (await send(host)).status === 201 && (await send(guestA)).status === 201);
    await api(baseUrl, "/api/blocks", guestA.token, {
      method: "POST", body: JSON.stringify({ blockedId: host.id, scope: "chat" })
    });
    record("reverse block prevents both send directions", (await send(host)).status === 403 && (await send(guestA)).status === 403);
    await api(baseUrl, `/api/blocks/${host.id}`, guestA.token, { method: "DELETE" });

    // Audit scoped policy without changing production rules or real accounts.
    const pendingPost = await api(baseUrl, "/api/matching/posts", host.token, {
      method: "POST", body: JSON.stringify({ restaurantName: "[TEST] policy", address: "[TEST]",
        scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 4, intro: "[TEST] policy audit" })
    });
    const pendingRequest = await api(baseUrl, `/api/matching/posts/${pendingPost.payload.id}/requests`, outsider.token, { method: "POST" });
    for (const scope of ["all", "matching", "chat"]) {
    for (const [blocker, blocked] of [[host, outsider], [outsider, host]]) {
      await api(baseUrl, "/api/blocks", blocker.token, {
        method: "POST", body: JSON.stringify({ blockedId: blocked.id, scope })
      });
      const join = await api(baseUrl, `/api/matching/posts/${pendingPost.payload.id}/requests`, outsider.token, { method: "POST" });
      const approval = await api(baseUrl, `/api/matching/requests/${pendingRequest.payload.id}/respond`, host.token, {
        method: "POST", body: JSON.stringify({ decision: "accepted" })
      });
      record(`${scope} join and pending approval policy in either direction`, join.status === (scope === "chat" ? 409 : 403) && approval.status === 403);
      await api(baseUrl, `/api/blocks/${blocked.id}`, blocker.token, { method: "DELETE" });
    }
    }
    const approvedAfterUnblock = await api(baseUrl, `/api/matching/requests/${pendingRequest.payload.id}/respond`, host.token, {
      method: "POST", body: JSON.stringify({ decision: "accepted" })
    });
    record("pending approval recovers after unblock", approvedAfterUnblock.status === 200);
    await api(baseUrl, "/api/blocks", host.token, {
      method: "POST", body: JSON.stringify({ blockedId: outsider.id, scope: "all" })
    });
    const recovery = await api(baseUrl, `/api/matching/requests/${pendingRequest.payload.id}/respond`, host.token, {
      method: "POST", body: JSON.stringify({ decision: "accepted" })
    });
    const acceptedRoomId = approvedAfterUnblock.payload.chatRoom.id;
    const history = await api(baseUrl, `/api/chat/rooms/${acceptedRoomId}/messages`, outsider.token);
    const allBlockedSend = await api(baseUrl, `/api/chat/rooms/${acceptedRoomId}/messages`, outsider.token, {
      method: "POST", body: JSON.stringify({ text: "[TEST] all blocked" })
    });
    record("all block preserves accepted recovery and history but rejects send",
      recovery.status === 200 && recovery.payload.chatRoom.id === acceptedRoomId && history.status === 200 && allBlockedSend.status === 403);
    const blockedReport = await api(baseUrl, "/api/reports", outsider.token, {
      method: "POST", body: JSON.stringify({ reportedUserId: host.id, targetType: "chat_room", targetId: acceptedRoomId, chatRoomId: acceptedRoomId, reason: "spam" })
    });
    record("all block preserves report access", blockedReport.status === 201);
    await api(baseUrl, `/api/blocks/${outsider.id}`, host.token, { method: "DELETE" });
    const allRestored = await api(baseUrl, `/api/chat/rooms/${acceptedRoomId}/messages`, outsider.token, {
      method: "POST", body: JSON.stringify({ text: "[TEST] unblocked" })
    });
    record("all unblock restores send", allRestored.status === 201);
    for (const type of ["temporary_suspension", "permanent_ban"]) {
      const restriction = await repositories.sanctions.createSanction("memory-admin", {
        userId: outsider.id, type, reason: "[TEST] moderation regression"
      });
      const create = await api(baseUrl, "/api/matching/posts", outsider.token, {
        method: "POST", body: JSON.stringify({ restaurantName: "[TEST]", address: "[TEST]",
          scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 4, intro: "[TEST]" })
      });
      const join = await api(baseUrl, `/api/matching/posts/${pendingPost.payload.id}/requests`, outsider.token, { method: "POST" });
      const chat = await api(baseUrl, `/api/chat/rooms/${approvedAfterUnblock.payload.chatRoom.id}/messages`, outsider.token, {
        method: "POST", body: JSON.stringify({ text: "[TEST] restricted" })
      });
      record(`${type} blocks create/join/send`, create.status === 403 && join.status === 403 && chat.status === 403);
      await repositories.sanctions.revokeSanction("memory-admin", restriction.id);
    }

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
