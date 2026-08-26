import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../domain/matching_party.dart';
import '../providers/matching_provider.dart';

class PartyDetailScreen extends ConsumerWidget {
  const PartyDetailScreen({
    required this.partyId,
    super.key,
  });

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final partyAsync = ref.watch(partyByIdProvider(partyId));

    return partyAsync.when(
      data: (party) {
        if (party == null) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MukkingCard(
                child: Text(
                  '파티를 찾을 수 없어요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          );
        }

        final restaurant =
            ref.watch(restaurantByIdProvider(party.restaurantId));

        if (restaurant == null) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MukkingCard(
                child: Text(
                  '식당 정보를 찾을 수 없어요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          );
        }

        final joinState = ref.watch(joinPartyControllerProvider);
        final currentUser = ref.watch(currentUserProvider);
        final isHost = currentUser?.id == party.hostUserId;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                BackButton(color: tokens.textPrimary),
                Expanded(
                  child: Text(
                    '파티 상세',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: '신고/차단 메뉴',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    tokens.secondary.withValues(alpha: 0.94),
                    tokens.primary.withValues(alpha: 0.84),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -26,
                    bottom: -28,
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: tokens.surface.withValues(alpha: 0.16),
                      size: 160,
                    ),
                  ),
                  Positioned(
                    left: 22,
                    bottom: 22,
                    right: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.imageLabel,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: tokens.surface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${restaurant.name} · ${restaurant.category}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: tokens.surface.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            MukkingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusPill(status: party.status),
                  const SizedBox(height: 12),
                  Text(
                    party.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.address,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: '날짜/시간',
                    value: party.scheduledLabel,
                  ),
                  _DetailRow(
                    icon: Icons.place_rounded,
                    label: '지역/거리',
                    value:
                        '${restaurant.address.split(' ').take(2).join(' ')} · ${party.distanceLabel}',
                  ),
                  _DetailRow(
                    icon: Icons.people_alt_rounded,
                    label: '모집 인원',
                    value: party.memberLabel,
                  ),
                  _DetailRow(
                    icon: Icons.person_rounded,
                    label: '파티장',
                    value: party.hostName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MukkingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('획득 가능한 보상',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _RewardPanel(
                        icon: Icons.bolt_rounded,
                        label: '+${party.rewardXp} XP',
                        color: tokens.rewardXp,
                      ),
                      const SizedBox(width: 10),
                      _RewardPanel(
                        icon: Icons.toll_rounded,
                        label: '+${party.rewardPoints}P',
                        color: tokens.rewardPoint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MukkingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('참여자', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in party.memberNames)
                        Chip(
                          avatar: Icon(
                            Icons.face_rounded,
                            color: tokens.primary,
                            size: 18,
                          ),
                          label: Text(member),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('태그', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in party.tags)
                        Chip(
                          label: Text('#$tag'),
                          backgroundColor:
                              tokens.accent.withValues(alpha: 0.55),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MukkingCard(
              backgroundColor: tokens.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('파티 소개', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(party.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '신고/차단 메뉴 placeholder · 실제 기능은 다음 단계에서 연결',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.danger,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isHost)
              _JoinRequestManagementCard(partyId: party.id)
            else
              FilledButton.icon(
                onPressed: joinState.isLoading
                    ? null
                    : () async {
                        final result = await ref
                            .read(joinPartyControllerProvider.notifier)
                            .join(party.id);

                        if (!context.mounted) {
                          return;
                        }

                        final error =
                            ref.read(joinPartyControllerProvider).error;
                        final message = result?.message ??
                            (error is ApiError
                                ? error.userMessage
                                : '참가 요청을 처리하지 못했어요.');

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      },
                icon: joinState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg_rounded),
                label: Text(joinState.isLoading ? '요청 중' : '파티 참가하기'),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final message =
            error is ApiError ? error.userMessage : '파티 상세 정보를 불러오지 못했어요.';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            MukkingCard(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _JoinRequestManagementCard extends ConsumerWidget {
  const _JoinRequestManagementCard({required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(partyJoinRequestsProvider(partyId));
    final action = ref.watch(respondJoinRequestControllerProvider(partyId));
    final tokens = context.tokens;

    return MukkingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: tokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '참가 요청 관리',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          requests.when(
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  '아직 참가 요청이 없어요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }

              return Column(
                children: [
                  for (final request in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tokens.background,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.requesterLabel,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _requestStatusLabel(request.status),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (request.isPending) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: action.isLoading
                                          ? null
                                          : () => _respond(
                                                context,
                                                ref,
                                                request.id,
                                                'rejected',
                                              ),
                                      child: const Text('거절'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: action.isLoading
                                          ? null
                                          : () => _respond(
                                                context,
                                                ref,
                                                request.id,
                                                'accepted',
                                              ),
                                      child: const Text('승인'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(
              error is ApiError ? error.userMessage : '참가 요청을 불러오지 못했어요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.danger,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    String decision,
  ) async {
    final result = await ref
        .read(respondJoinRequestControllerProvider(partyId).notifier)
        .respond(requestId: requestId, decision: decision);

    if (!context.mounted) return;
    final error = ref.read(respondJoinRequestControllerProvider(partyId)).error;
    final message = result == null
        ? (error is ApiError ? error.userMessage : '참가 요청 처리에 실패했어요.')
        : decision == 'accepted'
            ? '참가 요청을 승인했어요. 채팅방이 생성됐습니다.'
            : '참가 요청을 거절했어요.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    if (result?.chatRoomId != null) {
      context.go(AppRoutes.chat);
    }
  }

  String _requestStatusLabel(String status) {
    return switch (status) {
      'accepted' => '승인됨',
      'rejected' => '거절됨',
      'cancelled' => '취소됨',
      _ => '승인 대기 중',
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final MatchingPartyStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (status) {
      MatchingPartyStatus.hot => tokens.partyHot,
      MatchingPartyStatus.urgent => tokens.partyUrgent,
      MatchingPartyStatus.full => tokens.textSecondary,
      MatchingPartyStatus.open => tokens.success,
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _RewardPanel extends StatelessWidget {
  const _RewardPanel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
