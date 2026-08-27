class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.imageUrl,
    required this.isFavorite,
    required this.activePartyCount,
    required this.imageLabel,
    required this.markerDx,
    required this.markerDy,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final double? latitude;
  final double? longitude;
  final int? distanceMeters;
  final String imageUrl;
  final bool isFavorite;
  final int activePartyCount;
  final String imageLabel;
  final double markerDx;
  final double markerDy;

  String get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return '거리 정보 없음';
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Restaurant copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    int? distanceMeters,
    bool clearDistance = false,
    String? imageUrl,
    bool? isFavorite,
    int? activePartyCount,
    String? imageLabel,
    double? markerDx,
    double? markerDy,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      latitude: clearLatitude ? null : latitude ?? this.latitude,
      longitude: clearLongitude ? null : longitude ?? this.longitude,
      distanceMeters:
          clearDistance ? null : distanceMeters ?? this.distanceMeters,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      activePartyCount: activePartyCount ?? this.activePartyCount,
      imageLabel: imageLabel ?? this.imageLabel,
      markerDx: markerDx ?? this.markerDx,
      markerDy: markerDy ?? this.markerDy,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}
