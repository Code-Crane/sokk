import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum ApiErrorKind {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  rateLimited,
  server,
  timeout,
  network,
  cancelled,
  unknown,
}

class ApiError implements Exception {
  const ApiError({
    required this.kind,
    required this.userMessage,
    this.statusCode,
    this.serverMessage,
  });

  factory ApiError.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _readServerMessage(error.response?.data);

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiError(
        kind: ApiErrorKind.timeout,
        userMessage: '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.',
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return ApiError(
        kind: ApiErrorKind.network,
        statusCode: statusCode,
        serverMessage: serverMessage,
        userMessage: kIsWeb
            ? '브라우저에서 API에 연결할 수 없어요. 서버 CORS 허용 주소를 확인해주세요.'
            : '서버에 연결할 수 없어요. 서버 실행 상태와 네트워크를 확인해주세요.',
      );
    }

    if (error.type == DioExceptionType.cancel) {
      return const ApiError(
        kind: ApiErrorKind.cancelled,
        userMessage: '이전 요청이 새 요청으로 교체됐어요.',
      );
    }

    return ApiError.fromStatusCode(statusCode, serverMessage: serverMessage);
  }

  factory ApiError.fromStatusCode(
    int? statusCode, {
    String? serverMessage,
  }) {
    return switch (statusCode) {
      400 => ApiError(
          kind: ApiErrorKind.badRequest,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage: '요청 내용을 확인해주세요.',
        ),
      401 => ApiError(
          kind: ApiErrorKind.unauthorized,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage: '로그인이 필요해요.',
        ),
      403 => ApiError(
          kind: ApiErrorKind.forbidden,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage: '권한, 인증 상태, 이용 제한 조건을 확인해주세요.',
        ),
      404 => ApiError(
          kind: ApiErrorKind.notFound,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage: '요청한 정보를 찾을 수 없어요.',
        ),
      409 => ApiError(
          kind: ApiErrorKind.conflict,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage: '이미 처리된 요청이거나 중복 요청이에요.',
        ),
      429 => ApiError(
          kind: ApiErrorKind.rateLimited,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage: '요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
        ),
      _ => ApiError(
          kind: statusCode != null && statusCode >= 500 && statusCode < 600
              ? ApiErrorKind.server
              : ApiErrorKind.unknown,
          statusCode: statusCode,
          serverMessage: serverMessage,
          userMessage:
              statusCode != null && statusCode >= 500 && statusCode < 600
                  ? '서버 오류가 발생했어요. 잠시 후 다시 시도해주세요.'
                  : '알 수 없는 오류가 발생했어요.',
        ),
    };
  }

  final ApiErrorKind kind;
  final int? statusCode;
  final String userMessage;
  final String? serverMessage;

  @override
  String toString() {
    return 'ApiError(kind: $kind, statusCode: $statusCode)';
  }
}

String? _readServerMessage(Object? data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    return message is String ? message : null;
  }

  if (data is Map) {
    final message = data['message'];
    return message is String ? message : null;
  }

  return null;
}
