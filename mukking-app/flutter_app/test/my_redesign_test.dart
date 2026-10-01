import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mukking_flutter_app/core/theme/brand_assets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/router/app_router.dart';
import 'package:mukking_flutter_app/core/router/app_routes.dart';
import 'package:mukking_flutter_app/features/auth/data/auth_repository.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_state.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_repository.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/features/pet/domain/pet.dart';
import 'package:mukking_flutter_app/features/pet/providers/pet_provider.dart';
import 'package:mukking_flutter_app/features/pet/presentation/pet_widgets.dart';
import 'package:mukking_flutter_app/features/profile/domain/profile_summary.dart';
import 'package:mukking_flutter_app/features/profile/presentation/my_screen.dart';
import 'package:mukking_flutter_app/features/profile/providers/profile_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  testWidgets('MY activity and settings shortcuts reach their real sections',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _container(pet: _pet(PetType.cat), populated: true);
    addTearDown(container.dispose);
    await _pump(tester, container);
    expect(find.bySemanticsLabel('먹킹'), findsWidgets);
    await _visible(tester, find.text('내 모집글'));
    await tester.tap(find.text('내 모집글'));
    await tester.pumpAndSettle();
    expect(find.byKey(myPartiesCardKey), findsOneWidget);
    await _visible(tester, find.text('찜한 맛집'), delta: -250);
    await tester.tap(find.text('찜한 맛집'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('my-favorite-restaurant')), findsOneWidget);
    await _visible(tester, find.byTooltip('설정으로 이동'), delta: -250);
    await tester.tap(find.byTooltip('설정으로 이동'));
    await tester.pumpAndSettle();
    await _visible(tester, find.text('화면 테마'));
    await tester.tap(find.text('화면 테마'));
    await tester.pumpAndSettle();
    expect(find.text('내 먹킹 테마'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('party retry reloads source feed without hiding profile and pet',
      (tester) async {
    var calls = 0;
    final container = _container(
        pet: _pet(PetType.dog),
        feed: () async {
          calls++;
          if (calls == 1) throw StateError('private');
          return MatchingFeed(parties: [_party('hosted')], restaurants: []);
        });
    addTearDown(container.dispose);
    await _pump(tester, container);
    expect(find.byType(PetImage), findsOneWidget);
    await _visible(tester, find.byKey(const Key('my-parties-retry')));
    expect(find.text('내 모임을 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('my-parties-retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(myAuthoredPartyKey('hosted')), findsOneWidget);
  });
  setUpAll(() async {
    if (!const bool.fromEnvironment('MY_CAPTURE')) return;
    for (final family in ['Roboto', 'Ahem']) {
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
  for (final type in PetType.values) {
    testWidgets('MY and Pet Detail preserve ${type.name} image and growth',
        (tester) async {
      final container = _container(pet: _pet(type));
      addTearDown(container.dispose);
      await _pump(tester, container);
      expect(tester.widget<PetImage>(find.byType(PetImage)).type, type);
      final asset = tester
          .widget<Image>(find.descendant(
              of: find.byType(PetImage), matching: find.byType(Image)))
          .image as AssetImage;
      expect(asset.assetName, BrandAssets.heart);
      expect(find.text('Lv.2'), findsOneWidget);
      await _visible(tester, find.byKey(const Key('my-pet-entry')));
      await tester.tap(find.byKey(const Key('my-pet-entry')));
      await tester.pumpAndSettle();
      expect(
          container
              .read(appRouterProvider)
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          AppRoutes.pet);
      expect(tester.widget<PetImage>(find.byType(PetImage)).type, type);
      expect(
        Theme.of(tester.element(find.text('내 먹킹 펫'))).colorScheme.primary,
        MukkingBrand.green,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final layout in [(390.0, 1.0), (360.0, 1.0), (360.0, 1.8)]) {
    testWidgets('MY layout ${layout.$1} scale ${layout.$2}', (tester) async {
      tester.view.physicalSize = Size(layout.$1, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = _container(pet: _pet(PetType.cat), populated: true);
      addTearDown(container.dispose);
      await _pump(tester, container);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'my-${layout.$1}-${layout.$2}');
      for (final key in [
        const Key('logout_button'),
        myPartiesCardKey,
        const ValueKey('my-favorite-restaurant'),
      ]) {
        await _visible(tester, find.byKey(key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (key == const Key('logout_button')) {
          await _capture(tester, 'my-settings-${layout.$1}-${layout.$2}');
        }
      }
    });
  }
  testWidgets('no pet and empty groups never invent mascot or statistics',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);
    expect(find.byType(PetImage), findsNothing);
    expect(find.text('먹킹 보러가기'), findsOneWidget);
    await _visible(tester, find.byKey(myPartiesCardKey));
    expect(find.text('첫 모임을 만들어보세요.'), findsOneWidget);
    await _visible(tester, find.text('아직 찜한 식당이 없어요'));
    expect(find.text('아직 찜한 식당이 없어요'), findsOneWidget);
    expect(find.textContaining('API 연결 예정'), findsNothing);
  });
  testWidgets(
      'profile loading and failure leave pet and other sections then retry',
      (tester) async {
    var calls = 0;
    final pending = Completer<ProfileSummary>();
    final container = _container(
        pet: _pet(PetType.dog),
        profile: () {
          calls++;
          return calls == 1 ? pending.future : Future.value(_profile());
        });
    addTearDown(container.dispose);
    await _pump(tester, container);
    expect(find.text('프로필을 불러오는 중이에요.'), findsOneWidget);
    expect(find.byType(PetImage), findsOneWidget);
    pending.completeError(StateError('private error'));
    await tester.pumpAndSettle();
    expect(find.text('프로필을 불러오지 못했어요.'), findsOneWidget);
    expect(find.textContaining('private error'), findsNothing);
    await tester.tap(find.byKey(const Key('my-profile-retry')));
    await tester.pumpAndSettle();
    expect(find.text(_user.nickname), findsOneWidget);
    expect(calls, 2);
  });
  testWidgets('favorite opens existing restaurant route and preserves back',
      (tester) async {
    final container = _container(populated: true);
    addTearDown(container.dispose);
    await _pump(tester, container);
    await _visible(
        tester, find.byKey(const ValueKey('my-favorite-restaurant')));
    await tester.tap(find.byKey(const ValueKey('my-favorite-restaurant')));
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.restaurantDetailPath('restaurant'));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MyScreen), findsOneWidget);
  });
  testWidgets(
      'logout cancel preserves account then confirm uses existing action',
      (tester) async {
    final repo = _AuthRepo();
    final container = _container(auth: repo);
    addTearDown(container.dispose);
    await _pump(tester, container);
    await _visible(tester, find.byKey(const Key('logout_button')));
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '로그아웃')));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
  });
}

final _user = AuthUser(
    id: 'me',
    nickname: '함께 식사하는 긴 한국어 닉네임의 먹킹 친구',
    email: 'test@example.invalid',
    verificationStatus: VerificationStatus.verified,
    mannerScore: 36.5,
    mannerGrade: MannerGrade.regular,
    pendingEvaluationCount: 1,
    createdAt: DateTime(2026));
ProfileSummary _profile() =>
    ProfileSummary(user: _user, verification: null, pendingEvaluationCount: 1);
Pet _pet(PetType type) => Pet(
    id: 'pet',
    type: type,
    xp: 250,
    level: 2,
    growthStage: '꼬마',
    levelXp: 50,
    nextLevelXp: 100,
    remainingXp: 50,
    progress: .5);
const _restaurant = Restaurant(
    id: 'restaurant',
    name: '긴 한국어 이름을 사용하는 함께 먹는 테스트 식당',
    category: '한식',
    address: '테스트 주소',
    latitude: null,
    longitude: null,
    distanceMeters: null,
    imageUrl: '',
    isFavorite: true,
    activePartyCount: 2,
    imageLabel: '',
    markerDx: 0,
    markerDy: 0);
MatchingParty _party(String id) => MatchingParty(
    id: id,
    hostUserId: id == 'hosted' ? 'me' : 'other',
    restaurantId: 'restaurant',
    restaurantName: _restaurant.name,
    title: '실제 모임 소개',
    scheduledAt: DateTime(2026, 10, 1, 19, 30),
    currentMembers: 2,
    maxMembers: 4,
    distanceKm: 0,
    rewardXp: 0,
    rewardPoints: 0,
    status: MatchingPartyStatus.open,
    hostName: '',
    memberNames: const [],
    tags: const [],
    description: '');
ProviderContainer _container(
        {Pet? pet,
        bool populated = false,
        Future<MatchingFeed> Function()? feed,
        Future<ProfileSummary> Function()? profile,
        _AuthRepo? auth}) =>
    ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(AppConfig.test()),
      authControllerProvider.overrideWith((ref) =>
          AuthController(auth ?? _AuthRepo())
            ..set(MukkingAuthState.authenticated(user: _user))),
      profileSummaryProvider
          .overrideWith((ref) => profile?.call() ?? Future.value(_profile())),
      myPetProvider.overrideWith((ref) async => pet),
      if (feed != null) matchingFeedProvider.overrideWith((ref) => feed()),
      if (feed == null)
        myPartyOverviewProvider.overrideWith((ref) async => MyPartyOverview(
            authored: populated ? [_party('hosted')] : [],
            confirmed: populated ? [_party('joined')] : [])),
      restaurantFeedProvider
          .overrideWith((ref) async => populated ? [_restaurant] : []),
    ]);
Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child:
          const RepaintBoundary(key: Key('my-capture'), child: MukkingApp())));
  container.read(appRouterProvider).go(AppRoutes.my);
  await tester.pumpAndSettle();
}

class _AuthRepo implements AuthRepository {
  int calls = 0;
  @override
  Future<void> logout() async {
    calls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('MY_CAPTURE')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('my-capture')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/my_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _visible(WidgetTester tester, Finder finder,
    {double delta = 250}) async {
  await tester.scrollUntilVisible(finder, delta,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}
