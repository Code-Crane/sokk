import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/core/platform/external_url_launcher.dart';
import 'package:mukking_flutter_app/core/router/app_router.dart';
import 'package:mukking_flutter_app/core/router/app_routes.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_api.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_repository.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/restaurant_detail_screen.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_repository.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  testWidgets('direct restaurant route reloads real fields and filters parties',
      (tester) async {
    final restaurantRepository = _RestaurantRepository(
      restaurant: _restaurant(),
      includeInList: false,
    );
    final matchingRepository = _MatchingRepository([
      _party('party-matching', 'restaurant-detail'),
      _party('party-other', 'restaurant-other'),
      _party(
        'party-full',
        'restaurant-detail',
        status: MatchingPartyStatus.full,
      ),
    ]);
    Uri? launchedUri;
    final container = _container(
      restaurantRepository,
      matchingRepository,
      launcher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );
    addTearDown(container.dispose);

    await _pumpApp(tester, container);
    container
        .read(appRouterProvider)
        .go(AppRoutes.restaurantDetailPath('restaurant-detail'));
    await tester.pumpAndSettle();

    expect(restaurantRepository.getByIdCalls, 1);
    expect(find.byKey(restaurantDetailPageKey), findsOneWidget);
    expect(find.text('상세 테스트 식당'), findsWidgets);
    expect(find.text('부산 중구 테스트로 1'), findsOneWidget);
    expect(find.text('051-123-4567'), findsOneWidget);
    expect(find.text('1.4km'), findsOneWidget);
    expect(find.text('모집 중인 모임'), findsOneWidget);
    expect(find.text('현재 모집 중 1개'), findsOneWidget);
    expect(find.text('남은 자리 2'), findsOneWidget);
    expect(find.text('모임 상세 보기'), findsOneWidget);
    expect(find.byKey(restaurantDetailPartyCardKey('party-matching')),
        findsOneWidget);
    expect(find.text('party-other'), findsNothing);
    expect(find.text('party-full'), findsNothing);

    await tester.ensureVisible(find.byKey(restaurantDetailPhoneButtonKey));
    await tester.tap(find.byKey(restaurantDetailPhoneButtonKey));
    await tester.pump();
    expect(launchedUri?.scheme, 'tel');

    await tester.tap(find.byKey(restaurantDetailPlaceButtonKey));
    await tester.pump();
    expect(launchedUri.toString(), 'https://place.map.kakao.com/123');

    await tester.ensureVisible(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.discovery,
    );
  });

  testWidgets('optional rows stay hidden and empty party state is explicit',
      (tester) async {
    final repository = _RestaurantRepository(
      restaurant: _restaurant(
        phone: null,
        roadAddress: null,
        placeUrl: null,
        distanceMeters: null,
      ),
      includeInList: false,
    );
    final container = _container(repository, _MatchingRepository(const []));
    addTearDown(container.dispose);

    await _pumpApp(tester, container);
    container
        .read(appRouterProvider)
        .go(AppRoutes.restaurantDetailPath('restaurant-detail'));
    await tester.pumpAndSettle();

    expect(find.text('부산 중구 지번 2'), findsOneWidget);
    expect(find.byKey(restaurantDetailPhoneButtonKey), findsNothing);
    expect(find.byKey(restaurantDetailPlaceButtonKey), findsNothing);
    expect(find.text('현재 모집 중인 모임이 없어요.'), findsOneWidget);
  });

  testWidgets('party and create actions keep their restaurant identifiers',
      (tester) async {
    final repository = _RestaurantRepository(restaurant: _restaurant());
    final matching = _MatchingRepository([
      _party('party-route', 'restaurant-detail'),
    ]);
    final container = _container(repository, matching);
    addTearDown(container.dispose);

    await _pumpApp(tester, container);
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.restaurantDetailPath('restaurant-detail'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(restaurantDetailPartyCardKey('party-route')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(restaurantDetailPartyCardKey('party-route')),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedPartyIdProvider), 'party-route');
    expect(router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.partyDetailPath('party-route'));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.restaurantDetailPath('restaurant-detail'),
    );

    await tester.ensureVisible(
      find.byKey(restaurantDetailCreatePartyButtonKey),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(restaurantDetailCreatePartyButtonKey));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.createParty);
    expect(
      router.routerDelegate.currentConfiguration.uri
          .queryParameters['restaurantId'],
      'restaurant-detail',
    );
    expect(find.textContaining('상세 테스트 식당에서 열 파티'), findsOneWidget);
  });

  testWidgets('favorite change converges across detail and restaurant feed',
      (tester) async {
    final repository = _RestaurantRepository(restaurant: _restaurant());
    final container = _container(repository, _MatchingRepository(const []));
    addTearDown(container.dispose);

    await _pumpApp(tester, container);
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.restaurantDetailPath('restaurant-detail'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(restaurantDetailFavoriteButtonKey));
    await tester.pumpAndSettle();
    expect(repository.restaurant.isFavorite, isTrue);
    expect(
      container
          .read(restaurantDetailProvider('restaurant-detail'))
          .valueOrNull
          ?.isFavorite,
      isTrue,
    );
    expect(
      container
          .read(restaurantsProvider)
          .singleWhere((row) => row.id == 'restaurant-detail')
          .isFavorite,
      isTrue,
    );
  });

  testWidgets('direct detail exposes loading and safe API error states',
      (tester) async {
    final pending = Completer<Restaurant?>();
    final repository = _RestaurantRepository(
      restaurant: _restaurant(),
      includeInList: false,
      onGetById: (_) => pending.future,
    );
    final container = _container(repository, _MatchingRepository(const []));
    addTearDown(container.dispose);

    await _pumpApp(tester, container);
    container
        .read(appRouterProvider)
        .go(AppRoutes.restaurantDetailPath('restaurant-detail'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.completeError(
      const ApiError(
        kind: ApiErrorKind.server,
        statusCode: 500,
        userMessage: '식당 정보를 잠시 불러올 수 없어요.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('식당 정보를 잠시 불러올 수 없어요.'), findsOneWidget);
    expect(find.byKey(restaurantDetailRetryButtonKey), findsOneWidget);
  });
}

ProviderContainer _container(
  RestaurantRepository restaurantRepository,
  MatchingRepository matchingRepository, {
  ExternalUrlLauncher launcher = _successfulLaunch,
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig.test()),
      restaurantRepositoryProvider.overrideWithValue(restaurantRepository),
      matchingRepositoryProvider.overrideWithValue(matchingRepository),
      externalUrlLauncherProvider.overrideWithValue(launcher),
    ],
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MukkingApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<bool> _successfulLaunch(Uri _) async => true;

Restaurant _restaurant({
  String? phone = '051-123-4567',
  String? roadAddress = '부산 중구 테스트로 1',
  String? placeUrl = 'https://place.map.kakao.com/123',
  int? distanceMeters = 1420,
}) {
  return Restaurant(
    id: 'restaurant-detail',
    name: '상세 테스트 식당',
    category: '한식',
    address: '부산 중구 지번 2',
    latitude: 35.1,
    longitude: 129.0,
    distanceMeters: distanceMeters,
    imageUrl: '',
    isFavorite: false,
    activePartyCount: 1,
    imageLabel: '상세 테스트 식당',
    markerDx: 0.4,
    markerDy: 0.4,
    phone: phone,
    roadAddress: roadAddress,
    placeUrl: placeUrl,
  );
}

MatchingParty _party(
  String id,
  String restaurantId, {
  MatchingPartyStatus status = MatchingPartyStatus.open,
}) {
  return MatchingParty(
    id: id,
    hostUserId: 'host-1',
    restaurantId: restaurantId,
    title: id,
    scheduledAt: DateTime(2026, 9, 1, 19, 30),
    currentMembers: 2,
    maxMembers: 4,
    distanceKm: 1.4,
    rewardXp: 50,
    rewardPoints: 100,
    status: status,
    hostName: '테스트 파티장',
    memberNames: const ['테스트 파티장', '참여자'],
    tags: const ['한식'],
    description: '테스트 파티',
  );
}

class _RestaurantRepository implements RestaurantRepository {
  _RestaurantRepository({
    required this.restaurant,
    this.includeInList = true,
    this.onGetById,
  });

  Restaurant restaurant;
  final bool includeInList;
  final Future<Restaurant?> Function(String restaurantId)? onGetById;
  int getByIdCalls = 0;

  @override
  Future<List<Restaurant>> discover(RestaurantDiscoverRequest request) =>
      list(const RestaurantListQuery());

  @override
  Future<Restaurant?> getById(String restaurantId) async {
    getByIdCalls += 1;
    final override = onGetById;
    if (override != null) return override(restaurantId);
    return restaurantId == restaurant.id ? restaurant : null;
  }

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async =>
      includeInList ? [restaurant] : const [];

  @override
  Future<List<Restaurant>> listFavorites() async =>
      restaurant.isFavorite ? [restaurant] : const [];

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    this.restaurant = restaurant.copyWith(isFavorite: isFavorite);
    return this.restaurant;
  }
}

class _MatchingRepository implements MatchingRepository {
  const _MatchingRepository(this.parties);

  final List<MatchingParty> parties;

  @override
  Future<MatchingParty> createParty(CreatePartyInput input) async =>
      throw UnimplementedError();

  @override
  Future<JoinRequestResult> createJoinRequest(String partyId) async =>
      throw UnimplementedError();

  @override
  Future<MatchingParty?> findPartyById(String partyId) async {
    for (final party in parties) {
      if (party.id == partyId) return party;
    }
    return null;
  }

  @override
  Future<PartyJoinRequest?> findMyJoinRequest(String partyId) async => null;

  @override
  Future<List<PartyJoinRequest>> listJoinRequests(String partyId) async =>
      const [];

  @override
  Future<MatchingFeed> listFeed() async =>
      MatchingFeed(parties: parties, restaurants: const []);

  @override
  Future<RespondJoinRequestResult> respondJoinRequest({
    required String requestId,
    required String decision,
  }) async =>
      throw UnimplementedError();
}
