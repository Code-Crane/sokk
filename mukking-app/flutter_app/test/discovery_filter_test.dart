import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        ..selectCategory('고기');
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
    });

    test('filtering 100 restaurants returns a stable filtered list', () {
      final restaurants = [
        for (var index = 0; index < 100; index += 1)
          _restaurant(
            id: 'restaurant-$index',
            name: index.isEven ? '테스트 치킨 $index' : '테스트 한식 $index',
            category: index.isEven ? '음식점 > 치킨' : '음식점 > 한식',
          ),
      ];

      final filtered = filterRestaurants(
        restaurants,
        const DiscoveryFilterState(
          query: '테스트',
          selectedCategory: '치킨',
        ),
      );

      expect(filtered, hasLength(50));
      expect(
          filtered.map((restaurant) => restaurant.id).toSet(), hasLength(50));
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
    await tester.pumpAndSettle();
    expect(find.byKey(restaurantDetailsSheetKey), findsNothing);
    expect(container.read(selectedRestaurantIdProvider), isNull);

    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);
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
}) {
  return Restaurant(
    id: id,
    name: name,
    category: category,
    address: '부산',
    latitude: 35.1,
    longitude: 129,
    distanceMeters: 500,
    imageUrl: '',
    isFavorite: false,
    activePartyCount: 0,
    imageLabel: name,
    markerDx: .5,
    markerDy: .5,
  );
}
