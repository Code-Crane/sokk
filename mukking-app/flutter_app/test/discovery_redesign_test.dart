import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/core/theme/app_theme.dart';
import 'package:mukking_flutter_app/core/theme/theme_tokens.dart';
import 'package:mukking_flutter_app/core/theme/brand_assets.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/domain/user_location.dart';
import 'package:mukking_flutter_app/features/discovery/domain/discovery_filter.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_visuals.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_party_filter_sheet.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/fullscreen_map_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/map/restaurant_map_view.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/restaurant_bottom_sheet.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_location_provider.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/widgets/app_shell.dart';

const _capture = bool.fromEnvironment('DISCOVERY_CAPTURE');
const _cardKey = ValueKey('nearby-restaurant-card-r');
const _restaurant = Restaurant(
  id: 'r',
  name: '함께 먹는 한식',
  category: '한식',
  address: '부산 테스트 주소',
  latitude: 35.1,
  longitude: 129,
  distanceMeters: 350,
  imageUrl: '',
  isFavorite: true,
  activePartyCount: 2,
  imageLabel: '',
  markerDx: .2,
  markerDy: .4,
);

MatchingParty _party(String id, int hour, {bool full = false}) => MatchingParty(
      id: id,
      hostUserId: 'host',
      restaurantId: 'r',
      title: '테스트 모임',
      scheduledAt: DateTime(2030, 9, 10, hour, 30),
      currentMembers: full ? 4 : 2,
      maxMembers: 4,
      distanceKm: 0,
      rewardXp: 0,
      rewardPoints: 0,
      status: full ? MatchingPartyStatus.full : MatchingPartyStatus.open,
      hostName: '',
      memberNames: [],
      tags: [],
      description: '',
    );

