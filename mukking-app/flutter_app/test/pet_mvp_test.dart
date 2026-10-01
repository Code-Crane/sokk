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
import 'package:mukking_flutter_app/core/theme/brand_assets.dart';
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
  testWidgets('single mascot replaces selection without writing a pet', (tester) async {
    final repo = FakePets();
    await mount(tester, repo);
    expect(find.byType(MukkingMascot), findsOneWidget);
    expect(find.text('먹킹과 함께할 준비 중이에요.'), findsOneWidget);
    for (final type in PetType.values) {
      expect(find.text('${type.label} 선택'), findsNothing);
    }
    expect(repo.writes, 0);
    expect(tester.takeException(), isNull);
  });
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
    testWidgets(
        'parse and restore original type with available art ${type.name}',
        (tester) async {
      final pet = fixture(type);
      expect(pet.type, type);
      expect(pet.xp, 150);
      expect((await rootBundle.load(type.assetForStage('꼬마'))).lengthInBytes,
          greaterThan(0));
      if (type.isLegacy) {
        expect(type.assetForMood(), 'assets/pets/dog/dog_happy.png');
      }
      await mount(tester, FakePets()..pet = pet);
      expect(tester.widget<PetImage>(find.byType(PetImage)).type, type);
      expect(tester.widget<PetImage>(find.byType(PetImage)).mascotAsset,
          BrandAssets.defaultMascot);
      expect(tester.takeException(), isNull);
    });
  }
  for (final type in PetType.selectable) {
    test('API saves and restores ${type.name} without legacy conversion',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
      Map<String, dynamic>? saved;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.method == 'POST') {
          expect(options.path, '/api/pets/me');
          expect(options.data, {'petType': type.name});
          saved = dto(type);
        }
        handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: saved));
      }));
      final repo = ApiPetRepository(ApiClient(dio));
      expect((await repo.select(type)).type, type);
      expect((await ApiPetRepository(ApiClient(dio)).getMe())?.type, type);
      dio.close();
    });
    for (final mood in PetMood.values) {
      testWidgets('bundled ${type.name} ${mood.name} pose', (tester) async {
        expect(type.assetForMood(mood),
            'assets/pets/${type.name}/${type.name}_${mood.name}.png');
        expect((await rootBundle.load(type.assetForMood(mood))).lengthInBytes,
            greaterThan(0));
      });
    }
    testWidgets('saved ${type.name} uses mascot without changing type or XP', (tester) async {
      final repo = FakePets()..pet = fixture(type);
      await mount(tester, repo);
      final widget = tester.widget<PetImage>(find.byType(PetImage));
      expect(widget.type, type);
      expect(widget.mascotAsset, BrandAssets.defaultMascot);
      expect(repo.pet?.xp, 150);
      expect(repo.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('MY mascot entry and back preserve empty record', (tester) async {
    final repo = FakePets();
    await mount(tester, repo, path: '/my');
    await tester.tap(find.text('먹킹 보러가기'));
    await tester.pumpAndSettle();
    expect(find.text('먹킹과 함께할 준비 중이에요.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('먹킹 보러가기'), findsOneWidget);
    expect(repo.writes, 0);
  });
  test('legacy selection service failure remains retryable', () async {
    final repo = FakePets()..failWrite = true;
    final c = ProviderContainer(overrides: overrides(repo));
    addTearDown(c.dispose);
    final subscription = c.listen(selectPetProvider, (_, __) {});
    addTearDown(subscription.close);
    expect(await c.read(selectPetProvider.notifier).select(PetType.dog), false);
    expect(repo.pet, isNull);
    repo.failWrite = false;
    expect(await c.read(selectPetProvider.notifier).select(PetType.dog), true);
    expect(repo.pet?.type, PetType.dog);
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
      await tester.tap(find.text('펫 보러가기'));
    await tester.pumpAndSettle();
    expect(find.text('다음 성장: Lv. 5 새싹 친구'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
