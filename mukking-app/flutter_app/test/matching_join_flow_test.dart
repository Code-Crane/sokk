import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/core/network/api_client.dart';
import 'package:mukking_flutter_app/core/router/app_router.dart';
import 'package:mukking_flutter_app/core/router/app_routes.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/chat/data/chat_repository.dart';
import 'package:mukking_flutter_app/features/chat/domain/chat_message.dart';
import 'package:mukking_flutter_app/features/chat/domain/chat_room.dart';
import 'package:mukking_flutter_app/features/discovery/domain/discovery_filter.dart';
import 'package:mukking_flutter_app/features/discovery/domain/map_camera_center.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_repository.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_api.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_mapper.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/presentation/party_detail_screen.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  group('party viewer state', () {
    test('uses author, pending, approved, available and full states', () {
      final open = _party();
      expect(
        resolvePartyViewerRole(party: open, currentUserId: 'host'),
        PartyViewerRole.author,
      );
      expect(
        resolvePartyViewerRole(
          party: open,
          currentUserId: 'guest',
          localRequestStatus: MatchingJoinRequestStatus.pending,
        ),
        PartyViewerRole.pending,
      );
      expect(
        resolvePartyViewerRole(
          party: _party(participantIds: const ['guest']),
          currentUserId: 'guest',
        ),
        PartyViewerRole.approved,
      );
      expect(
        resolvePartyViewerRole(party: open, currentUserId: 'guest'),
        PartyViewerRole.available,
      );
      expect(
        resolvePartyViewerRole(
          party: _party(status: MatchingPartyStatus.full),
          currentUserId: 'guest',
        ),
        PartyViewerRole.unavailable,
      );
    });

    test('maps API join statuses without guessed strings', () {
      expect(
        MatchingJoinRequestStatus.fromWire('pending'),
        MatchingJoinRequestStatus.pending,
      );
      expect(
        MatchingJoinRequestStatus.fromWire('accepted'),
        MatchingJoinRequestStatus.accepted,
      );
      expect(
        MatchingJoinRequestStatus.fromWire('rejected'),
        MatchingJoinRequestStatus.rejected,
      );
      expect(
        MatchingJoinRequestStatus.fromWire('cancelled'),
        MatchingJoinRequestStatus.cancelled,
      );
    });

    test('accepted membership wins over stale request state', () {
      expect(
        resolvePartyViewerRole(
          party: _party(),
          currentUserId: 'guest',
          localRequestStatus: MatchingJoinRequestStatus.accepted,
        ),
        PartyViewerRole.approved,
      );
      expect(
        resolvePartyViewerRole(
          party: _party(participantIds: const ['guest']),
          currentUserId: 'guest',
          localRequestStatus: MatchingJoinRequestStatus.rejected,
        ),
        PartyViewerRole.approved,
      );
    });

    test('API mapper preserves participant ids and capacity-full state', () {
      final party = const MatchingPostMapper().toParty(
        MatchingPostDto.fromJson({
          'id': 'party-full',
          'authorId': 'host',
          'restaurantId': 'restaurant-1',
          'restaurantName': '실제 식당',
          'address': '부산 중구',
          'scheduledAt': '2026-09-10T10:30:00.000Z',
          'maxParticipants': 4,
          'intro': '같이 먹어요',
          'status': 'open',
          'participantIds': ['a', 'b', 'c'],
          'createdAt': '2026-09-04T00:00:00.000Z',
          'updatedAt': '2026-09-04T00:00:00.000Z',
        }),
      );

      expect(party.participantIds, ['a', 'b', 'c']);
      expect(party.currentMembers, 4);
      expect(party.status, MatchingPartyStatus.full);
      expect(party.restaurantName, '실제 식당');
      expect(party.address, '부산 중구');
    });
  });

  test('my join request API uses authenticated recovery endpoint and null',
      () async {
    final adapter = _MyJoinRequestAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = adapter;
    final api = MatchingApi(ApiClient(dio));

    final pending = await api.getMyJoinRequest('party-1');
    final missing = await api.getMyJoinRequest('missing-party');

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.method, 'GET');
    expect(
      adapter.requests.first.path,
      '/api/matching/posts/party-1/request/me',
    );
    expect(pending?.status, 'pending');
    expect(missing, isNull);
  });

  for (final status in MatchingJoinRequestStatus.values) {
    testWidgets('direct refresh restores ${status.name} join request state',
        (tester) async {
      final repository = _MatchingRepository(
        party: _party(),
        myRequest: _request(status: status),
      );
      final chat = _MutableChatRepository();
      if (status == MatchingJoinRequestStatus.accepted) {
        chat.rooms = [_room()];
      }
      final container = _container(repository, chat);
      addTearDown(container.dispose);

      await _pumpRoute(
        tester,
        container,
        AppRoutes.partyDetailPath('party-1'),
      );

      expect(repository.myRequestCalls, 1);
      switch (status) {
        case MatchingJoinRequestStatus.pending:
          await _scrollTo(tester, find.byKey(partyPendingButtonKey));
          expect(find.byKey(partyPendingButtonKey), findsOneWidget);
        case MatchingJoinRequestStatus.accepted:
          await _scrollTo(tester, find.byKey(partyChatButtonKey));
          expect(find.byKey(partyChatButtonKey), findsOneWidget);
        case MatchingJoinRequestStatus.rejected:
          expect(find.text('참여 신청 거절됨'), findsOneWidget);
          await _scrollTo(tester, find.byKey(partyJoinButtonKey));
          expect(find.byKey(partyJoinButtonKey), findsOneWidget);
        case MatchingJoinRequestStatus.cancelled:
          expect(find.text('참여 신청 취소됨'), findsOneWidget);
          await _scrollTo(tester, find.byKey(partyJoinButtonKey));
          expect(find.byKey(partyJoinButtonKey), findsOneWidget);
      }
    });
  }

  testWidgets('direct party route loads by id and renders actual post fields',
      (tester) async {
    final repository = _MatchingRepository(party: _party());
    final container = _container(repository, const _ChatRepository());
    addTearDown(container.dispose);

    await _pumpRoute(tester, container, AppRoutes.partyDetailPath('party-1'));

    expect(repository.findCalls, greaterThan(0));
    expect(find.byKey(partyDetailPageKey), findsOneWidget);
    expect(find.text('실제 API 식당'), findsWidgets);
    expect(find.text('부산 중구 실제로 1'), findsWidgets);
    expect(find.text('9/10 19:30'), findsOneWidget);
    expect(find.text('1/4명'), findsOneWidget);
    expect(find.text('신청 가능'), findsOneWidget);
    await _scrollTo(tester, find.byKey(partyJoinButtonKey));
    expect(find.byKey(partyJoinButtonKey), findsOneWidget);
  });

  testWidgets('direct party route exposes loading, not-found and error retry',
      (tester) async {
    final pending = Completer<MatchingParty?>();
    final repository = _MatchingRepository(
      party: _party(),
      findParty: (_) => pending.future,
    );
    final container = _container(repository, const _ChatRepository());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MukkingApp(),
      ),
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.partyDetailPath('missing-party'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('파티를 찾을 수 없어요.'), findsOneWidget);
    expect(find.byKey(partyDetailRetryKey), findsOneWidget);
  });

  testWidgets('direct party route exposes API error and retry', (tester) async {
    final errorRepository = _MatchingRepository(
      party: _party(),
      findParty: (_) => Future.error(
        const ApiError(
          kind: ApiErrorKind.server,
          statusCode: 500,
          userMessage: '파티 API 오류',
        ),
      ),
    );
    final errorContainer = _container(
      errorRepository,
      const _ChatRepository(),
    );
    addTearDown(errorContainer.dispose);

    await _pumpRoute(
      tester,
      errorContainer,
      AppRoutes.partyDetailPath('error-party'),
    );
    expect(find.text('파티 API 오류'), findsOneWidget);
    expect(find.byKey(partyDetailRetryKey), findsOneWidget);
  });

  testWidgets('join succeeds once and immediately exposes pending state',
      (tester) async {
    final repository = _MatchingRepository(party: _party());
    final container = _container(repository, const _ChatRepository());
    addTearDown(container.dispose);
    await _pumpRoute(tester, container, AppRoutes.partyDetailPath('party-1'));

    await _scrollTo(tester, find.byKey(partyJoinButtonKey));
    await tester.tap(find.byKey(partyJoinButtonKey));
    await tester.pumpAndSettle();

    expect(repository.joinCalls, 1);
    expect(find.text('참여 신청을 보냈어요'), findsOneWidget);
    expect(find.byKey(partyPendingButtonKey), findsOneWidget);
    expect(find.text('참여 신청 중'), findsWidgets);
  });

  test('join and approve controllers reject rapid duplicate taps', () async {
    final joinCompleter = Completer<JoinRequestResult>();
    final respondCompleter = Completer<RespondJoinRequestResult>();
    final repository = _MatchingRepository(
      party: _party(),
      joinRequest: (_) => joinCompleter.future,
      respondRequest: ({required requestId, required decision}) =>
          respondCompleter.future,
    );
    final container = _container(repository, const _ChatRepository());
    addTearDown(container.dispose);

    final joinController =
        container.read(joinPartyControllerProvider('party-1').notifier);
    final firstJoin = joinController.join('party-1');
    final duplicateJoin = await joinController.join('party-1');
    expect(duplicateJoin, isNull);
    expect(repository.joinCalls, 1);
    joinCompleter.complete(_joinResult());
    await firstJoin;

    const key = (partyId: 'party-1', requestId: 'request-1');
    final respondController =
        container.read(respondJoinRequestControllerProvider(key).notifier);
    final firstResponse = respondController.respond(
      requestId: 'request-1',
      decision: 'accepted',
    );
    final duplicateResponse = await respondController.respond(
      requestId: 'request-1',
      decision: 'accepted',
    );
    expect(duplicateResponse, isNull);
    expect(repository.respondCalls, 1);
    respondCompleter.complete(_respondResult());
    await firstResponse;
  });

  testWidgets('author can approve without forced navigation then open chat',
      (tester) async {
    final chat = _MutableChatRepository();
    final repository = _MatchingRepository(
      party: _party(),
      requests: [_request()],
      onAccepted: () => chat.rooms = [
        _room(id: 'other-room', postId: 'other-party', title: '다른 채팅방'),
        _room(),
      ],
    );
    final container = _container(
      repository,
      chat,
      userId: 'host',
    );
    addTearDown(container.dispose);
    await _pumpRoute(tester, container, AppRoutes.partyDetailPath('party-1'));

    expect(find.text('내가 만든 모임'), findsOneWidget);
    await _scrollTo(tester, find.byKey(partyRequestManagementKey));
    expect(find.byKey(partyRequestManagementKey), findsOneWidget);
    expect(find.text('참여 신청 1명 · 승인된 참가자 0명'), findsOneWidget);
    expect(find.byKey(partyManageRequestsButtonKey), findsOneWidget);
    await _scrollTo(tester, find.byKey(approveJoinRequestKey('request-1')));
    await tester.tap(find.byKey(approveJoinRequestKey('request-1')));
    await tester.pumpAndSettle();

    expect(repository.respondCalls, 1);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      AppRoutes.partyDetailPath('party-1'),
    );
    expect(find.text('참가 요청을 승인했어요.'), findsOneWidget);
    await _scrollTo(tester, find.byKey(partyChatButtonKey));
    expect(find.byKey(partyChatButtonKey), findsOneWidget);
    expect(find.text('참여 신청 0명 · 승인된 참가자 1명'), findsOneWidget);

    await tester.tap(find.byKey(partyChatButtonKey));
    await tester.pumpAndSettle();
    final uri =
        container.read(appRouterProvider).routeInformationProvider.value.uri;
    expect(uri.path, AppRoutes.chat);
    expect(uri.queryParameters['roomId'], 'room-party-1');
    expect(find.text('정확한 파티 채팅방'), findsWidgets);
  });

  testWidgets('author sees an explicit empty request state without chat CTA',
      (tester) async {
    final repository = _MatchingRepository(party: _party());
    final container = _container(
      repository,
      const _ChatRepository(),
      userId: 'host',
    );
    addTearDown(container.dispose);
    await _pumpRoute(tester, container, AppRoutes.partyDetailPath('party-1'));

    expect(find.text('내가 만든 모임'), findsOneWidget);
    await _scrollTo(tester, find.byKey(partyRequestManagementKey));
    expect(find.text('참여 신청 0명 · 승인된 참가자 0명'), findsOneWidget);
    expect(find.byKey(partyRequestEmptyKey), findsOneWidget);
    expect(find.text('아직 참여 신청이 없어요.'), findsOneWidget);
    expect(find.byKey(partyManageRequestsButtonKey), findsOneWidget);
    expect(find.byKey(partyChatButtonKey), findsNothing);
  });

  testWidgets('author can reject without changing participant count',
      (tester) async {
    final repository = _MatchingRepository(
      party: _party(),
      requests: [_request()],
    );
    final container = _container(
      repository,
      const _ChatRepository(),
      userId: 'host',
    );
    addTearDown(container.dispose);
    await _pumpRoute(tester, container, AppRoutes.partyDetailPath('party-1'));
    final membersBefore = repository.party.currentMembers;

    await _scrollTo(tester, find.byKey(rejectJoinRequestKey('request-1')));
    await tester.tap(find.byKey(rejectJoinRequestKey('request-1')));
    await tester.pumpAndSettle();

    expect(repository.party.currentMembers, membersBefore);
    expect(find.text('거절됨'), findsOneWidget);
    expect(find.text('참가 요청을 거절했어요.'), findsOneWidget);
  });

  testWidgets('approved participant restores chat CTA after a fresh container',
      (tester) async {
    final repository = _MatchingRepository(
      party: _party(participantIds: const ['guest'], currentMembers: 2),
    );
    final container = _container(
      repository,
      _MutableChatRepository()
        ..rooms = [
          _room(id: 'other-room', postId: 'other-party', title: '다른 채팅방'),
          _room(),
        ],
      userId: 'guest',
    );
    addTearDown(container.dispose);
    await _pumpRoute(tester, container, AppRoutes.partyDetailPath('party-1'));

    expect(find.text('참여 승인됨'), findsOneWidget);
    await _scrollTo(tester, find.byKey(partyChatButtonKey));
    expect(find.byKey(partyChatButtonKey), findsOneWidget);
    await tester.tap(find.byKey(partyChatButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('정확한 파티 채팅방'), findsWidgets);
  });

  test('join errors map business rules without exposing server internals', () {
    ApiError error(String message, {int status = 409}) => ApiError(
          kind: status == 403 ? ApiErrorKind.forbidden : ApiErrorKind.conflict,
          statusCode: status,
          serverMessage: message,
          userMessage: 'generic',
        );

    expect(
      matchingActionErrorMessage(
        error('A pending join request already exists.'),
      ),
      '이미 참여 신청한 모임이에요.',
    );
    expect(
      matchingActionErrorMessage(
        error('This matching post is not open.'),
      ),
      '모집이 마감된 모임이에요.',
    );
    expect(
      matchingActionErrorMessage(
        error('Verification is required for this action.', status: 403),
      ),
      '본인인증 후 이용할 수 있어요.',
    );
    expect(
      matchingActionErrorMessage(
        error('internal database stack detail'),
      ),
      'generic',
    );
  });

  test('join refresh leaves discovery filters and camera state untouched',
      () async {
    final repository = _MatchingRepository(party: _party());
    final container = _container(repository, const _ChatRepository());
    addTearDown(container.dispose);
    container.read(discoveryFilterProvider.notifier)
      ..updateQuery('치킨')
      ..selectCategory('한식')
      ..selectSort(RestaurantSortOption.favoriteFirst);
    container.read(searchAreaProvider.notifier).onCameraIdle(
          const MapCameraIdleEvent(
            center: MapCameraCenter(latitude: 35.1, longitude: 129),
            userInitiated: true,
          ),
        );
    final filterBefore = container.read(discoveryFilterProvider);
    final cameraBefore = container.read(searchAreaProvider).center;

    await container
        .read(joinPartyControllerProvider('party-1').notifier)
        .join('party-1');

    expect(container.read(discoveryFilterProvider), same(filterBefore));
    expect(container.read(searchAreaProvider).center, cameraBefore);
  });
}

