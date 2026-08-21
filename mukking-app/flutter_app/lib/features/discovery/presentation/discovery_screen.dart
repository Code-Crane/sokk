import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../data/mock_restaurant_repository.dart';
import '../domain/restaurant.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  Restaurant? _selectedRestaurant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final restaurants = ref.watch(nearbyRestaurantsProvider);
    final selectedRestaurant = _selectedRestaurant ?? restaurants.first;

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
                    '발견',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
              label: const Text('지역'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: tokens.primary),
            hintText: '식당, 음식, 지역 검색',
          ),
        ),
        const SizedBox(height: 16),
        _MapPlaceholder(
          restaurants: restaurants,
          selectedRestaurant: selectedRestaurant,
          onSelect: (restaurant) {
            setState(() => _selectedRestaurant = restaurant);
          },
        ),
        const SizedBox(height: 16),
        _RestaurantBottomPanel(
          restaurant: selectedRestaurant,
          onCreateParty: () => context.go(AppRoutes.createParty),
        ),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.restaurants,
    required this.selectedRestaurant,
    required this.onSelect,
  });

  final List<Restaurant> restaurants;
  final Restaurant selectedRestaurant;
  final ValueChanged<Restaurant> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 330,
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
                            tokens.secondary.withValues(alpha: 0.2),
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
                    child: _MapLegend(
                      title: '지도 SDK 예정 영역',
                      subtitle: 'Naver Map은 아직 연결하지 않음',
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: _MapLegend(
                      title: 'Restaurant markers',
                      subtitle: 'mock 위치 데이터',
                    ),
                  ),
                  for (final restaurant in restaurants)
                    Positioned(
                      left: restaurant.markerDx * constraints.maxWidth,
                      top: restaurant.markerDy * constraints.maxHeight,
                      child: _RestaurantMarker(
                        restaurant: restaurant,
                        isSelected: restaurant.id == selectedRestaurant.id,
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
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
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
        color: tokens.surface.withValues(alpha: 0.88),
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

class _RestaurantMarker extends StatelessWidget {
  const _RestaurantMarker({
    required this.restaurant,
    required this.isSelected,
    required this.onTap,
  });

  final Restaurant restaurant;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? tokens.primary : tokens.surface,
          borderRadius: BorderRadius.circular(999),
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
              Icons.location_on_rounded,
              color: isSelected ? tokens.surface : tokens.primary,
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

class _RestaurantBottomPanel extends StatelessWidget {
  const _RestaurantBottomPanel({
    required this.restaurant,
    required this.onCreateParty,
  });

  final Restaurant restaurant;
  final VoidCallback onCreateParty;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tokens.secondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.ramen_dining_rounded,
                  color: tokens.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.region} · ${restaurant.category} · ${restaurant.distanceLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.waitingSignal} · 진행 중 파티 ${restaurant.partyCount}개',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border_rounded),
                  label: const Text('가고 싶어요'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreateParty,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('파티 만들기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '향후 흐름: 식당 발견 → 관심 저장 → 파티 생성 알림 → 파티 참여',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
