import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../discovery/domain/restaurant.dart';
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

final joinPartyControllerProvider =
    StateNotifierProvider<JoinPartyController, AsyncValue<JoinRequestResult?>>(
        (ref) {
  return JoinPartyController(ref.watch(matchingRepositoryProvider));
});

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
