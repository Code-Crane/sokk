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

    expect(find.text('지도 placeholder'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('멘야 하쿠'), findsOneWidget);
    expect(find.text('라멘 · 800m'), findsOneWidget);
    expect(find.text('현재 모집 중 파티 2개'), findsOneWidget);
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
