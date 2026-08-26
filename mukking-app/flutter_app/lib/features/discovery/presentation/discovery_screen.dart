import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../matching/domain/matching_party.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/restaurant.dart';
import '../providers/discovery_provider.dart';
import 'restaurant_bottom_sheet.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final categories = ref.watch(discoveryCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final restaurants = ref.watch(filteredRestaurantsProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final parties = ref.watch(matchingPartiesProvider).valueOrNull ?? const [];
    final restaurantFeed = ref.watch(restaurantFeedProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('발견', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.defaultRegion,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('지역 선택'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: tokens.primary),
            hintText: '맛집, 음식, 지역 검색',
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in categories) ...[
                ChoiceChip(
                  selected: selectedCategory == category,
                  label: Text(category),
                  onSelected: (_) {
                    ref.read(selectedCategoryProvider.notifier).state =
                        category;
                    ref.read(selectedRestaurantIdProvider.notifier).state =
                        null;
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        restaurantFeed.when(
          data: (items) => _RestaurantFeedStatus(
            message: '주변 맛집 ${items.length}곳을 불러왔어요.',
            icon: Icons.restaurant_rounded,
          ),
          loading: () => const _RestaurantFeedStatus(
            message: '주변 맛집을 불러오는 중이에요.',
            icon: Icons.sync_rounded,
          ),
          error: (error, _) => _RestaurantFeedStatus(
            message:
                error is ApiError ? error.userMessage : '맛집 목록을 불러오지 못했어요.',
            icon: Icons.error_outline_rounded,
            onRetry: () => ref.invalidate(restaurantFeedProvider),
          ),
        ),
        const SizedBox(height: 12),
        _MapPlaceholder(
          restaurants: restaurants,
          parties: parties,
          selectedRestaurant: selectedRestaurant,
          onSelect: (restaurant) {
            ref.read(selectedRestaurantIdProvider.notifier).state =
                restaurant.id;
          },
        ),
        const SizedBox(height: 12),
        const _MapLegendRow(),
        const SizedBox(height: 16),
        if (selectedRestaurant != null)
          RestaurantBottomSheet(restaurant: selectedRestaurant)
        else
          MukkingCard(
            child: Text(
              '선택 가능한 식당이 없어요. 카테고리 필터를 변경해보세요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _RestaurantFeedStatus extends StatelessWidget {
  const _RestaurantFeedStatus({
    required this.message,
    required this.icon,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.restaurants,
    required this.parties,
    required this.selectedRestaurant,
    required this.onSelect,
  });

  final List<Restaurant> restaurants;
  final List<MatchingParty> parties;
  final Restaurant? selectedRestaurant;
  final ValueChanged<Restaurant> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 348,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tokens.mapMarker.withValues(alpha: 0.18),
                            tokens.background,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: _MapFloatingLabel(
                      title: '지도 placeholder',
                      subtitle: 'Naver Map SDK는 아직 연결하지 않음',
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: _MapFloatingLabel(
                      title: 'Mock markers',
                      subtitle: '찜/파티/마감 상태 반영',
                    ),
                  ),
                  for (final restaurant in restaurants)
                    Positioned(
                      left: restaurant.markerDx * constraints.maxWidth,
                      top: restaurant.markerDy * constraints.maxHeight,
                      child: _RestaurantMarker(
                        restaurant: restaurant,
                        status: _markerStatus(restaurant, parties),
                        isSelected: restaurant.id == selectedRestaurant?.id,
                        onTap: () => onSelect(restaurant),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  _RestaurantMarkerStatus _markerStatus(
    Restaurant restaurant,
    List<MatchingParty> parties,
  ) {
    if (restaurant.isFavorite) {
      return _RestaurantMarkerStatus.favorite;
    }

    final restaurantParties =
        parties.where((party) => party.restaurantId == restaurant.id);

    if (restaurantParties.any((party) => party.isUrgent)) {
      return _RestaurantMarkerStatus.urgentParty;
    }

    if (restaurantParties.isNotEmpty) {
      return _RestaurantMarkerStatus.activeParty;
    }

    return _RestaurantMarkerStatus.normal;
  }
}

class _MapFloatingLabel extends StatelessWidget {
  const _MapFloatingLabel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

enum _RestaurantMarkerStatus {
  normal,
  favorite,
  activeParty,
  urgentParty;
}

class _RestaurantMarker extends StatelessWidget {
  const _RestaurantMarker({
    required this.restaurant,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final Restaurant restaurant;
  final _RestaurantMarkerStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final markerColor = switch (status) {
      _RestaurantMarkerStatus.urgentParty => tokens.partyUrgent,
      _RestaurantMarkerStatus.activeParty => tokens.partyHot,
      _RestaurantMarkerStatus.favorite => tokens.favorite,
      _RestaurantMarkerStatus.normal => tokens.mapMarker,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? markerColor : tokens.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: markerColor.withValues(alpha: 0.48)),
          boxShadow: [
            BoxShadow(
              color: tokens.textPrimary.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == _RestaurantMarkerStatus.favorite
                  ? Icons.favorite_rounded
                  : Icons.location_on_rounded,
              color: isSelected ? tokens.surface : markerColor,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              restaurant.category,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? tokens.surface : tokens.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegendRow extends StatelessWidget {
  const _MapLegendRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _LegendChip(label: '일반', color: tokens.mapMarker),
        _LegendChip(label: '찜', color: tokens.favorite),
        _LegendChip(label: '파티', color: tokens.partyHot),
        _LegendChip(label: '마감 임박', color: tokens.partyUrgent),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}
