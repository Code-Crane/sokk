import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_client.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/core/network/dio_provider.dart';
import 'package:mukking_flutter_app/core/theme/app_theme.dart';
import 'package:mukking_flutter_app/core/theme/theme_tokens.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_state.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_api.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_repository.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/domain/map_camera_center.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant_map_marker.dart';
import 'package:mukking_flutter_app/features/discovery/domain/user_location.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/map/kakao_marker_adapter.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/map/kakao_cluster_policy.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/map/restaurant_camera_policy.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/map/restaurant_map_view.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/search_this_area_button.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_location_provider.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';

void main() {
  test('permission denied keeps the general restaurant query', () async {
    final location = _FakeLocationService(
      checkedPermission: AppLocationPermission.denied,
      requestedPermission: AppLocationPermission.denied,
    );
    final repository = _RecordingRestaurantRepository();
    final container = _container(location, repository);
    addTearDown(container.dispose);

    await container
        .read(discoveryLocationProvider.notifier)
        .loadNearbyRestaurants();

    expect(
      container.read(discoveryLocationProvider).status,
      DiscoveryLocationStatus.permissionDenied,
    );
    final query = container.read(restaurantListQueryProvider);
    expect(query.lat, isNull);
    expect(query.lng, isNull);
    expect(repository.queries, isEmpty);
  });

  test('disabled location service exposes a recoverable state', () async {
    final location = _FakeLocationService(serviceEnabled: false);
    final repository = _RecordingRestaurantRepository();
    final container = _container(location, repository);
    addTearDown(container.dispose);

    await container
        .read(discoveryLocationProvider.notifier)
        .loadNearbyRestaurants();

    expect(
      container.read(discoveryLocationProvider).status,
      DiscoveryLocationStatus.serviceDisabled,
    );
    expect(repository.queries, isEmpty);
  });

  test('available location sends nearby query parameters to repository',
      () async {
    final location = _FakeLocationService(
      checkedPermission: AppLocationPermission.whileInUse,
      currentLocation: const UserLocation(
        latitude: 37.5447,
        longitude: 127.0557,
      ),
    );
    final repository = _RecordingRestaurantRepository();
    final container = _container(location, repository);
    addTearDown(container.dispose);

    await container
        .read(discoveryLocationProvider.notifier)
        .loadNearbyRestaurants();

    final state = container.read(discoveryLocationProvider);
    expect(state.status, DiscoveryLocationStatus.ready);
    expect(state.location?.latitude, 37.5447);
    expect(repository.queries, hasLength(1));
    expect(repository.queries.single.lat, 37.5447);
    expect(repository.queries.single.lng, 127.0557);
    expect(
      repository.queries.single.radiusKm,
      DiscoveryLocationController.nearbyRadiusKm,
    );
  });

  test('nearby refresh replaces an already-loaded general request', () async {
    final location = _FakeLocationService(
      checkedPermission: AppLocationPermission.whileInUse,
      currentLocation: const UserLocation(
        latitude: 37.5447,
        longitude: 127.0557,
      ),
    );
    final repository = _RecordingRestaurantRepository();
    final container = _container(location, repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      restaurantFeedProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(restaurantFeedProvider.future);
    expect(repository.queries.single.lat, isNull);

    await container
        .read(discoveryLocationProvider.notifier)
        .loadNearbyRestaurants();

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.lat, 37.5447);
    expect(repository.queries.last.lng, 127.0557);
    expect(repository.queries.last.radiusKm, 5);
  });

  test('location lookup failure does not send a nearby request', () async {
    final repository = _RecordingRestaurantRepository();
    final container = _container(
      _ThrowingLocationService(),
      repository,
    );
    addTearDown(container.dispose);

    await container
        .read(discoveryLocationProvider.notifier)
        .loadNearbyRestaurants();

    expect(
      container.read(discoveryLocationProvider).status,
      DiscoveryLocationStatus.error,
    );
    expect(repository.queries, isEmpty);
  });

  test('restaurant API failure is distinct from a location failure', () async {
    final location = _FakeLocationService(
      checkedPermission: AppLocationPermission.whileInUse,
    );
    final container = _container(
      location,
      _ThrowingRestaurantRepository(),
    );
    addTearDown(container.dispose);

    await container
        .read(discoveryLocationProvider.notifier)
        .loadNearbyRestaurants();

    final state = container.read(discoveryLocationProvider);
    expect(state.status, DiscoveryLocationStatus.restaurantError);
    expect(state.location, isNotNull);
    expect(state.message, '주변 식당을 불러오지 못했어요.');
  });

  test('restaurant API serializes nearby and general queries separately',
      () async {
    final adapter = _RestaurantListRecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = adapter;
    final api = RestaurantApi(ApiClient(dio));

    await api.list(
      const RestaurantListQuery(
        lat: 37.5447,
        lng: 127.0557,
        radiusKm: 5,
        limit: 50,
        offset: 0,
      ),
    );
    await api.list(const RestaurantListQuery(limit: 50, offset: 0));

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.path, '/api/restaurants');
    expect(
      adapter.requests.first.queryParameters,
      containsPair('lat', 37.5447),
    );
    expect(
      adapter.requests.first.queryParameters,
      containsPair('lng', 127.0557),
    );
    expect(
      adapter.requests.first.queryParameters,
      containsPair('radiusKm', 5.0),
    );
    expect(adapter.requests.first.queryParameters['limit'], 50);
    expect(adapter.requests.first.queryParameters['offset'], 0);
    expect(adapter.requests.last.queryParameters.containsKey('lat'), isFalse);
    expect(adapter.requests.last.queryParameters.containsKey('lng'), isFalse);
    expect(
      adapter.requests.last.queryParameters.containsKey('radiusKm'),
      isFalse,
    );
  });

  test('restaurant discovery POST serializes center and fixed radius',
      () async {
    final adapter = _RestaurantListRecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = adapter;
    final api = RestaurantApi(ApiClient(dio));

    await api.discover(
      const RestaurantDiscoverRequest(
        latitude: 35.1146,
        longitude: 129.037,
        radiusKm: 2,
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/restaurants/discover');
    expect(request.data, {
      'latitude': 35.1146,
      'longitude': 129.037,
      'radiusKm': 2.0,
    });
  });

  test('map movement only exposes search and never auto-discovers', () async {
    final repository = _SearchAreaRestaurantRepository();
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final controller = container.read(searchAreaProvider.notifier);

    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.1146, longitude: 129.037),
        userInitiated: false,
      ),
    );
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.12, longitude: 129.045),
        userInitiated: true,
      ),
    );

    expect(container.read(searchAreaProvider).hasMovedMeaningfully, isTrue);
    expect(repository.discoverRequests, isEmpty);
  });

  test('search posts once, refreshes nearby and resets without camera focus',
      () async {
    final repository = _SearchAreaRestaurantRepository();
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final controller = container.read(searchAreaProvider.notifier);
    const movedCenter = MapCameraCenter(
      latitude: 35.12,
      longitude: 129.045,
    );
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.1146, longitude: 129.037),
        userInitiated: false,
      ),
    );
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: movedCenter,
        userInitiated: true,
      ),
    );
    final focusBefore = container.read(
      selectedRestaurantFocusRequestProvider,
    );

    expect(await controller.searchCurrentArea(), isTrue);

    expect(repository.discoverRequests, hasLength(1));
    expect(repository.discoverRequests.single.latitude, movedCenter.latitude);
    expect(repository.discoverRequests.single.longitude, movedCenter.longitude);
    expect(repository.discoverRequests.single.radiusKm, 2);
    expect(repository.queries.last.lat, movedCenter.latitude);
    expect(repository.queries.last.lng, movedCenter.longitude);
    expect(repository.queries.last.radiusKm, 2);
    expect(container.read(searchAreaProvider).hasMovedMeaningfully, isFalse);
    expect(
      container.read(selectedRestaurantFocusRequestProvider),
      focusBefore,
    );
  });

  test('duplicate search tap is ignored while discovery is in flight',
      () async {
    final completer = Completer<void>();
    final repository = _SearchAreaRestaurantRepository(
      discoveryGate: completer.future,
    );
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final controller = container.read(searchAreaProvider.notifier);
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.1, longitude: 129.0),
        userInitiated: false,
      ),
    );
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.2, longitude: 129.1),
        userInitiated: true,
      ),
    );

    final first = controller.searchCurrentArea();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.searchCurrentArea(), isFalse);
    expect(repository.discoverRequests, hasLength(1));
    completer.complete();
    expect(await first, isTrue);
  });

  test('failed discovery preserves restaurants and remains retryable',
      () async {
    final repository = _SearchAreaRestaurantRepository(failDiscovery: true);
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final before = container.read(restaurantsProvider);
    final controller = container.read(searchAreaProvider.notifier);
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.1, longitude: 129.0),
        userInitiated: false,
      ),
    );
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.2, longitude: 129.1),
        userInitiated: true,
      ),
    );

    expect(await controller.searchCurrentArea(), isFalse);

    final state = container.read(searchAreaProvider);
    expect(state.status, SearchAreaStatus.error);
    expect(state.hasMovedMeaningfully, isTrue);
    final after = container.read(restaurantsProvider);
    expect(after.map((restaurant) => restaurant.id),
        before.map((restaurant) => restaurant.id));
    expect(after.single.isFavorite, before.single.isFavorite);
  });

  test('successful nearby refresh is not failed by favorite hydration',
      () async {
    final repository = _SearchAreaRestaurantRepository(failFavorites: true);
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final controller = container.read(searchAreaProvider.notifier);
    _moveSearchArea(controller);

    expect(await controller.searchCurrentArea(), isTrue);
    expect(container.read(searchAreaProvider).status, SearchAreaStatus.idle);
    expect(container.read(searchAreaProvider).errorMessage, isNull);
    expect(container.read(restaurantsProvider), isNotEmpty);
  });

  testWidgets('successful rendered data never shows a false error snackbar',
      (tester) async {
    final repository = _SearchAreaRestaurantRepository(failFavorites: true);
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    _moveSearchArea(container.read(searchAreaProvider.notifier));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: SearchThisAreaButton())),
        ),
      ),
    );

    await tester.tap(find.text('이 지역에서 다시 검색'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('이 지역의 식당을 불러오지 못했어요. 다시 시도해주세요.'), findsNothing);
    expect(container.read(restaurantsProvider), isNotEmpty);
  });

  test('actual nearby refresh failure remains an error', () async {
    final repository = _SearchAreaRestaurantRepository(
      failNearbyRefresh: true,
    );
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final before = container.read(restaurantsProvider);
    final controller = container.read(searchAreaProvider.notifier);
    _moveSearchArea(controller);

    expect(await controller.searchCurrentArea(), isFalse);

    final state = container.read(searchAreaProvider);
    expect(state.status, SearchAreaStatus.error);
    expect(state.errorMessage, isNotNull);
    final after = container.read(restaurantsProvider);
    expect(
      after.map((restaurant) => restaurant.id),
      before.map((restaurant) => restaurant.id),
    );
    expect(after.single.isFavorite, before.single.isFavorite);
  });

  test('cancelled stale refresh yields to the active feed generation',
      () async {
    final staleGate = Completer<void>();
    final staleStarted = Completer<void>();
    final repository = _SearchAreaRestaurantRepository(
      cancelSecondList: true,
      secondListGate: staleGate.future,
      secondListStarted: staleStarted,
    );
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final controller = container.read(searchAreaProvider.notifier);
    _moveSearchArea(controller);

    final search = controller.searchCurrentArea();
    await staleStarted.future;
    final activeRefresh = container.refresh(restaurantFeedProvider.future);
    await activeRefresh;
    staleGate.complete();

    expect(await search, isTrue);
    expect(container.read(searchAreaProvider).status, SearchAreaStatus.idle);
    expect(container.read(searchAreaProvider).errorMessage, isNull);
    expect(repository.queries, hasLength(3));
  });

  test('304 with reusable cached list body is treated as success', () async {
    final adapter = _StatusListAdapter(statusCode: 304);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = adapter;

    final rows = await ApiClient(dio).getList('/api/restaurants');

    expect(rows, hasLength(1));
    expect(rows.single, containsPair('id', 'cached-restaurant'));
  });

  test('superseded search cannot overwrite the latest center or error state',
      () async {
    final gate = Completer<void>();
    final repository = _SearchAreaRestaurantRepository(
      discoveryGate: gate.future,
    );
    final container = _container(_FakeLocationService(), repository);
    addTearDown(container.dispose);
    await container.read(restaurantFeedProvider.future);
    final controller = container.read(searchAreaProvider.notifier);
    _moveSearchArea(controller);

    final staleSearch = controller.searchCurrentArea();
    await Future<void>.delayed(Duration.zero);
    const latestCenter = MapCameraCenter(latitude: 35.3, longitude: 129.2);
    controller.resetForExternalCenter(latestCenter);
    gate.complete();

    expect(await staleSearch, isTrue);
    final state = container.read(searchAreaProvider);
    expect(state.center, latestCenter);
    expect(state.status, SearchAreaStatus.idle);
    expect(state.errorMessage, isNull);
  });

  test('API provider forwards the nearby query to Dio', () async {
    final adapter = _RestaurantListRecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.test(dataSource: AppDataSource.api),
        ),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
        restaurantAuthStateProvider.overrideWithValue(
          MukkingAuthState.authenticated(
            user: AuthUser.fallback(
              id: 'user-1',
              email: 'user@example.com',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(restaurantListQueryProvider.notifier).state =
        const RestaurantListQuery(
      lat: 37.5447,
      lng: 127.0557,
      radiusKm: 5,
      limit: 50,
      offset: 0,
    );

    await container.read(restaurantFeedProvider.future);

    final request = adapter.requests.singleWhere(
      (item) => item.path == '/api/restaurants',
    );
    expect(request.queryParameters['lat'], 37.5447);
    expect(request.queryParameters['lng'], 127.0557);
    expect(request.queryParameters['radiusKm'], 5.0);
    expect(request.queryParameters['limit'], 50);
    expect(request.queryParameters['offset'], 0);
  });

  test('marker conversion skips missing coordinates and duplicate ids', () {
    final first = _restaurant(id: 'restaurant-1');
    final duplicate = first.copyWith(latitude: 37.6, longitude: 127.1);
    final missing = _restaurant(id: 'restaurant-2').copyWith(
      clearLatitude: true,
      clearLongitude: true,
    );

    final markers = buildRestaurantMapMarkers([first, duplicate, missing]);

    expect(markers, hasLength(1));
    expect(markers.single.id, 'restaurant-1');
    expect(markers.single.latitude, first.latitude);
    expect(markers.single.status, RestaurantMapMarkerStatus.activeParty);
  });

  test('distance label uses backend distanceMeters without recalculation', () {
    expect(_restaurant(id: 'near', distanceMeters: 350).distanceLabel, '350m');
    expect(
      _restaurant(id: 'far', distanceMeters: 1420).distanceLabel,
      '1.4km',
    );
  });

  testWidgets('map fallback keeps restaurant selection available',
      (tester) async {
    final restaurant = _restaurant(id: 'restaurant-1');
    final selectedIds = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(MukkingThemeId.violet),
        home: Scaffold(
          body: RestaurantMapView(
            enableMap: false,
            restaurants: [restaurant],
            markers: buildRestaurantMapMarkers([restaurant]),
            selectedRestaurantId: null,
            focusSelectedRestaurantRequest: 0,
            userLocation: null,
            onMarkerSelected: selectedIds.add,
            onCameraIdle: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Kakao Map 설정 필요'), findsOneWidget);
    await tester.tap(find.text('한식'));
    expect(selectedIds, ['restaurant-1']);
  });

  test('Kakao marker adapter keeps ids, status and current location', () {
    final markers = buildRestaurantMapMarkers([
      const Restaurant(
        id: 'favorite',
        name: '찜 식당',
        category: '한식',
        address: '서울',
        imageUrl: '',
        isFavorite: true,
        activePartyCount: 1,
        latitude: 37.5,
        longitude: 127.0,
        distanceMeters: 400,
        imageLabel: '찜 식당',
        markerDx: 0.5,
        markerDy: 0.5,
      ),
    ]);

    final options = buildKakaoMarkerOptions(
      markers: markers,
      selectedRestaurantId: 'favorite',
      userLocation: const UserLocation(latitude: 37.51, longitude: 127.01),
    );

    expect(options.map((option) => option.id).toSet().length, options.length);
    expect(options.first.id, 'favorite');
    expect(options.first.text, contains('선택 · 찜'));
    expect(options.first.rank, 9000);
    expect(options.last.id, kakaoCurrentLocationMarkerId);
    expect(options.last.text, '내 위치');
    expect(
      isRestaurantMarkerTap(kakaoCurrentLocationMarkerId, markers),
      isFalse,
    );
    expect(isRestaurantMarkerTap('favorite', markers), isTrue);
  });

  test('cluster input contains restaurants only and excludes current location',
      () {
    final markers = buildRestaurantMapMarkers([
      _restaurant(id: 'restaurant-1'),
      _restaurant(id: 'restaurant-2'),
    ]);

    final restaurantOptions = buildKakaoRestaurantMarkerOptions(
      markers: markers,
      selectedRestaurantId: null,
    );
    final locationOption = buildKakaoCurrentLocationMarkerOption(
      const UserLocation(latitude: 35.1, longitude: 129.0),
    );

    expect(restaurantOptions, hasLength(2));
    expect(
      restaurantOptions.any(
        (option) => option.id == kakaoCurrentLocationMarkerId,
      ),
      isFalse,
    );
    expect(locationOption?.id, kakaoCurrentLocationMarkerId);
  });

  test('cluster tap moves camera once and never selects a restaurant',
      () async {
    final bounds = LatLngBounds(
      southwest: const LatLng(latitude: 35.1, longitude: 129.0),
      northeast: const LatLng(latitude: 35.2, longitude: 129.1),
    );
    final event = ClusterClickEvent(
      clustererId: kakaoRestaurantClusterLayerId,
      position: const LatLng(latitude: 35.15, longitude: 129.05),
      size: 12,
      bounds: bounds,
    );
    final cameraUpdates = <CameraUpdate>[];

    final handled = await handleRestaurantClusterTap(
      event,
      moveCamera: (update) async => cameraUpdates.add(update),
      readZoomLevel: () async => 14,
    );

    expect(handled, isTrue);
    expect(event.size, 12);
    expect(cameraUpdates, hasLength(1));
    expect(cameraUpdates.single.position, event.position);
    expect(cameraUpdates.single.zoomLevel, 15);
    expect(cameraUpdates.single.rotationAngle, -1);
    expect(cameraUpdates.single.tiltAngle, -1);
    expect(
      isRestaurantMarkerTap(kakaoRestaurantClusterLayerId, const []),
      isFalse,
    );
  });

  test('cluster visual policy uses three readable count tiers', () {
    final styles = kakaoWebClusterStyles(const Color(0xFF5B3DF5));

    expect(kakaoRestaurantMinClusterSize, 3);
    expect(kakaoRestaurantClusterGridSize, 56);
    expect(kakaoRestaurantMinClusterLevel, 4);
    expect(kakaoRestaurantClusterCalculator, [5, 10]);
    expect(kakaoRestaurantClusterSizes, [36, 42, 48]);
    expect(
      styles.map((style) => style['width']),
      ['36px', '42px', '48px'],
    );
    expect(
      styles.map((style) => style['border-radius']),
      ['18px', '21px', '24px'],
    );
    expect(styles.every((style) => style['text-align'] == 'center'), isTrue);
  });

  test('unrelated cluster event performs no camera work', () async {
    var zoomReads = 0;
    var cameraMoves = 0;
    final handled = await handleRestaurantClusterTap(
      ClusterClickEvent(
        clustererId: 'another-layer',
        position: const LatLng(latitude: 35.15, longitude: 129.05),
        size: 5,
        bounds: LatLngBounds(
          southwest: const LatLng(latitude: 35.1, longitude: 129.0),
          northeast: const LatLng(latitude: 35.2, longitude: 129.1),
        ),
      ),
      readZoomLevel: () async {
        zoomReads += 1;
        return 14;
      },
      moveCamera: (_) async => cameraMoves += 1,
    );

    expect(handled, isFalse);
    expect(zoomReads, 0);
    expect(cameraMoves, 0);
  });

  test('cluster marker sync is incremental for 50 restaurants', () {
    final markers = buildRestaurantMapMarkers([
      for (var index = 0; index < 50; index += 1)
        _restaurant(id: 'restaurant-$index').copyWith(
          latitude: 35.1 + index * .0001,
          longitude: 129.0 + index * .0001,
        ),
    ]);
    final initialOptions = buildKakaoRestaurantMarkerOptions(
      markers: markers,
      selectedRestaurantId: null,
    );
    final initialPlan = buildKakaoMarkerSyncPlan(
      previous: const {},
      next: initialOptions,
    );
    final rendered = {for (final option in initialOptions) option.id: option};
    final noChangePlan = buildKakaoMarkerSyncPlan(
      previous: rendered,
      next: initialOptions,
    );
    final selectedOptions = buildKakaoRestaurantMarkerOptions(
      markers: markers,
      selectedRestaurantId: 'restaurant-25',
    );
    final selectionPlan = buildKakaoMarkerSyncPlan(
      previous: rendered,
      next: selectedOptions,
    );

    expect(initialPlan.optionsToAdd, hasLength(50));
    expect(initialPlan.removedIds, isEmpty);
    expect(noChangePlan.hasChanges, isFalse);
    expect(selectionPlan.removedIds, ['restaurant-25']);
    expect(selectionPlan.optionsToAdd.single.id, 'restaurant-25');
  });

  test('restaurant camera update preserves zoom, rotation and tilt', () {
    const target = RestaurantCameraTarget(
      id: 'restaurant-1',
      latitude: 35.1,
      longitude: 129.0,
    );

    final update = stablePositionCameraUpdate(target);

    expect(update.position?.latitude, target.latitude);
    expect(update.position?.longitude, target.longitude);
    expect(update.zoomLevel, -1);
    expect(update.rotationAngle, -1);
    expect(update.tiltAngle, -1);
  });

  test('rapid camera requests coalesce to the latest restaurant', () async {
    final movedLatitudes = <double>[];
    final coordinator = RestaurantCameraCoordinator(
      debounce: const Duration(milliseconds: 1),
      move: (update) async {
        movedLatitudes.add(update.position!.latitude);
      },
    );
    addTearDown(coordinator.dispose);

    final settled = coordinator.request(
      const RestaurantCameraTarget(id: 'A', latitude: 1, longitude: 1),
    );
    coordinator.request(
      const RestaurantCameraTarget(id: 'B', latitude: 2, longitude: 2),
    );
    coordinator.request(
      const RestaurantCameraTarget(id: 'C', latitude: 3, longitude: 3),
    );
    await settled;

    expect(movedLatitudes, [3]);
  });

  test('an in-flight camera move cannot finish after the latest move',
      () async {
    final firstMove = Completer<void>();
    final movedIds = <double>[];
    final coordinator = RestaurantCameraCoordinator(
      debounce: Duration.zero,
      move: (update) {
        final latitude = update.position!.latitude;
        movedIds.add(latitude);
        return latitude == 1 ? firstMove.future : Future.value();
      },
    );
    addTearDown(coordinator.dispose);

    final settled = coordinator.request(
      const RestaurantCameraTarget(id: 'A', latitude: 1, longitude: 1),
    );
    await Future<void>.delayed(Duration.zero);
    coordinator.request(
      const RestaurantCameraTarget(id: 'B', latitude: 2, longitude: 2),
    );
    coordinator.request(
      const RestaurantCameraTarget(id: 'C', latitude: 3, longitude: 3),
    );
    firstMove.complete();
    await settled;

    expect(movedIds, [1, 3]);
  });
}

ProviderContainer _container(
  LocationService locationService,
  RestaurantRepository repository,
) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig.test()),
      locationServiceProvider.overrideWithValue(locationService),
      restaurantRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void _moveSearchArea(SearchAreaController controller) {
  controller.onCameraIdle(
    const MapCameraIdleEvent(
      center: MapCameraCenter(latitude: 35.1, longitude: 129.0),
      userInitiated: false,
    ),
  );
  controller.onCameraIdle(
    const MapCameraIdleEvent(
      center: MapCameraCenter(latitude: 35.2, longitude: 129.1),
      userInitiated: true,
    ),
  );
}

Restaurant _restaurant({required String id, int? distanceMeters = 800}) {
  return Restaurant(
    id: id,
    name: '테스트 식당',
    category: '한식',
    address: '서울 성동구',
    latitude: 37.5447,
    longitude: 127.0557,
    distanceMeters: distanceMeters,
    imageUrl: '',
    isFavorite: false,
    activePartyCount: 1,
    imageLabel: '테스트 음식',
    markerDx: 0.4,
    markerDy: 0.4,
  );
}

class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.serviceEnabled = true,
    this.checkedPermission = AppLocationPermission.whileInUse,
    this.requestedPermission = AppLocationPermission.whileInUse,
    this.currentLocation = const UserLocation(
      latitude: 37.5,
      longitude: 127.0,
    ),
  });

  final bool serviceEnabled;
  final AppLocationPermission checkedPermission;
  final AppLocationPermission requestedPermission;
  final UserLocation currentLocation;

  @override
  Future<AppLocationPermission> checkPermission() async => checkedPermission;

  @override
  Future<UserLocation> getCurrentLocation() async => currentLocation;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<AppLocationPermission> requestPermission() async =>
      requestedPermission;
}

