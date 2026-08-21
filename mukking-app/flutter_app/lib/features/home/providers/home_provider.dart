import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/providers/discovery_provider.dart';
import '../../matching/domain/matching_party.dart';
import '../../matching/providers/matching_provider.dart';

final favoriteRestaurantPartiesProvider = Provider<List<MatchingParty>>((ref) {
  final favoriteIds = ref.watch(favoriteRestaurantIdsProvider);
  final parties = ref.watch(matchingPartiesProvider).valueOrNull ?? const [];

  return parties
      .where((party) => favoriteIds.contains(party.restaurantId))
      .toList();
});

final userPointsProvider = Provider<int>((ref) => 12800);
