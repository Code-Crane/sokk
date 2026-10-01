import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/platform/external_url_launcher.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/theme/theme_tokens.dart';
import 'discovery_visuals.dart';
import '../../matching/domain/matching_party.dart';
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
    backgroundColor: MukkingBrand.surface,
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
    return DiscoveryTheme(
        child: Builder(
      builder: (context) => _buildContent(context, ref),
    ));
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final partiesAsync = ref.watch(partiesByRestaurantProvider(restaurant.id));
    final parties = partiesAsync.valueOrNull ?? const [];
    final activeParties = parties
        .where(
          (party) =>
              party.status != MatchingPartyStatus.full &&
              party.hasAvailableSeat,
        )
        .toList();
    final firstParty = activeParties.isEmpty ? null : activeParties.first;
    final phone = restaurant.phone?.trim();
    final placeUri = restaurant.placeUri;

    return DiscoverySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiscoveryRestaurantImage(restaurant: restaurant, size: 56),
              const SizedBox(width: 12),
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
                              ? MukkingBrand.orange
                              : tokens.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (restaurant.category.isNotEmpty) restaurant.category,
                        if (restaurant.distanceMeters != null)
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
                        '현재 모집 중 파티 ${activeParties.length}개',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: MukkingBrand.green,
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
          const SizedBox(height: 12),
          DiscoveryPartyPreview(restaurantId: restaurant.id),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChipButton(
                key: restaurantViewDetailsButtonKey,
                primary: true,
                icon: Icons.info_outline_rounded,
                label: '보러가기',
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
                  color: MukkingBrand.green,
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
                color: tokens.primary,
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
                label: firstParty == null
                    ? '모집 중인 파티 없음'
                    : '모집 중 파티 ${activeParties.length}개 보기',
                color: MukkingBrand.green,
                onTap: firstParty == null
                    ? null
                    : () {
                        context.push(AppRoutes.partyDetailPath(firstParty.id));
                        ref.read(selectedPartyIdProvider.notifier).state =
                            firstParty.id;
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
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18),
      const SizedBox(width: 7),
      Flexible(child: Text(label)),
    ]);
    if (primary) {
      return SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onTap, child: content));
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: color),
      child: content,
    );
  }
}
