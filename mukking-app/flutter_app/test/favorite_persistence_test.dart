import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukking_flutter_app/core/config/app_config.dart';
import 'package:mukking_flutter_app/core/network/api_client.dart';
import 'package:mukking_flutter_app/core/network/auth_interceptor.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_state.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_api.dart';
import 'package:mukking_flutter_app/features/discovery/data/restaurant_repository.dart';
import 'package:mukking_flutter_app/features/discovery/domain/restaurant.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';

final _authStateHarnessProvider = StateProvider<MukkingAuthState>((ref) {
  return const MukkingAuthState.loading();
});

void main() {
  test('API hydration keeps server favorite after provider reload', () async {
    final repository = _FakeRestaurantRepository(initialFavorite: true);
    final container = _apiContainer(repository);
    addTearDown(container.dispose);

    final firstLoad = await container.read(restaurantFeedProvider.future);
    expect(firstLoad.single.isFavorite, isTrue);
    expect(container.read(restaurantsProvider).single.isFavorite, isTrue);

    container.invalidate(restaurantFeedProvider);
    final reloaded = await container.read(restaurantFeedProvider.future);
    expect(reloaded.single.isFavorite, isTrue);
    expect(repository.listCalls, 2);
    expect(repository.favoriteListCalls, 2);
  });

  test('favorite POST and DELETE converge to refetched API state', () async {
    final repository = _FakeRestaurantRepository(initialFavorite: false);
    final container = _apiContainer(repository);
    addTearDown(container.dispose);

    await container.read(restaurantFeedProvider.future);
    var restaurant = container.read(restaurantsProvider).single;
    expect(restaurant.isFavorite, isFalse);

    await container.read(favoriteOverridesProvider.notifier).toggle(restaurant);
    restaurant = container.read(restaurantsProvider).single;
    expect(restaurant.isFavorite, isTrue);
    expect(repository.favoriteAdds, 1);

    await container.read(favoriteOverridesProvider.notifier).toggle(restaurant);
    restaurant = container.read(restaurantsProvider).single;
    expect(restaurant.isFavorite, isFalse);
    expect(repository.favoriteRemoves, 1);
    expect(repository.listCalls, 3);
  });

  test('restaurant request waits for auth ready then refetches', () async {
    final repository = _FakeRestaurantRepository(initialFavorite: true);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.test(dataSource: AppDataSource.api),
        ),
        restaurantRepositoryProvider.overrideWithValue(repository),
        restaurantAuthStateProvider.overrideWith(
          (ref) => ref.watch(_authStateHarnessProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(restaurantFeedProvider.future), isEmpty);
    expect(repository.listCalls, 0);

    container.read(_authStateHarnessProvider.notifier).state = _authenticated;
    final hydrated = await container.read(restaurantFeedProvider.future);
    expect(hydrated.single.isFavorite, isTrue);
    expect(repository.listCalls, 1);
  });

  test('favorite HTTP methods attach authorization without logging token',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(readAccessToken: () async => 'test-token'),
      );
    final api = RestaurantApi(ApiClient(dio));

    final added = await api.addFavorite('restaurant-1');
    await api.removeFavorite('restaurant-1');

    expect(added.isFavorite, isTrue);
    expect(
        adapter.requests.map((request) => request.method), ['POST', 'DELETE']);
    expect(
      adapter.requests.map((request) => request.path),
      everyElement('/api/restaurants/restaurant-1/favorite'),
    );
    expect(
      adapter.requests.every(
        (request) => request.headers['Authorization'] != null,
      ),
      isTrue,
    );
  });
}

ProviderContainer _apiContainer(RestaurantRepository repository) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.test(dataSource: AppDataSource.api),
      ),
      restaurantRepositoryProvider.overrideWithValue(repository),
      restaurantAuthStateProvider.overrideWithValue(_authenticated),
    ],
  );
}

final _authenticated = MukkingAuthState.authenticated(
  user: AuthUser.fallback(id: 'user-1', email: 'user@example.com'),
);

class _FakeRestaurantRepository implements RestaurantRepository {
  _FakeRestaurantRepository({required bool initialFavorite})
      : _isFavorite = initialFavorite;

  bool _isFavorite;
  int listCalls = 0;
  int favoriteListCalls = 0;
  int favoriteAdds = 0;
  int favoriteRemoves = 0;

  Restaurant get _restaurant => Restaurant(
        id: 'restaurant-1',
        name: '지속성 테스트 식당',
        category: '한식',
        address: '서울시 성동구',
        latitude: 37.5,
        longitude: 127.0,
        distanceMeters: 420,
        imageUrl: '',
        isFavorite: _isFavorite,
        activePartyCount: 1,
        imageLabel: '테스트 음식',
        markerDx: 0.4,
        markerDy: 0.4,
      );

  @override
  Future<Restaurant?> getById(String restaurantId) async => _restaurant;

  @override
  Future<List<Restaurant>> list(RestaurantListQuery query) async {
    listCalls += 1;
    return [_restaurant];
  }

  @override
  Future<List<Restaurant>> listFavorites() async {
    favoriteListCalls += 1;
    return _isFavorite ? [_restaurant] : [];
  }

  @override
  Future<Restaurant> setFavorite(
    Restaurant restaurant,
    bool isFavorite,
  ) async {
    _isFavorite = isFavorite;
    if (isFavorite) {
      favoriteAdds += 1;
    } else {
      favoriteRemoves += 1;
    }
    return _restaurant;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') {
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'id': 'restaurant-1',
        'name': '지속성 테스트 식당',
        'address': '서울시 성동구',
        'category': '한식',
        'latitude': 37.5,
        'longitude': 127.0,
        'isFavorite': true,
        'activePartyCount': 1,
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
