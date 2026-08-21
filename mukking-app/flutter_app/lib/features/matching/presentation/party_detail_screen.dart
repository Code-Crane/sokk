import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../data/mock_party_repository.dart';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('파티를 찾을 수 없어요', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('mock 데이터에 없는 파티 ID입니다.', style: Theme.of(context).textTheme.bodyMedium),
              ],
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
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [
                tokens.primary,
                tokens.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 22,
                bottom: 22,
                right: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.imageLabel,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: tokens.surface,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '음식/식당 사진 placeholder',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.surface.withValues(alpha: 0.86),
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
              Text(party.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                party.restaurantName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.primary,
                    ),
              ),
              const SizedBox(height: 16),
              _DetailRow(icon: Icons.schedule_rounded, label: '날짜/시간', value: party.scheduledLabel),
              _DetailRow(icon: Icons.place_rounded, label: '지역', value: party.region),
              _DetailRow(icon: Icons.people_alt_rounded, label: '모집 인원', value: party.participantLabel),
              _DetailRow(icon: Icons.workspace_premium_rounded, label: '보상', value: '+${party.rewardXp} XP'),
              _DetailRow(icon: Icons.person_rounded, label: '파티장', value: party.hostName),
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
              Text(party.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '신고/차단 메뉴 영역: 실제 기능은 추후 연결',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
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
