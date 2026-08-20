import { StyleSheet, Text, View } from "react-native";
import { PostCard } from "../components/PostCard";
import { ScreenShell } from "../components/ScreenShell";
import { useAuth } from "../features/auth/auth.hooks";
import { useMatchingPosts } from "../features/matching/matching.hooks";
import { canDisplayUserAsMatchable } from "../features/rating/rating.calculator";

export function PostDetailScreen() {
  const auth = useAuth();
  const matching = useMatchingPosts();
  const post = matching.posts[0];
  const canUseMatching = auth.user
    ? canDisplayUserAsMatchable(
        auth.user.verificationStatus,
        auth.user.pendingEvaluationCount,
        auth.user.mannerScore
      )
    : false;

  return (
    <ScreenShell
      title="모집 상세"
      subtitle="목록에서 선택한 글을 보여주는 상세 화면 자리입니다."
    >
      {post ? (
        <PostCard
          canUseMatching={canUseMatching}
          onCompleteMeeting={matching.completePost}
          onRequestJoin={matching.requestJoin}
          post={post}
          viewerId={matching.viewerId}
        />
      ) : (
        <View style={styles.emptyBox}>
          <Text style={styles.empty}>아직 상세로 볼 모집 글이 없습니다.</Text>
        </View>
      )}
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  emptyBox: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    padding: 16
  },
  empty: {
    color: "#5b6470",
    fontSize: 15
  }
});
