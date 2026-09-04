import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_api.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_repository.dart';
import 'package:mukking_flutter_app/features/discovery/domain/discovery_filter.dart';
import 'package:mukking_flutter_app/features/discovery/domain/discovery_party_filter.dart';
import 'package:mukking_flutter_app/features/discovery/domain/map_camera_center.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_party_filter_sheet.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/fullscreen_map_screen.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_repository.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  group('discovery party filter domain', () {
    final now = DateTime(2026, 8, 29, 12);

    test('uses actual domain statuses for recruiting', () {
      expect(
          isRecruitingParty(_party(status: MatchingPartyStatus.open)), isTrue);
      expect(
          isRecruitingParty(_party(status: MatchingPartyStatus.hot)), isTrue);
      expect(
        isRecruitingParty(_party(status: MatchingPartyStatus.urgent)),
        isTrue,
      );
      expect(
          isRecruitingParty(_party(status: MatchingPartyStatus.full)), isFalse);
    });

    test('excludes posts without a real restaurant relationship', () {
      final parties = [
        _party(id: 'linked', restaurantId: 'restaurant-1'),
        _party(id: 'legacy', restaurantId: 'legacy-restaurant-post-1'),
        _party(id: 'empty', restaurantId: ''),
      ];

      expect(
        filterDiscoveryParties(
          parties,
          const DiscoveryPartyFilterState(recruitingOnly: true),
          now: now,
        ).map((party) => party.id),
        ['linked'],
      );
    });

    test('handles today and tomorrow date boundaries in local time', () {
      final parties = [
        _party(id: 'today-start', scheduledAt: DateTime(2026, 8, 29)),
        _party(
          id: 'today-end',
          scheduledAt: DateTime(2026, 8, 29, 23, 59),
        ),
        _party(id: 'tomorrow-start', scheduledAt: DateTime(2026, 8, 30)),
        _party(
          id: 'tomorrow-end',
          scheduledAt: DateTime(2026, 8, 30, 23, 59),
        ),
        _party(id: 'later', scheduledAt: DateTime(2026, 8, 31)),
      ];

      expect(
        filterDiscoveryParties(
          parties,
          const DiscoveryPartyFilterState(date: PartyDateFilter.today),
          now: now,
        ).map((party) => party.id),
        ['today-start', 'today-end'],
      );
      expect(
        filterDiscoveryParties(
          parties,
          const DiscoveryPartyFilterState(date: PartyDateFilter.tomorrow),
          now: now,
        ).map((party) => party.id),
        ['tomorrow-start', 'tomorrow-end'],
      );
    });

    test('maps all time-slot boundaries including cross-midnight night', () {
      final parties = [
        _party(id: 'night-0459', scheduledAt: DateTime(2026, 8, 29, 4, 59)),
        _party(id: 'morning-0500', scheduledAt: DateTime(2026, 8, 29, 5)),
        _party(
          id: 'morning-1059',
          scheduledAt: DateTime(2026, 8, 29, 10, 59),
        ),
        _party(id: 'lunch-1100', scheduledAt: DateTime(2026, 8, 29, 11)),
        _party(
          id: 'lunch-1459',
          scheduledAt: DateTime(2026, 8, 29, 14, 59),
        ),
        _party(id: 'evening-1500', scheduledAt: DateTime(2026, 8, 29, 15)),
        _party(
          id: 'evening-2059',
          scheduledAt: DateTime(2026, 8, 29, 20, 59),
        ),
        _party(id: 'night-2100', scheduledAt: DateTime(2026, 8, 29, 21)),
      ];

      Iterable<String> ids(PartyTimeSlot slot) => filterDiscoveryParties(
            parties,
            DiscoveryPartyFilterState(timeSlot: slot),
            now: now,
          ).map((party) => party.id);

      expect(ids(PartyTimeSlot.morning), ['morning-0500', 'morning-1059']);
      expect(ids(PartyTimeSlot.lunch), ['lunch-1100', 'lunch-1459']);
      expect(ids(PartyTimeSlot.evening), ['evening-1500', 'evening-2059']);
      expect(ids(PartyTimeSlot.night), ['night-0459', 'night-2100']);
    });

    test('available seats and recruiting filters are independent and ANDed',
        () {
      final parties = [
        _party(
          id: 'open-seat',
          currentMembers: 2,
          maxMembers: 4,
          status: MatchingPartyStatus.open,
        ),
        _party(
          id: 'open-full',
          currentMembers: 4,
          maxMembers: 4,
          status: MatchingPartyStatus.full,
        ),
        _party(
          id: 'closed-seat',
          currentMembers: 2,
          maxMembers: 4,
          status: MatchingPartyStatus.full,
        ),
      ];

      expect(
        filterDiscoveryParties(
          parties,
          const DiscoveryPartyFilterState(availableSeatsOnly: true),
          now: now,
        ).map((party) => party.id),
        ['open-seat', 'closed-seat'],
      );
      expect(
        filterDiscoveryParties(
          parties,
          const DiscoveryPartyFilterState(recruitingOnly: true),
          now: now,
        ).map((party) => party.id),
        ['open-seat'],
      );
      expect(
        filterDiscoveryParties(
          parties,
          const DiscoveryPartyFilterState(
            availableSeatsOnly: true,
            recruitingOnly: true,
          ),
          now: now,
        ).map((party) => party.id),
        ['open-seat'],
      );
    });

    test('all party conditions combine with AND semantics', () {
      final parties = [
        _party(
          id: 'match',
          restaurantId: 'chicken-favorite',
          scheduledAt: DateTime(2026, 8, 29, 18),
          currentMembers: 2,
          maxMembers: 4,
          status: MatchingPartyStatus.urgent,
        ),
        _party(
          id: 'wrong-time',
          restaurantId: 'chicken-favorite',
          scheduledAt: DateTime(2026, 8, 29, 12),
        ),
        _party(
          id: 'full',
          restaurantId: 'chicken-favorite',
          scheduledAt: DateTime(2026, 8, 29, 18),
          currentMembers: 4,
          maxMembers: 4,
          status: MatchingPartyStatus.full,
        ),
      ];

      final visible = filterDiscoveryParties(
        parties,
        const DiscoveryPartyFilterState(
          date: PartyDateFilter.today,
          timeSlot: PartyTimeSlot.evening,
          availableSeatsOnly: true,
          recruitingOnly: true,
        ),
        now: now,
      );

      expect(visible.map((party) => party.id), ['match']);
    });
  });

  group('discovery party filter providers', () {
    test('party and restaurant filters intersect through restaurant ids',
        () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(
          id: 'chicken-favorite',
          name: '부산 치킨',
          category: '음식점 > 치킨',
          isFavorite: true,
        ),
        _restaurant(
          id: 'chicken-normal',
          name: '부산 치킨 일반',
          category: '음식점 > 치킨',
        ),
        _restaurant(
          id: 'korean-favorite',
          name: '부산 국밥',
          category: '음식점 > 한식',
          isFavorite: true,
        ),
      ]);
      final container = _container(
        repository: repository,
        parties: [
          _party(
            restaurantId: 'chicken-favorite',
            status: MatchingPartyStatus.open,
          ),
          _party(
            id: 'normal-party',
            restaurantId: 'chicken-normal',
            status: MatchingPartyStatus.open,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      await container.read(matchingPartiesProvider.future);
      container.read(discoveryFilterProvider.notifier)
        ..updateQuery('부산')
        ..selectCategory('치킨')
        ..toggleFavoritesOnly()
        ..selectSort(RestaurantSortOption.favoriteFirst);
      container.read(discoveryPartyFilterProvider.notifier).apply(
            const DiscoveryPartyFilterState(recruitingOnly: true),
          );

      expect(
        container
            .read(filteredRestaurantsProvider)
            .map((restaurant) => restaurant.id),
        ['chicken-favorite'],
      );
    });

    test('apply clears excluded selection but preserves surviving selection',
        () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(id: 'with-party', name: '파티 식당', category: '한식'),
        _restaurant(id: 'without-party', name: '일반 식당', category: '한식'),
      ]);
      final container = _container(
        repository: repository,
        parties: [_party(restaurantId: 'with-party')],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      await container.read(matchingPartiesProvider.future);
      container.read(selectedRestaurantIdProvider.notifier).state =
          'with-party';

      container.read(discoveryPartyFilterProvider.notifier).apply(
            const DiscoveryPartyFilterState(recruitingOnly: true),
          );
      expect(container.read(selectedRestaurantIdProvider), 'with-party');

      container.read(discoveryPartyFilterProvider.notifier).reset();
      container.read(selectedRestaurantIdProvider.notifier).state =
          'without-party';
      container.read(discoveryPartyFilterProvider.notifier).apply(
            const DiscoveryPartyFilterState(recruitingOnly: true),
          );
      expect(container.read(selectedRestaurantIdProvider), isNull);
    });

    test('apply is client-only and search-this-area preserves party state',
        () async {
      final repository = _CountingRestaurantRepository([
        _restaurant(id: 'restaurant-1', name: '식당', category: '한식'),
      ]);
      final container = _container(
        repository: repository,
        parties: [_party(restaurantId: 'restaurant-1')],
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      await container.read(matchingPartiesProvider.future);
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

      const filter = DiscoveryPartyFilterState(
        timeSlot: PartyTimeSlot.evening,
        recruitingOnly: true,
      );
      container.read(discoveryPartyFilterProvider.notifier).apply(filter);

      expect(repository.listCalls, 1);
      expect(repository.discoverCalls, 0);
      expect(container.read(searchAreaProvider).center, centerBefore);
      expect(
        container.read(selectedRestaurantFocusRequestProvider),
        focusBefore,
      );

      searchController.onCameraIdle(
        const MapCameraIdleEvent(
          center: MapCameraCenter(latitude: 35.2, longitude: 129.1),
          userInitiated: true,
        ),
      );
      expect(await searchController.searchCurrentArea(), isTrue);
      expect(container.read(discoveryPartyFilterProvider).timeSlot,
          PartyTimeSlot.evening);
      expect(
          container.read(discoveryPartyFilterProvider).recruitingOnly, isTrue);
    });

    test('filters 100 restaurants and posts without changing source data',
        () async {
      final restaurants = [
        for (var index = 0; index < 100; index += 1)
          _restaurant(
            id: 'restaurant-$index',
            name: '식당 $index',
            category: '한식',
          ),
      ];
      final parties = [
        for (var index = 0; index < 100; index += 1)
          _party(
            id: 'party-$index',
            restaurantId: 'restaurant-$index',
            status: index.isEven
                ? MatchingPartyStatus.open
                : MatchingPartyStatus.full,
          ),
      ];
      final container = _container(
        repository: _CountingRestaurantRepository(restaurants),
        parties: parties,
      );
      addTearDown(container.dispose);
      await container.read(restaurantFeedProvider.future);
      await container.read(matchingPartiesProvider.future);

      container.read(discoveryPartyFilterProvider.notifier).apply(
            const DiscoveryPartyFilterState(recruitingOnly: true),
          );

      expect(container.read(filteredRestaurantsProvider), hasLength(50));
      expect(container.read(restaurantsProvider), hasLength(100));
      expect(container.read(matchingPartiesProvider).value, hasLength(100));
    });
  });

  testWidgets('draft changes apply only after confirmation and reset is scoped',
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
    container.read(discoveryFilterProvider.notifier)
      ..updateQuery('멘야')
      ..selectSort(RestaurantSortOption.activePartyCount)
      ..toggleFavoritesOnly();
    await tester.pump();

    await tester.tap(find.byKey(discoveryPartyFilterButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(partyDateFilterKey(PartyDateFilter.today)));
    await tester.tap(find.byKey(recruitingPartyFilterKey));
    await tester.pump();
    expect(container.read(discoveryPartyFilterProvider).activeCount, 0);

    await tester.tap(find.byKey(applyPartyFiltersKey));
    await tester.pumpAndSettle();
    expect(container.read(discoveryPartyFilterProvider).activeCount, 2);
    expect(find.text('모임 조건 2'), findsOneWidget);

    await tester.tap(find.byKey(discoveryPartyFilterButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(resetPartyFilterDraftKey));
    await tester.pump();
    expect(container.read(discoveryPartyFilterProvider).activeCount, 2);
    await tester.tap(find.byKey(applyPartyFiltersKey));
    await tester.pumpAndSettle();

    expect(container.read(discoveryPartyFilterProvider).activeCount, 0);
    final restaurantFilter = container.read(discoveryFilterProvider);
    expect(restaurantFilter.query, '멘야');
    expect(restaurantFilter.favoritesOnly, isTrue);
    expect(
      restaurantFilter.selectedSort,
      RestaurantSortOption.activePartyCount,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('party filtered-empty is explicit and fullscreen shares state',
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
    container.read(discoveryPartyFilterProvider.notifier).apply(
          const DiscoveryPartyFilterState(date: PartyDateFilter.today),
        );
    await tester.pump();
    expect(find.text('전체 4곳 중 0곳'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -620));
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 모임이 있는 식당이 없어요.'), findsOneWidget);

    container.read(discoveryPartyFilterProvider.notifier).apply(
          const DiscoveryPartyFilterState(recruitingOnly: true),
        );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 620));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);
    expect(container.read(discoveryPartyFilterProvider).recruitingOnly, isTrue);
    expect(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-004')),
      findsNothing,
    );
  });
}