class _ThrowingLocationService implements LocationService {
  @override
  Future<AppLocationPermission> checkPermission() async =>
      AppLocationPermission.whileInUse;

  @override
  Future<UserLocation> getCurrentLocation() =>
      Future<UserLocation>.error(StateError('location unavailable'));

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<AppLocationPermission> requestPermission() async =>
      AppLocationPermission.whileInUse;
}

class _RecordingRestaurantRepository implements RestaurantRepository {
  final List<RestaurantListQuery> queries = [];

  @override
  Future<List<Restaurant>> discover(RestaurantDiscoverRequest request) async {
    return [_restaurant(id: 'restaurant-discovered')];
  }

  @override
  Future<Restaurant?> getById(String restaurantId) async => null;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async {
    queries.add(query);
    return [_restaurant(id: 'restaurant-api')];
  }

  @override
  Future<List<Restaurant>> listFavorites() async => const [];

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    return restaurant.copyWith(isFavorite: isFavorite);
  }
}

class _ThrowingRestaurantRepository implements RestaurantRepository {
  @override
  Future<List<Restaurant>> discover(RestaurantDiscoverRequest request) {
    return Future<List<Restaurant>>.error(StateError('discovery failed'));
  }

  @override
  Future<Restaurant?> getById(String restaurantId) async => null;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) {
    return Future<List<Restaurant>>.error(StateError('restaurant API failed'));
  }

  @override
  Future<List<Restaurant>> listFavorites() async => const [];

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    return restaurant.copyWith(isFavorite: isFavorite);
  }
}

