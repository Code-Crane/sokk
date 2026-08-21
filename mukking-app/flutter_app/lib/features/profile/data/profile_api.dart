import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/profile_summary.dart';

class ProfileApi {
  const ProfileApi(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthUser> me() async {
    return AuthUser.fromJson(await _apiClient.getMap(ApiEndpoints.authMe));
  }

  Future<VerificationSnapshot> verificationStatus() async {
    return VerificationSnapshot.fromJson(
      await _apiClient.getMap(ApiEndpoints.verificationStatus),
    );
  }

  Future<int> pendingEvaluationCount() async {
    final list = await _apiClient.getList(ApiEndpoints.pendingRatings);
    return list.length;
  }
}
