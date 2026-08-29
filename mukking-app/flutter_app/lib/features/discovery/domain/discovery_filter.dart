import 'restaurant.dart';

const allRestaurantCategory = '전체';

const restaurantCategoryOrder = <String>[
  '한식',
  '중식',
  '일식',
  '양식',
  '치킨',
  '고기',
  '카페/디저트',
  '술집',
  '분식',
  '기타',
];

enum RestaurantSortOption {
  distance,
  activePartyCount,
  favoriteFirst,
}

extension RestaurantSortOptionLabel on RestaurantSortOption {
  String get label => switch (this) {
        RestaurantSortOption.distance => '거리순',
        RestaurantSortOption.activePartyCount => '모집 많은 순',
        RestaurantSortOption.favoriteFirst => '찜 우선',
      };
}

class DiscoveryFilterState {
  const DiscoveryFilterState({
    this.query = '',
    this.selectedCategory = allRestaurantCategory,
    this.selectedSort = RestaurantSortOption.distance,
    this.favoritesOnly = false,
    this.activePartyOnly = false,
  });

  final String query;
  final String selectedCategory;
  final RestaurantSortOption selectedSort;
  final bool favoritesOnly;
  final bool activePartyOnly;

  bool get isActive =>
      normalizeRestaurantSearch(query).isNotEmpty ||
      selectedCategory != allRestaurantCategory ||
      favoritesOnly ||
      activePartyOnly;

  DiscoveryFilterState copyWith({
    String? query,
    String? selectedCategory,
    RestaurantSortOption? selectedSort,
    bool? favoritesOnly,
    bool? activePartyOnly,
  }) {
    return DiscoveryFilterState(
      query: query ?? this.query,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedSort: selectedSort ?? this.selectedSort,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      activePartyOnly: activePartyOnly ?? this.activePartyOnly,
    );
  }
}

String normalizeRestaurantSearch(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String mapRestaurantCategory(String category) {
  final normalized = normalizeRestaurantSearch(category);

  if (_containsAny(normalized, const [
    '치킨',
    '닭강정',
  ])) {
    return '치킨';
  }
  if (_containsAny(normalized, const [
    '이자카야',
    '술집',
    '주점',
    '호프',
    '포차',
    '와인바',
    '펍',
  ])) {
    return '술집';
  }
  if (_containsAny(normalized, const [
    '육류',
    '고기',
    '삼겹살',
    '갈비',
    '곡창',
    '정육',
  ])) {
    return '고기';
  }
  if (_containsAny(normalized, const [
    '카페',
    '디저트',
    '커피',
    '베이커리',
    '제과',
    '아이스크림',
  ])) {
    return '카페/디저트';
  }
  if (_containsAny(normalized, const [
    '분식',
    '떡볶이',
    '김밥',
  ])) {
    return '분식';
  }
  if (_containsAny(normalized, const [
    '중식',
    '중국요리',
    '중화요리',
  ])) {
    return '중식';
  }
  if (_containsAny(normalized, const [
    '일식',
    '초밥',
    '스시',
    '라멘',
    '돈카츠',
    '돈까스',
    '우동',
    '소바',
  ])) {
    return '일식';
  }
  if (_containsAny(normalized, const [
    '양식',
    '이탈리안',
    '파스타',
    '피자',
    '브런치',
    '스테이크',
    '햄버거',
  ])) {
    return '양식';
  }
  if (_containsAny(normalized, const [
    '한식',
    '국밥',
    '냉면',
    '족발',
    '보쌈',
    '찌개',
  ])) {
    return '한식';
  }
  return '기타';
}

List<Restaurant> filterRestaurants(
  List<Restaurant> restaurants,
  DiscoveryFilterState filter,
) {
  final query = normalizeRestaurantSearch(filter.query);

  return restaurants.where((restaurant) {
    final mappedCategory = mapRestaurantCategory(restaurant.category);
    final matchesCategory = filter.selectedCategory == allRestaurantCategory ||
        mappedCategory == filter.selectedCategory;
    if (!matchesCategory) return false;
    if (filter.favoritesOnly && !restaurant.isFavorite) return false;
    if (filter.activePartyOnly && restaurant.activePartyCount <= 0) {
      return false;
    }
    if (query.isEmpty) return true;

    final searchable = normalizeRestaurantSearch(
      '${restaurant.name} ${restaurant.category} $mappedCategory',
    );
    return searchable.contains(query);
  }).toList(growable: false);
}

List<Restaurant> filterAndSortRestaurants(
  List<Restaurant> restaurants,
  DiscoveryFilterState filter,
) {
  final visible = filterRestaurants(restaurants, filter).toList();
  visible.sort(_restaurantComparator(filter.selectedSort));
  return List.unmodifiable(visible);
}

Comparator<Restaurant> _restaurantComparator(RestaurantSortOption option) {
  return switch (option) {
    RestaurantSortOption.distance => _compareByDistance,
    RestaurantSortOption.activePartyCount => _compareByActivePartyCount,
    RestaurantSortOption.favoriteFirst => _compareByFavoriteFirst,
  };
}

int _compareByDistance(Restaurant first, Restaurant second) {
  final firstDistance = first.distanceMeters;
  final secondDistance = second.distanceMeters;

  if (firstDistance == null && secondDistance != null) return 1;
  if (firstDistance != null && secondDistance == null) return -1;
  if (firstDistance != null && secondDistance != null) {
    final distanceOrder = firstDistance.compareTo(secondDistance);
    if (distanceOrder != 0) return distanceOrder;
  }
  return first.id.compareTo(second.id);
}

int _compareByActivePartyCount(Restaurant first, Restaurant second) {
  final partyOrder = second.activePartyCount.compareTo(first.activePartyCount);
  if (partyOrder != 0) return partyOrder;
  return _compareByDistance(first, second);
}

int _compareByFavoriteFirst(Restaurant first, Restaurant second) {
  if (first.isFavorite != second.isFavorite) {
    return first.isFavorite ? -1 : 1;
  }
  return _compareByDistance(first, second);
}

bool _containsAny(String value, List<String> candidates) {
  return candidates.any(value.contains);
}
