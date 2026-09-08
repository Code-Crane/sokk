import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_client.dart';
import 'package:mukking_flutter_app/core/router/app_routes.dart';
import 'package:mukking_flutter_app/core/router/app_router.dart';
import 'package:mukking_flutter_app/core/theme/app_theme.dart';
import 'package:mukking_flutter_app/core/theme/theme_tokens.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/pet/domain/pet.dart';
import 'package:mukking_flutter_app/features/pet/data/pet_repository.dart';
import 'package:mukking_flutter_app/features/pet/providers/pet_provider.dart';
import 'package:mukking_flutter_app/features/pet/presentation/pet_screen.dart';
import 'package:mukking_flutter_app/features/pet/presentation/pet_widgets.dart';

Pet fixture([PetType type = PetType.healthy]) => Pet.fromJson(dto(type));
Map<String, dynamic> dto(PetType type) => {
      'id': 'pet-${type.name}',
      'petType': type.name,
      'name': null,
      'xp': 150,
      'level': 2,
      'growthStage': '꼬마',
      'levelXp': 50,
      'nextLevelXp': 125,
      'remainingXp': 75,
      'progress': 0.4,
    };

class FakePets implements PetRepository {
  Pet? pet;
  int reads = 0, writes = 0;
  bool failRead = false, failWrite = false;
  Completer<Pet>? pending;
  @override
  Future<Pet?> getMe() async {
    reads++;
    if (failRead) throw StateError('offline');
    return pet;
  }

  @override
  Future<Pet> select(PetType type) async {
    writes++;
    if (failWrite) throw StateError('offline');
    return pet = pending == null ? fixture(type) : await pending!.future;
  }
}

final testIdentity =
    StateProvider<AuthUser?>((ref) => AuthUser.fallback(id: 'A', email: ''));
List<Override> overrides(PetRepository repository) => [
      appConfigProvider.overrideWithValue(AppConfig.test()),
      currentUserProvider.overrideWith((ref) => ref.watch(testIdentity)),
      petRepositoryProvider.overrideWithValue(repository),
    ];
