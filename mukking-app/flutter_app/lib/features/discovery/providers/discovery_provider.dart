import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/restaurant_api.dart';
import '../data/restaurant_repository.dart';
import '../domain/discovery_filter.dart';
import '../domain/map_camera_center.dart';
import '../domain/restaurant.dart';

final selectedRestaurantIdProvider = StateProvider<String?>((ref) => null);
final selectedRestaurantFocusRequestProvider = StateProvider<int>((ref) => 0);

final discoveryFilterProvider =
    StateNotifierProvider<DiscoveryFilterController, DiscoveryFilterState>(
        (ref) {
  return DiscoveryFilterController(ref);
});

class DiscoveryFilterController extends StateNotifier<DiscoveryFilterState> {
  DiscoveryFilterController(this._ref) : super(const DiscoveryFilterState());

  final Ref _ref;

  void updateQuery(String query) {
    state = state.copyWith(query: query);
    _clearSelectionIfExcluded();
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    _clearSelectionIfExcluded();
  }

  void selectSort(RestaurantSortOption sort) {
    state = state.copyWith(selectedSort: sort);
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
    _clearSelectionIfExcluded();
  }

  void toggleActivePartyOnly() {
    state = state.copyWith(activePartyOnly: !state.activePartyOnly);
    _clearSelectionIfExcluded();
  }

  void clearCriteria() {
    state = DiscoveryFilterState(selectedSort: state.selectedSort);
    _clearSelectionIfExcluded();
  }

  void clear() {
    state = const DiscoveryFilterState();
    _clearSelectionIfExcluded();
  }

  void _clearSelectionIfExcluded() {
    _clearSelectedRestaurantIfExcluded(_ref, filter: state);
  }
}

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

  final restaurants = await repository.list(query);
  List<Restaurant> favorites;
  try {
    favorites = await repository.listFavorites();
  } catch (_) {
    // RestaurantResponse already carries isFavorite. Favorite hydration is
    // supplemental and must not turn a successful nearby list into a failure.
    return restaurants;
  }
  final favoriteIds = favorites.map((restaurant) => restaurant.id).toSet();

  return restaurants
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

enum SearchAreaStatus { idle, loading, error }

class SearchAreaState {
  const SearchAreaState({
    this.center,
    this.lastSearchedCenter,
    this.status = SearchAreaStatus.idle,
    this.hasMovedMeaningfully = false,
    this.errorMessage,
    this.preservedRestaurants,
  });

  final MapCameraCenter? center;
  final MapCameraCenter? lastSearchedCenter;
  final SearchAreaStatus status;
  final bool hasMovedMeaningfully;
  final String? errorMessage;
  final List<Restaurant>? preservedRestaurants;

  bool get isLoading => status == SearchAreaStatus.loading;

  SearchAreaState copyWith({
    MapCameraCenter? center,
    MapCameraCenter? lastSearchedCenter,
    SearchAreaStatus? status,
    bool? hasMovedMeaningfully,
    String? errorMessage,
    bool clearError = false,
    List<Restaurant>? preservedRestaurants,
    bool clearPreservedRestaurants = false,
  }) {
    return SearchAreaState(
      center: center ?? this.center,
      lastSearchedCenter: lastSearchedCenter ?? this.lastSearchedCenter,
      status: status ?? this.status,
      hasMovedMeaningfully: hasMovedMeaningfully ?? this.hasMovedMeaningfully,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      preservedRestaurants: clearPreservedRestaurants
          ? null
          : preservedRestaurants ?? this.preservedRestaurants,
    );
  }
}

final searchAreaProvider =
    StateNotifierProvider<SearchAreaController, SearchAreaState>((ref) {
  return SearchAreaController(
    ref: ref,
    repository: ref.watch(restaurantRepositoryProvider),
  );
});

class SearchAreaController extends StateNotifier<SearchAreaState> {
  SearchAreaController({
    required Ref ref,
    required RestaurantRepository repository,
  })  : _ref = ref,
        _repository = repository,
        super(const SearchAreaState());

