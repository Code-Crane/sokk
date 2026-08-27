import 'package:flutter/material.dart';

import '../../../../core/theme/theme_tokens.dart';
import '../../../../widgets/mukking_card.dart';
import '../../domain/restaurant.dart';
import '../../domain/restaurant_map_marker.dart';

class RestaurantMapFallback extends StatelessWidget {
  const RestaurantMapFallback({
    required this.restaurants,
    required this.markers,
    required this.selectedRestaurantId,
    required this.onMarkerSelected,
    this.expanded = false,
    this.title = '지도 미리보기',
    this.subtitle = 'Web에서는 맛집 목록과 찜 기능을 이용할 수 있어요.',
    super.key,
  });

  final List<Restaurant> restaurants;
  final List<RestaurantMapMarker> markers;
  final String? selectedRestaurantId;
  final ValueChanged<String> onMarkerSelected;
  final bool expanded;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final restaurantById = {for (final item in restaurants) item.id: item};

    final map = ClipRRect(
      borderRadius: expanded ? BorderRadius.zero : BorderRadius.circular(28),
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
                child: _MapFloatingLabel(title: title, subtitle: subtitle),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: const _MapFloatingLabel(
                  title: 'Fallback markers',
                  subtitle: '찜/파티 상태를 동일하게 반영해요.',
                ),
              ),
              for (final marker in markers)
                if (restaurantById[marker.id] case final restaurant?)
                  Positioned(
                    left: restaurant.markerDx * constraints.maxWidth,
                    top: restaurant.markerDy * constraints.maxHeight,
                    child: _RestaurantMarker(
                      restaurant: restaurant,
                      status: marker.status,
                      isSelected: marker.id == selectedRestaurantId,
                      onTap: () => onMarkerSelected(marker.id),
                    ),
                  ),
            ],
          );
        },
      ),
    );
    if (expanded) {
      return SizedBox.expand(child: map);
    }
    return MukkingCard(
      padding: EdgeInsets.zero,
      child: SizedBox(height: 348, child: map),
    );
  }
}

class _MapFloatingLabel extends StatelessWidget {
  const _MapFloatingLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
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

class _RestaurantMarker extends StatelessWidget {
  const _RestaurantMarker({
    required this.restaurant,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final Restaurant restaurant;
  final RestaurantMapMarkerStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final markerColor = switch (status) {
      RestaurantMapMarkerStatus.urgentParty => tokens.partyUrgent,
      RestaurantMapMarkerStatus.activeParty => tokens.partyHot,
      RestaurantMapMarkerStatus.favorite => tokens.favorite,
      RestaurantMapMarkerStatus.normal => tokens.mapMarker,
    };

    return GestureDetector(
      key: ValueKey('restaurant-map-marker-${restaurant.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
              status == RestaurantMapMarkerStatus.favorite
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
