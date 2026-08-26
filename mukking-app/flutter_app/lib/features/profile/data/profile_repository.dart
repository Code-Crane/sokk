import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/profile_summary.dart';
import 'profile_api.dart';

abstract class ProfileRepository {
  Future<ProfileSummary> currentProfile();
  Future<VerificationSnapshot> completeMockVerification();
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.usesApiData) {
    return ApiProfileRepository(ref.watch(profileApiProvider));
  }

  return const MockProfileRepository();
});

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository();

  @override
  Future<ProfileSummary> currentProfile() async {
    return ProfileSummary(
      user: AuthUser(
        id: 'mock-user',
        nickname: '먹킹러 태훈',
        email: 'mock@mukking.local',
        verificationStatus: VerificationStatus.pending,
        mannerScore: 4.8,
        mannerGrade: MannerGrade.foodie,
        pendingEvaluationCount: 0,
        createdAt: DateTime(2026, 8, 20),
      ),
      verification: const VerificationSnapshot(
        status: VerificationStatus.pending,
        label: '인증중',
        canUseMatching: false,
        canUseChat: false,
      ),
      pendingEvaluationCount: 0,
    );
  }

  @override
  Future<VerificationSnapshot> completeMockVerification() async {
    return const VerificationSnapshot(
      status: VerificationStatus.verified,
      label: '인증완료',
      canUseMatching: true,
      canUseChat: true,
    );
  }
}

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);

  final ProfileApi _api;

  @override
  Future<ProfileSummary> currentProfile() async {
    final user = await _api.me();
    final verification = await _api.verificationStatus();
    final pendingCount = await _api.pendingEvaluationCount();

    return ProfileSummary(
      user: user,
      verification: verification,
      pendingEvaluationCount: pendingCount,
    );
  }

  @override
  Future<VerificationSnapshot> completeMockVerification() {
    return _api.completeMockVerification();
  }
}
