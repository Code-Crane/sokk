import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Content-Type': 'application/json',
      },
    ),
  );
});
