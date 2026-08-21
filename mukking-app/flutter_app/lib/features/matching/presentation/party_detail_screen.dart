import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
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
    final party = ref.watch(partyByIdProvider(partyId));

    if (party == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MukkingCard(
            child: Text(
              '파티를 찾을 수 없어요. mock 데이터에 없는 파티 ID입니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    final restaurant = ref.watch(restaurantByIdProvider(party.restaurantId));

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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: tokens.surface,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${restaurant.name} · ${restaurant.category}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
              Text('획득 가능한 보상', style: Theme.of(context).textTheme.titleMedium),
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
                      backgroundColor: tokens.accent.withValues(alpha: 0.55),
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
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.how_to_reg_rounded),
          label: const Text('파티 참가하기'),
        ),
      ],
    );
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
