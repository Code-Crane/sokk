import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/restaurant.dart';

final mockRestaurantRepositoryProvider =
    Provider<MockRestaurantRepository>((ref) {
  return const MockRestaurantRepository();
});

final nearbyRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  return ref.watch(mockRestaurantRepositoryProvider).nearbyRestaurants();
});

class MockRestaurantRepository {
  const MockRestaurantRepository();

  List<Restaurant> nearbyRestaurants() {
    return const [
      Restaurant(
        id: 'restaurant-001',
        name: '멘야 하쿠',
        category: '라멘',
        address: '서울 성수동 연무장길 12',
        distanceKm: 0.8,
        imageUrl: 'mock://ramen',
        isFavorite: false,
        activePartyCount: 2,
        imageLabel: '돈코츠 라멘',
        markerDx: 0.24,
        markerDy: 0.32,
      ),
      Restaurant(
        id: 'restaurant-002',
        name: '성수 숯불연구소',
        category: '고기',
        address: '서울 성수동 아차산로 42',
        distanceKm: 1.2,
        imageUrl: 'mock://kbbq',
        isFavorite: false,
        activePartyCount: 1,
        imageLabel: '숯불 삼겹살',
        markerDx: 0.68,
        markerDy: 0.48,
      ),
      Restaurant(
        id: 'restaurant-003',
        name: '크림 아틀리에',
        category: '디저트',
        address: '서울 서울숲2길 7',
        distanceKm: 0.6,
        imageUrl: 'mock://dessert',
        isFavorite: false,
        activePartyCount: 3,
        imageLabel: '과일 타르트',
        markerDx: 0.44,
        markerDy: 0.68,
      ),
      Restaurant(
        id: 'restaurant-004',
        name: '초록 키친',
        category: '브런치',
        address: '서울 성수이로 18',
        distanceKm: 1.6,
        imageUrl: 'mock://brunch',
        isFavorite: false,
        activePartyCount: 0,
        imageLabel: '아보카도 브런치',
        markerDx: 0.78,
        markerDy: 0.22,
      ),
    ];
  }
}
