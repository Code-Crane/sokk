import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/discovery/presentation/fullscreen_map_screen.dart';
import '../../features/discovery/presentation/restaurant_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/matching/presentation/create_party_screen.dart';
import '../../features/matching/presentation/party_detail_screen.dart';
import '../../features/profile/presentation/my_screen.dart';
import '../../widgets/app_shell.dart';
import 'app_routes.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
              path: AppRoutes.notifications,
              builder: (context, state) => const NotificationsScreen()),
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: HomeScreen());
            },
          ),
          GoRoute(
            path: AppRoutes.discovery,
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: DiscoveryScreen());
            },
            routes: [
              GoRoute(
                path: 'map',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  return const MaterialPage(
                    fullscreenDialog: true,
                    child: FullscreenMapScreen(),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.createParty,
            pageBuilder: (context, state) {
              return NoTransitionPage(
                child: CreatePartyScreen(
                  restaurantId: state.uri.queryParameters['restaurantId'],
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.chat,
            pageBuilder: (context, state) {
              return NoTransitionPage(
                child: ChatScreen(
                  roomId: state.uri.queryParameters['roomId'],
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.my,
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: MyScreen());
            },
          ),
          GoRoute(
            path: AppRoutes.partyDetail,
            pageBuilder: (context, state) {
              final partyId = state.pathParameters['partyId'] ?? '';
              return MaterialPage(
                child: PartyDetailScreen(
                  partyId: partyId,
                  returnPath: state.uri.queryParameters['returnTo'],
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.restaurantDetail,
            pageBuilder: (context, state) {
              final restaurantId = state.pathParameters['restaurantId'] ?? '';
              return MaterialPage(
                child: RestaurantDetailScreen(restaurantId: restaurantId),
              );
            },
          ),
        ],
      ),
    ],
  );
});
