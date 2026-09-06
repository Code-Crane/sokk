import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mukking_flutter_app/core/network/api_client.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/chat/data/chat_repository.dart';
import 'package:mukking_flutter_app/features/chat/data/chat_safety_repository.dart';
import 'package:mukking_flutter_app/features/chat/domain/chat_message.dart';
import 'package:mukking_flutter_app/features/chat/domain/chat_room.dart';
import 'package:mukking_flutter_app/features/chat/presentation/chat_screen.dart';
import 'package:mukking_flutter_app/features/chat/providers/chat_provider.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';

ChatMessage message(String id,
        {String sender = 'other', String? text, int minute = 0}) =>
    ChatMessage(
        id: id,
        roomId: 'r',
        senderId: sender,
        text: text ?? id,
        createdAt: DateTime(2026, 9, 5, 12, minute));

class FakeChat extends ChatRepository {
  List<ChatRoom> rooms = [
    ChatRoom(
        id: 'r',
        postId: 'p',
        title: '테스트 식당',
        participantIds: ['me', 'other'],
        status: 'active',
        updatedAt: DateTime(2026, 9, 5))
  ];
  List<ChatMessage> messages = [];
  int sends = 0;
  int fetches = 0;
  bool fail = false;
  bool forbidden = false;
  bool roomFail = false;
  bool loadFail = false;
  Completer<List<ChatRoom>>? roomWait;
  Completer<ChatMessage>? sendWait;
  @override
  Future<List<ChatRoom>> listRooms() async {
    if (roomFail) throw ApiError.fromStatusCode(500);
    if (roomWait != null) return roomWait!.future;
    return rooms;
  }

  @override
  Future<List<ChatMessage>> listMessages(String roomId) async {
    fetches++;
    if (loadFail) throw ApiError.fromStatusCode(500);
    return [...messages];
  }

  @override
  Future<ChatMessage> sendMessage(
      {required String roomId, required String text}) async {
    sends++;
    if (forbidden) throw ApiError.fromStatusCode(403);
    if (sendWait != null) return sendWait!.future;
    if (fail) throw ApiError.fromStatusCode(500);
    final sent = message('sent-$sends', sender: 'me', text: text, minute: 50);
    messages.add(sent);
    return sent;
  }
}

class FakeSafety extends ChatSafetyRepository {
  FakeSafety() : super(null);
  int reports = 0;
  bool failUnblock = false;
  @override
  Future<void> unblock(String userId) async {
    if (failUnblock) throw ApiError.fromStatusCode(500);
    await super.unblock(userId);
  }

  @override
  Future<void> report(
      {required String roomId,
      required String userId,
      required String reason,
      String? messageId,
      String description = ''}) async {
    reports++;
  }
}

MatchingParty party() => MatchingParty(
    id: 'p',
    hostUserId: 'me',
    restaurantId: 'x',
    title: '모임',
    scheduledAt: DateTime(2026, 9, 6, 19),
    currentMembers: 2,
    maxMembers: 4,
    distanceKm: 0,
    rewardXp: 0,
    rewardPoints: 0,
    status: MatchingPartyStatus.open,
    hostName: '',
    memberNames: [],
    tags: [],
    description: '',
    restaurantName: '실제 식당');

