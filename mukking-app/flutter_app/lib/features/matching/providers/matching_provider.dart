import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../chat/providers/chat_provider.dart';
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

final partyJoinRequestsProvider =
    FutureProvider.family<List<PartyJoinRequest>, String>((ref, partyId) {
  return ref.watch(matchingRepositoryProvider).listJoinRequests(partyId);
});

final respondJoinRequestControllerProvider = StateNotifierProvider.family<
    RespondJoinRequestController,
    AsyncValue<RespondJoinRequestResult?>,
    String>((ref, partyId) {
  return RespondJoinRequestController(
    ref.watch(matchingRepositoryProvider),
    onResponded: () {
      ref.invalidate(partyJoinRequestsProvider(partyId));
      ref.invalidate(matchingFeedProvider);
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

final joinPartyControllerProvider =
    StateNotifierProvider<JoinPartyController, AsyncValue<JoinRequestResult?>>(
        (ref) {
  return JoinPartyController(ref.watch(matchingRepositoryProvider));
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
  JoinPartyController(this._repository) : super(const AsyncValue.data(null));

  final MatchingRepository _repository;

  Future<JoinRequestResult?> join(String partyId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.createJoinRequest(partyId);
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
