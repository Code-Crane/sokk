import { StyleSheet, Text, View } from "react-native";
import { PendingEvaluationList } from "../components/PendingEvaluationList";
import { ScreenShell } from "../components/ScreenShell";
import { useAuth } from "../features/auth/auth.hooks";
import { usePendingEvaluations } from "../features/rating/rating.hooks";
import { getMannerGradeLabel } from "../features/rating/rating.calculator";

export function ProfileScreen() {
  const auth = useAuth();
  const evaluations = usePendingEvaluations();

  if (!auth.user) {
    return (
      <ScreenShell title="프로필" subtitle="로그인 후 먹킹 프로필을 볼 수 있습니다.">
        <Text style={styles.empty}>홈에서 먼저 로그인해 주세요.</Text>
      </ScreenShell>
    );
  }

  return (
    <ScreenShell title="프로필" subtitle="Phase 2에서 평가 UI와 등급 변동 내역이 확장됩니다.">
      <View style={styles.card}>
        <Text style={styles.nickname}>{auth.user.nickname}</Text>
        <Text style={styles.meta}>{auth.user.email}</Text>
        <Text style={styles.score}>{auth.user.mannerScore.toFixed(1)}도</Text>
        <Text style={styles.grade}>{getMannerGradeLabel(auth.user.mannerScore)}</Text>
        <Text style={styles.meta}>본인인증: {auth.user.verificationStatus}</Text>
        <Text style={styles.meta}>남은 상호평가: {auth.user.pendingEvaluationCount}</Text>
      </View>
      <PendingEvaluationList
        evaluations={evaluations.pendingEvaluations}
        isSubmitting={evaluations.isLoading}
        onSubmit={evaluations.submitRating}
      />
      {evaluations.error ? <Text style={styles.error}>{evaluations.error}</Text> : null}
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    gap: 8,
    padding: 16
  },
  nickname: {
    color: "#172026",
    fontSize: 22,
    fontWeight: "800"
  },
  meta: {
    color: "#5b6470",
    fontSize: 14
  },
  score: {
    color: "#1f7a5c",
    fontSize: 28,
    fontWeight: "900"
  },
  grade: {
    color: "#26323d",
    fontSize: 17,
    fontWeight: "800"
  },
  empty: {
    color: "#5b6470",
    fontSize: 15
  },
  error: {
    color: "#b42318",
    fontSize: 14
  }
});
