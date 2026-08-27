import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geolocator_location_service.dart';
import '../data/restaurant_api.dart';
import '../domain/user_location.dart';
import 'discovery_provider.dart';

enum DiscoveryLocationStatus {
  initial,
  requestingPermission,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  loadingLocation,
  loadingRestaurants,
  restaurantError,
  ready,
  error;
}

class DiscoveryLocationState {
  const DiscoveryLocationState({
    this.status = DiscoveryLocationStatus.initial,
    this.location,
    this.message,
  });

  final DiscoveryLocationStatus status;
  final UserLocation? location;
  final String? message;

  bool get isLoading =>
      status == DiscoveryLocationStatus.requestingPermission ||
      status == DiscoveryLocationStatus.loadingLocation ||
      status == DiscoveryLocationStatus.loadingRestaurants;
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return const GeolocatorLocationService();
});

final discoveryLocationProvider =
    StateNotifierProvider<DiscoveryLocationController, DiscoveryLocationState>(
        (ref) {
  return DiscoveryLocationController(
    ref: ref,
    locationService: ref.watch(locationServiceProvider),
  );
});

class DiscoveryLocationController
    extends StateNotifier<DiscoveryLocationState> {
  DiscoveryLocationController({
    required Ref ref,
    required LocationService locationService,
  })  : _ref = ref,
        _locationService = locationService,
        super(const DiscoveryLocationState());

  static const nearbyRadiusKm = 5.0;

  final Ref _ref;
  final LocationService _locationService;

  Future<void> loadNearbyRestaurants() async {
    if (state.isLoading) return;

    try {
      if (!await _locationService.isServiceEnabled()) {
        state = const DiscoveryLocationState(
          status: DiscoveryLocationStatus.serviceDisabled,
          message: '위치 서비스가 꺼져 있어요.',
        );
        return;
      }

      var permission = await _locationService.checkPermission();
      if (permission == AppLocationPermission.denied) {
        state = const DiscoveryLocationState(
          status: DiscoveryLocationStatus.requestingPermission,
        );
        permission = await _locationService.requestPermission();
      }

      if (permission == AppLocationPermission.deniedForever) {
        state = const DiscoveryLocationState(
          status: DiscoveryLocationStatus.permissionDeniedForever,
          message: '앱 설정에서 위치 권한을 허용해주세요.',
        );
        return;
      }

      if (!permission.isGranted) {
        state = const DiscoveryLocationState(
          status: DiscoveryLocationStatus.permissionDenied,
          message: '위치 권한 없이도 일반 맛집 목록을 볼 수 있어요.',
        );
        return;
      }

      state = const DiscoveryLocationState(
        status: DiscoveryLocationStatus.loadingLocation,
      );
      final location = await _locationService.getCurrentLocation();

      state = DiscoveryLocationState(
        status: DiscoveryLocationStatus.loadingRestaurants,
        location: location,
      );
      _ref.read(restaurantListQueryProvider.notifier).state =
          RestaurantListQuery(
        lat: location.latitude,
        lng: location.longitude,
        radiusKm: nearbyRadiusKm,
        limit: 50,
        offset: 0,
      );
      try {
        final _ = await _ref.refresh(restaurantFeedProvider.future);
      } catch (_) {
        state = DiscoveryLocationState(
          status: DiscoveryLocationStatus.restaurantError,
          location: location,
          message: '주변 식당을 불러오지 못했어요.',
        );
        return;
      }

      state = DiscoveryLocationState(
        status: DiscoveryLocationStatus.ready,
        location: location,
        message: '현재 위치 기준 ${nearbyRadiusKm.toInt()}km 맛집이에요.',
      );
    } on TimeoutException {
      state = const DiscoveryLocationState(
        status: DiscoveryLocationStatus.error,
        message: '현재 위치를 확인하는 데 시간이 오래 걸리고 있어요.',
      );
    } catch (_) {
      state = const DiscoveryLocationState(
        status: DiscoveryLocationStatus.error,
        message: '현재 위치를 불러오지 못했어요. 일반 목록은 계속 볼 수 있어요.',
      );
    }
  }

  void useGeneralRestaurantList() {
    _ref.read(restaurantListQueryProvider.notifier).state =
        const RestaurantListQuery(limit: 50, offset: 0);
    state = const DiscoveryLocationState();
  }

  Future<void> openAppSettings() => _locationService.openAppSettings();

  Future<void> openLocationSettings() =>
      _locationService.openLocationSettings();
}
