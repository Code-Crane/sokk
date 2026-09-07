import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../matching/providers/matching_provider.dart';
import '../data/notification_api.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import '../../auth/providers/auth_provider.dart';

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.watch(apiClientProvider));
});

final notificationRepositoryProvider =
    FutureProvider<NotificationRepository>((ref) async {
  ref.watch(currentUserProvider.select((user) => user?.id));
  if (ref.watch(appConfigProvider).usesApiData) {
    return ApiNotificationRepository(ref.watch(notificationApiProvider));
  }

  final favoriteIds = ref.watch(favoriteRestaurantIdsProvider);
  final parties = await ref.watch(matchingPartiesProvider.future);
  final notifications = parties
      .where((party) => favoriteIds.contains(party.restaurantId))
      .map(
        (party) => AppNotification(
          id: 'favorite-alert-${party.id}',
          type: 'favorite_restaurant_party_created',
          restaurantId: party.restaurantId,
          matchingPostId: party.id,
          title: '가고 싶어한 식당에 새 파티가 열렸어요',
          body: '${party.title} · ${party.memberLabel} · +${party.rewardXp} XP',
          createdAt: party.scheduledAt.subtract(const Duration(hours: 2)),
        ),
      )
      .toList();
  return MockNotificationRepository(notifications);
});

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (ref.watch(appConfigProvider).usesApiData && userId == null) return [];
  final repository = await ref.watch(notificationRepositoryProvider.future);
  final items = [...await repository.list()];
  items.sort((a, b) {
    final order = b.createdAt.compareTo(a.createdAt);
    return order == 0 ? b.id.compareTo(a.id) : order;
  });
  return items;
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (ref.watch(appConfigProvider).usesApiData && userId == null) return 0;
  final repository = await ref.watch(notificationRepositoryProvider.future);
  return repository.unreadCount();
});

final markNotificationReadProvider = StateNotifierProvider<
    MarkNotificationReadController, AsyncValue<AppNotification?>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return MarkNotificationReadController(ref);
});

class MarkNotificationReadController
    extends StateNotifier<AsyncValue<AppNotification?>> {
  MarkNotificationReadController(this._ref)
      : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<AppNotification?> markRead(String notificationId) async {
    if (state.isLoading) return null;
    state = const AsyncValue.loading();
    try {
      final repository = await _ref.read(notificationRepositoryProvider.future);
      if (!mounted) return null;
      final updated = await repository.markRead(notificationId);
      if (!mounted) return null;
      state = AsyncValue.data(updated);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
      return updated;
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
