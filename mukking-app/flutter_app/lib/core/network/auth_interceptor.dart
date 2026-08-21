import 'package:dio/dio.dart';

typedef AccessTokenReader = Future<String?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AccessTokenReader readAccessToken,
  }) : _readAccessToken = readAccessToken;

  final AccessTokenReader _readAccessToken;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
