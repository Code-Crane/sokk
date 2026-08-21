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
  final String status;
  final String message;
}

abstract class MatchingRepository {
  Future<MatchingFeed> listFeed();
  Future<MatchingParty?> findPartyById(String partyId);
  Future<JoinRequestResult> createJoinRequest(String partyId);
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
  Future<JoinRequestResult> createJoinRequest(String partyId) async {
    return JoinRequestResult(
      requestId: 'mock-join-$partyId',
      status: 'pending',
      message: 'Mock 참가 요청이 접수됐어요.',
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
  Future<JoinRequestResult> createJoinRequest(String partyId) async {
    final dto = await _api.createJoinRequest(partyId);
    return JoinRequestResult(
      requestId: dto.id,
      status: dto.status,
      message: '참가 요청이 접수됐어요. 파티장의 승인을 기다려주세요.',
    );
  }
}
