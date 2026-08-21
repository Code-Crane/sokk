import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/network/api_error.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, MukkingAuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final controller = AuthController(repository);
  controller.bootstrap();

  final subscription = repository.authStateChanges().listen(controller.set);
  ref.onDispose(subscription.cancel);

  return controller;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

final currentSessionProvider = FutureProvider<Session?>((ref) {
  return ref.watch(authRepositoryProvider).currentSession();
});

class AuthController extends StateNotifier<MukkingAuthState> {
  AuthController(this._repository) : super(const MukkingAuthState.loading());

  final AuthRepository _repository;

  Future<void> bootstrap() async {
    state = await _repository.currentState();
  }

  void set(MukkingAuthState nextState) {
    state = nextState;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const MukkingAuthState.loading();
    try {
      await _repository.login(email: email, password: password);
      state = await _repository.currentState();
    } on ApiError catch (error) {
      state = MukkingAuthState.error(error.userMessage);
    } catch (_) {
      state = const MukkingAuthState.error('로그인에 실패했어요.');
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
    required String phoneNumber,
  }) async {
    state = const MukkingAuthState.loading();
    try {
      await _repository.signup(
        email: email,
        password: password,
        nickname: nickname,
        phoneNumber: phoneNumber,
      );
      state = await _repository.currentState();
    } on ApiError catch (error) {
      state = MukkingAuthState.error(error.userMessage);
    } catch (_) {
      state = const MukkingAuthState.error('회원가입에 실패했어요.');
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const MukkingAuthState.unauthenticated();
  }
}
