import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mukking_flutter_app/features/chat/domain/chat_room.dart';
import 'package:mukking_flutter_app/features/chat/providers/chat_provider.dart';
import 'package:mukking_flutter_app/features/notifications/data/notification_api.dart';
import 'package:mukking_flutter_app/core/theme/app_theme.dart';
import 'package:mukking_flutter_app/core/theme/theme_tokens.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/notifications/data/notification_repository.dart';
import 'package:mukking_flutter_app/features/notifications/domain/app_notification.dart';
import 'package:mukking_flutter_app/features/notifications/providers/notification_provider.dart';
import 'package:mukking_flutter_app/features/notifications/presentation/notifications_screen.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';

AppNotification alert(String id,
        {int day = 1,
        String type = 'favorite_restaurant_party_created',
        String? roomId}) =>
    AppNotification(
        id: id,
        type: type,
        chatRoomId: roomId,
        title: id,
        body: '실제 알림',
        matchingPostId: 'missing-party',
        createdAt: DateTime(2026, 9, day));

class FailingNotifications extends MockNotificationRepository {
  FailingNotifications(super.items);
  bool failList = false;
  bool failRead = false;
  @override
  Future<List<AppNotification>> list({int limit = 50, int offset = 0}) {
    if (failList) throw StateError('unavailable');
    return super.list(limit: limit, offset: offset);
  }

  @override
  Future<AppNotification> markRead(String id) {
    if (failRead) throw StateError('unavailable');
    return super.markRead(id);
  }
}

