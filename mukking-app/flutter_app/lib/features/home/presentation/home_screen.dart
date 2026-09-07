import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mission_card.dart';
import '../../../widgets/mukking_card.dart';
import '../../../widgets/party_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/xp_progress_bar.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../matching/domain/matching_party.dart';
import '../../matching/providers/matching_provider.dart';
import '../../notifications/presentation/notification_card.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../notifications/presentation/notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final points = ref.watch(userPointsProvider);
    final popularParties = ref.watch(popularPartiesProvider);
    final favoriteParties = ref.watch(favoriteRestaurantPartiesProvider);
    final urgentParties = ref.watch(urgentPartiesProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadState = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadState.isLoading || unreadState.hasError
        ? 0
        : unreadState.valueOrNull ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
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
                        ?.copyWith(color: tokens.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '맛집 발견에서 파티 참여까지, 미식 퀘스트를 이어가요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    tooltip: '알림 목록',
                    onPressed: () => context.push(AppRoutes.notifications),
                    icon: Icon(Icons.notifications_rounded,
                        color: tokens.textPrimary),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: tokens.surface,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
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
                      color: tokens.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Lv. 7 미식 탐험가',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: tokens.primary,
                          ),
                    ),
                  ),
                  const Spacer(),
                  _PointBadge(points: points),
                ],
              ),
              const SizedBox(height: 16),
              const XpProgressBar(currentXp: 840, targetXp: 1000),
            ],
          ),
        ),
        const SizedBox(height: 16),
        notifications.when(
          data: (items) {
            if (items.isEmpty) {
              return const MissionCard();
            }

            return NotificationCard(
              notification: items.first,
              onTap: () => openNotification(context, ref, items.first),
            );
          },
          loading: () => const MissionCard(),
          error: (_, __) => const MissionCard(),
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: '인기 파티',
          actionLabel: '발견하기',
          onActionTap: () => context.go(AppRoutes.discovery),
        ),
        const SizedBox(height: 12),
        _AsyncPartySection(
          parties: popularParties,
          emptyMessage: '인기 파티가 아직 없어요.',
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: '내가 찜한 맛집에서 열린 파티',
          actionLabel: '찜하러 가기',
          onActionTap: () => context.go(AppRoutes.discovery),
        ),
        const SizedBox(height: 12),
        _PartySection(
          parties: favoriteParties,
          emptyMessage: '아직 찜한 맛집 파티가 없어요. 발견 탭에서 가고 싶은 식당을 눌러보세요.',
          compact: true,
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: '모집 마감 임박 파티',
          actionLabel: '전체 보기',
          onActionTap: () => context.go(AppRoutes.discovery),
        ),
        const SizedBox(height: 12),
        _AsyncPartySection(
          parties: urgentParties,
          emptyMessage: '마감 임박 파티가 아직 없어요.',
          compact: true,
        ),
        const SizedBox(height: 18),
        MukkingCard(
          backgroundColor: tokens.secondary.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '먹고 싶은 식당이 떠올랐나요?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '하단 파티 만들기 또는 발견 탭의 식당 카드에서 바로 파티를 열 수 있어요.',
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
    );
  }
}

class _AsyncPartySection extends StatelessWidget {
  const _AsyncPartySection({
    required this.parties,
    required this.emptyMessage,
    this.compact = false,
  });

  final AsyncValue<List<MatchingParty>> parties;
  final String emptyMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return parties.when(
      data: (items) => _PartySection(
        parties: items,
        emptyMessage: emptyMessage,
        compact: compact,
      ),
      loading: () => const _LoadingPartyCard(),
      error: (error, _) => _PartyErrorCard(error: error),
    );
  }
}

class _PartySection extends ConsumerWidget {
  const _PartySection({
    required this.parties,
    required this.emptyMessage,
    this.compact = false,
  });

  final List<MatchingParty> parties;
  final String emptyMessage;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (parties.isEmpty) {
      return MukkingCard(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (final party in parties) ...[
          _PartyWithRestaurantCard(party: party, compact: compact),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _LoadingPartyCard extends StatelessWidget {
  const _LoadingPartyCard();

  @override
  Widget build(BuildContext context) {
    return const MukkingCard(
      child: Text('파티 정보를 불러오는 중이에요.'),
    );
  }
}

class _PartyErrorCard extends StatelessWidget {
  const _PartyErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiError
        ? (error as ApiError).userMessage
        : '파티 정보를 불러오지 못했어요.';

    return MukkingCard(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _PartyWithRestaurantCard extends ConsumerWidget {
  const _PartyWithRestaurantCard({
    required this.party,
    required this.compact,
  });

  final MatchingParty party;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantByIdProvider(party.restaurantId));
    if (restaurant == null) {
      return const SizedBox.shrink();
    }

    return PartyCard(
      party: party,
      restaurant: restaurant,
      compact: compact,
      onTap: () => _goDetail(context, ref, party),
      onJoinTap: () => _goDetail(context, ref, party),
    );
  }

  void _goDetail(BuildContext context, WidgetRef ref, MatchingParty party) {
    ref.read(selectedPartyIdProvider.notifier).state = party.id;
    context.push(AppRoutes.partyDetailPath(party.id));
  }
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.rewardPoint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.toll_rounded, color: tokens.rewardPoint, size: 18),
          const SizedBox(width: 6),
          Text(
            '$points P',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.rewardPoint,
                ),
          ),
        ],
      ),
    );
  }
}