ProviderContainer _container({
  required _CountingRestaurantRepository repository,
  required List<MatchingParty> parties,
}) {
  return ProviderContainer(
    overrides: [
      restaurantRepositoryProvider.overrideWithValue(repository),
      matchingFeedProvider.overrideWith(
        (ref) async => MatchingFeed(parties: parties, restaurants: const []),
      ),
    ],
  );
}

MatchingParty _party({
  String id = 'party-1',
  String restaurantId = 'restaurant-1',
  DateTime? scheduledAt,
  int currentMembers = 1,
  int maxMembers = 4,
  MatchingPartyStatus status = MatchingPartyStatus.open,
}) {
  return MatchingParty(
    id: id,
    hostUserId: 'host',
    restaurantId: restaurantId,
    title: id,
    scheduledAt: scheduledAt ?? DateTime(2026, 8, 29, 18),
    currentMembers: currentMembers,
    maxMembers: maxMembers,
    distanceKm: 1,
    rewardXp: 100,
    rewardPoints: 500,
    status: status,
    hostName: '호스트',
    memberNames: const ['호스트'],
    tags: const [],
    description: '',
  );
}

Restaurant _restaurant({
  required String id,
  required String name,
  required String category,
  bool isFavorite = false,
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
    isFavorite: isFavorite,
    activePartyCount: 1,
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
