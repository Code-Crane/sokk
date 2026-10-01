import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_api.dart';
import 'package:mukking_flutter_app/core/router/app_router.dart';
import 'package:mukking_flutter_app/core/router/app_routes.dart';
import 'package:mukking_flutter_app/core/theme/brand_assets.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_repository.dart';
import 'package:mukking_flutter_app/features/matching/data/mock_party_repository.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/presentation/create_party_screen.dart';
import 'package:mukking_flutter_app/main.dart';

const _submit = Key('create_party_submit_button');
const _restaurant = Restaurant(
  id: 'create-restaurant',
  name: '테스트 함께 먹는 식당',
  category: '한식',
  address: '부산 테스트 주소 1',
  latitude: null,
  longitude: null,
  distanceMeters: null,
  imageUrl: '',
  isFavorite: false,
  activePartyCount: 0,
  imageLabel: '',
  markerDx: 0,
  markerDy: 0,
);

void main() {
  test('create wire contract keeps intro, total capacity and UTC schedule', () {
    final date = DateTime(2026, 10, 1, 19, 30);
    final json = CreateMatchingPostRequest(
            restaurantId: 'create-restaurant',
            restaurantName: '식당',
            address: '주소',
            scheduledAt: date,
            maxParticipants: 4,
            intro: '소개')
        .toJson();
    expect(json, {
      'restaurantId': 'create-restaurant',
      'restaurantName': '식당',
      'address': '주소',
      'scheduledAt': date.toUtc().toIso8601String(),
      'maxParticipants': 4,
      'intro': '소개',
    });
  });

  testWidgets(
      'past schedule is rejected next to date and time without API call',
      (tester) async {
    final repo = _Repository();
    final container = _container(repo);
    addTearDown(container.dispose);
    await _pump(tester, container, preset: true);
    await tester.tap(find.byKey(const Key('create-date')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime.now());
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-time')));
    await tester.pumpAndSettle();
    // Return a valid picker value (today at midnight is already in the past).
    Navigator.of(tester.element(find.byType(TimePickerDialog)))
        .pop(const TimeOfDay(hour: 0, minute: 0));
    await tester.pumpAndSettle();
    expect(find.text('00:00'), findsOneWidget);
    await _visible(tester, _submit);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(repo.inputs, isEmpty);
    await _visible(tester, const Key('create-schedule-error'));
    expect(find.text('현재보다 이후 날짜와 시간을 선택해주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final kind in [ApiErrorKind.server, ApiErrorKind.network]) {
    testWidgets('$kind retains form and exposes safe retry message',
        (tester) async {
      final pending = Completer<MatchingParty>();
      final repo = _Repository()..pending = pending;
      final container = _container(repo);
      addTearDown(container.dispose);
      await _pump(tester, container, preset: true);
      await _visible(tester, _submit);
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      pending.completeError(ApiError(
          kind: kind,
          userMessage: '연결을 확인하고 다시 시도해주세요.',
          serverMessage: 'private-debug'));
      await tester.pumpAndSettle();
      expect(find.text('연결을 확인하고 다시 시도해주세요.'), findsOneWidget);
      expect(find.textContaining('private-debug'), findsNothing);
      expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('create-intro')))
              .controller!
              .text,
          '${_restaurant.name} 같이 가요');
      expect(tester.widget<FilledButton>(find.byKey(_submit)).onPressed,
          isNotNull);
    });
  }
  setUpAll(() async {
    if (!const bool.fromEnvironment('CREATE_CAPTURE')) return;
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

  for (final layout in [(390.0, 1.0), (360.0, 1.0), (360.0, 1.8)]) {
    testWidgets('create layout ${layout.$1} scale ${layout.$2} keyboard safe',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final restaurant = layout.$2 > 1
          ? _restaurant.copyWith(
              name: '아주 긴 한국어 이름을 사용하는 함께 먹는 식당 테스트',
              address: '부산광역시 중구 긴 한국어 주소와 상세 위치를 자연스럽게 줄바꿈하는 테스트 주소 101동 202호',
            )
          : _restaurant;
      final container = _container(_Repository(), restaurant: restaurant);
      addTearDown(container.dispose);
      await _pump(tester, container, preset: true);
      expect(find.byKey(const Key('create-restaurant-name')), findsNothing);
      expect(find.text(restaurant.name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'create-${layout.$1}-${layout.$2}');
      await _visible(tester, const Key('create-intro'));
      await tester.enterText(find.byKey(const Key('create-intro')),
          '함께 편하게 식사하며 서로 배려하는 즐거운 시간을 보내요. 긴 한국어 소개도 자연스럽게 읽을 수 있어야 해요.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _visible(tester, _submit);
      expect(find.byKey(_submit).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'keyboard-${layout.$1}-${layout.$2}');
    });
  }

  testWidgets('preset keeps restaurant identity and success navigates to party',
      (tester) async {
    final repo = _Repository();
    final container = _container(repo);
    addTearDown(container.dispose);
    await _pump(tester, container, preset: true);
    expect(find.text(_restaurant.category), findsOneWidget);
    await _visible(tester, _submit);
    expect(
      tester
          .widget<FilledButton>(find.byKey(_submit))
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{}),
      MukkingBrand.green,
    );
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(repo.inputs, hasLength(1));
    final input = repo.inputs.single;
    expect(input.restaurantId, _restaurant.id);
    expect(input.restaurantName, _restaurant.name);
    expect(input.address, _restaurant.address);
    expect(input.maxParticipants, 4);
    expect(input.intro, '${_restaurant.name} 같이 가요');
    expect(input.scheduledAt.isAfter(DateTime.now()), isTrue);
    expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        AppRoutes.partyDetailPath(repo.created!.id));
  });

  testWidgets('manual required errors stay by fields and capacity is 2 to 8',
      (tester) async {
    final repo = _Repository();
    final container = _container(repo);
    addTearDown(container.dispose);
    await _pump(tester, container);
    await _visible(tester, _submit);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(repo.inputs, isEmpty);
    expect(find.text('식당명을 입력해주세요.'), findsOneWidget);
    expect(find.text('주소를 입력해주세요.'), findsOneWidget);
    expect(find.text('모임 소개를 입력해주세요.'), findsOneWidget);
    await _visible(tester, const Key('create-capacity'));
    final capacity = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('create-capacity')));
    // The picker cannot produce an out-of-range value.
    expect(capacity.initialValue, 4);
    await tester.tap(find.byKey(const Key('create-capacity')));
    await tester.pumpAndSettle();
    for (final count in [2, 3, 4, 5, 6, 7, 8]) {
      expect(find.text('$count명'), findsWidgets);
    }
    expect(find.text('9명'), findsNothing);
    await tester.tap(find.text('8명').last);
    await tester.pumpAndSettle();
    for (final field in [
      (const Key('create-restaurant-name'), '직접 입력 식당'),
      (const Key('create-address'), '직접 입력 주소'),
      (const Key('create-intro'), '편하게 저녁 같이 먹어요'),
    ]) {
      await _visible(tester, field.$1);
      await tester.enterText(find.byKey(field.$1), field.$2);
    }
    await _visible(tester, _submit);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(repo.inputs.single.restaurantId, isNull);
    expect(repo.inputs.single.maxParticipants, 8);
    expect(repo.inputs.single.intro, '편하게 저녁 같이 먹어요');
  });

  testWidgets('existing date and time pickers keep their values on cancel',
      (tester) async {
    final container = _container(_Repository());
    addTearDown(container.dispose);
    await _pump(tester, container, preset: true);
    await tester.tap(find.byKey(const Key('create-date')));
    await tester.pumpAndSettle();
    final picker =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(picker.firstDate.day, DateTime.now().day);
    expect(picker.initialDate!.isAfter(picker.firstDate), isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-time')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 19, minute: 30));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('19:30'), findsOneWidget);
  });

  testWidgets('submit lock handles rapid taps and failure permits retry',
      (tester) async {
    final pending = Completer<MatchingParty>();
    final repo = _Repository()..pending = pending;
    final container = _container(repo);
    addTearDown(container.dispose);
    await _pump(tester, container, preset: true);
    await _visible(tester, _submit);
    final submit = tester.widget<FilledButton>(find.byKey(_submit)).onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(repo.inputs, hasLength(1));
    expect(tester.widget<FilledButton>(find.byKey(_submit)).onPressed, isNull);
    expect(find.text('모임 만드는 중...'), findsOneWidget);
    pending.completeError(StateError('private server detail'));
    await tester.pumpAndSettle();
    expect(find.text('파티를 만들지 못했어요.'), findsOneWidget);
    expect(find.textContaining('private server'), findsNothing);
    repo.pending = null;
    await _visible(tester, _submit);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(repo.inputs, hasLength(2));
    expect(find.byType(CreatePartyScreen), findsNothing);
  });

  testWidgets('intro retains existing 80 character limit', (tester) async {
    final container = _container(_Repository());
    addTearDown(container.dispose);
    await _pump(tester, container, preset: true);
    await _visible(tester, const Key('create-intro'));
    final field =
        tester.widget<TextFormField>(find.byKey(const Key('create-intro')));
    await tester.enterText(find.byKey(const Key('create-intro')), '가' * 100);
    expect(field.controller!.text.length, 80);
  });
}

ProviderContainer _container(_Repository repo,
        {Restaurant restaurant = _restaurant}) =>
    ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(AppConfig.test()),
      matchingRepositoryProvider.overrideWithValue(repo),
      restaurantDetailProvider(_restaurant.id)
          .overrideWith((ref) => AsyncData(restaurant)),
    ]);

Future<void> _pump(WidgetTester tester, ProviderContainer container,
    {bool preset = false}) async {
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const RepaintBoundary(
          key: Key('create-capture'), child: MukkingApp())));
  container.read(appRouterProvider).go(
      AppRoutes.createPartyPath(restaurantId: preset ? _restaurant.id : null));
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

class _Repository extends MockMatchingRepository {
  _Repository() : super(const MockPartyRepository());
  final inputs = <CreatePartyInput>[];
  Completer<MatchingParty>? pending;
  MatchingParty? created;
  @override
  Future<MatchingParty> createParty(CreatePartyInput input) async {
    inputs.add(input);
    if (pending != null) return pending!.future;
    return created = await super.createParty(input);
  }

  @override
  Future<MatchingParty?> findPartyById(String id) async => created;
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CREATE_CAPTURE')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('create-capture')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/create_party_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
