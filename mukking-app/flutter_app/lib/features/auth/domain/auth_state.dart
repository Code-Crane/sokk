import 'auth_user.dart';

enum MukkingAuthStatus {
  loading,
  authenticated,
  unauthenticated,
  error,
}

class MukkingAuthState {
  const MukkingAuthState({
    required this.status,
    this.user,
    this.message,
  });

  const MukkingAuthState.loading()
      : status = MukkingAuthStatus.loading,
        user = null,
        message = null;

  const MukkingAuthState.authenticated({
    required AuthUser this.user,
    this.message,
  }) : status = MukkingAuthStatus.authenticated;

  const MukkingAuthState.unauthenticated({this.message})
      : status = MukkingAuthStatus.unauthenticated,
        user = null;

  const MukkingAuthState.error(this.message)
      : status = MukkingAuthStatus.error,
        user = null;

  final MukkingAuthStatus status;
  final AuthUser? user;
  final String? message;

  bool get isAuthenticated => status == MukkingAuthStatus.authenticated;
  bool get isLoading => status == MukkingAuthStatus.loading;
}