Future<GoRouter> mount(WidgetTester tester, FakeChat repo,
    {String path = '/chat?roomId=r',
    FakeSafety? safety,
    bool withParty = false}) async {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final router = GoRouter(initialLocation: path, routes: [
    GoRoute(
        path: '/chat',
        builder: (_, state) => Scaffold(
            body: ChatScreen(roomId: state.uri.queryParameters['roomId']))),
    GoRoute(
        path: '/party/:id',
        builder: (_, state) =>
            Scaffold(body: Text('party:${state.pathParameters['id']}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserProvider
        .overrideWithValue(AuthUser.fallback(id: 'me', email: '')),
    chatRepositoryProvider.overrideWithValue(repo),
    chatSafetyRepositoryProvider.overrideWithValue(safety ?? FakeSafety()),
    partyByIdProvider
        .overrideWith((ref, id) async => withParty ? party() : null),
  ], child: MaterialApp.router(routerConfig: router)));
  return router;
}

void main() {
  test('moderation error uses safe message without exposing server details',
      () {
    expect(
        ApiError.fromStatusCode(403,
                serverMessage: 'This chat action is blocked by a user block.')
            .userMessage,
        '이 사용자와는 상호작용할 수 없어요.');
    expect(
        ApiError.fromStatusCode(403,
                serverMessage: 'This account is restricted from chat.')
            .userMessage,
        '현재 이 기능을 사용할 수 없어요.');
  });

  testWidgets(
      'unblock failure retains state; retry restores input without message reload',
      (tester) async {
    final safety = FakeSafety()..failUnblock = true;
    await safety.block('other');
    final chat = FakeChat()..messages = [message('evidence')];
    await mount(tester, chat, safety: safety);
    await tester.pumpAndSettle();
    final fetches = chat.fetches;
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
            .enabled,
        false);
    expect(find.byTooltip('이 메시지 신고'), findsOneWidget);
    await tester.tap(find.text('신고 / 차단'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('차단 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('해제 확인'));
    await tester.pumpAndSettle();
    expect(await safety.blockedUsers(), {'other'});
    safety.failUnblock = false;
    await tester.tap(find.text('차단 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('해제 확인'));
    await tester.pumpAndSettle();
    expect(await safety.blockedUsers(), isEmpty);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
            .enabled,
        true);
    expect(find.text('evidence'), findsOneWidget);
    expect(chat.fetches, fetches);
  });
  testWidgets('room-list error is retryable and not empty', (tester) async {
    final repo = FakeChat()..roomFail = true;
    await mount(tester, repo, path: '/chat');
    await tester.pumpAndSettle();
    expect(find.text('아직 참여 중인 채팅이 없어요.'), findsNothing);
    repo.roomFail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('room-r')), findsOneWidget);
  });

  testWidgets('server forbidden disables send and retains draft until refresh',
      (tester) async {
    final repo = FakeChat()..forbidden = true;
    await mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-draft')), '남길 초안');
    await tester.pump();
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pumpAndSettle();
    final field =
        tester.widget<TextField>(find.byKey(const ValueKey('chat-draft')));
    expect(field.controller!.text, '남길 초안');
    expect(field.enabled, false);
    expect(repo.sends, 1);
  });

  testWidgets('long message wraps on 430px and actual sender aligns right',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeChat()
      ..messages = [message('long', sender: 'me', text: '긴 메시지 ' * 100)];
    await mount(tester, repo);
    await tester.pumpAndSettle();
    final bubble = find.byKey(const ValueKey('message-long'));
    final align = tester.widget<Align>(
        find.ancestor(of: bubble, matching: find.byType(Align)).first);
    expect(align.alignment, Alignment.centerRight);
    expect(find.text('나'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh failure retains history without pretending empty',
      (tester) async {
    final repo = FakeChat()..messages = [message('saved')];
    await mount(tester, repo);
    await tester.pumpAndSettle();
    repo.loadFail = true;
    await tester.tap(find.byTooltip('메시지 새로고침'));
    await tester.pumpAndSettle();
    expect(find.text('saved'), findsOneWidget);
    expect(find.text('첫 메시지를 보내보세요.'), findsNothing);
    expect(find.text('메시지를 불러오지 못했어요.'), findsOneWidget);
  });

  testWidgets('fresh provider scope reloads history from room ID',
      (tester) async {
    final repo = FakeChat()..messages = [message('persisted')];
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('persisted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('persisted'), findsOneWidget);
    expect(repo.fetches, 2);
  });

  test(
      'message merge orders ascending, deterministic ties, deduplicates response',
      () {
    final items = mergeChatMessages([message('b', minute: 2), message('a')],
        [message('b', minute: 2), message('c')]);
    expect(items.map((m) => m.id), ['a', 'c', 'b']);
  });

  test('send rejects whitespace and concurrent duplicate', () async {
    final repo = FakeChat()..sendWait = Completer<ChatMessage>();
    final controller = SendMessageController(repo);
    addTearDown(controller.dispose);
    expect(await controller.send(roomId: 'r', text: '  '), isNull);
    final first = controller.send(roomId: 'r', text: 'hello');
    expect(await controller.send(roomId: 'r', text: 'hello'), isNull);
    expect(repo.sends, 1);
    repo.sendWait!.complete(message('sent'));
    expect((await first)?.id, 'sent');
  });

  testWidgets(
      'room list shows last message/time and navigates with actual room ID',
      (tester) async {
    final repo = FakeChat()..messages = [message('latest', text: '마지막 대화')];
    final router = await mount(tester, repo, path: '/chat');
    await tester.pumpAndSettle();
    expect(find.text('마지막 대화'), findsOneWidget);
    expect(find.textContaining('2명'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-r')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters['roomId'],
        'r');
    await tester.tap(find.byTooltip('채팅방 목록'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters['roomId'],
        isNull);
  });

  testWidgets('empty rooms and direct missing room are distinct',
      (tester) async {
    final repo = FakeChat()..rooms = [];
    final router = await mount(tester, repo, path: '/chat');
    await tester.pumpAndSettle();
    expect(find.text('아직 참여 중인 채팅이 없어요.'), findsOneWidget);
    router.go('/chat?roomId=missing');
    await tester.pumpAndSettle();
    expect(find.textContaining('참여 권한'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('direct load shows loading then room and missing party fallback',
      (tester) async {
    final repo = FakeChat()..roomWait = Completer<List<ChatRoom>>();
    await mount(tester, repo);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    repo.roomWait!.complete(repo.rooms);
    await tester.pumpAndSettle();
    expect(find.text('첫 메시지를 보내보세요.'), findsOneWidget);
    expect(find.text('모임 정보를 불러올 수 없어요.'), findsOneWidget);
  });

  testWidgets('send failure keeps draft; retry success clears and appends once',
      (tester) async {
    final repo = FakeChat()..fail = true;
    await mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-draft')), '안녕하세요');
    await tester.pump();
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
            .controller!
            .text,
        '안녕하세요');
    repo.fail = false;
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
            .controller!
            .text,
        '');
    expect(find.text('안녕하세요'), findsOneWidget);
    await tester.tap(find.byTooltip('메시지 새로고침'));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(repo.sends, 2);
  });

  testWidgets('rapid taps only send once; blank submit disabled',
      (tester) async {
    final repo = FakeChat()..sendWait = Completer<ChatMessage>();
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '메시지 전송'))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const ValueKey('chat-draft')), 'hello');
    await tester.pump();
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pump();
    expect(repo.sends, 1);
    repo.sendWait!.complete(message('sent', sender: 'me', text: 'hello'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('message failure retry recovers same room', (tester) async {
    final repo = FakeChat()..loadFail = true;
    final router = await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('메시지를 불러오지 못했어요.'), findsOneWidget);
    repo.loadFail = false;
    repo.messages.add(message('history'));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('history'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters['roomId'],
        'r');
    expect(repo.fetches, 2);
  });

  testWidgets('party header exposes actual schedule and detail link',
      (tester) async {
    final router = await mount(tester, FakeChat(), withParty: true);
    await tester.pumpAndSettle();
    expect(find.text('실제 식당'), findsOneWidget);
    expect(find.text('9/6 19:00 · 2명'), findsOneWidget);
    await tester.tap(find.byTooltip('파티 상세로 이동'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/party/p');
  });

  testWidgets('report submit and confirmed block disables send but keeps room',
      (tester) async {
    final safety = FakeSafety();
    await mount(tester, FakeChat(), safety: safety);
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고 / 차단'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고 제출'));
    await tester.pumpAndSettle();
    expect(safety.reports, 1);
    await tester.tap(find.text('신고 / 차단'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('차단하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('모임 참여 신청과 새 메시지'), findsOneWidget);
    expect(await safety.blockedUsers(), isEmpty);
    await tester.tap(find.text('차단 확인'));
    await tester.pumpAndSettle();
    expect(await safety.blockedUsers(), {'other'});
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
            .enabled,
        false);
    expect(find.text('테스트 식당'), findsOneWidget);
  });

  testWidgets(
      '100 messages initial latest; refresh preserves reader scroll and no fetch loop',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeChat()
      ..messages = [for (var i = 0; i < 100; i++) message('m$i', minute: i)];
    await mount(tester, repo);
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('chat-messages'));
    final controller = tester.widget<ListView>(list).controller!;
    expect(controller.position.extentAfter, lessThan(5));
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    repo.messages.add(message('new', minute: 101));
    await tester.tap(find.byTooltip('메시지 새로고침'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(find.text('새 메시지 보기'), findsOneWidget);
    await tester.tap(find.text('새 메시지 보기'));
    await tester.pumpAndSettle();
    expect(controller.position.extentAfter, lessThan(5));
    expect(repo.fetches, 2);
    expect(tester.takeException(), isNull);
  });

  test(
      'moderation API uses real IDs, excludes expired/revoked/matching-only blocks',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: options.method == 'GET'
              ? [
                  {'blockedId': 'active', 'scope': 'chat'},
                  {'blockedId': 'all-active', 'scope': 'all'},
                  {
                    'blockedId': 'expired',
                    'scope': 'all',
                    'expiresAt': '2000-01-01T00:00:00Z'
                  },
                  {
                    'blockedId': 'revoked',
                    'scope': 'chat',
                    'revokedAt': '2026-01-01'
                  },
                  {'blockedId': 'matching', 'scope': 'matching'},
                ]
              : <String, dynamic>{}));
    }));
    final safety = ChatSafetyRepository(ApiClient(dio));
    expect(await safety.blockedUsers(), {'active', 'all-active'});
    // A fresh repository reads persisted all/chat scopes rather than local memory.
    expect(await ChatSafetyRepository(ApiClient(dio)).blockedUsers(),
        {'active', 'all-active'});
    await safety.report(
        roomId: 'room-real',
        userId: 'user-real',
        reason: 'spam',
        messageId: 'message-real');
    expect(requests.last.path, '/api/reports');
    expect(requests.last.data['targetType'], 'chat_message');
    expect(requests.last.data['targetId'], 'message-real');
    expect(requests.last.data['chatRoomId'], 'room-real');
    await safety.block('user-real', roomId: 'room-real');
    expect(requests.last.path, '/api/blocks');
    expect(requests.last.data, {
      'blockedId': 'user-real',
      'scope': 'all',
      'reason': 'chat_room:room-real',
    });
    await safety.unblock('user-real');
    expect(requests.last.method, 'DELETE');
    expect(requests.last.path, '/api/blocks/user-real');
    dio.close();
  });
}
