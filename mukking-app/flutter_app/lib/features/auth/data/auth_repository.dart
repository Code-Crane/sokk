import '../domain/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> currentUser();
}
