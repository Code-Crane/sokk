import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/providers/chat_provider.dart';
import '../data/profile_repository.dart';
import 'profile_provider.dart';

final verificationActionProvider =
    StateNotifierProvider<VerificationActionController, AsyncValue<void>>(
  (ref) => VerificationActionController(
    ref.watch(profileRepositoryProvider),
    onVerified: () {
      ref.invalidate(profileSummaryProvider);
      ref.invalidate(chatRoomsProvider);
    },
  ),
);

class VerificationActionController extends StateNotifier<AsyncValue<void>> {
  VerificationActionController(
    this._repository, {
    required void Function() onVerified,
  })  : _onVerified = onVerified,
        super(const AsyncValue.data(null));

  final ProfileRepository _repository;
  final void Function() _onVerified;

  Future<bool> completeDevelopmentVerification() async {
    state = const AsyncValue.loading();
    try {
      await _repository.completeMockVerification();
      _onVerified();
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}
