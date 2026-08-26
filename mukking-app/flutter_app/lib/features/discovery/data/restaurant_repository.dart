import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/restaurant.dart';
import 'mock_restaurant_repository.dart';
import 'restaurant_api.dart';

abstract class RestaurantRepository {
  Future<List<Restaurant>> list(RestaurantListQuery query);
  Future<Restaurant?> getById(String restaurantId);
  Future<Restaurant> setFavorite(Restaurant restaurant, bool isFavorite);
  Future<List<Restaurant>> listFavorites();
}

final restaurantApiProvider = Provider<RestaurantApi>((ref) {
  return RestaurantApi(ref.watch(apiClientProvider));
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  if (ref.watch(appConfigProvider).usesApiData) {
    return ApiRestaurantRepository(ref.watch(restaurantApiProvider));
  }
  return MockRestaurantDataRepository(
    ref.watch(mockRestaurantRepositoryProvider),
  );
});

class ApiRestaurantRepository implements RestaurantRepository {
  const ApiRestaurantRepository(this._api);

  final RestaurantApi _api;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async {
    final rows = await _api.list(query);
    return [for (var i = 0; i < rows.length; i++) _toDomain(rows[i], i)];
  }

  @override
  Future<Restaurant?> getById(String restaurantId) async {
    return _toDomain(await _api.getById(restaurantId), 0);
  }

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    if (isFavorite) {
      return _toDomain(await _api.addFavorite(restaurant.id), 0);
    }
    await _api.removeFavorite(restaurant.id);
    return restaurant.copyWith(isFavorite: false);
  }

  @override
  Future<List<Restaurant>> listFavorites() async {
    final rows = await _api.listFavorites();
    return [for (var i = 0; i < rows.length; i++) _toDomain(rows[i], i)];
  }

  Restaurant _toDomain(RestaurantDto dto, int index) {
    return Restaurant(
      id: dto.id,
      name: dto.name,
      category: dto.category,
      address: dto.address,
      distanceMeters: dto.distanceMeters,
      imageUrl: dto.imageUrl ?? '',
      isFavorite: dto.isFavorite,
      activePartyCount: dto.activePartyCount,
      imageLabel: dto.name,
      markerDx: 0.18 + (index % 3) * 0.26,
      markerDy: 0.2 + (index % 4) * 0.16,
    );
  }
}

class MockRestaurantDataRepository implements RestaurantRepository {
  const MockRestaurantDataRepository(this._repository);

  final MockRestaurantRepository _repository;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async {
    var rows = _repository.nearbyRestaurants();
    if (query.category != null && query.category!.isNotEmpty) {
      rows = rows.where((row) => row.category == query.category).toList();
    }
    return rows.skip(query.offset).take(query.limit).toList();
  }

  @override
  Future<Restaurant?> getById(String restaurantId) async {
    for (final restaurant in _repository.nearbyRestaurants()) {
      if (restaurant.id == restaurantId) return restaurant;
    }
    return null;
  }

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    return restaurant.copyWith(isFavorite: isFavorite);
  }

  @override
  Future<List<Restaurant>> listFavorites() async {
    return _repository
        .nearbyRestaurants()
        .where((restaurant) => restaurant.isFavorite)
        .toList();
  }
}