ProviderContainer _container(
  MatchingRepository matching,
  ChatRepository chat, {
  String userId = 'guest',
}) {
  return ProviderContainer(
    overrides: [
      matchingRepositoryProvider.overrideWithValue(matching),
      chatRepositoryProvider.overrideWithValue(chat),
      currentUserProvider.overrideWithValue(_user(userId)),
    ],
  );
}

Future<void> _pumpRoute(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MukkingApp(),
    ),
  );
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    320,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

AuthUser _user(String id) {
  return AuthUser(
    id: id,
    nickname: id,
    email: '$id@example.com',
    verificationStatus: VerificationStatus.verified,
    mannerScore: 36.5,
    mannerGrade: MannerGrade.regular,
    pendingEvaluationCount: 0,
    createdAt: DateTime(2026),
  );
}

MatchingParty _party({
  MatchingPartyStatus status = MatchingPartyStatus.open,
  List<String> participantIds = const [],
  int currentMembers = 1,
}) {
  return MatchingParty(
    id: 'party-1',
    hostUserId: 'host',
    restaurantId: 'restaurant-1',
    restaurantName: '실제 API 식당',
    address: '부산 중구 실제로 1',
    title: '저녁 같이 먹어요',
    scheduledAt: DateTime(2026, 9, 10, 19, 30),
    currentMembers: currentMembers,
    maxMembers: 4,
    distanceKm: 0,
    rewardXp: 80,
    rewardPoints: 400,
    status: status,
    hostName: '파티장',
    memberNames: const ['파티장'],
    tags: const ['실제API', 'open'],
    description: '부담 없이 같이 식사해요.',
    participantIds: participantIds,
  );
}

