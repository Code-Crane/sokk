import { StyleSheet, Text, View } from "react-native";
import type { JoinRequest, MatchingPost } from "../../shared/types";
import { PrimaryButton } from "./PrimaryButton";

interface JoinRequestListProps {
  posts: MatchingPost[];
  requestsByPostId: Record<string, JoinRequest[]>;
  onRespond: (requestId: string, decision: "accepted" | "rejected") => Promise<void>;
}

export function JoinRequestList({
  posts,
  requestsByPostId,
  onRespond
}: JoinRequestListProps) {
  const pendingRequests = posts.flatMap((post) =>
    (requestsByPostId[post.id] ?? [])
      .filter((request) => request.status === "pending")
      .map((request) => ({ post, request }))
  );

  if (pendingRequests.length === 0) {
    return null;
  }

  return (
    <View style={styles.panel}>
      <Text style={styles.heading}>참가 요청</Text>
      {pendingRequests.map(({ post, request }) => (
        <View key={request.id} style={styles.item}>
          <Text style={styles.body}>{post.restaurantName} 참가 요청</Text>
          <Text style={styles.meta}>요청자: {request.requesterId}</Text>
          <View style={styles.actions}>
            <PrimaryButton onPress={() => onRespond(request.id, "accepted")}>
              수락
            </PrimaryButton>
            <PrimaryButton
              onPress={() => onRespond(request.id, "rejected")}
              variant="danger"
            >
              거절
            </PrimaryButton>
          </View>
        </View>
      ))}
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
    fontSize: 13
  },
  actions: {
    flexDirection: "row",
    gap: 8
  }
});

