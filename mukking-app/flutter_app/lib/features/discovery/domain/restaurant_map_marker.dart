import 'restaurant.dart';

enum RestaurantMapMarkerStatus {
  normal,
  favorite,
  activeParty,
  urgentParty;
}

class RestaurantMapMarker {
  const RestaurantMapMarker({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final RestaurantMapMarkerStatus status;
}

List<RestaurantMapMarker> buildRestaurantMapMarkers(
  Iterable<Restaurant> restaurants, {
  Set<String> urgentRestaurantIds = const {},
}) {
  final seenIds = <String>{};
  final markers = <RestaurantMapMarker>[];

  for (final restaurant in restaurants) {
    final latitude = restaurant.latitude;
    final longitude = restaurant.longitude;
    if (latitude == null || longitude == null || !seenIds.add(restaurant.id)) {
      continue;
    }

    final status = restaurant.isFavorite
        ? RestaurantMapMarkerStatus.favorite
        : urgentRestaurantIds.contains(restaurant.id)
            ? RestaurantMapMarkerStatus.urgentParty
            : restaurant.activePartyCount > 0
                ? RestaurantMapMarkerStatus.activeParty
                : RestaurantMapMarkerStatus.normal;

    markers.add(
      RestaurantMapMarker(
        id: restaurant.id,
        name: restaurant.name,
        latitude: latitude,
        longitude: longitude,
        status: status,
      ),
    );
  }

  return markers;
}