Future<GoRouter> mount(WidgetTester tester, FakePets repository,
    {String path = '/pet'}) async {
  final router = GoRouter(initialLocation: path, routes: [
    GoRoute(
        path: '/my',
        builder: (context, state) => const Scaffold(body: MyPetCard())),
    GoRoute(
        path: '/pet',
        builder: (context, state) => const Scaffold(body: PetScreen())),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: overrides(repository),
      child: MaterialApp.router(
          theme: AppTheme.build(MukkingThemeId.violet), routerConfig: router)));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('production router registers pet direct path', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final router = c.read(appRouterProvider);
    final shell = router.configuration.routes.whereType<ShellRoute>().first;
    expect(
        shell.routes.whereType<GoRoute>().any((r) => r.path == AppRoutes.pet),
        isTrue);
    router.dispose();
  });
  test('server progress and level30 parsed without client XP invention', () {
    expect(fixture().progressLabel, contains('75 XP'));
    final capped = Pet.fromJson({
      ...dto(PetType.night),
      'xp': 50000,
      'level': 30,
      'growthStage': '먹킹 마스터',
      'nextLevelXp': null,
      'remainingXp': 0,
      'progress': 1,
      'levelXp': 0
    });
    expect(capped.nextGrowthLabel, contains('도달'));
    expect(capped.progressLabel, contains('최고 레벨'));
    expect(capped.xp, 50000);
  });
  test('GET null and POST only petType through existing client', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
    final calls = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(options);
      handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: options.method == 'GET' ? null : dto(PetType.hearty)));
    }));
    final repo = ApiPetRepository(ApiClient(dio));
    expect(await repo.getMe(), isNull);
    expect((await repo.select(PetType.hearty)).type, PetType.hearty);
    expect(calls.map((r) => r.path), ['/api/pets/me', '/api/pets/me']);
    expect(calls.map((r) => r.method), ['GET', 'POST']);
    expect(calls.map((r) => r.uri.toString()), [
      'http://localhost:4000/api/pets/me',
      'http://localhost:4000/api/pets/me',
    ]);
    expect(calls.last.data, {'petType': 'hearty'});
    dio.close();
  });
  test('duplicate taps one POST; reload uses repository', () async {
    final repo = FakePets()..pending = Completer<Pet>();
    final c = ProviderContainer(overrides: overrides(repo));
    addTearDown(c.dispose);
    final subscription = c.listen(selectPetProvider, (_, __) {});
    addTearDown(subscription.close);
    final first = c.read(selectPetProvider.notifier).select(PetType.healthy);
    expect(
        await c.read(selectPetProvider.notifier).select(PetType.night), false);
    expect(repo.writes, 1);
    repo.pending!.complete(fixture());
    expect(await first, true);
    expect((await c.read(myPetProvider.future))?.type, PetType.healthy);
    c.invalidate(myPetProvider);
    expect((await c.read(myPetProvider.future))?.type, PetType.healthy);
  });
  test('account switch ignores old in-flight selection and restores own pet',
      () async {
    final a = FakePets()..pending = Completer<Pet>();
    final b = FakePets()..pet = fixture(PetType.night);
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(AppConfig.test()),
      currentUserProvider.overrideWith((ref) => ref.watch(testIdentity)),
      petRepositoryProvider.overrideWith(
          (ref) => ref.watch(currentUserProvider)?.id == 'A' ? a : b),
    ]);
    addTearDown(c.dispose);
    final keep = c.listen(selectPetProvider, (_, __) {});
    addTearDown(keep.close);
    final read = c.listen(myPetProvider, (_, __) {});
    addTearDown(read.close);
    final old = c.read(selectPetProvider.notifier).select(PetType.healthy);
    c.read(testIdentity.notifier).state = AuthUser.fallback(id: 'B', email: '');
    await c.pump();
    expect((await c.read(myPetProvider.future))?.type, PetType.night);
    a.pending!.complete(fixture());
    expect(await old, false);
    expect(c.read(selectPetProvider).value, isNull);
    expect((await c.read(myPetProvider.future))?.type, PetType.night);
  });
  test('logout API mode does not fetch another pet', () async {
    final repo = FakePets();
    final c = ProviderContainer(overrides: [
      ...overrides(repo),
      appConfigProvider
          .overrideWithValue(AppConfig.test(dataSource: AppDataSource.api)),
      currentUserProvider.overrideWithValue(null),
    ]);
    addTearDown(c.dispose);
    expect(await c.read(myPetProvider.future), isNull);
    expect(repo.reads, 0);
  });
  for (final type in PetType.values) {
    testWidgets('canonical asset and confirmed selection ${type.name}',
        (tester) async {
      final bytes = await rootBundle.load(type.assetForStage('꼬마'));
      expect(bytes.lengthInBytes, greaterThan(0));
      expect(type.assetForStage('먹킹 마스터'), type.assetForStage('꼬마'));
      final repo = FakePets();
      await mount(tester, repo);
      await tester.scrollUntilVisible(find.text('${type.label} 선택'), 250);
      await tester.ensureVisible(find.text('${type.label} 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${type.label} 선택'));
      await tester.pumpAndSettle();
      expect(find.text('${type.label}와 함께할까요?'), findsOneWidget);
      expect(repo.writes, 0);
      await tester.tap(find.text('함께하기'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.pet?.type, type);
      expect(find.text('Lv. 2 · 꼬마'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('MY empty CTA opens selection and back returns MY',
      (tester) async {
    final repo = FakePets();
    await mount(tester, repo, path: '/my');
    await tester.tap(find.text('펫 선택하기'));
    await tester.pumpAndSettle();
    expect(find.text('함께할 식탁 친구를 선택해주세요.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('펫 선택하기'), findsOneWidget);
  });
  testWidgets('selection cancel does not write', (tester) async {
    final repo = FakePets();
    await mount(tester, repo);
    await tester.tap(find.text('건강이 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
  });
  testWidgets('failed selection can retry and never shows fake success',
      (tester) async {
    final repo = FakePets()..failWrite = true;
    await mount(tester, repo);
    await tester.tap(find.text('건강이 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('함께하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('펫 선택을 완료하지 못했어요'), findsOneWidget);
    expect(repo.pet, isNull);
    repo.failWrite = false;
    await tester.ensureVisible(find.text('건강이 선택'));
    await tester.tap(find.text('건강이 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('함께하기'));
    await tester.pumpAndSettle();
    expect(repo.pet, isNotNull);
  });
  testWidgets('direct load failure retry reads server state', (tester) async {
    final repo = FakePets()..failRead = true;
    await mount(tester, repo);
    expect(find.textContaining('펫 정보를 불러오지 못했어요'), findsOneWidget);
    repo
      ..failRead = false
      ..pet = fixture();
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('총 150 XP'), findsOneWidget);
    expect(repo.reads, 2);
  });
  testWidgets('360px MY pet card and detail no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakePets()..pet = fixture();
    await mount(tester, repo, path: '/my');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('내 펫 자세히 보기'));
    await tester.pumpAndSettle();
    expect(find.text('다음 성장: Lv. 5 새싹 친구'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
