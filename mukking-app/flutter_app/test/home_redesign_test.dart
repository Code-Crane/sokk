import 'dart:async';
import 'reference_visual_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/widgets/app_shell.dart';
import 'package:mukking_flutter_app/core/theme/brand_assets.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/features/home/presentation/home_screen.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/features/notifications/providers/notification_provider.dart';
import 'package:mukking_flutter_app/features/pet/domain/pet.dart';
import 'package:mukking_flutter_app/features/pet/providers/pet_provider.dart';

MatchingParty party(
        {String id = 'p',
        String host = 'other',
        List<String> tags = const [],
        DateTime? date}) =>
    MatchingParty(
        id: id,
        hostUserId: host,
        restaurantId: 'r',
        title: '저녁 모임',
        restaurantName: '오래도록 함께 먹고 싶은 따뜻한 한식 식당',
        address: '부산 식당 주소',
        scheduledAt: date ?? DateTime.now().add(const Duration(hours: 2)),
        currentMembers: 1,
        maxMembers: 4,
        distanceKm: 0,
        rewardXp: 100,
        rewardPoints: 500,
        status: MatchingPartyStatus.open,
        hostName: '작성자',
        memberNames: [],
        tags: tags,
        description: '함께 먹어요');

Future<GoRouter> mount(
    WidgetTester tester, Future<List<MatchingParty>> Function() load,
    {Set<String> favorites = const {},
    Pet? pet,
    bool shell = false,
    int unread = 2}) async {
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => shell
            ? const AppShell(child: HomeScreen())
            : const Scaffold(body: HomeScreen())),
    for (final path in [
      '/discovery',
      '/notifications',
      '/pet',
      '/my',
      '/chat',
      '/create-party',
      '/party/:id'
    ])
      GoRoute(
          path: path,
          builder: (_, state) =>
              Scaffold(body: Text('route:${state.uri.path}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.test()),
        matchingPartiesProvider.overrideWith((ref) => load()),
        currentUserProvider
            .overrideWithValue(AuthUser.fallback(id: 'me', email: '')),
        favoriteRestaurantIdsProvider.overrideWithValue(favorites),
        restaurantByIdProvider.overrideWith((ref, id) => null),
        myPetProvider.overrideWith((ref) async => pet),
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
      ],
      child: RepaintBoundary(
          key: const ValueKey('home-capture'),
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: referenceCapture
                  ? ThemeData(fontFamily: 'ReferenceQA')
                  : null,
              routerConfig: router))));
  await tester.pump();
  return router;
}

