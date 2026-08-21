import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mission_card.dart';
import '../../../widgets/mukking_card.dart';
import '../../../widgets/party_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/xp_progress_bar.dart';
import '../../matching/data/mock_party_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final parties = ref.watch(featuredPartiesProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: tokens.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '맛집을 발견하고, 함께 먹는 파티를 매칭해요.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                MukkingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Lv. 7 미식 탐험가',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: tokens.primary),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '다음 배지까지 160 XP',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const XpProgressBar(currentXp: 840, targetXp: 1000),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const MissionCard(),
                const SizedBox(height: 24),
                SectionHeader(
                  title: '추천/인기 파티',
                  actionLabel: '발견하기',
                  onActionTap: () => context.go(AppRoutes.discovery),
                ),
                const SizedBox(height: 12),
                for (final party in parties) ...[
                  PartyCard(
                    party: party,
                    onTap: () {
                      context.push(AppRoutes.partyDetailPath(party.id));
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                MukkingCard(
                  backgroundColor: tokens.secondary.withValues(alpha: 0.12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '먹고 싶은 곳이 있나요?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '식당을 먼저 저장하거나 직접 파티를 만들어 참가자를 모을 수 있어요.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.createParty),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('파티 만들기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
