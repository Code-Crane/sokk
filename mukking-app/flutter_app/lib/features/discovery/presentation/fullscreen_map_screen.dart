import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/map/kakao_map_initializer.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/restaurant_map_marker.dart';
import '../providers/discovery_location_provider.dart';
import '../providers/discovery_provider.dart';
import 'map/restaurant_map_view.dart';
import 'map/kakao_marker_adapter.dart';
import 'restaurant_bottom_sheet.dart';

const fullscreenMapScreenKey = Key('fullscreen-map-screen');
const closeFullscreenMapButtonKey = Key('close-fullscreen-map-button');
const focusCurrentLocationButtonKey = Key('focus-current-location-button');

class FullscreenMapScreen extends ConsumerStatefulWidget {
  const FullscreenMapScreen({super.key});

  @override
  ConsumerState<FullscreenMapScreen> createState() =>
      _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends ConsumerState<FullscreenMapScreen> {
  int _focusCurrentLocationRequest = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final restaurants = ref.watch(filteredRestaurantsProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final selectedRestaurantFocusRequest =
        ref.watch(selectedRestaurantFocusRequestProvider);
    final parties = ref.watch(matchingPartiesProvider).valueOrNull ?? const [];
    final locationState = ref.watch(discoveryLocationProvider);
    final config = ref.watch(appConfigProvider);
    final kakaoMapReady = ref.watch(kakaoMapReadyProvider);
    final urgentRestaurantIds = parties
        .where((party) => party.isUrgent)
        .map((party) => party.restaurantId)
        .toSet();
    final markers = buildRestaurantMapMarkers(
      restaurants,
      urgentRestaurantIds: urgentRestaurantIds,
    );

    return Scaffold(
      key: fullscreenMapScreenKey,
      backgroundColor: tokens.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RestaurantMapView(
            enableMap: config.hasAnyKakaoMapConfig && kakaoMapReady,
            restaurants: restaurants,
            markers: markers,
            selectedRestaurantId: selectedRestaurant?.id,
            focusSelectedRestaurantRequest: selectedRestaurantFocusRequest,
            userLocation: locationState.location,
            onMarkerSelected: _selectRestaurant,
            expanded: true,
            focusCurrentLocationRequest: _focusCurrentLocationRequest,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapControlButton(
                    key: closeFullscreenMapButtonKey,
                    tooltip: '지도 닫기',
                    icon: Icons.close_rounded,
                    onPressed: _close,
                  ),
                  const Spacer(),
                  _MapControlButton(
                    key: focusCurrentLocationButtonKey,
                    tooltip: '현재 위치로 이동',
                    icon: Icons.my_location_rounded,
                    onPressed:
                        locationState.isLoading ? null : _focusCurrentLocation,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectRestaurant(String restaurantId) {
    if (restaurantId == kakaoCurrentLocationMarkerId) return;
    final restaurant = ref.read(restaurantByIdProvider(restaurantId));
    if (restaurant == null) return;

    ref.read(selectedRestaurantIdProvider.notifier).state = restaurantId;
    showRestaurantDetailsSheet(context, restaurantId: restaurantId);
  }

  void _focusCurrentLocation() {
    final location = ref.read(discoveryLocationProvider).location;
    if (location == null) {
      ref.read(discoveryLocationProvider.notifier).loadNearbyRestaurants();
      return;
    }
    setState(() => _focusCurrentLocationRequest += 1);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.discovery);
    }
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