class _SearchAreaRestaurantRepository implements RestaurantRepository {
  _SearchAreaRestaurantRepository({
    this.failDiscovery = false,
    this.failNearbyRefresh = false,
    this.failFavorites = false,
    this.cancelSecondList = false,
    this.discoveryGate,
    this.secondListGate,
    this.secondListStarted,
  });

  final bool failDiscovery;
  final bool failNearbyRefresh;
  final bool failFavorites;
  final bool cancelSecondList;
  final Future<void>? discoveryGate;
  final Future<void>? secondListGate;
  final Completer<void>? secondListStarted;
  final List<RestaurantListQuery> queries = [];
  final List<RestaurantDiscoverRequest> discoverRequests = [];

  @override
  Future<List<Restaurant>> discover(RestaurantDiscoverRequest request) async {
    discoverRequests.add(request);
    if (discoveryGate != null) await discoveryGate;
    if (failDiscovery) throw StateError('discovery failed');
    return [_restaurant(id: 'restaurant-discovered')];
  }

  @override
  Future<Restaurant?> getById(String restaurantId) async => null;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async {
    queries.add(query);
    final call = queries.length;
    if (call == 2) {
      if (secondListStarted != null && !secondListStarted!.isCompleted) {
        secondListStarted!.complete();
      }
      if (secondListGate != null) await secondListGate;
      if (cancelSecondList) {
        throw const ApiError(
          kind: ApiErrorKind.cancelled,
          userMessage: 'stale request cancelled',
        );
      }
      if (failNearbyRefresh) {
        throw const ApiError(
          kind: ApiErrorKind.server,
          statusCode: 500,
          userMessage: 'nearby request failed',
        );
      }
    }
    return [_restaurant(id: 'restaurant-existing')];
  }

  @override
  Future<List<Restaurant>> listFavorites() async {
    if (failFavorites) throw StateError('favorite hydration failed');
    return const [];
  }

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    return restaurant.copyWith(isFavorite: isFavorite);
  }
}

class _RestaurantListRecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<Object>[]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StatusListAdapter implements HttpClientAdapter {
  _StatusListAdapter({required this.statusCode});

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<Object>[
        <String, Object?>{'id': 'cached-restaurant'},
      ]),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
