import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/features/auth/data/auth_repository.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_state.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

void main() {
  test('logout clears the authenticated app state', () async {
    final repository = _LogoutRepository();
    final controller = AuthController(repository);

    await controller.logout();

    expect(repository.didLogout, isTrue);
    expect(controller.state.status, MukkingAuthStatus.unauthenticated);
    expect(controller.state.user, isNull);
  });

  test('logout clears app state even when remote sign out fails', () async {
    final repository = _LogoutRepository(shouldFail: true);
    final controller = AuthController(repository);

    await controller.logout();

    expect(controller.state.status, MukkingAuthStatus.unauthenticated);
    expect(controller.state.user, isNull);
  });
}

class _LogoutRepository implements AuthRepository {
  _LogoutRepository({this.shouldFail = false});

  final bool shouldFail;
  bool didLogout = false;

  @override
  Future<void> logout() async {
    didLogout = true;
    if (shouldFail) throw Exception('remote sign out failed');
  }

  @override
  Future<MukkingAuthState> currentState() async {
    return MukkingAuthState.authenticated(
      user: AuthUser.fallback(
        id: 'logout-user',
        email: 'logout@example.com',
      ),
    );
  }

  @override
  Stream<MukkingAuthState> authStateChanges() => const Stream.empty();

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<Session?> currentSession() async => null;

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
    required String phoneNumber,
  }) async {}
}
