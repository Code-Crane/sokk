import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import 'auth_api.dart';

abstract class AuthRepository {
  Future<MukkingAuthState> currentState();
  Stream<MukkingAuthState> authStateChanges();
  Future<AuthUser?> currentUser();
  Future<Session?> currentSession();
  Future<String?> accessToken();
  Future<void> login({
    required String email,
    required String password,
  });
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
    required String phoneNumber,
  });
  Future<void> logout();
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    supabase: ref.watch(supabaseClientProvider),
    authApi: ref.watch(authApiProvider),
  );
});

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository({
    required SupabaseClient? supabase,
    required AuthApi authApi,
  })  : _supabase = supabase,
        _authApi = authApi;

  final SupabaseClient? _supabase;
  final AuthApi _authApi;

  @override
  Future<String?> accessToken() async {
    return _supabase?.auth.currentSession?.accessToken;
  }

  @override
  Future<Session?> currentSession() async {
    return _supabase?.auth.currentSession;
  }

  @override
  Future<AuthUser?> currentUser() async {
    final session = await currentSession();
    if (session == null) {
      return null;
    }

    try {
      return await _authApi.me();
    } on ApiError {
      return _fallbackUserFromSession(session);
    }
  }

  @override
  Future<MukkingAuthState> currentState() async {
    final session = await currentSession();

    if (_supabase == null) {
      return const MukkingAuthState.unauthenticated(
        message: 'Supabase 설정이 없어 mock/비로그인 상태로 실행 중입니다.',
      );
    }

    if (session == null) {
      return const MukkingAuthState.unauthenticated();
    }

    try {
      return MukkingAuthState.authenticated(user: await _authApi.me());
    } on ApiError catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        return const MukkingAuthState.unauthenticated(
          message: '백엔드가 현재 Supabase 세션을 인증하지 못했어요.',
        );
      }
      return MukkingAuthState.authenticated(
        user: _fallbackUserFromSession(session),
        message: error.userMessage,
      );
    }
  }

  @override
  Stream<MukkingAuthState> authStateChanges() {
    final supabase = _supabase;
    if (supabase == null) {
      return const Stream.empty();
    }

    return supabase.auth.onAuthStateChange.asyncMap((authState) async {
      final session = authState.session;
      if (session == null) {
        return const MukkingAuthState.unauthenticated();
      }

      try {
        return MukkingAuthState.authenticated(user: await _authApi.me());
      } on ApiError catch (error) {
        if (error.kind == ApiErrorKind.unauthorized) {
          return const MukkingAuthState.unauthenticated(
            message: '백엔드가 현재 Supabase 세션을 인증하지 못했어요.',
          );
        }
        return MukkingAuthState.authenticated(
          user: _fallbackUserFromSession(session),
          message: error.userMessage,
        );
      }
    });
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final supabase = _requireSupabase();
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
    required String phoneNumber,
  }) async {
    final supabase = _requireSupabase();
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'nickname': nickname,
        'phone_number': phoneNumber,
      },
    );
  }

  @override
  Future<void> logout() async {
    await _supabase?.auth.signOut();
  }

  SupabaseClient _requireSupabase() {
    final supabase = _supabase;
    if (supabase == null) {
      throw const ApiError(
        kind: ApiErrorKind.unauthorized,
        userMessage: 'Supabase URL과 anon key 설정이 필요해요.',
      );
    }

    return supabase;
  }

  AuthUser _fallbackUserFromSession(Session session) {
    final user = session.user;
    final nickname = user.userMetadata?['nickname'] as String?;

    return AuthUser.fallback(
      id: user.id,
      email: user.email ?? '',
      nickname: nickname,
    );
  }
}
