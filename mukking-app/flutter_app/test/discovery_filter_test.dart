import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_api.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_repository.dart';
import 'package:mukking_flutter_app/features/discovery/domain/discovery_filter.dart';
import 'package:mukking_flutter_app/features/discovery/domain/map_camera_center.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/fullscreen_map_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/restaurant_bottom_sheet.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  group('restaurant discovery filter', () {
    test('normalizes whitespace and supports partial name/category search', () {
      final restaurants = [
        _restaurant(
          id: 'chicken',
          name: '평산 치킨',
          category: '음식점 > 치킨',
        ),
        _restaurant(
          id: 'korean',
          name: '부산 평산옥',
          category: '음식점 > 한식',
        ),
      ];

      expect(normalizeRestaurantSearch('  평 산  '), '평산');
      expect(
        filterRestaurants(
          restaurants,
          const DiscoveryFilterState(query: '평산'),
        ).map((restaurant) => restaurant.id),
        ['chicken', 'korean'],
      );
      expect(
        filterRestaurants(
          restaurants,
          const DiscoveryFilterState(query: '치킨'),
        ).single.id,
        'chicken',
      );
    });

    test('maps Kakao categories into the compact UI taxonomy', () {
      expect(mapRestaurantCategory('음식점 > 한식 > 육류,고기'), '고기');
      expect(mapRestaurantCategory('음식점 > 카페'), '카페/디저트');
      expect(mapRestaurantCategory('음식점 > 일식 > 이자카야'), '술집');
      expect(mapRestaurantCategory('음식점 > 중식'), '중식');
      expect(mapRestaurantCategory('알 수 없는 분류'), '기타');
    });

    test('combines query and category with AND semantics', () {
      final restaurants = [
        _restaurant(
          id: 'korean-busan',
          name: '부산 국밥',
          category: '음식점 > 한식',
        ),
        _restaurant(
          id: 'japanese-busan',
          name: '부산 라멘',
          category: '음식점 > 일식',
        ),
      ];

      final filtered = filterRestaurants(
        restaurants,
        const DiscoveryFilterState(query: '부산', selectedCategory: '한식'),
      );

      expect(filtered.map((restaurant) => restaurant.id), ['korean-busan']);
    });

    test('applies favorites and active-party quick filters with AND semantics',
        () {
      final restaurants = [
        _restaurant(
          id: 'favorite-active',
          name: '찜 모집 식당',
          category: '한식',
          isFavorite: true,
          activePartyCount: 2,
        ),
        _restaurant(
          id: 'favorite-idle',
          name: '찜 식당',
          category: '한식',
          isFavorite: true,
        ),
        _restaurant(
          id: 'normal-active',
          name: '모집 식당',
          category: '한식',
          activePartyCount: 1,
        ),
      ];

      expect(
        filterRestaurants(
          restaurants,
          const DiscoveryFilterState(favoritesOnly: true),
        ).map((restaurant) => restaurant.id),
        ['favorite-active', 'favorite-idle'],
      );
      expect(
        filterRestaurants(
          restaurants,
          const DiscoveryFilterState(activePartyOnly: true),
        ).map((restaurant) => restaurant.id),
        ['favorite-active', 'normal-active'],
      );
      expect(
        filterRestaurants(
          restaurants,
          const DiscoveryFilterState(
            favoritesOnly: true,
            activePartyOnly: true,
          ),
        ).map((restaurant) => restaurant.id),
        ['favorite-active'],
      );
    });

    test('combines search category quick filters and sort in one pipeline', () {
      final restaurants = [
        _restaurant(
          id: 'favorite-one',
          name: '부산 치킨 A',
          category: '음식점 > 치킨',
          isFavorite: true,
          activePartyCount: 1,
        ),
        _restaurant(
          id: 'favorite-three',
          name: '부산 치킨 B',
          category: '음식점 > 치킨',
          isFavorite: true,
          activePartyCount: 3,
        ),
        _restaurant(
          id: 'normal-four',
          name: '부산 치킨 C',
          category: '음식점 > 치킨',
          activePartyCount: 4,
        ),
        _restaurant(
          id: 'favorite-korean',
          name: '부산 국밥',
          category: '음식점 > 한식',
          isFavorite: true,
          activePartyCount: 5,
        ),
      ];

      final visible = filterAndSortRestaurants(
        restaurants,
        const DiscoveryFilterState(
          query: '부산',
          selectedCategory: '치킨',
          favoritesOnly: true,
          activePartyOnly: true,
          selectedSort: RestaurantSortOption.activePartyCount,
        ),
      );

      expect(
        visible.map((restaurant) => restaurant.id),
        ['favorite-three', 'favorite-one'],
      );
    });

    test('sorts distance ascending with null last and deterministic ties', () {
      final restaurants = [
        _restaurant(
          id: 'null-distance',
          name: '거리 없음',
          category: '한식',
          distanceMeters: null,
        ),
        _restaurant(
          id: 'tie-b',
          name: '동률 B',
          category: '한식',
          distanceMeters: 300,
        ),
        _restaurant(
          id: 'nearest',
          name: '가장 가까움',
          category: '한식',
          distanceMeters: 120,
        ),
        _restaurant(
          id: 'tie-a',
          name: '동률 A',
          category: '한식',
          distanceMeters: 300,
        ),
      ];

      final sorted = filterAndSortRestaurants(
        restaurants,
        const DiscoveryFilterState(),
      );

      expect(
        sorted.map((restaurant) => restaurant.id),
        ['nearest', 'tie-a', 'tie-b', 'null-distance'],
      );
    });

    test('sorts active parties descending then distance and id', () {
      final restaurants = [
        _restaurant(
          id: 'one-party',
          name: '한 파티',
          category: '한식',
          distanceMeters: 50,
          activePartyCount: 1,
        ),
        _restaurant(
          id: 'three-far',
          name: '세 파티 먼 곳',
          category: '한식',
          distanceMeters: 800,
          activePartyCount: 3,
        ),
        _restaurant(
          id: 'three-near-b',
          name: '세 파티 가까운 B',
          category: '한식',
          distanceMeters: 200,
          activePartyCount: 3,
        ),
        _restaurant(
          id: 'three-near-a',
          name: '세 파티 가까운 A',
          category: '한식',
          distanceMeters: 200,
          activePartyCount: 3,
        ),
      ];

      final sorted = filterAndSortRestaurants(
        restaurants,
        const DiscoveryFilterState(
          selectedSort: RestaurantSortOption.activePartyCount,
        ),
      );

      expect(
        sorted.map((restaurant) => restaurant.id),
        ['three-near-a', 'three-near-b', 'three-far', 'one-party'],
      );
    });

    test('sorts favorites first and each group by distance', () {
      final restaurants = [
        _restaurant(
          id: 'normal-near',
          name: '일반 가까움',
          category: '한식',
          distanceMeters: 100,
        ),
        _restaurant(
          id: 'favorite-far',
          name: '찜 멀리',
          category: '한식',
          distanceMeters: 900,
          isFavorite: true,
        ),
        _restaurant(
          id: 'normal-far',
          name: '일반 멀리',
          category: '한식',
          distanceMeters: 700,
        ),
        _restaurant(
          id: 'favorite-near',
          name: '찜 가까움',
          category: '한식',
          distanceMeters: 300,
          isFavorite: true,
        ),
      ];

      final sorted = filterAndSortRestaurants(
        restaurants,
        const DiscoveryFilterState(
          selectedSort: RestaurantSortOption.favoriteFirst,
        ),
      );

      expect(
        sorted.map((restaurant) => restaurant.id),
        ['favorite-near', 'favorite-far', 'normal-near', 'normal-far'],
      );
    });

    test('applies search category and sort through one visible source', () {
      final restaurants = [
        _restaurant(
          id: 'korean-one',
          name: '부산 국밥 A',
          category: '음식점 > 한식',
          activePartyCount: 1,
        ),
        _restaurant(
          id: 'korean-three',
          name: '부산 국밥 B',
          category: '음식점 > 한식',
          activePartyCount: 3,
        ),
        _restaurant(
          id: 'japanese-four',
          name: '부산 라멘',
          category: '음식점 > 일식',
          activePartyCount: 4,
        ),
      ];

      final visible = filterAndSortRestaurants(
        restaurants,
        const DiscoveryFilterState(
          query: '부산',
          selectedCategory: '한식',
          selectedSort: RestaurantSortOption.activePartyCount,
        ),
      );

      expect(
        visible.map((restaurant) => restaurant.id),
        ['korean-three', 'korean-one'],
      );
    });

    test('provider exposes one shared filtered source and clears selection',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      container.read(selectedRestaurantIdProvider.notifier).state =
          'restaurant-001';
      final focusBefore =
          container.read(selectedRestaurantFocusRequestProvider);

      container.read(discoveryFilterProvider.notifier).selectCategory('고기');

      expect(container.read(filteredRestaurantsProvider), hasLength(1));
      expect(container.read(filteredRestaurantsProvider).single.id,
          'restaurant-002');
      expect(container.read(selectedRestaurantIdProvider), isNull);
      expect(
        container.read(selectedRestaurantFocusRequestProvider),
        focusBefore,
      );
      expect(
        container.read(discoveryCategoriesProvider),
        [allRestaurantCategory, '일식', '양식', '고기', '카페/디저트'],
      );
    });

    test('search-this-area refresh preserves query and category', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      container.read(discoveryFilterProvider.notifier)
        ..updateQuery('성수')
        ..selectCategory('고기')
        ..selectSort(RestaurantSortOption.activePartyCount)
        ..toggleFavoritesOnly()
        ..toggleActivePartyOnly();
      final controller = container.read(searchAreaProvider.notifier);
      controller.onCameraIdle(
        const MapCameraIdleEvent(
          center: MapCameraCenter(latitude: 35.1, longitude: 129),
          userInitiated: false,
        ),
      );
      controller.onCameraIdle(
        const MapCameraIdleEvent(
          center: MapCameraCenter(latitude: 35.2, longitude: 129.1),
          userInitiated: true,
        ),
      );

      expect(await controller.searchCurrentArea(), isTrue);
      expect(container.read(discoveryFilterProvider).query, '성수');
      expect(
        container.read(discoveryFilterProvider).selectedCategory,
        '고기',
      );
      expect(
        container.read(discoveryFilterProvider).selectedSort,
        RestaurantSortOption.activePartyCount,
      );
      expect(container.read(discoveryFilterProvider).favoritesOnly, isTrue);
      expect(container.read(discoveryFilterProvider).activePartyOnly, isTrue);
    });

    test('quick filters stay client-side and clear only excluded selection',
        () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(
          id: 'favorite-active',
          name: '찜 모집 식당',
          category: '한식',
          isFavorite: true,
          activePartyCount: 1,
        ),
        _restaurant(
          id: 'favorite-idle',
          name: '찜 식당',
          category: '한식',
          isFavorite: true,
        ),
        _restaurant(
          id: 'normal-active',
          name: '일반 모집 식당',
          category: '한식',
          activePartyCount: 2,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      final searchController = container.read(searchAreaProvider.notifier);
      searchController.onCameraIdle(
        const MapCameraIdleEvent(
          center: MapCameraCenter(latitude: 35.1, longitude: 129),
          userInitiated: false,
        ),
      );
      final centerBefore = container.read(searchAreaProvider).center;
      final focusBefore =
          container.read(selectedRestaurantFocusRequestProvider);
      container.read(selectedRestaurantIdProvider.notifier).state =
          'favorite-idle';

      container.read(discoveryFilterProvider.notifier).toggleFavoritesOnly();
      expect(container.read(selectedRestaurantIdProvider), 'favorite-idle');
      container.read(discoveryFilterProvider.notifier).toggleActivePartyOnly();

      expect(container.read(selectedRestaurantIdProvider), isNull);
      expect(repository.listCalls, 1);
      expect(repository.discoverCalls, 0);
      expect(container.read(searchAreaProvider).center, centerBefore);
      expect(
        container.read(selectedRestaurantFocusRequestProvider),
        focusBefore,
      );
      expect(
        container
            .read(filteredRestaurantsProvider)
            .map((restaurant) => restaurant.id),
        ['favorite-active'],
      );
    });

    test('clear criteria keeps the selected sort preference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(discoveryFilterProvider.notifier)
        ..updateQuery('치킨')
        ..selectCategory('치킨')
        ..selectSort(RestaurantSortOption.favoriteFirst)
        ..toggleFavoritesOnly()
        ..toggleActivePartyOnly()
        ..clearCriteria();

      final filter = container.read(discoveryFilterProvider);
      expect(filter.query, isEmpty);
      expect(filter.selectedCategory, allRestaurantCategory);
      expect(filter.favoritesOnly, isFalse);
      expect(filter.activePartyOnly, isFalse);
      expect(filter.selectedSort, RestaurantSortOption.favoriteFirst);
    });

    test('sort changes stay client-side and do not move camera', () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(
          id: 'near',
          name: '가까운 식당',
          category: '한식',
          distanceMeters: 100,
        ),
        _restaurant(
          id: 'party',
          name: '파티 식당',
          category: '한식',
          distanceMeters: 500,
          activePartyCount: 3,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      final searchController = container.read(searchAreaProvider.notifier);
      searchController.onCameraIdle(
        const MapCameraIdleEvent(
          center: MapCameraCenter(latitude: 35.1, longitude: 129),
          userInitiated: false,
        ),
      );
      final centerBefore = container.read(searchAreaProvider).center;
      final focusBefore =
          container.read(selectedRestaurantFocusRequestProvider);
      final queryBefore = container.read(restaurantListQueryProvider);
      container.read(selectedRestaurantIdProvider.notifier).state = 'near';

      container
          .read(discoveryFilterProvider.notifier)
          .selectSort(RestaurantSortOption.activePartyCount);

      expect(repository.listCalls, 1);
      expect(repository.discoverCalls, 0);
      expect(container.read(restaurantListQueryProvider), same(queryBefore));
      expect(container.read(searchAreaProvider).center, centerBefore);
      expect(
          container.read(selectedRestaurantFocusRequestProvider), focusBefore);
      expect(container.read(selectedRestaurantIdProvider), 'near');
      expect(
        container
            .read(filteredRestaurantsProvider)
            .map((restaurant) => restaurant.id),
        ['party', 'near'],
      );
    });

    test('favorite toggle immediately reorders favorite-first results',
        () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(
          id: 'near',
          name: '가까운 식당',
          category: '한식',
          distanceMeters: 100,
        ),
        _restaurant(
          id: 'far',
          name: '먼 식당',
          category: '한식',
          distanceMeters: 900,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      container
          .read(discoveryFilterProvider.notifier)
          .selectSort(RestaurantSortOption.favoriteFirst);
      final far = container
          .read(restaurantsProvider)
          .firstWhere((restaurant) => restaurant.id == 'far');
      final focusBefore =
          container.read(selectedRestaurantFocusRequestProvider);

      await container.read(favoriteOverridesProvider.notifier).toggle(far);

      expect(
        container
            .read(filteredRestaurantsProvider)
            .map((restaurant) => restaurant.id),
        ['far', 'near'],
      );
      expect(
          container.read(selectedRestaurantFocusRequestProvider), focusBefore);
      expect(repository.listCalls, 1);
    });

    test('unfavoriting immediately removes a favorites-only result', () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(
          id: 'favorite',
          name: '찜 식당',
          category: '한식',
          isFavorite: true,
        ),
        _restaurant(
          id: 'normal',
          name: '일반 식당',
          category: '한식',
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      container.read(discoveryFilterProvider.notifier).toggleFavoritesOnly();
      container.read(selectedRestaurantIdProvider.notifier).state = 'favorite';
      final favorite = container.read(filteredRestaurantsProvider).single;

      await container.read(favoriteOverridesProvider.notifier).toggle(favorite);

      expect(container.read(filteredRestaurantsProvider), isEmpty);
      expect(container.read(selectedRestaurantIdProvider), isNull);
      expect(repository.listCalls, 1);
      container.read(discoveryFilterProvider.notifier).toggleFavoritesOnly();
      expect(container.read(filteredRestaurantsProvider), hasLength(2));
    });

    test('filtering 100 restaurants returns a stable filtered list', () {
      final restaurants = [
        for (var index = 0; index < 100; index += 1)
          _restaurant(
            id: 'restaurant-$index',
            name: index.isEven ? '테스트 치킨 $index' : '테스트 한식 $index',
            category: index.isEven ? '음식점 > 치킨' : '음식점 > 한식',
            isFavorite: index.isEven,
            activePartyCount: index % 4,
          ),
      ];

      final filtered = filterAndSortRestaurants(
        restaurants,
        const DiscoveryFilterState(
          query: '테스트',
          selectedCategory: '치킨',
          favoritesOnly: true,
          activePartyOnly: true,
          selectedSort: RestaurantSortOption.activePartyCount,
        ),
      );

      expect(filtered, hasLength(25));
      expect(
          filtered.map((restaurant) => restaurant.id).toSet(), hasLength(25));
    });
  });

  testWidgets('search keeps marker card and result count synchronized',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MukkingApp()),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(discoverySearchFieldKey), ' 멘 야 ');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-002')),
      findsNothing,
    );
    expect(find.text('전체 4곳 중 1곳'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nearby-restaurant-card-restaurant-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('nearby-restaurant-card-restaurant-002')),
      findsNothing,
    );
  });

  testWidgets('category and query combine and show distinct empty UX',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discovery-category-치킨')), findsNothing);
    await tester.enterText(find.byKey(discoverySearchFieldKey), '치킨');
    await tester.pump();
    expect(find.text('전체 4곳 중 0곳'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text("'치킨' 검색 결과가 없어요."), findsOneWidget);
    expect(find.byKey(discoverySortButtonKey), findsNothing);

    container.read(discoveryFilterProvider.notifier).updateQuery('');
    container.read(discoveryFilterProvider.notifier).selectCategory('한식');
    await tester.pump();
    expect(
      find.text('현재 지역에 선택한 카테고리 식당이 없어요.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 520));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-category-한식')),
      findsOneWidget,
    );
  });

  testWidgets('compact sort menu changes the shared visible order',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -540));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(discoverySortButtonKey), findsOneWidget);
    expect(find.text('거리순'), findsOneWidget);

    await tester.tap(find.byKey(discoverySortButtonKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.byKey(
        discoverySortOptionKey(RestaurantSortOption.activePartyCount),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(
      container.read(discoveryFilterProvider).selectedSort,
      RestaurantSortOption.activePartyCount,
    );
    expect(find.text('모집 많은 순'), findsOneWidget);
  });

  testWidgets('quick filter chips share one marker card and count source',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(favoritesOnlyFilterKey), findsOneWidget);
    expect(find.byKey(activePartyOnlyFilterKey), findsOneWidget);
    await tester.tap(find.byKey(activePartyOnlyFilterKey));
    await tester.pump();

    expect(container.read(discoveryFilterProvider).activePartyOnly, isTrue);
    expect(find.text('전체 4곳 중 3곳'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-004')),
      findsNothing,
    );

    await tester.tap(find.byKey(favoritesOnlyFilterKey));
    await tester.pump();
    expect(container.read(filteredRestaurantsProvider), isEmpty);
    expect(find.text('전체 4곳 중 0곳'), findsOneWidget);
    expect(find.byKey(clearDiscoveryFiltersKey), findsOneWidget);

    container
        .read(discoveryFilterProvider.notifier)
        .selectSort(RestaurantSortOption.favoriteFirst);
    await tester.tap(find.byKey(clearDiscoveryFiltersKey));
    await tester.pump();
    final resetFilter = container.read(discoveryFilterProvider);
    expect(resetFilter.favoritesOnly, isFalse);
    expect(resetFilter.activePartyOnly, isFalse);
    expect(resetFilter.selectedSort, RestaurantSortOption.favoriteFirst);
    expect(find.text('식당 4곳을 불러왔어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick-filter empty state is explicit', (tester) async {
    final filteredContainer = ProviderContainer();
    addTearDown(filteredContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: filteredContainer,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();
    filteredContainer
        .read(discoveryFilterProvider.notifier)
        .toggleFavoritesOnly();
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -540));
    await tester.pumpAndSettle();
    expect(find.text('찜한 식당이 없어요.'), findsOneWidget);
  });

  testWidgets('raw no-data state stays distinct from quick-filter empty',
      (tester) async {
    final emptyContainer = ProviderContainer(
      overrides: [
        restaurantRepositoryProvider.overrideWithValue(
          _CountingRestaurantRepository(const []),
        ),
      ],
    );
    addTearDown(emptyContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: emptyContainer,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -540));
    await tester.pumpAndSettle();
    expect(find.text('현재 지역에 등록된 식당이 없어요.'), findsWidgets);
    expect(find.text('찜한 식당이 없어요.'), findsNothing);
  });

  testWidgets('filter state is shared with fullscreen and closes stale sheet',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-001')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(restaurantDetailsSheetKey), findsOneWidget);

    container.read(discoveryFilterProvider.notifier).selectCategory('고기');
    container
        .read(discoveryFilterProvider.notifier)
        .selectSort(RestaurantSortOption.favoriteFirst);
    container.read(discoveryFilterProvider.notifier).toggleActivePartyOnly();
    await tester.pumpAndSettle();
    expect(find.byKey(restaurantDetailsSheetKey), findsNothing);
    expect(container.read(selectedRestaurantIdProvider), isNull);

    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);
    expect(
      container.read(discoveryFilterProvider).selectedSort,
      RestaurantSortOption.favoriteFirst,
    );
    expect(container.read(discoveryFilterProvider).activePartyOnly, isTrue);
    expect(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-002')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-001')),
      findsNothing,
    );
  });
}

