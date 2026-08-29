import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/map/kakao_map_initializer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/discovery_filter.dart';
import '../domain/restaurant.dart';
import '../domain/restaurant_map_marker.dart';
import '../providers/discovery_location_provider.dart';
import '../providers/discovery_provider.dart';
import 'map/restaurant_map_view.dart';
import 'restaurant_bottom_sheet.dart';
import 'search_this_area_button.dart';

const fullscreenMapButtonKey = Key('open-fullscreen-map-button');
const nearbyRestaurantListKey = Key('nearby-restaurant-list');
const searchThisAreaButtonKey = Key('search-this-area-button');
const discoverySearchFieldKey = Key('discovery-search-field');
const discoveryResultCountKey = Key('discovery-result-count');

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final categories = ref.watch(discoveryCategoriesProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final rawRestaurants = ref.watch(restaurantsProvider);
    final restaurants = ref.watch(filteredRestaurantsProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final restaurantFeed = ref.watch(restaurantFeedProvider);
    final restaurantQuery = ref.watch(restaurantListQueryProvider);
    final isNearbyMode = restaurantQuery.lat != null &&
        restaurantQuery.lng != null &&
        restaurantQuery.radiusKm != null;
    final locationState = ref.watch(discoveryLocationProvider);

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
              onPressed: locationState.isLoading
                  ? null
                  : () => ref
                      .read(discoveryLocationProvider.notifier)
                      .loadNearbyRestaurants(),
              icon: const Icon(Icons.my_location_rounded),
              label: Text(locationState.isLoading ? '위치 확인 중' : '내 주변 식당'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DiscoverySearchField(
          key: discoverySearchFieldKey,
          query: filter.query,
          iconColor: tokens.primary,
          onChanged: ref.read(discoveryFilterProvider.notifier).updateQuery,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in categories) ...[
                ChoiceChip(
                  key: ValueKey('discovery-category-$category'),
                  selected: filter.selectedCategory == category,
                  label: Text(category),
                  onSelected: (_) => ref
                      .read(discoveryFilterProvider.notifier)
                      .selectCategory(category),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (locationState.status != DiscoveryLocationStatus.initial) ...[
          _LocationStatusCard(state: locationState),
          const SizedBox(height: 12),
        ],
        restaurantFeed.when(
          data: (_) {
            final message = _resultStatusMessage(
              rawCount: rawRestaurants.length,
              filteredCount: restaurants.length,
              filter: filter,
              isNearbyMode: isNearbyMode,
            );
            return _RestaurantFeedStatus(
              key: discoveryResultCountKey,
              message: message,
              icon: Icons.restaurant_rounded,
            );
          },
          loading: () => const _RestaurantFeedStatus(
            message: '식당 목록을 불러오는 중이에요.',
            icon: Icons.sync_rounded,
            showProgress: true,
          ),
          error: (error, _) => _RestaurantFeedStatus(
            message:
                error is ApiError ? error.userMessage : '맛집 목록을 불러오지 못했어요.',
            icon: Icons.error_outline_rounded,
            onRetry: () => ref.invalidate(restaurantFeedProvider),
          ),
        ),
        const SizedBox(height: 12),
        const _DiscoveryMapSection(),
        const SizedBox(height: 12),
        const _MapLegendRow(),
        const SizedBox(height: 16),
        if (restaurants.isNotEmpty) ...[
          Text(
            isNearbyMode ? '내 주변 식당' : '식당 목록',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _RestaurantList(
            key: nearbyRestaurantListKey,
            restaurants: restaurants,
            selectedRestaurantId: selectedRestaurant?.id,
            onSelect: (restaurantId) => _selectRestaurant(
              context,
              ref,
              restaurantId,
              focusCamera: true,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (selectedRestaurant != null)
          RestaurantBottomSheet(restaurant: selectedRestaurant)
        else if (restaurants.isEmpty)
          MukkingCard(
            child: Text(
              _emptyStateMessage(
                rawRestaurants: rawRestaurants,
                filter: filter,
                isNearbyMode: isNearbyMode,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _DiscoverySearchField extends StatefulWidget {
  const _DiscoverySearchField({
    required this.query,
    required this.iconColor,
    required this.onChanged,
    super.key,
  });

  final String query;
  final Color iconColor;
  final ValueChanged<String> onChanged;

  @override
  State<_DiscoverySearchField> createState() => _DiscoverySearchFieldState();
}

class _DiscoverySearchFieldState extends State<_DiscoverySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _DiscoverySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.query,
      selection: TextSelection.collapsed(offset: widget.query.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search_rounded, color: widget.iconColor),
        hintText: '맛집, 음식, 지역 검색',
      ),
    );
  }
}

String _resultStatusMessage({
  required int rawCount,
  required int filteredCount,
  required DiscoveryFilterState filter,
  required bool isNearbyMode,
}) {
  if (rawCount == 0) {
    return isNearbyMode ? '현재 위치 5km 안에 등록된 식당이 없어요.' : '현재 지역에 등록된 식당이 없어요.';
  }
  if (filter.isActive) return '전체 $rawCount곳 중 $filteredCount곳';
  return isNearbyMode
      ? '현재 위치 5km 안의 식당 $filteredCount곳을 불러왔어요.'
      : '식당 $filteredCount곳을 불러왔어요.';
}

String _emptyStateMessage({
  required List<Restaurant> rawRestaurants,
  required DiscoveryFilterState filter,
  required bool isNearbyMode,
}) {
  if (rawRestaurants.isEmpty) {
    return isNearbyMode ? '현재 위치 5km 안에 등록된 식당이 없어요.' : '현재 지역에 등록된 식당이 없어요.';
  }

  final query = filter.query.trim();
  if (query.isNotEmpty) return "'$query' 검색 결과가 없어요.";
  if (filter.selectedCategory != allRestaurantCategory) {
    return '현재 지역에 선택한 카테고리 식당이 없어요.';
  }
  return '조건에 맞는 식당이 없어요.';
}

class _DiscoveryMapSection extends ConsumerWidget {
  const _DiscoveryMapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(filteredRestaurantsProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final selectedRestaurantFocusRequest =
        ref.watch(selectedRestaurantFocusRequestProvider);
    final parties = ref.watch(matchingPartiesProvider).valueOrNull ?? const [];
    final config = ref.watch(appConfigProvider);
    final kakaoMapReady = ref.watch(kakaoMapReadyProvider);
    final location = ref.watch(
      discoveryLocationProvider.select((state) => state.location),
    );
    final urgentRestaurantIds = parties
        .where((party) => party.isUrgent)
        .map((party) => party.restaurantId)
        .toSet();
    final markers = buildRestaurantMapMarkers(
      restaurants,
      urgentRestaurantIds: urgentRestaurantIds,
    );

    return Stack(
      children: [
        RestaurantMapView(
          enableMap: config.hasAnyKakaoMapConfig && kakaoMapReady,
          restaurants: restaurants,
          markers: markers,
          selectedRestaurantId: selectedRestaurant?.id,
          focusSelectedRestaurantRequest: selectedRestaurantFocusRequest,
          userLocation: location,
          onMarkerSelected: (restaurantId) => _selectRestaurant(
            context,
            ref,
            restaurantId,
            focusCamera: false,
          ),
          onCameraIdle: ref.read(searchAreaProvider.notifier).onCameraIdle,
        ),
        const Positioned(
          top: 12,
          left: 60,
          right: 60,
          child: Center(
            child: SearchThisAreaButton(
              buttonKey: searchThisAreaButtonKey,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(16),
            child: IconButton.filledTonal(
              key: fullscreenMapButtonKey,
              tooltip: '전체 화면 지도',
              onPressed: () => context.push(AppRoutes.discoveryMap),
              icon: const Icon(Icons.fullscreen_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

void _selectRestaurant(
  BuildContext context,
  WidgetRef ref,
  String restaurantId, {
  required bool focusCamera,
}) {
  final restaurant = ref.read(restaurantByIdProvider(restaurantId));
  if (restaurant == null) return;

  ref.read(selectedRestaurantIdProvider.notifier).state = restaurantId;
  if (focusCamera) {
    ref.read(selectedRestaurantFocusRequestProvider.notifier).state += 1;
  }
  showRestaurantDetailsSheet(context, restaurantId: restaurantId);
}

class _RestaurantFeedStatus extends StatelessWidget {
  const _RestaurantFeedStatus({
    required this.message,
    required this.icon,
    this.onRetry,
    this.showProgress = false,
    super.key,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        if (showProgress)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.primary,
            ),
          )
        else
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

class _LocationStatusCard extends ConsumerWidget {
  const _LocationStatusCard({required this.state});

  final DiscoveryLocationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final controller = ref.read(discoveryLocationProvider.notifier);
    final (icon, message) = switch (state.status) {
      DiscoveryLocationStatus.requestingPermission => (
          Icons.location_searching_rounded,
          '위치 권한을 확인하고 있어요.'
        ),
      DiscoveryLocationStatus.loadingLocation => (
          Icons.location_searching_rounded,
          '현재 위치를 찾고 있어요.'
        ),
      DiscoveryLocationStatus.loadingRestaurants => (
          Icons.restaurant_rounded,
          '내 주변 맛집을 불러오고 있어요.'
        ),
      DiscoveryLocationStatus.restaurantError => (
          Icons.error_outline_rounded,
          state.message ?? '주변 식당을 불러오지 못했어요.'
        ),
      DiscoveryLocationStatus.permissionDenied => (
          Icons.location_off_rounded,
          state.message ?? '위치 권한이 필요해요.'
        ),
      DiscoveryLocationStatus.permissionDeniedForever => (
          Icons.settings_rounded,
          state.message ?? '앱 설정에서 권한을 허용해주세요.'
        ),
      DiscoveryLocationStatus.serviceDisabled => (
          Icons.gps_off_rounded,
          state.message ?? '위치 서비스가 꺼져 있어요.'
        ),
      DiscoveryLocationStatus.ready => (
          Icons.near_me_rounded,
          state.message ?? '내 주변 맛집을 표시하고 있어요.'
        ),
      DiscoveryLocationStatus.error => (
          Icons.error_outline_rounded,
          state.message ?? '위치를 불러오지 못했어요.'
        ),
      DiscoveryLocationStatus.initial => (
          Icons.my_location_rounded,
          '내 주변 식당을 찾아보세요.'
        ),
    };

    return MukkingCard(
      child: Row(
        children: [
          Icon(icon, color: tokens.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (state.status == DiscoveryLocationStatus.serviceDisabled)
            TextButton(
              onPressed: controller.openLocationSettings,
              child: const Text('위치 설정'),
            )
          else if (state.status ==
              DiscoveryLocationStatus.permissionDeniedForever)
            TextButton(
              onPressed: controller.openAppSettings,
              child: const Text('앱 설정'),
            )
          else if (state.status == DiscoveryLocationStatus.permissionDenied ||
              state.status == DiscoveryLocationStatus.error ||
              state.status == DiscoveryLocationStatus.restaurantError)
            TextButton(
              onPressed: controller.loadNearbyRestaurants,
              child: const Text('다시 시도'),
            )
          else if (state.status == DiscoveryLocationStatus.ready)
            TextButton(
              onPressed: controller.useGeneralRestaurantList,
              child: const Text('일반 목록'),
            ),
        ],
      ),
    );
  }
}

class _RestaurantList extends StatelessWidget {
  const _RestaurantList({
    required this.restaurants,
    required this.selectedRestaurantId,
    required this.onSelect,
    super.key,
  });

  final List<Restaurant> restaurants;
  final String? selectedRestaurantId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: restaurants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final selected = restaurant.id == selectedRestaurantId;
          return InkWell(
            key: ValueKey('nearby-restaurant-card-${restaurant.id}'),
            onTap: () => onSelect(restaurant.id),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 250,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? tokens.primary.withValues(alpha: 0.1)
                    : tokens.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? tokens.primary
                      : tokens.textSecondary.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            if (restaurant.category.isNotEmpty)
                              restaurant.category,
                            restaurant.distanceLabel,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        restaurant.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: restaurant.isFavorite
                            ? tokens.favorite
                            : tokens.textSecondary,
                      ),
                    ],
                  ),
                  if (restaurant.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 17, color: tokens.partyHot),
                      const SizedBox(width: 5),
                      Text(
                        '모집 중 ${restaurant.activePartyCount}개',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: tokens.partyHot,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