PartyJoinRequest _request({
  MatchingJoinRequestStatus status = MatchingJoinRequestStatus.pending,
}) {
  return PartyJoinRequest(
    id: 'request-1',
    postId: 'party-1',
    requesterId: 'guest',
    status: status,
    createdAt: DateTime(2026, 9, 4),
  );
}

JoinRequestResult _joinResult() {
  return const JoinRequestResult(
    requestId: 'request-1',
    status: MatchingJoinRequestStatus.pending,
    message: '참가 요청이 접수됐어요.',
  );
}

RespondJoinRequestResult _respondResult({String? chatRoomId = 'room-party-1'}) {
  return RespondJoinRequestResult(
    request: _request(status: MatchingJoinRequestStatus.accepted),
    chatRoomId: chatRoomId,
  );
}

ChatRoom _room({
  String id = 'room-party-1',
  String postId = 'party-1',
  String title = '정확한 파티 채팅방',
}) {
  return ChatRoom(
    id: id,
    postId: postId,
    title: title,
    participantIds: const ['host', 'guest'],
    status: 'active',
    updatedAt: DateTime(2026, 9, 4),
  );
}

typedef _RespondCallback = Future<RespondJoinRequestResult> Function({
  required String requestId,
  required String decision,
});

class _MatchingRepository implements MatchingRepository {
  _MatchingRepository({
    required this.party,
    this.requests = const [],
    this.myRequest,
    this.findParty,
    this.joinRequest,
    this.respondRequest,
    this.onAccepted,
  });