Future<({ProviderContainer container, GoRouter router})> _mount(
    WidgetTester tester,
    {double width = 390,
    double scale = 1,
    List<Restaurant> restaurants = const [_restaurant],
    Future<List<Restaurant>> Function()? load,
    List<MatchingParty>? parties,
    LocationService? location}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(AppConfig.test()),
    restaurantFeedProvider.overrideWith(
        (ref) => load != null ? load() : Future.value(restaurants)),
    matchingPartiesProvider.overrideWith((ref) async =>
        parties ??
        [
          _party('late', 20),
          _party('early', 12),
          _party('full', 10, full: true)
        ]),
    if (location != null) locationServiceProvider.overrideWithValue(location),
  ]);
  final router = GoRouter(initialLocation: '/discovery', routes: [
    GoRoute(
        path: '/discovery',
        builder: (_, __) => const AppShell(child: DiscoveryScreen())),
    GoRoute(
        path: '/discovery/map',
        builder: (_, __) => const FullscreenMapScreen()),
    GoRoute(
        path: '/restaurants/:id',
        builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('detail:${state.pathParameters['id']}'))),
  ]);
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  var theme = AppTheme.build(MukkingThemeId.violet);
  if (_capture) {
    theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'DiscoveryQA'));
  }
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: const ValueKey('discovery-capture'),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
      ),
    ),
  ));
  await tester.pump();
  return (container: container, router: router);
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('discovery-capture')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('build/discovery_redesign_qa/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!_capture) return;
    for (final family in ['DiscoveryQA', 'Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(File('C:/Windows/Fonts/malgun.ttf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b))))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final width in [390.0, 360.0]) {
    testWidgets('$width layout card sheet route and back preserve selection',
        (tester) async {
      final scope = await _mount(tester, width: width);
      await tester.pumpAndSettle();
      expect(find.text('식당 이름이나 메뉴를 검색해보세요'), findsOneWidget);
      expect(find.bySemanticsLabel('먹킹'), findsOneWidget);
      final field = tester.element(find.byType(TextField));
      expect(Theme.of(field).colorScheme.primary, MukkingBrand.green);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'discovery-${width.toInt()}');
      await tester.scrollUntilVisible(find.byKey(_cardKey), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('9/10 12:30 · 2/4명'), findsOneWidget);
      expect(find.text('모집 중 2개'), findsOneWidget);
      expect(find.text('지도에서 찾은 동행 2개'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(DiscoveryRestaurantImage),
              matching: find.byType(Image)),
          findsNothing);
      await _snapshot(tester, 'cards-${width.toInt()}');
      await tester.tap(find.byKey(_cardKey));
      await tester.pumpAndSettle();
      expect(find.byKey(restaurantDetailsSheetKey), findsOneWidget);
      expect(scope.container.read(selectedRestaurantIdProvider), 'r');
      expect(scope.container.read(selectedRestaurantFocusRequestProvider), 1);
      await _snapshot(tester, 'preview-${width.toInt()}');
      final action = find.descendant(
          of: find.byKey(restaurantDetailsSheetKey),
          matching: find.byKey(restaurantViewDetailsButtonKey));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('detail:r'), findsOneWidget);
      scope.router.pop();
      await tester.pumpAndSettle();
      expect(scope.container.read(selectedRestaurantIdProvider), 'r');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('360 large Korean text fits cards and both sheets',
      (tester) async {
    await _mount(tester, width: 360, scale: 1.8, restaurants: [
      _restaurant.copyWith(
          name: '함께 먹는 아주 길고 긴 이름의 따뜻한 우리 동네 한식 식당',
          category: '음식점 > 한식 > 아주 긴 카테고리',
          roadAddress: '부산광역시 중구 매우 긴 도로명 주소 테스트 123번길 456',
          phone: '051-123-4567',
          placeUrl: 'https://place.map.kakao.com/123'),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(discoveryPartyFilterButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(applyPartyFiltersKey));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(applyPartyFiltersKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_cardKey), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(_cardKey));
    await tester.pumpAndSettle();
    final sheet = find.byKey(restaurantDetailsSheetKey);
    await tester.ensureVisible(find.descendant(
        of: sheet, matching: find.byKey(restaurantPlaceUrlButtonKey)));
    expect(tester.takeException(), isNull);
    await _snapshot(tester, 'large-text-preview');
  });

  testWidgets('filter and sort preserve map element and camera requests',
      (tester) async {
    var loads = 0;
    final scope = await _mount(tester, load: () async {
      loads++;
      return [_restaurant];
    });
    await tester.pumpAndSettle();
    final mapElement = tester.element(find.byType(RestaurantMapView));
    final filter = scope.container.read(discoveryFilterProvider.notifier);
    filter.updateQuery('한식');
    filter.selectSort(RestaurantSortOption.favoriteFirst);
    filter.toggleFavoritesOnly();
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(RestaurantMapView)), same(mapElement));
    expect(scope.container.read(selectedRestaurantFocusRequestProvider), 0);
    expect(loads, 1);
    await tester.ensureVisible(find.byKey(fullscreenMapButtonKey));
    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);
    expect(
        tester
            .widget<RestaurantMapView>(find.byType(RestaurantMapView))
            .restaurants
            .single
            .id,
        'r');
    await tester.tap(find.byKey(closeFullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(scope.container.read(discoveryFilterProvider).favoritesOnly, isTrue);
    expect(scope.container.read(selectedRestaurantFocusRequestProvider), 0);
    expect(loads, 1);
  });

  testWidgets('loading and API failure do not masquerade as empty results',
      (tester) async {
    final pending = Completer<List<Restaurant>>();
    await _mount(tester, load: () => pending.future);
    expect(find.text('식당 목록을 불러오는 중이에요.'), findsOneWidget);
    expect(find.text('현재 지역에 등록된 식당이 없어요.'), findsNothing);
    pending.completeError(
        const ApiError(kind: ApiErrorKind.network, userMessage: '연결을 확인해주세요.'));
    await tester.pumpAndSettle();
    expect(find.text('연결을 확인해주세요.'), findsOneWidget);
    expect(find.text('현재 지역에 등록된 식당이 없어요.'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _snapshot(tester, 'network-error');
  });

  testWidgets('missing distance and party data are not fabricated',
      (tester) async {
    await _mount(tester, restaurants: [
      _restaurant.copyWith(clearDistance: true, activePartyCount: 0)
    ], parties: []);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_cardKey), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('현재 모집 중인 모임이 없어요.'), findsOneWidget);
    expect(find.textContaining('거리 정보 없음'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(DiscoveryRestaurantImage),
            matching: find.byType(Image)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denied permission keeps restaurant browsing available',
      (tester) async {
    await _mount(tester, location: _DeniedLocation());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 위치'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 없이도 일반 맛집 목록을 볼 수 있어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _snapshot(tester, 'location-denied');
  });

  testWidgets('failed real image URL has a safe icon fallback', (tester) async {
    await _mount(tester, restaurants: [
      _restaurant.copyWith(imageUrl: 'https://example.invalid/restaurant.jpg')
    ]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_cardKey), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryRestaurantImage), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _DeniedLocation implements LocationService {
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<AppLocationPermission> checkPermission() async =>
      AppLocationPermission.denied;
  @override
  Future<AppLocationPermission> requestPermission() async =>
      AppLocationPermission.denied;
  @override
  Future<UserLocation> getCurrentLocation() async =>
      throw StateError('Not authorized');
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}
