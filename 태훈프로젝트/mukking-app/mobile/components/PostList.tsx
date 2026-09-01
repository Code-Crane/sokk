import { StyleSheet, Text, View } from "react-native";
import type { MatchingPost } from "../../shared/types";
import { PostCard } from "./PostCard";

interface PostListProps {
  canUseMatching: boolean;
  posts: MatchingPost[];
  viewerId: string | null;
  onCompleteMeeting?: (postId: string) => Promise<void>;
  onRequestJoin: (postId: string) => Promise<void>;
}

export function PostList({
  canUseMatching,
  posts,
  viewerId,
  onCompleteMeeting,
  onRequestJoin
}: PostListProps) {
  if (posts.length === 0) {
    return <Text style={styles.empty}>아직 올라온 맛집 동행 모집이 없습니다.</Text>;
  }

  return (
    <View style={styles.list}>
      {posts.map((post) => (
        <PostCard
          canUseMatching={canUseMatching}
          key={post.id}
          onCompleteMeeting={onCompleteMeeting}
          onRequestJoin={onRequestJoin}
          post={post}
          viewerId={viewerId}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  list: {
    gap: 12
  },
  empty: {
    color: "#5b6470",
    fontSize: 15
  }
});
