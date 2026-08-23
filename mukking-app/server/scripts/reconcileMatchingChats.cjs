const dotenv = require("dotenv");

dotenv.config();
process.env.REPOSITORY_PROVIDER = "supabase";

const apply = process.argv.includes("--apply");
const postIdArg = process.argv.find((argument) => argument.startsWith("--post-id="));
const postId = postIdArg?.slice("--post-id=".length);
const openedMessage = "매칭이 성사되어 채팅방이 열렸습니다.";

async function main() {
  const { repositories } = require("../dist/server/repositories");
  const {
    ensureChatForAcceptedPost
  } = require("../dist/server/services/chat/chat.service");
  const posts = postId
    ? [await repositories.matching.findPostById(postId)].filter(Boolean)
    : await repositories.matching.listPosts();
  const candidates = posts.filter((post) => post.participantIds.length > 0);
  let inconsistent = 0;
  let repaired = 0;

  for (const post of candidates) {
    const room = await repositories.chat.findActiveRoomByPostId(post.id);
    const expectedParticipantIds = Array.from(
      new Set([post.authorId, ...post.participantIds])
    );
    const missingParticipantIds = room
      ? expectedParticipantIds.filter((id) => !room.participantIds.includes(id))
      : expectedParticipantIds;
    const systemMessageMissing = room
      ? !(await repositories.chat.hasSystemMessage(room.id, openedMessage))
      : true;

    if (room && missingParticipantIds.length === 0 && !systemMessageMissing) continue;
    inconsistent += 1;
    console.log(
      JSON.stringify({
        postId: post.id,
        roomId: room?.id ?? null,
        roomMissing: !room,
        missingParticipantCount: missingParticipantIds.length,
        systemMessageMissing,
        action: apply ? "repair" : "dry-run"
      })
    );

    if (apply) {
      await ensureChatForAcceptedPost(post);
      repaired += 1;
    }
  }

  console.log(
    JSON.stringify({
      mode: apply ? "apply" : "dry-run",
      scanned: candidates.length,
      inconsistent,
      repaired
    })
  );
}

main().catch((error) => {
  console.error(
    `[MATCHING_CHAT_RECONCILE] FAIL ${
      error instanceof Error ? error.message : "unknown error"
    }`
  );
  process.exitCode = 1;
});
