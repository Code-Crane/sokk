import { useEffect, useMemo } from "react";
import { useAuthStore } from "../../store/auth.store";
import { useMatchingStore } from "../../store/matching.store";

export function useMatchingPosts() {
  const user = useAuthStore((state) => state.user);
  const posts = useMatchingStore((state) => state.posts);
  const requestsByPostId = useMatchingStore((state) => state.requestsByPostId);
  const isLoading = useMatchingStore((state) => state.isLoading);
  const error = useMatchingStore((state) => state.error);
  const loadPosts = useMatchingStore((state) => state.loadPosts);
  const createPost = useMatchingStore((state) => state.createPost);
  const requestJoin = useMatchingStore((state) => state.requestJoin);
  const completePost = useMatchingStore((state) => state.completePost);
  const loadRequestsForPost = useMatchingStore((state) => state.loadRequestsForPost);
  const respondToRequest = useMatchingStore((state) => state.respondToRequest);

  useEffect(() => {
    void loadPosts();
  }, [loadPosts]);

  const authoredPosts = useMemo(
    () => posts.filter((post) => post.authorId === user?.id),
    [posts, user?.id]
  );

  useEffect(() => {
    authoredPosts.forEach((post) => {
      void loadRequestsForPost(post.id);
    });
  }, [authoredPosts, loadRequestsForPost]);

  return {
    posts,
    authoredPosts,
    requestsByPostId,
    viewerId: user?.id ?? null,
    isLoading,
    error,
    createPost,
    requestJoin,
    completePost,
    respondToRequest
  };
}
