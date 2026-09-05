import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/domain/chat_room.dart';
import '../../discovery/domain/restaurant.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../data/matching_repository.dart';
import '../domain/matching_party.dart';

final selectedPartyIdProvider = StateProvider<String?>((ref) => null);

final matchingFeedProvider = FutureProvider<MatchingFeed>((ref) {
  return ref.watch(matchingRepositoryProvider).listFeed();
});

final matchingPartiesProvider =
    FutureProvider<List<MatchingParty>>((ref) async {
  return (await ref.watch(matchingFeedProvider.future)).parties;
});

final matchingRestaurantsProvider =
    FutureProvider<List<Restaurant>>((ref) async {
  return (await ref.watch(matchingFeedProvider.future)).restaurants;
});

final popularPartiesProvider = FutureProvider<List<MatchingParty>>((ref) async {
  return (await ref.watch(matchingPartiesProvider.future))
      .where((party) => party.status == MatchingPartyStatus.hot)
      .toList();
});

final urgentPartiesProvider = FutureProvider<List<MatchingParty>>((ref) async {
  return (await ref.watch(matchingPartiesProvider.future))
      .where((party) => party.status == MatchingPartyStatus.urgent)
      .toList();
});

final partyByIdProvider =
    FutureProvider.family<MatchingParty?, String>((ref, partyId) {
  return ref.watch(matchingRepositoryProvider).findPartyById(partyId);
});

final selectedPartyProvider = FutureProvider<MatchingParty?>((ref) {
  final selectedId = ref.watch(selectedPartyIdProvider);
  if (selectedId == null) {
    return null;
  }
  return ref.watch(partyByIdProvider(selectedId).future);
});

final partiesByRestaurantProvider =
    FutureProvider.family<List<MatchingParty>, String>(
        (ref, restaurantId) async {
  return (await ref.watch(matchingPartiesProvider.future))
      .where((party) => party.restaurantId == restaurantId)
      .toList();
});

class MyPartyOverview {
  const MyPartyOverview({
    required this.authored,
    required this.confirmed,
  });

  final List<MatchingParty> authored;
  final List<MatchingParty> confirmed;
}

final myPartyOverviewProvider = FutureProvider<MyPartyOverview>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) {
    return const MyPartyOverview(authored: [], confirmed: []);
  }

  final parties = await ref.watch(matchingPartiesProvider.future);
  return MyPartyOverview(
    authored: [
      for (final party in parties)
        if (party.hostUserId == userId) party
    ],
    confirmed: [
      for (final party in parties)
        if (party.hostUserId != userId && party.isParticipant(userId)) party,
    ],
  );
});

final partyJoinRequestsProvider =
    FutureProvider.family<List<PartyJoinRequest>, String>((ref, partyId) {
  return ref.watch(matchingRepositoryProvider).listJoinRequests(partyId);
});

typedef MyJoinRequestKey = ({String partyId, String userId});

final myJoinRequestProvider =
    FutureProvider.family<PartyJoinRequest?, MyJoinRequestKey>((ref, key) {
  return ref.watch(matchingRepositoryProvider).findMyJoinRequest(key.partyId);
});

typedef RespondJoinRequestKey = ({String partyId, String requestId});

final respondJoinRequestControllerProvider = StateNotifierProvider.family<
    RespondJoinRequestController,
    AsyncValue<RespondJoinRequestResult?>,
    RespondJoinRequestKey>((ref, key) {
  return RespondJoinRequestController(
    ref.watch(matchingRepositoryProvider),
    onResponded: () {
      ref.invalidate(partyJoinRequestsProvider(key.partyId));
      ref.invalidate(matchingFeedProvider);
      ref.invalidate(partyByIdProvider(key.partyId));
      ref.invalidate(chatRoomsProvider);
    },
  );
});

class RespondJoinRequestController
    extends StateNotifier<AsyncValue<RespondJoinRequestResult?>> {
  RespondJoinRequestController(
    this._repository, {
    required void Function() onResponded,
  })  : _onResponded = onResponded,
        super(const AsyncValue.data(null));

  final MatchingRepository _repository;
  final void Function() _onResponded;

  Future<RespondJoinRequestResult?> respond({
    required String requestId,
    required String decision,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncValue.loading();
    try {
      final result = await _repository.respondJoinRequest(
        requestId: requestId,
        decision: decision,
      );
      _onResponded();
      state = AsyncValue.data(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}

final joinPartyControllerProvider = StateNotifierProvider.family<
    JoinPartyController,
    AsyncValue<JoinRequestResult?>,
    String>((ref, partyId) {
  final userId = ref.watch(currentUserProvider)?.id;
  return JoinPartyController(
    ref.watch(matchingRepositoryProvider),
    onJoined: () {
      ref.invalidate(partyByIdProvider(partyId));
      if (userId != null) {
        ref.invalidate(
          myJoinRequestProvider((partyId: partyId, userId: userId)),
        );
      }
    },
  );
});

final chatRoomForPartyProvider =
    FutureProvider.family<ChatRoom?, String>((ref, partyId) async {
  final rooms = await ref.watch(chatRoomsProvider.future);
  for (final room in rooms) {
    if (room.postId == partyId) return room;
  }
  return null;
});

final createPartyControllerProvider =
    StateNotifierProvider<CreatePartyController, AsyncValue<MatchingParty?>>(
        (ref) {
  return CreatePartyController(
    ref.watch(matchingRepositoryProvider),
    onCreated: () {
      ref.invalidate(matchingFeedProvider);
      ref.invalidate(restaurantFeedProvider);
    },
  );
});

class CreatePartyController extends StateNotifier<AsyncValue<MatchingParty?>> {
  CreatePartyController(
    this._repository, {
    required void Function() onCreated,
  })  : _onCreated = onCreated,
        super(const AsyncValue.data(null));

  final MatchingRepository _repository;
  final void Function() _onCreated;

  Future<MatchingParty?> create(CreatePartyInput input) async {
    state = const AsyncValue.loading();
    try {
      final party = await _repository.createParty(input);
      _onCreated();
      state = AsyncValue.data(party);
      return party;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}

class JoinPartyController
    extends StateNotifier<AsyncValue<JoinRequestResult?>> {
  JoinPartyController(
    this._repository, {
    required void Function() onJoined,
  })  : _onJoined = onJoined,
        super(const AsyncValue.data(null));

  final MatchingRepository _repository;
  final void Function() _onJoined;

  Future<JoinRequestResult?> join(String partyId) async {
    if (state.isLoading) return null;
    state = const AsyncValue.loading();
    try {
      final result = await _repository.createJoinRequest(partyId);
      _onJoined();
      state = AsyncValue.data(result);
      return result;
    } on ApiError catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
