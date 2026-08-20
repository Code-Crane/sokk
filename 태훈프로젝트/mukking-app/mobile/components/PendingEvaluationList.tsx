import { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import type { PendingEvaluation, SubmitMannerRatingInput } from "../../shared/types";
import { PrimaryButton } from "./PrimaryButton";

interface PendingEvaluationListProps {
  evaluations: PendingEvaluation[];
  isSubmitting: boolean;
  onSubmit: (input: SubmitMannerRatingInput) => Promise<void>;
}

export function PendingEvaluationList({
  evaluations,
  isSubmitting,
  onSubmit
}: PendingEvaluationListProps) {
  const [scoreById, setScoreById] = useState<Record<string, string>>({});
  const [tagsById, setTagsById] = useState<Record<string, string>>({});

  if (evaluations.length === 0) {
    return (
      <View style={styles.panel}>
        <Text style={styles.heading}>상호평가</Text>
        <Text style={styles.meta}>아직 제출할 평가가 없습니다.</Text>
      </View>
    );
  }

  return (
    <View style={styles.panel}>
      <Text style={styles.heading}>상호평가 필요</Text>
      <Text style={styles.meta}>
        남은 평가를 완료해야 다음 맛집 동행 모집과 참가 요청을 할 수 있습니다.
      </Text>
      {evaluations.map((evaluation) => {
        const scoreText = scoreById[evaluation.id] ?? "5";
        const tagsText = tagsById[evaluation.id] ?? "on_time,kind";

        return (
          <View key={evaluation.id} style={styles.item}>
            <Text style={styles.body}>상대: {evaluation.revieweeId}</Text>
            <Text style={styles.meta}>매칭: {evaluation.matchId}</Text>
            <TextInput
              keyboardType="number-pad"
              onChangeText={(value) =>
                setScoreById((current) => ({ ...current, [evaluation.id]: value }))
              }
              placeholder="별점 1-5"
              style={styles.input}
              value={scoreText}
            />
            <TextInput
              onChangeText={(value) =>
                setTagsById((current) => ({ ...current, [evaluation.id]: value }))
              }
              placeholder="태그: on_time,kind,no_show"
              style={styles.input}
              value={tagsText}
            />
            <PrimaryButton
              disabled={isSubmitting}
              onPress={() =>
                onSubmit({
                  matchId: evaluation.matchId,
                  revieweeId: evaluation.revieweeId,
                  score: Math.min(5, Math.max(1, Number(scoreText))) as 1 | 2 | 3 | 4 | 5,
                  tags: tagsText
                    .split(",")
                    .map((tag) => tag.trim())
                    .filter(Boolean)
                })
              }
            >
              평가 제출
            </PrimaryButton>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 16
  },
  heading: {
    color: "#172026",
    fontSize: 18,
    fontWeight: "800"
  },
  item: {
    borderTopColor: "#e2e8f0",
    borderTopWidth: 1,
    gap: 8,
    paddingTop: 12
  },
  body: {
    color: "#26323d",
    fontSize: 15,
    fontWeight: "700"
  },
  meta: {
    color: "#5b6470",
    fontSize: 13,
    lineHeight: 19
  },
  input: {
    backgroundColor: "#f8fafc",
    borderColor: "#cbd5e1",
    borderRadius: 8,
    borderWidth: 1,
    fontSize: 15,
    paddingHorizontal: 12,
    paddingVertical: 10
  }
});

