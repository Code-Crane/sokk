import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'MUKKING_API_BASE_URL',
        defaultValue: 'http://localhost:4000',
      ),
      supabaseUrl: String.fromEnvironment('MUKKING_SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('MUKKING_SUPABASE_ANON_KEY'),
    );
  }

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
