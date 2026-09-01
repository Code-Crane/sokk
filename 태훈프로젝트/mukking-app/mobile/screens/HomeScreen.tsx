import { StyleSheet, Text, View } from "react-native";
import { AuthPanel } from "../components/AuthPanel";
import { CreatePostForm } from "../components/CreatePostForm";
import { JoinRequestList } from "../components/JoinRequestList";
import { PostList } from "../components/PostList";
import { PrimaryButton } from "../components/PrimaryButton";
import { ScreenShell } from "../components/ScreenShell";
import { useAuth } from "../features/auth/auth.hooks";
import { useMatchingPosts } from "../features/matching/matching.hooks";
import { canDisplayUserAsMatchable } from "../features/rating/rating.calculator";

export function HomeScreen() {
  const auth = useAuth();
  const matching = useMatchingPosts();
  const canUseMatching = auth.user
    ? canDisplayUserAsMatchable(
        auth.user.verificationStatus,
        auth.user.pendingEvaluationCount,
        auth.user.mannerScore
      )
    : false;
  const disabledReason =
    auth.user?.verificationStatus !== "verified"
      ? "본인인증 완료 후 모집 글 등록과 참가 요청을 사용할 수 있습니다."
      : auth.user.pendingEvaluationCount > 0
        ? "완료한 만남의 상호평가를 먼저 제출해야 다음 매칭을 사용할 수 있습니다."
        : undefined;

  if (!auth.user) {
    return (
      <ScreenShell
        title="먹킹"
        subtitle="혼자 가기 어려운 동네 맛집, 오늘은 같이 갈 사람을 찾아요."
      >
        <AuthPanel
          error={auth.error}
          isSubmitting={auth.isLoading}
          onLogin={auth.login}
          onSignup={auth.signup}
        />
      </ScreenShell>
    );
  }

  return (
    <ScreenShell
      title="먹킹 홈"
      subtitle="모집 글을 올리고, 들어온 참가 요청을 수락하면 채팅방이 자동으로 열립니다."
    >
      <View style={styles.profileStrip}>
        <View>
          <Text style={styles.welcome}>{auth.user.nickname}님</Text>
          <Text style={styles.meta}>인증 상태: {auth.user.verificationStatus}</Text>
          <Text style={styles.meta}>남은 상호평가: {auth.user.pendingEvaluationCount}</Text>
        </View>
        <PrimaryButton onPress={auth.logout} variant="secondary">
          로그아웃
        </PrimaryButton>
      </View>

      <CreatePostForm
        disabled={!canUseMatching}
        disabledReason={disabledReason}
        isSubmitting={matching.isLoading}
        onSubmit={matching.createPost}
      />

      <JoinRequestList
        onRespond={(requestId, decision) =>
          matching.respondToRequest(requestId, { decision })
        }
        posts={matching.authoredPosts}
        requestsByPostId={matching.requestsByPostId}
      />

      {matching.error ? <Text style={styles.error}>{matching.error}</Text> : null}

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

const styles = StyleSheet.create({
  profileStrip: {
    alignItems: "center",
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: "row",
    justifyContent: "space-between",
    padding: 14
  },
  welcome: {
    color: "#172026",
    fontSize: 17,
    fontWeight: "800"
  },
  meta: {
    color: "#5b6470",
    fontSize: 13
  },
  error: {
    color: "#b42318",
    fontSize: 14
  }
});
