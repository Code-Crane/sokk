import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/router/app_routes.dart';
import '../core/theme/brand_assets.dart';
import '../features/auth/presentation/auth_placeholder_screen.dart';
import '../features/auth/providers/auth_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final requiresAuth = ref.watch(appConfigProvider).usesApiData;
    final auth = ref.watch(authControllerProvider);

    if (requiresAuth && auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (requiresAuth && !auth.isAuthenticated) {
      return const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: AuthPlaceholderScreen(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          location == AppRoutes.home ? MukkingBrand.background : null,
      body: SafeArea(child: child),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: MukkingBrand.contentWidth),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: MukkingBrand.surface,
              indicatorColor: Colors.transparent,
              iconTheme: WidgetStateProperty.resolveWith((states) =>
                  IconThemeData(
                      color: states.contains(WidgetState.selected)
                          ? MukkingBrand.green
                          : MukkingBrand.secondary,
                      size: 28)),
              labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                  TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: states.contains(WidgetState.selected)
                          ? MukkingBrand.green
                          : MukkingBrand.secondary)),
            ),
            child: NavigationBar(
              height: 68,
              selectedIndex: _selectedIndex(location),
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go(AppRoutes.home);
                    break;
                  case 1:
                    context.go(AppRoutes.discovery);
                    break;
                  case 2:
                    context.go(AppRoutes.chat);
                    break;
                  case 3:
                    context.go(AppRoutes.my);
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: '홈',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: '탐색',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: '채팅',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'MY',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith(AppRoutes.discovery) ||
        location.startsWith(AppRoutes.restaurants)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.createParty)) {
      return 0;
    }
    if (location.startsWith(AppRoutes.chat)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.my) || location == AppRoutes.pet) {
      return 3;
    }
    return 0;
  }
}
