import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/map/kakao_map_initializer.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appConfig = AppConfig.fromEnvironment();
  final preferences = await SharedPreferences.getInstance();
  var kakaoMapReady = false;

  if (appConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: appConfig.supabaseUrl,
      publishableKey: appConfig.supabaseAnonKey,
    );
  }

  if (appConfig.hasAnyKakaoMapConfig) {
    kakaoMapReady = await initializeKakaoMap(
      nativeAppKey: appConfig.kakaoNativeAppKey,
      javascriptKey: appConfig.kakaoJavascriptKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
        kakaoMapReadyProvider.overrideWithValue(kakaoMapReady),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MukkingApp(),
    ),
  );
}

class MukkingApp extends ConsumerWidget {
  const MukkingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '먹킹',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(themeId),
      routerConfig: router,
    );
  }
}
