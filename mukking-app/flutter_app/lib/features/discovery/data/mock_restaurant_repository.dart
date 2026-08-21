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
        region: '서울 성수동',
        category: '라멘',
        distanceLabel: '약 850m',
        waitingSignal: '관심 12명',
        partyCount: 2,
        imageLabel: '돈코츠 라멘',
        markerDx: 0.24,
        markerDy: 0.32,
      ),
      Restaurant(
        id: 'restaurant-002',
        name: '성수 숯불연구소',
        region: '서울 성수동',
        category: '고기',
        distanceLabel: '약 1.2km',
        waitingSignal: '관심 8명',
        partyCount: 1,
        imageLabel: '숯불 삼겹살',
        markerDx: 0.68,
        markerDy: 0.48,
      ),
      Restaurant(
        id: 'restaurant-003',
        name: '크림 아틀리에',
        region: '서울 서울숲',
        category: '디저트',
        distanceLabel: '약 600m',
        waitingSignal: '관심 21명',
        partyCount: 3,
        imageLabel: '과일 타르트',
        markerDx: 0.44,
        markerDy: 0.68,
      ),
    ];
  }
}
