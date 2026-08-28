import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class RestaurantListQuery {
  const RestaurantListQuery({
    this.lat,
    this.lng,
    this.radiusKm,
    this.category,
    this.limit = 50,
    this.offset = 0,
  });

  final double? lat;
  final double? lng;
  final double? radiusKm;
  final String? category;
  final int limit;
  final int offset;

  Map<String, dynamic> toQueryParameters() {
    return {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radiusKm != null) 'radiusKm': radiusKm,
      if (category != null && category!.isNotEmpty) 'category': category,
      'limit': limit,
      'offset': offset,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantListQuery &&
        other.lat == lat &&
        other.lng == lng &&
        other.radiusKm == radiusKm &&
        other.category == category &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(
        lat,
        lng,
        radiusKm,
        category,
        limit,
        offset,
      );
}

class RestaurantDiscoverRequest {
  const RestaurantDiscoverRequest({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  final double latitude;
  final double longitude;
  final double radiusKm;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
      };
}

class RestaurantApi {
  const RestaurantApi(this._client);

  final ApiClient _client;

  Future<List<RestaurantDto>> list(RestaurantListQuery query) async {
    final rows = await _client.getList(
      ApiEndpoints.restaurants,
      queryParameters: query.toQueryParameters(),
    );
    return rows.whereType<Map>().map(RestaurantDto.fromJson).toList();
  }

  Future<List<RestaurantDto>> discover(
    RestaurantDiscoverRequest request,
  ) async {
    final rows = await _client.postList(
      ApiEndpoints.restaurantDiscover,
      data: request.toJson(),
    );
    return rows.whereType<Map>().map(RestaurantDto.fromJson).toList();
  }

  Future<RestaurantDto> getById(String restaurantId) async {
    final json = await _client.getMap(ApiEndpoints.restaurant(restaurantId));
    return RestaurantDto.fromJson(json);
  }

  Future<RestaurantDto> addFavorite(String restaurantId) async {
    final json = await _client.postMap(
      ApiEndpoints.restaurantFavorite(restaurantId),
    );
    return RestaurantDto.fromJson(json);
  }

  Future<void> removeFavorite(String restaurantId) async {
    await _client.deleteMap(ApiEndpoints.restaurantFavorite(restaurantId));
  }

  Future<List<RestaurantDto>> listFavorites() async {
    final rows = await _client.getList(ApiEndpoints.favoriteRestaurants);
    return rows.whereType<Map>().map(RestaurantDto.fromJson).toList();
  }
}

class RestaurantDto {
  const RestaurantDto({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.isFavorite,
    required this.activePartyCount,
    required this.distanceMeters,
    this.phone,
    this.roadAddress,
    this.placeUrl,
  });

  factory RestaurantDto.fromJson(Map<dynamic, dynamic> json) {
    final metadata = json['metadata'];
    final metadataMap = metadata is Map ? metadata : const <dynamic, dynamic>{};
    return RestaurantDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '식당 이름 없음',
      address: json['address'] as String? ?? '주소 확인 필요',
      category: json['category'] as String? ?? '맛집',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      activePartyCount: (json['activePartyCount'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.round(),
      phone: _optionalText(json['phone']),
      roadAddress: _optionalText(json['roadAddress']),
      placeUrl: _optionalText(metadataMap['placeUrl']) ??
          _optionalText(json['placeUrl']),
    );
  }

  final String id;
  final String name;
  final String address;
  final String category;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final bool isFavorite;
  final int activePartyCount;
  final int? distanceMeters;
  final String? phone;
  final String? roadAddress;
  final String? placeUrl;

  static String? _optionalText(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
