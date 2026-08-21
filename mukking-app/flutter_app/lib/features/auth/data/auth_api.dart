import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/auth_user.dart';

class AuthApi {
  const AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthUser> me() async {
    final json = await _apiClient.getMap(ApiEndpoints.authMe);
    return AuthUser.fromJson(json);
  }
}
