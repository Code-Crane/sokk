import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/restaurant.dart';
import '../providers/discovery_provider.dart';

class RestaurantBottomSheet extends ConsumerWidget {
  const RestaurantBottomSheet({
    required this.restaurant,
    super.key,
  });

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final partiesAsync = ref.watch(partiesByRestaurantProvider(restaurant.id));
    final parties = partiesAsync.valueOrNull ?? const [];
    final firstParty = parties.isEmpty ? null : parties.first;

    return MukkingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tokens.secondary.withValues(alpha: 0.26),
                      tokens.primary.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: tokens.primary,
                  size: 36,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Icon(
                          restaurant.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: restaurant.isFavorite
                              ? tokens.favorite
                              : tokens.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.category} · ${restaurant.distanceLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    partiesAsync.when(
                      data: (_) => Text(
                        '현재 모집 중 파티 ${restaurant.activePartyCount}개',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      loading: () => Text(
                        '파티 수 확인 중',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      error: (_, __) => Text(
                        '파티 수를 불러오지 못했어요',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.danger,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChipButton(
                icon: restaurant.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: restaurant.isFavorite ? '찜 취소' : '가고 싶어요',
                color: restaurant.isFavorite ? tokens.favorite : tokens.primary,
                onTap: () async {
                  try {
                    await ref
                        .read(favoriteOverridesProvider.notifier)
                        .toggle(restaurant);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('찜 상태를 변경하지 못했어요.')),
                    );
                  }
                },
              ),
              _ActionChipButton(
                icon: Icons.groups_rounded,
                label: '파티 보기',
                color: tokens.partyHot,
                onTap: firstParty == null
                    ? null
                    : () {
                        ref.read(selectedPartyIdProvider.notifier).state =
                            firstParty.id;
                        context.push(AppRoutes.partyDetailPath(firstParty.id));
                      },
              ),
              _ActionChipButton(
                icon: Icons.add_rounded,
                label: '이 식당에서 파티 만들기',
                color: tokens.primary,
                onTap: () => context.go(
                  AppRoutes.createPartyPath(restaurantId: restaurant.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            restaurant.isFavorite
                ? '찜한 식당입니다. 새 파티 알림과 홈 섹션에 반영됩니다.'
                : '가고 싶어요를 누르면 이 식당의 파티 흐름을 홈에서 이어볼 수 있어요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: onTap == null ? 0.48 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: onTap == null ? tokens.textSecondary : color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
