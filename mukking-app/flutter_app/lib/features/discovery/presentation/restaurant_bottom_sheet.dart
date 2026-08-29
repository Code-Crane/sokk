import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/platform/external_url_launcher.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/restaurant.dart';
import '../providers/discovery_provider.dart';

const restaurantDetailsSheetKey = Key('restaurant-details-sheet');
const restaurantPhoneKey = Key('restaurant-phone');
const restaurantPlaceUrlButtonKey = Key('restaurant-place-url-button');
const restaurantViewDetailsButtonKey = Key('restaurant-view-details-button');

Future<void> showRestaurantDetailsSheet(
  BuildContext context, {
  required String restaurantId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RestaurantDetailsSheet(restaurantId: restaurantId),
  );
}

class _RestaurantDetailsSheet extends ConsumerWidget {
  const _RestaurantDetailsSheet({required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(selectedRestaurantIdProvider, (_, selectedId) {
      if (selectedId == restaurantId || !context.mounted) return;
      Navigator.of(context).pop();
    });
    final restaurant = ref.watch(restaurantByIdProvider(restaurantId));
    if (restaurant == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      key: restaurantDetailsSheetKey,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: RestaurantBottomSheet(
        restaurant: restaurant,
        onViewDetails: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(AppRoutes.restaurantDetailPath(restaurant.id));
        },
      ),
    );
  }
}

class RestaurantBottomSheet extends ConsumerWidget {
  const RestaurantBottomSheet({
    required this.restaurant,
    this.onViewDetails,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final partiesAsync = ref.watch(partiesByRestaurantProvider(restaurant.id));
    final parties = partiesAsync.valueOrNull ?? const [];
    final firstParty = parties.isEmpty ? null : parties.first;
    final phone = restaurant.phone?.trim();
    final placeUri = restaurant.placeUri;

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
                      [
                        if (restaurant.category.isNotEmpty) restaurant.category,
                        restaurant.distanceLabel,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (restaurant.displayAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        restaurant.displayAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        key: restaurantPhoneKey,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 17,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              phone,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                key: restaurantViewDetailsButtonKey,
                icon: Icons.info_outline_rounded,
                label: '식당 자세히 보기',
                color: tokens.primary,
                onTap: onViewDetails ??
                    () => context.push(
                          AppRoutes.restaurantDetailPath(restaurant.id),
                        ),
              ),
              if (placeUri != null)
                _ActionChipButton(
                  key: restaurantPlaceUrlButtonKey,
                  icon: Icons.open_in_new_rounded,
                  label: '카카오맵에서 자세히 보기',
                  color: tokens.secondary,
                  onTap: () async {
                    try {
                      final launched =
                          await ref.read(externalUrlLauncherProvider)(placeUri);
                      if (launched || !context.mounted) return;
                    } catch (_) {
                      if (!context.mounted) return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('카카오맵 상세 페이지를 열지 못했어요.'),
                      ),
                    );
                  },
                ),
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
    super.key,
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
