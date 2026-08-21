import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_party_repository.dart';
import '../domain/matching_party.dart';

final selectedPartyIdProvider = StateProvider<String?>((ref) => null);

final matchingPartiesProvider = Provider<List<MatchingParty>>((ref) {
  return ref.watch(mockPartyRepositoryProvider).featuredParties();
});

final popularPartiesProvider = Provider<List<MatchingParty>>((ref) {
  return ref
      .watch(matchingPartiesProvider)
      .where((party) => party.status == MatchingPartyStatus.hot)
      .toList();
});

final urgentPartiesProvider = Provider<List<MatchingParty>>((ref) {
  return ref
      .watch(matchingPartiesProvider)
      .where((party) => party.status == MatchingPartyStatus.urgent)
      .toList();
});

final partyByIdProvider =
    Provider.family<MatchingParty?, String>((ref, partyId) {
  for (final party in ref.watch(matchingPartiesProvider)) {
    if (party.id == partyId) {
      return party;
    }
  }
  return null;
});

final selectedPartyProvider = Provider<MatchingParty?>((ref) {
  final selectedId = ref.watch(selectedPartyIdProvider);
  if (selectedId == null) {
    return null;
  }
  return ref.watch(partyByIdProvider(selectedId));
});

final partiesByRestaurantProvider =
    Provider.family<List<MatchingParty>, String>((ref, restaurantId) {
  return ref
      .watch(matchingPartiesProvider)
      .where((party) => party.restaurantId == restaurantId)
      .toList();
});