  MatchingParty party;
  List<PartyJoinRequest> requests;
  PartyJoinRequest? myRequest;
  final Future<MatchingParty?> Function(String partyId)? findParty;
  final Future<JoinRequestResult> Function(String partyId)? joinRequest;
  final _RespondCallback? respondRequest;
  final VoidCallback? onAccepted;
  int findCalls = 0;
  int myRequestCalls = 0;
  int joinCalls = 0;
  int respondCalls = 0;

  @override
  Future<MatchingFeed> listFeed() async {
    return MatchingFeed(parties: [party], restaurants: const []);
  }

  @override
  Future<MatchingParty?> findPartyById(String partyId) async {
    findCalls += 1;
    final callback = findParty;
    if (callback != null) return callback(partyId);
    return party.id == partyId ? party : null;
  }

  @override
  Future<PartyJoinRequest?> findMyJoinRequest(String partyId) async {
    myRequestCalls += 1;
    return myRequest?.postId == partyId ? myRequest : null;
  }

  @override
  Future<JoinRequestResult> createJoinRequest(String partyId) async {
    joinCalls += 1;
    final callback = joinRequest;
    if (callback != null) return callback(partyId);
    return _joinResult();
  }

  @override
  Future<List<PartyJoinRequest>> listJoinRequests(String partyId) async {
    return List.unmodifiable(requests);
  }