Restaurant _restaurant({
  required String id,
  required String name,
  required String category,
  int? distanceMeters = 500,
  bool isFavorite = false,
  int activePartyCount = 0,
}) {
  return Restaurant(
    id: id,
    name: name,
    category: category,
    address: '부산',
    latitude: 35.1,
    longitude: 129,
    distanceMeters: distanceMeters,
    imageUrl: '',
    isFavorite: isFavorite,
    activePartyCount: activePartyCount,
    imageLabel: name,
    markerDx: .5,
    markerDy: .5,
  );
}

class _CountingRestaurantRepository implements RestaurantRepository {
  _CountingRestaurantRepository(this.restaurants);

  final List<Restaurant> restaurants;
  int listCalls = 0;
  int discoverCalls = 0;

  @override
  Future<List<Restaurant>> discover(RestaurantDiscoverRequest request) async {
    discoverCalls += 1;
    return restaurants;
  }

  @override
  Future<Restaurant?> getById(String restaurantId) async {
    for (final restaurant in restaurants) {
      if (restaurant.id == restaurantId) return restaurant;
    }
    return null;
  }

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async {
    listCalls += 1;
    return restaurants;
  }

  @override
  Future<List<Restaurant>> listFavorites() async {
    return restaurants.where((restaurant) => restaurant.isFavorite).toList();
  }

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    return restaurant.copyWith(isFavorite: isFavorite);
  }
}
