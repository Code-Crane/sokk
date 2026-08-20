import { create } from "zustand";
import type { AuthSession, LoginInput, PublicUserProfile, SignupInput } from "../../shared/types";
import { setAuthToken } from "../services/api.client";
import { getMe, login as loginRequest, signup as signupRequest } from "../features/auth/auth.service";

interface AuthState {
  session: AuthSession | null;
  user: PublicUserProfile | null;
  isLoading: boolean;
  error: string | null;
  signup: (input: SignupInput) => Promise<void>;
  login: (input: LoginInput) => Promise<void>;
  refreshMe: () => Promise<void>;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  session: null,
  user: null,
  isLoading: false,
  error: null,
  signup: async (input) => {
    set({ isLoading: true, error: null });

    try {
      const session = await signupRequest(input);
      setAuthToken(session.token);
      set({ session, user: session.user, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Signup failed.",
        isLoading: false
      });
    }
  },
  login: async (input) => {
    set({ isLoading: true, error: null });

    try {
      const session = await loginRequest(input);
      setAuthToken(session.token);
      set({ session, user: session.user, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : "Login failed.",
        isLoading: false
      });
    }
  },
  refreshMe: async () => {
    const token = get().session?.token;

    if (!token) {
      return;
    }

    setAuthToken(token);
    const user = await getMe();
    set((state) => ({
      user,
      session: state.session ? { ...state.session, user } : state.session
    }));
  },
  logout: () => {
    setAuthToken(null);
    set({ session: null, user: null, error: null });
  }
}));

