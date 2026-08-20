import { StyleSheet, Text, View } from "react-native";
import type { MatchingPost } from "../../shared/types";
import { PrimaryButton } from "./PrimaryButton";

interface PostCardProps {
  canUseMatching: boolean;
  post: MatchingPost;
  viewerId: string | null;
  onCompleteMeeting?: (postId: string) => Promise<void>;
  onRequestJoin: (postId: string) => Promise<void>;
}

export function PostCard({
  canUseMatching,
  post,
  viewerId,
  onCompleteMeeting,
  onRequestJoin
}: PostCardProps) {
  const isAuthor = post.authorId === viewerId;
  const isParticipant = viewerId ? post.participantIds.includes(viewerId) : false;
  const isClosed = post.status !== "open";
  const alreadyJoined = viewerId ? post.participantIds.includes(viewerId) : false;
  const disabled = !viewerId || !canUseMatching || isAuthor || isClosed || alreadyJoined;
  const canComplete = post.status === "closed" && (isAuthor || isParticipant);

  return (
    <View style={styles.card}>
      <View style={styles.titleRow}>
        <Text style={styles.restaurant}>{post.restaurantName}</Text>
        <Text style={styles.status}>{post.status}</Text>
      </View>
      <Text style={styles.meta}>{post.address}</Text>
      <Text style={styles.meta}>{new Date(post.scheduledAt).toLocaleString()}</Text>
      <Text style={styles.body}>{post.intro}</Text>
      <Text style={styles.meta}>
        {post.participantIds.length}/{post.maxParticipants}명 참여 확정
      </Text>
      <PrimaryButton
        disabled={disabled}
        onPress={() => onRequestJoin(post.id)}
        variant={disabled ? "secondary" : "primary"}
      >
        {!canUseMatching
          ? "인증/평가 필요"
          : isAuthor
            ? "내 모집 글"
            : alreadyJoined
              ? "참여 확정"
              : "같이 가요"}
      </PrimaryButton>
      {canComplete && onCompleteMeeting ? (
        <PrimaryButton onPress={() => onCompleteMeeting(post.id)} variant="secondary">
          만남 완료
        </PrimaryButton>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    gap: 8,
    padding: 14
  },
  titleRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between"
  },
  restaurant: {
    color: "#172026",
    flex: 1,
    fontSize: 18,
    fontWeight: "800"
  },
  status: {
    color: "#1f7a5c",
    fontSize: 12,
    fontWeight: "700",
    textTransform: "uppercase"
  },
  meta: {
    color: "#5b6470",
    fontSize: 13
  },
  body: {
    color: "#26323d",
    fontSize: 15,
    lineHeight: 21
  }
});
