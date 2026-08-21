import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/providers/discovery_provider.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/mock_notification.dart';

final mockNotificationsProvider =
    FutureProvider<List<MockNotification>>((ref) async {
  final favoriteIds = ref.watch(favoriteRestaurantIdsProvider);
  final parties = await ref.watch(matchingPartiesProvider.future);

  return parties
      .where((party) => favoriteIds.contains(party.restaurantId))
      .map(
        (party) => MockNotification(
          id: 'favorite-alert-${party.id}',
          restaurantId: party.restaurantId,
          partyId: party.id,
          title: '가고 싶어한 식당에 새 파티가 열렸어요',
          message:
              '${party.title} · ${party.memberLabel} · +${party.rewardXp} XP',
        ),
      )
      .toList();
});