  static const radiusKm = 2.0;
  static const _meaningfulCoordinateDelta = 0.00015;

  final Ref _ref;
  final RestaurantRepository _repository;
  int _operationId = 0;

  void onCameraIdle(MapCameraIdleEvent event) {
    final previousCenter = state.center;
    if (!event.userInitiated) {
      state = state.copyWith(
        center: event.center,
        lastSearchedCenter: state.hasMovedMeaningfully
            ? state.lastSearchedCenter
            : event.center,
      );
      return;
    }

    final anchor = state.lastSearchedCenter ?? previousCenter ?? event.center;
    state = state.copyWith(
      center: event.center,
      lastSearchedCenter: anchor,
      hasMovedMeaningfully: _hasMeaningfullyMoved(anchor, event.center),
      status:
          state.isLoading ? SearchAreaStatus.loading : SearchAreaStatus.idle,
      clearError: true,
    );
  }

  Future<bool> searchCurrentArea() async {
    final center = state.center;
    if (center == null || state.isLoading) return false;
    final operationId = ++_operationId;

    final previousQuery = _ref.read(restaurantListQueryProvider);
    final favoriteOverrides = _ref.read(favoriteOverridesProvider);
    final currentFeed = _ref.read(restaurantFeedProvider).valueOrNull;
    final preserved =
        (currentFeed ?? state.preservedRestaurants ?? const <Restaurant>[])
            .map(
              (restaurant) => restaurant.copyWith(
                isFavorite:
                    favoriteOverrides[restaurant.id] ?? restaurant.isFavorite,
              ),
            )
            .toList();
    state = state.copyWith(
      status: SearchAreaStatus.loading,
      clearError: true,
      preservedRestaurants: preserved,
    );

    final nextQuery = RestaurantListQuery(
      lat: center.latitude,
      lng: center.longitude,
      radiusKm: radiusKm,
      category: previousQuery.category,
      limit: 50,
      offset: 0,
    );

    try {
      await _repository.discover(
        RestaurantDiscoverRequest(
          latitude: center.latitude,
          longitude: center.longitude,
          radiusKm: radiusKm,
        ),
      );
      if (operationId != _operationId) return true;
      _ref.read(restaurantListQueryProvider.notifier).state = nextQuery;
      await _refreshLatestRestaurantFeed();
      if (operationId != _operationId) return true;
      _clearSelectedRestaurantIfExcluded(_ref);
      final visibleCenter = state.center ?? center;
      state = state.copyWith(
        center: visibleCenter,
        lastSearchedCenter: center,
        status: SearchAreaStatus.idle,
        hasMovedMeaningfully: _hasMeaningfullyMoved(center, visibleCenter),
        clearError: true,
        clearPreservedRestaurants: true,
      );
      return true;
    } catch (error) {
      if (operationId != _operationId) return true;
      if (_ref.read(restaurantListQueryProvider) != previousQuery) {
        _ref.read(restaurantListQueryProvider.notifier).state = previousQuery;
      }
      state = state.copyWith(
        status: SearchAreaStatus.error,
        hasMovedMeaningfully: true,
        errorMessage: error is ApiError
            ? error.userMessage
            : '이 지역의 식당을 불러오지 못했어요. 다시 시도해주세요.',
        preservedRestaurants: preserved,
      );
      return false;
    }
  }

  void resetForExternalCenter(MapCameraCenter center) {
    _operationId += 1;
    state = SearchAreaState(
      center: center,
      lastSearchedCenter: center,
    );
  }

  void reset() {
    _operationId += 1;
    state = const SearchAreaState();
  }

  Future<void> _refreshLatestRestaurantFeed() async {
    try {
      final refreshedFeed = _ref.refresh(restaurantFeedProvider.future);
      await refreshedFeed;
    } on ApiError catch (error) {
      if (error.kind != ApiErrorKind.cancelled) rethrow;
      // A provider generation can be cancelled when the query invalidation
      // and an explicit refresh overlap. Await the currently active generation.
      await _ref.read(restaurantFeedProvider.future);
    }
  }

