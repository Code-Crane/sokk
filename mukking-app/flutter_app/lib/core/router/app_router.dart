import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/matching/presentation/create_party_screen.dart';
import '../../features/matching/presentation/party_detail_screen.dart';
import '../../features/profile/presentation/my_screen.dart';
import '../../widgets/app_shell.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
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
              return const NoTransitionPage(child: ChatScreen());
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
                child: PartyDetailScreen(partyId: partyId),
              );
            },
          ),
        ],
      ),
    ],
  );
});
