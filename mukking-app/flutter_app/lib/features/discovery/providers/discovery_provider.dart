import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../matching/providers/matching_provider.dart';
import '../data/mock_restaurant_repository.dart';
import '../domain/restaurant.dart';

final selectedCategoryProvider = StateProvider<String>((ref) => '전체');

final favoriteRestaurantIdsProvider =
    StateNotifierProvider<FavoriteRestaurantsController, Set<String>>((ref) {
  return FavoriteRestaurantsController();
});

final selectedRestaurantIdProvider = StateProvider<String?>((ref) => null);

final baseRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  return ref.watch(mockRestaurantRepositoryProvider).nearbyRestaurants();
});

final restaurantsProvider = Provider<List<Restaurant>>((ref) {
  final favorites = ref.watch(favoriteRestaurantIdsProvider);
  final parties = ref.watch(matchingPartiesProvider).valueOrNull ?? const [];
  final apiRestaurants = ref.watch(matchingRestaurantsProvider).valueOrNull ??
      const <Restaurant>[];
  final restaurants = [
    ...ref.watch(baseRestaurantsProvider),
    ...apiRestaurants,
  ];

  return restaurants.map((restaurant) {
    final activePartyCount = parties
        .where((party) => party.restaurantId == restaurant.id)
        .where((party) => party.currentMembers < party.maxMembers)
        .length;

    return restaurant.copyWith(
      isFavorite: favorites.contains(restaurant.id),
      activePartyCount: activePartyCount,
    );
  }).toList();
});

final discoveryCategoriesProvider = Provider<List<String>>((ref) {
  final categories = ref.watch(restaurantsProvider).map((r) => r.category);
  return ['전체', ...categories.toSet()];
});

final filteredRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final restaurants = ref.watch(restaurantsProvider);

  if (selectedCategory == '전체') {
    return restaurants;
  }

  return restaurants
      .where((restaurant) => restaurant.category == selectedCategory)
      .toList();
});

final selectedRestaurantProvider = Provider<Restaurant?>((ref) {
  final restaurants = ref.watch(filteredRestaurantsProvider);
  if (restaurants.isEmpty) {
    return null;
  }

  final selectedId = ref.watch(selectedRestaurantIdProvider);
  return restaurants.firstWhere(
    (restaurant) => restaurant.id == selectedId,
    orElse: () => restaurants.first,
  );
});

final favoriteRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  return ref
      .watch(restaurantsProvider)
      .where((restaurant) => restaurant.isFavorite)
      .toList();
});

final restaurantByIdProvider = Provider.family<Restaurant?, String>((ref, id) {
  for (final restaurant in ref.watch(restaurantsProvider)) {
    if (restaurant.id == id) {
      return restaurant;
    }
  }
  return null;
});

class FavoriteRestaurantsController extends StateNotifier<Set<String>> {
  FavoriteRestaurantsController() : super(<String>{});

  void toggle(String restaurantId) {
    if (state.contains(restaurantId)) {
      state = {...state}..remove(restaurantId);
      return;
    }

    state = {...state, restaurantId};
  }
}
