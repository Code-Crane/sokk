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
    required this.dataSource,
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
    );
  }

  factory AppConfig.test({
    String apiBaseUrl = 'http://localhost:4000',
    String supabaseUrl = '',
    String supabaseAnonKey = '',
    AppDataSource dataSource = AppDataSource.mock,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      dataSource: dataSource,
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
      dataSource: AppDataSource.mock,
    );
  }

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final AppDataSource dataSource;

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get usesApiData => dataSource == AppDataSource.api;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