Finder homeScrollable() => find
    .descendant(
      of: find.byType(HomeScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .first;

Future<void> revealHomeTarget(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: homeScrollable(),
  );
  for (var attempt = 0;
      attempt < 5 && target.hitTestable().evaluate().isEmpty;
      attempt++) {
    await tester.drag(homeScrollable(), const Offset(0, -80));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  setUpAll(loadReferenceFonts);
  testWidgets('desktop body and four tabs share the reference width',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 866);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, () async => [], shell: true);
    await tester.pumpAndSettle();
    final body = find.descendant(
        of: find.byType(HomeScreen), matching: find.byType(ListView));
    expect(tester.getSize(body).width, MukkingBrand.contentWidth);
    expect(tester.getSize(find.byType(NavigationBar)).width,
        MukkingBrand.contentWidth);
    expect(tester.takeException(), isNull);
  });
  testWidgets('zero unread notifications never shows a badge', (tester) async {
    await mount(tester, () async => [], unread: 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });
  for (final layout in [(390.0, 1.0), (360.0, 1.0), (360.0, 1.8)]) {
    testWidgets(
        'final Home ${layout.$1} scale ${layout.$2} uses brand and four tabs',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, () async => [party()], shell: true);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MukkingMascot>(
                  find.byKey(const ValueKey('home-hero-mascot')))
              .asset,
          BrandAssets.food);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('탐색'), findsOneWidget);
      await captureReference(tester, find.byKey(const ValueKey('home-capture')),
          'home-${layout.$1}-${layout.$2}');
      for (var i = 0; i < 5; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('upcoming selection retains ordering and excludes ended posts', () {
    final now = DateTime.now(),
        future = DateTime.now().add(const Duration(hours: 2));
    expect(
        homeUpcomingParties([
          party(id: 'b', date: future),
          party(id: 'a', date: future),
          party(id: 'past', date: now.subtract(const Duration(days: 1))),
          party(id: 'done', tags: ['completed'])
        ], now)
            .map((p) => p.id),
        ['a', 'b']);
  });
  testWidgets('empty Home has no fake stats and still exposes create route',
      (tester) async {
    await mount(tester, () async => []);
    await tester.pumpAndSettle();
    final createButton = find.byKey(const Key('home-create-party'));
    await revealHomeTarget(tester, createButton);
    expect(find.textContaining('38.5'), findsNothing);
    expect(find.textContaining('새로운 동행 모집이'), findsNothing);
    await tester.tap(find.byKey(const Key('home-create-party')));
    await tester.pumpAndSettle();
    expect(find.text('route:/create-party'), findsOneWidget);
  });
  testWidgets('search uses actual Discovery query without new API',
      (tester) async {
    await mount(tester, () async => []);
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await tester.enterText(find.byKey(const Key('home-search')), '치킨');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(container.read(discoveryFilterProvider).query, '치킨');
    expect(find.text('route:/discovery'), findsOneWidget);
  });
  testWidgets('want to go reuses favorites filter', (tester) async {
    await mount(tester, () async => []);
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await tester.tap(find.text('가고싶어요'));
    await tester.pumpAndSettle();
    expect(container.read(discoveryFilterProvider).favoritesOnly, isTrue);
    expect(find.text('route:/discovery'), findsOneWidget);
  });
  testWidgets('today and tomorrow use existing date predicate', (tester) async {
    final now = DateTime.now();
    await mount(
        tester,
        () async => [
              party(
                  id: 'tomorrow',
                  date: DateTime(now.year, now.month, now.day + 1, 19))
            ]);
    await tester.pumpAndSettle();
    final today = find.text('오늘');
    await revealHomeTarget(tester, today);
    await tester.tap(find.text('오늘'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeDiningPartyCard), findsNothing);
    await tester.tap(find.text('내일'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeDiningPartyCard), findsOneWidget);
  });
  testWidgets('party card opens existing detail without inventing distance',
      (tester) async {
    await mount(tester, () async => [party()], favorites: {'r'});
    await tester.pumpAndSettle();
    final partyCard = find.byType(HomeDiningPartyCard);
    await revealHomeTarget(tester, partyCard);
    expect(find.text('0.0km'), findsNothing);
    await tester.tap(find.byType(HomeDiningPartyCard));
    await tester.pumpAndSettle();
    expect(find.text('route:/party/p'), findsOneWidget);
  });
  testWidgets('loading then network retry remains available', (tester) async {
    var calls = 0;
    final pending = Completer<List<MatchingParty>>();
    await mount(tester, () {
      calls++;
      return calls == 1 ? pending.future : Future.value([]);
    });
    pending.completeError(
        const ApiError(kind: ApiErrorKind.network, userMessage: '연결을 확인해주세요'));
    await tester.pumpAndSettle();
    final retry = find.text('다시 시도');
    await revealHomeTarget(tester, retry);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
  for (final entry in [('탐색', '/discovery'), ('채팅', '/chat'), ('MY', '/my')]) {
    testWidgets('four tab ${entry.$1} keeps route', (tester) async {
      await mount(tester, () async => [], shell: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(find.text('route:${entry.$2}'), findsOneWidget);
    });
  }
  testWidgets('notification keeps existing route', (tester) async {
    await mount(tester, () async => []);
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    await tester.tap(find.byTooltip('알림 목록'));
    await tester.pumpAndSettle();
    expect(find.text('route:/notifications'), findsOneWidget);
  });
}
