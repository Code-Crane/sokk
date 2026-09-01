import { create } from "zustand";
import type {
  CreateMatchingPostInput,
  JoinRequest,
  MatchingPost,
  RespondJoinRequestInput
} from "../../shared/types";
import {
  createMatchingPost,
  completeMatchingPost,
  listJoinRequestsForPost,
  listMatchingPosts,
  requestJoin,
  respondToJoinRequest
} from "../features/matching/matching.service";

interface MatchingState {
  posts: MatchingPost[];
  requestsByPostId: Record<string, JoinRequest[]>;
  isLoading: boolean;
  error: string | null;
  loadPosts: () => Promise<void>;
  createPost: (input: CreateMatchingPostInput) => Promise<void>;
  requestJoin: (postId: string) => Promise<void>;
  completePost: (postId: string) => Promise<void>;
  loadRequestsForPost: (postId: string) => Promise<void>;
  respondToRequest: (
    requestId: string,
    input: RespondJoinRequestInput
  ) => Promise<void>;
}

export const useMatchingStore = create<MatchingState>((set, get) => ({
  posts: [],
  requestsByPostId: {},
  isLoading: false,
  error: null,
  loadPosts: async () => {
    set({ isLoading: true, error: null });

    try {
      const posts = await listMatchingPosts();
      set({ posts, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to load posts.",
        isLoading: false
      });
    }
  },
  createPost: async (input) => {
    set({ isLoading: true, error: null });

    try {
      const post = await createMatchingPost(input);
      set((state) => ({ posts: [post, ...state.posts], isLoading: false }));
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to create post.",
        isLoading: false
      });
    }
  },
  requestJoin: async (postId) => {
    set({ isLoading: true, error: null });

    try {
      await requestJoin(postId);
      set({ isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to request join.",
        isLoading: false
      });
    }
  },
  completePost: async (postId) => {
    set({ isLoading: true, error: null });

    try {
      const post = await completeMatchingPost(postId);
      set((state) => ({
        posts: state.posts.map((currentPost) =>
          currentPost.id === post.id ? post : currentPost
        ),
        isLoading: false
      }));
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to complete meeting.",
        isLoading: false
      });
    }
  },
  loadRequestsForPost: async (postId) => {
    try {
      const requests = await listJoinRequestsForPost(postId);
      set((state) => ({
        requestsByPostId: {
          ...state.requestsByPostId,
          [postId]: requests
        }
      }));
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to load join requests."
      });
    }
  },
  respondToRequest: async (requestId, input) => {
    set({ isLoading: true, error: null });

    try {
      const result = await respondToJoinRequest(requestId, input);
      const postId = result.request.postId;
      const requests = get().requestsByPostId[postId] ?? [];

      set((state) => ({
        requestsByPostId: {
          ...state.requestsByPostId,
          [postId]: requests.map((request) =>
            request.id === requestId ? result.request : request
          )
        },
        isLoading: false
      }));

      await get().loadPosts();
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Failed to respond to request.",
        isLoading: false
      });
    }
  }
}));
