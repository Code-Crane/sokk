import { useAuthStore } from "../../store/auth.store";

export function useAuth() {
  const user = useAuthStore((state) => state.user);
  const isLoading = useAuthStore((state) => state.isLoading);
  const error = useAuthStore((state) => state.error);
  const signup = useAuthStore((state) => state.signup);
  const login = useAuthStore((state) => state.login);
  const logout = useAuthStore((state) => state.logout);
  const refreshMe = useAuthStore((state) => state.refreshMe);

  return {
    user,
    isAuthenticated: Boolean(user),
    isLoading,
    error,
    signup,
    login,
    logout,
    refreshMe
  };
}