  @override
  Future<RespondJoinRequestResult> respondJoinRequest({
    required String requestId,
    required String decision,
  }) async {
    respondCalls += 1;
    final callback = respondRequest;
    if (callback != null) {
      return callback(requestId: requestId, decision: decision);
    }

    final nextStatus = MatchingJoinRequestStatus.fromWire(decision);
    requests = [
      for (final request in requests)
        if (request.id == requestId)
          PartyJoinRequest(
            id: request.id,
            postId: request.postId,
            requesterId: request.requesterId,
            status: nextStatus,
            createdAt: request.createdAt,
          )
        else
          request,
    ];
    if (decision == 'accepted') {
      party = MatchingParty(
        id: party.id,
        hostUserId: party.hostUserId,
        restaurantId: party.restaurantId,
        restaurantName: party.restaurantName,
        address: party.address,
        title: party.title,
        scheduledAt: party.scheduledAt,
        currentMembers: party.currentMembers + 1,
        maxMembers: party.maxMembers,
        distanceKm: party.distanceKm,
        rewardXp: party.rewardXp,
        rewardPoints: party.rewardPoints,
        status: party.status,
        hostName: party.hostName,
        memberNames: [...party.memberNames, '참여자'],
        tags: party.tags,
        description: party.description,
        participantIds: [...party.participantIds, 'guest'],
      );
      onAccepted?.call();
    }
    return RespondJoinRequestResult(
      request: requests.firstWhere((request) => request.id == requestId),
      chatRoomId: decision == 'accepted' ? 'room-party-1' : null,
    );
  }

