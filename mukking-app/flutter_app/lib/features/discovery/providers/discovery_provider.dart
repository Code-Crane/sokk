import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/restaurant_api.dart';
import '../data/restaurant_repository.dart';
import '../domain/restaurant.dart';

final selectedCategoryProvider = StateProvider<String>((ref) => '전체');
final selectedRestaurantIdProvider = StateProvider<String?>((ref) => null);

final restaurantListQueryProvider = StateProvider<RestaurantListQuery>((ref) {
  return const RestaurantListQuery(limit: 50, offset: 0);
});

final restaurantAuthStateProvider = Provider<MukkingAuthState>((ref) {
  return ref.watch(authControllerProvider);
});

final restaurantFeedProvider = FutureProvider<List<Restaurant>>((ref) async {
  final config = ref.watch(appConfigProvider);
  final repository = ref.watch(restaurantRepositoryProvider);
  final query = ref.watch(restaurantListQueryProvider);

  if (!config.usesApiData) {
    return repository.list(query);
  }

  final authState = ref.watch(restaurantAuthStateProvider);
  if (authState.isLoading) {
    return const <Restaurant>[];
  }
  if (!authState.isAuthenticated) {
    throw const ApiError(
      kind: ApiErrorKind.unauthorized,
      statusCode: 401,
      userMessage: '로그인이 필요해요.',
    );
  }

  final results = await Future.wait([
    repository.list(query),
    repository.listFavorites(),
  ]);
  final favoriteIds = results[1].map((restaurant) => restaurant.id).toSet();

  return results[0]
      .map(
        (restaurant) => restaurant.copyWith(
          isFavorite:
              restaurant.isFavorite || favoriteIds.contains(restaurant.id),
        ),
      )
      .toList();
});

final favoriteRestaurantsApiProvider = FutureProvider<List<Restaurant>>((ref) {
  return ref.watch(restaurantRepositoryProvider).listFavorites();
});

final favoriteOverridesProvider =
    StateNotifierProvider<FavoriteRestaurantsController, Map<String, bool>>(
        (ref) {
  return FavoriteRestaurantsController(
    ref: ref,
    repository: ref.watch(restaurantRepositoryProvider),
    refreshFromServer: ref.watch(appConfigProvider).usesApiData,
  );
});

final restaurantsProvider = Provider<List<Restaurant>>((ref) {
  final overrides = ref.watch(favoriteOverridesProvider);
  final feed = ref.watch(restaurantFeedProvider).valueOrNull;

  if (feed == null) return const <Restaurant>[];

  return feed
      .map(
        (restaurant) => restaurant.copyWith(
          isFavorite: overrides[restaurant.id] ?? restaurant.isFavorite,
        ),
      )
      .toList();
});

final favoriteRestaurantIdsProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(restaurantsProvider)
      .where((restaurant) => restaurant.isFavorite)
      .map((restaurant) => restaurant.id)
      .toSet();
});

final discoveryCategoriesProvider = Provider<List<String>>((ref) {
  final categories = ref.watch(restaurantsProvider).map((r) => r.category);
  return ['전체', ...categories.toSet()];
});

final filteredRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final restaurants = ref.watch(restaurantsProvider);

  if (selectedCategory == '전체') return restaurants;
  return restaurants
      .where((restaurant) => restaurant.category == selectedCategory)
      .toList();
});

final selectedRestaurantProvider = Provider<Restaurant?>((ref) {
  final restaurants = ref.watch(filteredRestaurantsProvider);
  if (restaurants.isEmpty) return null;

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
    if (restaurant.id == id) return restaurant;
  }
  return null;
});

class FavoriteRestaurantsController extends StateNotifier<Map<String, bool>> {
  FavoriteRestaurantsController({
    required Ref ref,
    required RestaurantRepository repository,
    required bool refreshFromServer,
  })  : _ref = ref,
        _repository = repository,
        _refreshFromServer = refreshFromServer,
        super(const {});

  final Ref _ref;
  final RestaurantRepository _repository;
  final bool _refreshFromServer;

  Future<void> toggle(Restaurant restaurant) async {
    final previousOverride = state[restaurant.id];
    final current = previousOverride ?? restaurant.isFavorite;
    state = {...state, restaurant.id: !current};

    try {
      await _repository.setFavorite(restaurant, !current);
      if (_refreshFromServer) {
        _ref.invalidate(restaurantFeedProvider);
        _ref.invalidate(favoriteRestaurantsApiProvider);
        await _ref.read(restaurantFeedProvider.future);
        state = {...state}..remove(restaurant.id);
      }
    } catch (_) {
      final restored = {...state}..remove(restaurant.id);
      if (previousOverride != null) {
        restored[restaurant.id] = previousOverride;
      }
      state = restored;
      rethrow;
    }
  }
}
