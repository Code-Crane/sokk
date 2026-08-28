import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/features/auth/data/auth_repository.dart';
import 'package:mukking_flutter_app/features/chat/providers/chat_provider.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_api.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_repository.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/domain/map_camera_center.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/discovery_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/fullscreen_map_screen.dart';
import 'package:mukking_flutter_app/features/discovery/presentation/restaurant_bottom_sheet.dart';
import 'package:mukking_flutter_app/features/home/providers/home_provider.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_api.dart';
import 'package:mukking_flutter_app/features/notifications/data/notification_api.dart';
import 'package:mukking_flutter_app/features/notifications/data/notification_repository.dart';
import 'package:mukking_flutter_app/features/notifications/providers/notification_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  testWidgets('renders mukking home shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MukkingApp(),
      ),
    );

    expect(find.text('먹킹'), findsWidgets);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('발견'), findsOneWidget);
  });

  testWidgets('mock discovery renders restaurants and latest fields',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();

    expect(find.text('Kakao Map 설정 필요'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('멘야 하쿠'), findsWidgets);
    expect(find.text('라멘 · 800m'), findsWidgets);
    expect(find.text('현재 모집 중 파티 2개'), findsOneWidget);
  });

  testWidgets('restaurant marker opens details and keeps favorite flow',
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

    final marker = find.byKey(
      const ValueKey('restaurant-map-marker-restaurant-001'),
    );
    expect(marker, findsOneWidget);
    final markerSize = tester.getSize(marker);
    expect(markerSize.width, greaterThanOrEqualTo(44));
    expect(markerSize.height, greaterThanOrEqualTo(44));

    await tester.tap(marker);
    await tester.pumpAndSettle();

    expect(container.read(selectedRestaurantFocusRequestProvider), 0);
    expect(find.byKey(restaurantDetailsSheetKey), findsOneWidget);
    expect(find.text('멘야 하쿠'), findsWidgets);
    expect(find.text('라멘 · 800m'), findsWidgets);
    expect(find.text('현재 모집 중 파티 2개'), findsWidgets);
    await tester.tap(find.text('가고 싶어요').last);
    await tester.pumpAndSettle();
    expect(find.text('찜 취소'), findsOneWidget);
    expect(container.read(selectedRestaurantFocusRequestProvider), 0);
  });

  testWidgets('nearby restaurant card selects restaurant and opens details',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(restaurantListQueryProvider.notifier).state =
        const RestaurantListQuery(
      lat: 37.5,
      lng: 127.0,
      radiusKm: 5,
      limit: 50,
      offset: 0,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(nearbyRestaurantListKey), findsOneWidget);
    final card = find.byKey(
      const ValueKey('nearby-restaurant-card-restaurant-001'),
    );
    expect(card, findsOneWidget);
    expect(find.text('라멘 · 800m'), findsWidgets);

    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(
      container.read(selectedRestaurantIdProvider),
      'restaurant-001',
    );
    expect(container.read(selectedRestaurantFocusRequestProvider), 1);
    expect(find.byKey(restaurantDetailsSheetKey), findsOneWidget);
    expect(find.text('멘야 하쿠'), findsWidgets);
    expect(find.text('현재 모집 중 파티 2개'), findsWidgets);
    expect(container.read(selectedRestaurantFocusRequestProvider), 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(container.read(selectedRestaurantFocusRequestProvider), 2);
  });

  testWidgets('empty nearby response explains the five kilometer context',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        restaurantRepositoryProvider.overrideWithValue(
          _EmptyRestaurantRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(restaurantListQueryProvider.notifier).state =
        const RestaurantListQuery(
      lat: 37.5,
      lng: 127.0,
      radiusKm: 5,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();

    expect(
      find.text('현재 위치 5km 안에 등록된 식당이 없어요.'),
      findsWidgets,
    );
    expect(find.byKey(nearbyRestaurantListKey), findsNothing);
  });

  testWidgets('fullscreen map opens, keeps marker interaction and closes',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MukkingApp(),
      ),
    );
    await tester.tap(find.text('발견'));
    await tester.pumpAndSettle();

    expect(find.byKey(fullscreenMapButtonKey), findsOneWidget);
    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);
    expect(find.byKey(closeFullscreenMapButtonKey), findsOneWidget);
    expect(find.byKey(focusCurrentLocationButtonKey), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('restaurant-map-marker-restaurant-002')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(restaurantDetailsSheetKey), findsOneWidget);
    expect(find.text('성수 숯불연구소'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(restaurantDetailsSheetKey), findsNothing);
    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(closeFullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsNothing);
    expect(find.byKey(fullscreenMapButtonKey), findsOneWidget);

    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenMapScreenKey), findsNothing);
    expect(find.byKey(fullscreenMapButtonKey), findsOneWidget);
  });

  testWidgets('search-this-area button is shared with fullscreen map',
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
    expect(find.byKey(searchThisAreaButtonKey), findsNothing);

    final controller = container.read(searchAreaProvider.notifier);
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.1146, longitude: 129.037),
        userInitiated: false,
      ),
    );
    controller.onCameraIdle(
      const MapCameraIdleEvent(
        center: MapCameraCenter(latitude: 35.12, longitude: 129.045),
        userInitiated: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(searchThisAreaButtonKey), findsOneWidget);

    await tester.tap(find.byKey(fullscreenMapButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenSearchThisAreaButtonKey), findsOneWidget);

    await tester.tap(find.byKey(fullscreenSearchThisAreaButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(fullscreenSearchThisAreaButtonKey), findsNothing);
    expect(container.read(searchAreaProvider).hasMovedMeaningfully, isFalse);
  });

  testWidgets('MY login button is connected and validates form',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MukkingApp(),
      ),
    );
    await tester.tap(find.text('MY'));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pump();
    expect(find.text('이메일을 확인해주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해주세요.'), findsOneWidget);
  });

  testWidgets('API mode gates protected screens until authenticated',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.test(dataSource: AppDataSource.api),
          ),
        ],
        child: const MukkingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('인기 파티'), findsNothing);
  });

  test('favorite restaurant updates home parties and notifications', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(favoriteRestaurantPartiesProvider), isEmpty);
    await container.read(restaurantFeedProvider.future);
    expect(await container.read(notificationsProvider.future), isEmpty);

    await container.read(matchingPartiesProvider.future);

    final restaurant = container.read(restaurantsProvider).firstWhere(
          (item) => item.id == 'restaurant-001',
        );
    await container.read(favoriteOverridesProvider.notifier).toggle(restaurant);

    expect(container.read(favoriteRestaurantPartiesProvider), hasLength(2));
    expect(await container.read(notificationsProvider.future), hasLength(2));
  });

  test('mock matching fallback supports join request', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final parties = await container.read(matchingPartiesProvider.future);
    expect(parties, isNotEmpty);

    final result = await container
        .read(joinPartyControllerProvider.notifier)
        .join(parties.first.id);

    expect(result?.status, 'pending');
  });

  test('mock chat fallback exposes rooms and messages', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final rooms = await container.read(chatRoomsProvider.future);
    expect(rooms, hasLength(1));

    final messages =
        await container.read(chatMessagesProvider(rooms.first.id).future);
    expect(
      messages.map((message) => message.text),
      contains('좋아요. 도착하면 입구에서 만나요.'),
    );
  });

  test('auth state is unauthenticated without supabase config', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(authRepositoryProvider).currentState();
    expect(state.isAuthenticated, isFalse);
  });

  test('api error mapping hides server details from user message', () {
    final unauthorized = ApiError.fromStatusCode(
      401,
      serverMessage: 'Invalid or expired Supabase JWT.',
    );
    final forbidden = ApiError.fromStatusCode(403);
    final conflict = ApiError.fromStatusCode(409);
    final rateLimited = ApiError.fromStatusCode(429);
    final server = ApiError.fromStatusCode(500);

    expect(unauthorized.userMessage, '로그인이 필요해요.');
    expect(forbidden.userMessage, contains('권한'));
    expect(conflict.userMessage, contains('중복'));
    expect(rateLimited.userMessage, contains('잠시 후'));
    expect(server.userMessage, contains('서버 오류'));
    expect(unauthorized.userMessage, isNot(contains('JWT')));
  });

  test('latest restaurant response fields map without precision loss', () {
    final restaurant = RestaurantDto.fromJson({
      'id': 'restaurant-api-1',
      'name': '계약 테스트 식당',
      'address': '서울시 성동구',
      'category': '한식',
      'latitude': 37.5,
      'longitude': 127.0,
      'distanceMeters': 845.4,
      'activePartyCount': 2,
      'isFavorite': true,
    });

    expect(restaurant.distanceMeters, 845);
    expect(restaurant.activePartyCount, 2);
    expect(restaurant.isFavorite, isTrue);
  });

  test('matching and notification contracts retain relationship ids', () {
    final createRequest = CreateMatchingPostRequest(
      restaurantId: 'restaurant-1',
      restaurantName: '식당',
      address: '주소',
      scheduledAt: DateTime.utc(2026, 8, 26, 10),
      maxParticipants: 4,
      intro: '같이 먹어요',
    );
    final post = MatchingPostDto.fromJson({
      'id': 'post-1',
      'authorId': 'user-1',
      'restaurantId': 'restaurant-1',
      'restaurantName': '식당',
      'address': '주소',
      'scheduledAt': '2026-08-24T10:00:00.000Z',
      'maxParticipants': 4,
      'intro': '같이 먹어요',
      'status': 'open',
      'participantIds': <String>[],
      'createdAt': '2026-08-24T00:00:00.000Z',
      'updatedAt': '2026-08-24T00:00:00.000Z',
    });
    final notification = NotificationDto.fromJson({
      'id': 'notification-1',
      'type': 'favorite_restaurant_party_created',
      'title': '새 파티',
      'body': '파티가 열렸어요.',
      'restaurantId': 'restaurant-1',
      'matchingPostId': 'post-1',
      'createdAt': '2026-08-24T00:00:00.000Z',
    });
    final response = RespondJoinRequestDto.fromJson({
      'request': {
        'id': 'request-1',
        'postId': 'post-1',
        'requesterId': 'user-2',
        'status': 'accepted',
        'createdAt': '2026-08-25T00:00:00.000Z',
      },
      'chatRoom': {'id': 'room-1'},
    });

    expect(post.restaurantId, 'restaurant-1');
    expect(createRequest.toJson(), {
      'restaurantId': 'restaurant-1',
      'restaurantName': '식당',
      'address': '주소',
      'scheduledAt': '2026-08-26T10:00:00.000Z',
      'maxParticipants': 4,
      'intro': '같이 먹어요',
    });
    expect(notification.restaurantId, post.restaurantId);
    expect(notification.matchingPostId, post.id);
    expect(notification.readAt, isNull);
    expect(response.request.status, 'accepted');
    expect(response.chatRoomId, 'room-1');
  });

  test('api data source selects api restaurant and notification layers',
      () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.test(dataSource: AppDataSource.api),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(restaurantRepositoryProvider),
      isA<ApiRestaurantRepository>(),
    );
    expect(
      await container.read(notificationRepositoryProvider.future),
      isA<ApiNotificationRepository>(),
    );
  });
}

class _EmptyRestaurantRepository implements RestaurantRepository {
  @override
  Future<List<Restaurant>> discover(RestaurantDiscoverRequest request) async =>
      const [];

  @override
  Future<Restaurant?> getById(String restaurantId) async => null;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async => const [];

  @override
  Future<List<Restaurant>> listFavorites() async => const [];

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    return restaurant.copyWith(isFavorite: isFavorite);
  }
}