  @override
  Future<MatchingParty> createParty(CreatePartyInput input) async {
    throw UnimplementedError();
  }
}

class _ChatRepository implements ChatRepository {
  const _ChatRepository();

  @override
  Future<List<ChatRoom>> listRooms() async => const [];

  @override
  Future<List<ChatMessage>> listMessages(String roomId) async => const [];

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    throw UnimplementedError();
  }
}

class _MutableChatRepository implements ChatRepository {
  List<ChatRoom> rooms = [];

  @override
  Future<List<ChatRoom>> listRooms() async => List.unmodifiable(rooms);

  @override
  Future<List<ChatMessage>> listMessages(String roomId) async => [
        ChatMessage(
          id: 'message-1',
          roomId: roomId,
          senderId: 'host',
          text: '채팅 연결 확인',
          createdAt: DateTime(2026, 9, 4),
        ),
      ];

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    return ChatMessage(
      id: 'sent',
      roomId: roomId,
      senderId: 'guest',
      text: text,
      createdAt: DateTime(2026, 9, 4),
    );
  }
}

class _MyJoinRequestAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isMissing = options.path.contains('missing-party');
    return ResponseBody.fromString(
      jsonEncode(
        isMissing
            ? null
            : {
                'id': 'request-1',
                'postId': 'party-1',
                'requesterId': 'guest',
                'status': 'pending',
                'createdAt': '2026-09-04T00:00:00.000Z',
              },
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