void main() {
  test('core types and unknown type retain optional chat room', () {
    for (final type in [
      'join_request_received',
      'join_request_accepted',
      'join_request_rejected',
      'chat_message_created',
      'favorite_restaurant_party_created',
      'future_unknown'
    ]) {
      final dto = NotificationDto.fromJson({
        'id': 'n',
        'type': type,
        'chatRoomId': 'room-exact',
        'createdAt': '2026-09-07T00:00:00Z'
      });
      expect(dto.type, type);
      expect(dto.chatRoomId, 'room-exact');
      expect(
          alert('n', type: type, roomId: dto.chatRoomId)
              .copyWith(readAt: DateTime.now())
              .chatRoomId,
          'room-exact');
    }
  });
  test('newest first, read persistence and exact unread count', () async {
    final repository =
        MockNotificationRepository([alert('old'), alert('new', day: 2)]);
    final container = ProviderContainer(overrides: [
      notificationRepositoryProvider.overrideWith((ref) async => repository),
    ]);
    addTearDown(container.dispose);
    expect(
        (await container.read(notificationsProvider.future)).map((n) => n.id),
        ['new', 'old']);
    expect(await container.read(unreadNotificationCountProvider.future), 2);
    await container.read(markNotificationReadProvider.notifier).markRead('new');
    expect(await container.read(unreadNotificationCountProvider.future), 1);
    container.invalidate(notificationsProvider);
    expect((await container.read(notificationsProvider.future)).first.isRead,
        true);
  });

  test('account switch reloads notification and unread state', () async {
    final identity = StateProvider<String>((ref) => 'A');
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith(
          (ref) => AuthUser.fallback(id: ref.watch(identity), email: '')),
      notificationRepositoryProvider.overrideWith((ref) async =>
          MockNotificationRepository(ref.watch(currentUserProvider)?.id == 'A'
              ? [alert('A-only')]
              : [])),
    ]);
    addTearDown(container.dispose);
    expect((await container.read(notificationsProvider.future)).single.id,
        'A-only');
    container.read(identity.notifier).state = 'B';
    expect(await container.read(notificationsProvider.future), isEmpty);
    expect(await container.read(unreadNotificationCountProvider.future), 0);
  });

  Future<void> mount(WidgetTester tester, NotificationRepository repository,
      {bool targetExists = false}) async {
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(
          path: '/chat',
          builder: (_, state) => Scaffold(
              body: Text('chat:${state.uri.queryParameters['roomId']}'))),
      GoRoute(
          path: '/party/:id',
          builder: (_, state) =>
              Scaffold(body: Text('party:${state.pathParameters['id']}'))),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const Scaffold(body: NotificationsScreen())),
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          chatRoomsProvider.overrideWith((ref) async => targetExists
              ? [
                  ChatRoom(
                      id: 'room-exact',
                      postId: 'missing-party',
                      title: 'test',
                      participantIds: ['a', 'b'],
                      status: 'active',
                      updatedAt: DateTime(2026, 9, 7))
                ]
              : []),
          notificationRepositoryProvider
              .overrideWith((ref) async => repository),
          partyByIdProvider.overrideWith((ref, id) async => !targetExists
              ? null
              : MatchingParty(
                  id: id,
                  hostUserId: 'author',
                  restaurantId: 'restaurant',
                  title: 'test',
                  scheduledAt: DateTime(2026, 9, 9),
                  currentMembers: 1,
                  maxMembers: 4,
                  distanceKm: 0,
                  rewardXp: 0,
                  rewardPoints: 0,
                  status: MatchingPartyStatus.open,
                  hostName: '',
                  memberNames: [],
                  tags: [],
                  description: '',
                )),
        ],
        child: MaterialApp.router(
            theme: AppTheme.build(MukkingThemeId.violet),
            routerConfig: router)));
    await tester.pumpAndSettle();
  }

  testWidgets('direct notification route has empty state', (tester) async {
    await mount(tester, MockNotificationRepository([]));
    expect(find.text('아직 새로운 알림이 없어요.'), findsOneWidget);
  });

  for (final type in [
    'join_request_received',
    'join_request_accepted',
    'join_request_rejected',
    'favorite_restaurant_party_created'
  ]) {
    testWidgets('$type opens exact party and marks read', (tester) async {
      final repository = MockNotificationRepository([alert(type, type: type)]);
      await mount(tester, repository, targetExists: true);
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
      expect(find.text('party:missing-party'), findsOneWidget);
      expect(await repository.unreadCount(), 0);
    });
  }
  testWidgets('chat notification opens exact room', (tester) async {
    final repository = MockNotificationRepository([
      alert('chat-alert', type: 'chat_message_created', roomId: 'room-exact')
    ]);
    await mount(tester, repository, targetExists: true);
    await tester.tap(find.text('chat-alert'));
    await tester.pumpAndSettle();
    expect(find.text('chat:room-exact'), findsOneWidget);
    expect(await repository.unreadCount(), 0);
  });
  for (final type in ['chat_message_created', 'future_unknown']) {
    testWidgets('$type missing target is safe and readable', (tester) async {
      final repository = MockNotificationRepository(
          [alert('unknown-target', type: type, roomId: 'deleted-room')]);
      await mount(tester, repository);
      await tester.tap(find.text('unknown-target'));
      await tester.pumpAndSettle();
      expect(find.text('대상을 찾을 수 없어요.'), findsOneWidget);
      expect(await repository.unreadCount(), 0);
    });
  }

  testWidgets('list failure retries without pretending empty', (tester) async {
    final repository = FailingNotifications([alert('retry-item')])
      ..failList = true;
    await mount(tester, repository);
    expect(find.text('알림을 불러오지 못했어요.'), findsOneWidget);
    repository.failList = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('retry-item'), findsOneWidget);
  });

  testWidgets('deleted target still marks read and shows fallback',
      (tester) async {
    final repository = MockNotificationRepository([alert('missing')]);
    await mount(tester, repository);
    await tester.tap(find.text('missing'));
    await tester.pumpAndSettle();
    expect(await repository.unreadCount(), 0);
    expect(find.text('대상을 찾을 수 없어요.'), findsOneWidget);
  });

  testWidgets('read failure does not prevent exact party navigation',
      (tester) async {
    final repository = FailingNotifications([alert('go-party')])
      ..failRead = true;
    await mount(tester, repository, targetExists: true);
    await tester.tap(find.text('go-party'));
    await tester.pumpAndSettle();
    expect(find.text('party:missing-party'), findsOneWidget);
    expect(await repository.unreadCount(), 1);
  });

  testWidgets('failed read remains unread and retry succeeds', (tester) async {
    final repository = FailingNotifications([alert('read-retry')])
      ..failRead = true;
    await mount(tester, repository);
    await tester.tap(find.text('읽음 처리'));
    await tester.pumpAndSettle();
    expect(await repository.unreadCount(), 1);
    repository.failRead = false;
    await tester.tap(find.text('읽음 처리'));
    await tester.pumpAndSettle();
    expect(await repository.unreadCount(), 0);
  });
}
