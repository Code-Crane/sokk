import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDataSource {
  mock,
  api;

  static AppDataSource fromValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'api' => AppDataSource.api,
      _ => AppDataSource.mock,
    };
  }
}

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.kakaoNativeAppKey,
    required this.kakaoJavascriptKey,
    required this.dataSource,
    required this.enableMockVerification,
  });

  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment(
      'MUKKING_API_BASE_URL',
      defaultValue: 'http://localhost:4000',
    );

    return AppConfig(
      apiBaseUrl: apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl,
      dataSource: AppDataSource.fromValue(
        const String.fromEnvironment(
          'MUKKING_DATA_PROVIDER',
          defaultValue: 'mock',
        ),
      ),
      supabaseUrl: const String.fromEnvironment('MUKKING_SUPABASE_URL'),
      supabaseAnonKey:
          const String.fromEnvironment('MUKKING_SUPABASE_ANON_KEY'),
      kakaoNativeAppKey:
          const String.fromEnvironment('MUKKING_KAKAO_NATIVE_APP_KEY'),
      kakaoJavascriptKey:
          const String.fromEnvironment('MUKKING_KAKAO_JAVASCRIPT_KEY'),
      enableMockVerification: const bool.fromEnvironment(
        'MUKKING_ENABLE_MOCK_VERIFICATION',
        defaultValue: kDebugMode,
      ),
    );
  }

  factory AppConfig.test({
    String apiBaseUrl = 'http://localhost:4000',
    String supabaseUrl = '',
    String supabaseAnonKey = '',
    String kakaoNativeAppKey = '',
    String kakaoJavascriptKey = '',
    AppDataSource dataSource = AppDataSource.mock,
    bool enableMockVerification = false,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      kakaoNativeAppKey: kakaoNativeAppKey,
      kakaoJavascriptKey: kakaoJavascriptKey,
      dataSource: dataSource,
      enableMockVerification: enableMockVerification,
    );
  }

  factory AppConfig.fromLegacyEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'MUKKING_API_BASE_URL',
        defaultValue: 'http://localhost:4000',
      ),
      supabaseUrl: String.fromEnvironment('MUKKING_SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('MUKKING_SUPABASE_ANON_KEY'),
      kakaoNativeAppKey: String.fromEnvironment('MUKKING_KAKAO_NATIVE_APP_KEY'),
      kakaoJavascriptKey:
          String.fromEnvironment('MUKKING_KAKAO_JAVASCRIPT_KEY'),
      dataSource: AppDataSource.mock,
      enableMockVerification: false,
    );
  }

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String kakaoNativeAppKey;
  final String kakaoJavascriptKey;
  final AppDataSource dataSource;
  final bool enableMockVerification;

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasAnyKakaoMapConfig =>
      kakaoNativeAppKey.isNotEmpty || kakaoJavascriptKey.isNotEmpty;

  bool get usesApiData => dataSource == AppDataSource.api;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