  bool _hasMeaningfullyMoved(
    MapCameraCenter first,
    MapCameraCenter second,
  ) {
    return (first.latitude - second.latitude).abs() >=
            _meaningfulCoordinateDelta ||
        (first.longitude - second.longitude).abs() >=
            _meaningfulCoordinateDelta;
  }
}

final restaurantsProvider = Provider<List<Restaurant>>((ref) {
  final overrides = ref.watch(favoriteOverridesProvider);
  final searchArea = ref.watch(searchAreaProvider);
  final feed = searchArea.preservedRestaurants ??
      ref.watch(restaurantFeedProvider).valueOrNull;

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
  final filter = ref.watch(discoveryFilterProvider);
  final available = ref
      .watch(restaurantsProvider)
      .map((restaurant) => mapRestaurantCategory(restaurant.category))
      .toSet();
  final categories = <String>[allRestaurantCategory];

  for (final category in restaurantCategoryOrder) {
    if (available.contains(category) || filter.selectedCategory == category) {
      categories.add(category);
    }
  }
  return categories;
});

final filteredRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final filter = ref.watch(discoveryFilterProvider);
  final restaurants = ref.watch(restaurantsProvider);
  return filterAndSortRestaurants(restaurants, filter);
});

final selectedRestaurantProvider = Provider<Restaurant?>((ref) {
  final restaurants = ref.watch(filteredRestaurantsProvider);
  final selectedId = ref.watch(selectedRestaurantIdProvider);
  if (selectedId == null) return null;
  for (final restaurant in restaurants) {
    if (restaurant.id == selectedId) return restaurant;
  }
  return null;
});

void _clearSelectedRestaurantIfExcluded(
  Ref ref, {
  DiscoveryFilterState? filter,
}) {
  final selectedId = ref.read(selectedRestaurantIdProvider);
  if (selectedId == null) return;
  final filtered = filterRestaurants(
    ref.read(restaurantsProvider),
    filter ?? ref.read(discoveryFilterProvider),
  );
  if (filtered.any((restaurant) => restaurant.id == selectedId)) return;
  ref.read(selectedRestaurantIdProvider.notifier).state = null;
}

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

final restaurantDetailSourceProvider =
    FutureProvider.family<Restaurant?, String>((ref, restaurantId) async {
  final cached = ref.watch(restaurantByIdProvider(restaurantId));
  if (cached != null) return cached;

  final config = ref.watch(appConfigProvider);
  if (config.usesApiData) {
    final authState = ref.watch(restaurantAuthStateProvider);
    if (authState.isLoading) return null;
    if (!authState.isAuthenticated) {
      throw const ApiError(
        kind: ApiErrorKind.unauthorized,
        statusCode: 401,
        userMessage: '로그인이 필요해요.',
      );
    }
  }

  return ref.watch(restaurantRepositoryProvider).getById(restaurantId);
});

final restaurantDetailProvider =
    Provider.family<AsyncValue<Restaurant?>, String>((ref, restaurantId) {
  final favoriteOverride = ref.watch(favoriteOverridesProvider)[restaurantId];
  return ref.watch(restaurantDetailSourceProvider(restaurantId)).whenData(
        (restaurant) => restaurant?.copyWith(
          isFavorite: favoriteOverride ?? restaurant.isFavorite,
        ),
      );
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
    final nextFavorite = !current;
    final clearSelection = !nextFavorite &&
        _ref.read(discoveryFilterProvider).favoritesOnly &&
        _ref.read(selectedRestaurantIdProvider) == restaurant.id;
    state = {...state, restaurant.id: nextFavorite};
    if (clearSelection) {
      _ref.read(selectedRestaurantIdProvider.notifier).state = null;
    }

    try {
      await _repository.setFavorite(restaurant, nextFavorite);
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
      if (clearSelection) {
        _ref.read(selectedRestaurantIdProvider.notifier).state = restaurant.id;
      }
      rethrow;
    }
  }
}
