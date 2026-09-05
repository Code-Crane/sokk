import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../discovery/domain/restaurant.dart';
import '../domain/matching_party.dart';
import 'matching_api.dart';
import 'matching_mapper.dart';
import 'mock_party_repository.dart';

class MatchingFeed {
  const MatchingFeed({
    required this.parties,
    required this.restaurants,
  });

  final List<MatchingParty> parties;
  final List<Restaurant> restaurants;
}

class JoinRequestResult {
  const JoinRequestResult({
    required this.requestId,
    required this.status,
    required this.message,
  });

  final String requestId;
  final MatchingJoinRequestStatus status;
  final String message;
}

class CreatePartyInput {
  const CreatePartyInput({
    required this.restaurantId,
    required this.restaurantName,
    required this.address,
    required this.scheduledAt,
    required this.maxParticipants,
    required this.intro,
  });

  final String? restaurantId;
  final String restaurantName;
  final String address;
  final DateTime scheduledAt;
  final int maxParticipants;
  final String intro;
}

class PartyJoinRequest {
  const PartyJoinRequest({
    required this.id,
    required this.postId,
    required this.requesterId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String requesterId;
  final MatchingJoinRequestStatus status;
  final DateTime? createdAt;

  bool get isPending => status == MatchingJoinRequestStatus.pending;

  String get requesterLabel {
    if (requesterId.length <= 8) return requesterId;
    return '사용자 ${requesterId.substring(0, 8)}';
  }
}

class RespondJoinRequestResult {
  const RespondJoinRequestResult({
    required this.request,
    required this.chatRoomId,
  });

  final PartyJoinRequest request;
  final String? chatRoomId;
}

abstract class MatchingRepository {
  Future<MatchingFeed> listFeed();
  Future<MatchingParty?> findPartyById(String partyId);
  Future<MatchingParty> createParty(CreatePartyInput input);
  Future<JoinRequestResult> createJoinRequest(String partyId);
  Future<PartyJoinRequest?> findMyJoinRequest(String partyId);
  Future<List<PartyJoinRequest>> listJoinRequests(String partyId);
  Future<RespondJoinRequestResult> respondJoinRequest({
    required String requestId,
    required String decision,
  });
}

final matchingApiProvider = Provider<MatchingApi>((ref) {
  return MatchingApi(ref.watch(apiClientProvider));
});

final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.usesApiData) {
    return ApiMatchingRepository(
      api: ref.watch(matchingApiProvider),
      mapper: const MatchingPostMapper(),
    );
  }

  return MockMatchingRepository(ref.watch(mockPartyRepositoryProvider));
});

class MockMatchingRepository implements MatchingRepository {
  const MockMatchingRepository(this._mockPartyRepository);

  final MockPartyRepository _mockPartyRepository;

  @override
  Future<MatchingFeed> listFeed() async {
    return MatchingFeed(
      parties: _mockPartyRepository.featuredParties(),
      restaurants: const [],
    );
  }

  @override
  Future<MatchingParty?> findPartyById(String partyId) async {
    return _mockPartyRepository.findById(partyId);
  }

  @override
  Future<MatchingParty> createParty(CreatePartyInput input) async {
    return MatchingParty(
      id: 'mock-created-${DateTime.now().millisecondsSinceEpoch}',
      hostUserId: 'mock-current-user',
      restaurantId: input.restaurantId ?? 'mock-manual-restaurant',
      title: input.intro,
      scheduledAt: input.scheduledAt,
      currentMembers: 1,
      maxMembers: input.maxParticipants,
      distanceKm: 0,
      rewardXp: 60 + (input.maxParticipants * 10),
      rewardPoints: (60 + (input.maxParticipants * 10)) * 5,
      status: MatchingPartyStatus.open,
      hostName: '나',
      memberNames: const ['나'],
      tags: const ['Mock', 'open'],
      description: input.intro,
      restaurantName: input.restaurantName,
      address: input.address,
    );
  }

  @override
  Future<JoinRequestResult> createJoinRequest(String partyId) async {
    return JoinRequestResult(
      requestId: 'mock-join-$partyId',
      status: MatchingJoinRequestStatus.pending,
      message: 'Mock 참가 요청이 접수됐어요.',
    );
  }

  @override
  Future<PartyJoinRequest?> findMyJoinRequest(String partyId) async => null;

  @override
  Future<List<PartyJoinRequest>> listJoinRequests(String partyId) async {
    return [
      PartyJoinRequest(
        id: 'mock-request-$partyId',
        postId: partyId,
        requesterId: 'mock-requester',
        status: MatchingJoinRequestStatus.pending,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<RespondJoinRequestResult> respondJoinRequest({
    required String requestId,
    required String decision,
  }) async {
    return RespondJoinRequestResult(
      request: PartyJoinRequest(
        id: requestId,
        postId: 'mock-post',
        requesterId: 'mock-requester',
        status: MatchingJoinRequestStatus.fromWire(decision),
        createdAt: DateTime.now(),
      ),
      chatRoomId: decision == 'accepted' ? 'mock-chat-room' : null,
    );
  }
}

class ApiMatchingRepository implements MatchingRepository {
  const ApiMatchingRepository({
    required MatchingApi api,
    required MatchingPostMapper mapper,
  })  : _api = api,
        _mapper = mapper;

  final MatchingApi _api;
  final MatchingPostMapper _mapper;

  @override
  Future<MatchingFeed> listFeed() async {
    return _mapper.toFeed(await _api.listPosts());
  }

  @override
  Future<MatchingParty?> findPartyById(String partyId) async {
    final feed = await listFeed();
    for (final party in feed.parties) {
      if (party.id == partyId) {
        return party;
      }
    }

    return null;
  }

  @override
  Future<MatchingParty> createParty(CreatePartyInput input) async {
    final dto = await _api.createPost(
      CreateMatchingPostRequest(
        restaurantId: input.restaurantId,
        restaurantName: input.restaurantName,
        address: input.address,
        scheduledAt: input.scheduledAt,
        maxParticipants: input.maxParticipants,
        intro: input.intro,
      ),
    );
    return _mapper.toParty(dto);
  }

  @override
  Future<JoinRequestResult> createJoinRequest(String partyId) async {
    final dto = await _api.createJoinRequest(partyId);
    return JoinRequestResult(
      requestId: dto.id,
      status: MatchingJoinRequestStatus.fromWire(dto.status),
      message: '참가 요청이 접수됐어요. 파티장의 승인을 기다려주세요.',
    );
  }

  @override
  Future<PartyJoinRequest?> findMyJoinRequest(String partyId) async {
    final dto = await _api.getMyJoinRequest(partyId);
    return dto == null ? null : _toJoinRequest(dto);
  }

  @override
  Future<List<PartyJoinRequest>> listJoinRequests(String partyId) async {
    final requests = await _api.listJoinRequests(partyId);
    return requests.map(_toJoinRequest).toList();
  }

  @override
  Future<RespondJoinRequestResult> respondJoinRequest({
    required String requestId,
    required String decision,
  }) async {
    final result = await _api.respondJoinRequest(
      requestId: requestId,
      decision: decision,
    );
    return RespondJoinRequestResult(
      request: _toJoinRequest(result.request),
      chatRoomId: result.chatRoomId,
    );
  }

  PartyJoinRequest _toJoinRequest(JoinRequestDto dto) {
    return PartyJoinRequest(
      id: dto.id,
      postId: dto.postId,
      requesterId: dto.requesterId,
      status: MatchingJoinRequestStatus.fromWire(dto.status),
      createdAt: DateTime.tryParse(dto.createdAt)?.toLocal(),
    );
  }
}
