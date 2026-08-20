import { Text } from "react-native";
import { PostList } from "../components/PostList";
import { ScreenShell } from "../components/ScreenShell";
import { useAuth } from "../features/auth/auth.hooks";
import { useMatchingPosts } from "../features/matching/matching.hooks";
import { canDisplayUserAsMatchable } from "../features/rating/rating.calculator";

export function MapScreen() {
  const auth = useAuth();
  const matching = useMatchingPosts();
  const canUseMatching = auth.user
    ? canDisplayUserAsMatchable(
        auth.user.verificationStatus,
        auth.user.pendingEvaluationCount,
        auth.user.mannerScore
      )
    : false;

  return (
    <ScreenShell
      title="동네 맛집"
      subtitle="Phase 1에서는 지도 대신 리스트로 가까운 모집 글을 확인합니다."
    >
      {matching.error ? <Text>{matching.error}</Text> : null}
      <PostList
        canUseMatching={canUseMatching}
        onCompleteMeeting={matching.completePost}
        onRequestJoin={matching.requestJoin}
        posts={matching.posts}
        viewerId={matching.viewerId}
      />
    </ScreenShell>
  );
}
