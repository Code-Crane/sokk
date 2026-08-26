import 'package:dio/dio.dart';

import 'api_error.dart';

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _request(
      () => _dio.get<Object?>(path, queryParameters: queryParameters),
    );
    final data = response.data;

    if (data is List) {
      return data;
    }

    throw const ApiError(
      kind: ApiErrorKind.unknown,
      userMessage: '서버 응답 형식을 확인할 수 없어요.',
    );
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _request(
      () => _dio.get<Object?>(path, queryParameters: queryParameters),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? data,
  }) async {
    final response = await _request(() => _dio.post<Object?>(path, data: data));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchMap(
    String path, {
    Object? data,
  }) async {
    final response =
        await _request(() => _dio.patch<Object?>(path, data: data));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> deleteMap(String path) async {
    final response = await _request(() => _dio.delete<Object?>(path));
    return _asMap(response.data);
  }

  Future<Response<Object?>> _request(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiError.fromDio(error);
    }
  }
}

Map<String, dynamic> _asMap(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }

  throw const ApiError(
    kind: ApiErrorKind.unknown,
    userMessage: '서버 응답 형식을 확인할 수 없어요.',
  );
}
