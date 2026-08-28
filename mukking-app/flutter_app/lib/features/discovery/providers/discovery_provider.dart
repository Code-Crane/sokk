import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/restaurant_api.dart';
import '../data/restaurant_repository.dart';
import '../domain/map_camera_center.dart';
import '../domain/restaurant.dart';

final selectedCategoryProvider = StateProvider<String>((ref) => '전체');
final selectedRestaurantIdProvider = StateProvider<String?>((ref) => null);
final selectedRestaurantFocusRequestProvider = StateProvider<int>((ref) => 0);

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
      status: SearchAreaStatus.idle,
      clearError: true,
    );
  }

  Future<bool> searchCurrentArea() async {
    final center = state.center;
    if (center == null || state.isLoading) return false;

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
      _ref.read(restaurantListQueryProvider.notifier).state = nextQuery;
      await _ref.read(restaurantFeedProvider.future);
      state = state.copyWith(
        center: center,
        lastSearchedCenter: center,
        status: SearchAreaStatus.idle,
        hasMovedMeaningfully: false,
        clearError: true,
        clearPreservedRestaurants: true,
      );
      return true;
    } catch (error) {
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
    state = SearchAreaState(
      center: center,
      lastSearchedCenter: center,
    );
  }

  void reset() {
    state = const SearchAreaState();
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
