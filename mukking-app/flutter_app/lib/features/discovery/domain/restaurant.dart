class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.distanceKm,
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
  final double distanceKm;
  final String imageUrl;
  final bool isFavorite;
  final int activePartyCount;
  final String imageLabel;
  final double markerDx;
  final double markerDy;

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)}km';

  Restaurant copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? distanceKm,
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
      distanceKm: distanceKm ?? this.distanceKm,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      activePartyCount: activePartyCount ?? this.activePartyCount,
      imageLabel: imageLabel ?? this.imageLabel,
      markerDx: markerDx ?? this.markerDx,
      markerDy: markerDy ?? this.markerDy,
    );
  }
}
